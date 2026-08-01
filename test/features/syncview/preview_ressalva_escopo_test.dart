// test/features/syncview/preview_ressalva_escopo_test.dart
//
// G-E / A4 no preview do atendimento: a frase que qualifica o card ("isto é
// pré-visualização, não fato fiscal") é redigida pelo backend
// (`SimularNotaRessalvas`) e exibida COMO VEIO. Derivar/parafrasear na tela foi
// o gap que o G-E fechou — por isso os testes assertam texto exato e a ausência
// da copy local quando a canônica chega.

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medvie/core/models/medico.dart';
import 'package:medvie/core/providers/nota_fiscal_provider.dart';
import 'package:medvie/core/providers/onboarding_provider.dart';
import 'package:medvie/core/providers/servico_provider.dart';
import 'package:medvie/core/services/medvie_api_service.dart';
import 'package:medvie/features/syncview/widgets/atendimento_cnpj_flow.dart';
import 'package:medvie/features/syncview/widgets/preview_fiscal_cnpj_card.dart';

class _MockApi extends Mock implements MedvieApiService {}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

const _ressalvaBackend =
    'Pré-visualização. Sem tomador escolhido, ISS/IRRF/CSRF ainda não foram '
    'avaliados — retenções só se realizam após evento autoritativo (NFS-e '
    'autorizada / Split confirmado pelo ADN). IBS/CBS em 2026 seguem '
    'informativos — Split só a partir de 2027/2029.';

const _fallbackLocal =
    'Retenções e IBS/CBS são definidos no envio. A UI não infere alíquota — o '
    'cálculo oficial vem do backend.';

Widget _card({String ressalva = ''}) => MaterialApp(
      home: Scaffold(
        body: PreviewFiscalCnpjCard(
          bruto: 1000,
          retemIss: false,
          retemIrrf: false,
          liquido: 1000,
          backendCalculado: true,
          ressalvaEscopo: ressalva,
        ),
      ),
    );

void main() {
  group('PreviewFiscalCnpjCard — ressalva de escopo', () {
    testWidgets('exibe a frase do backend sem reescrevê-la', (tester) async {
      await tester.pumpWidget(_card(ressalva: _ressalvaBackend));

      expect(find.text(_ressalvaBackend), findsOneWidget);
    });

    testWidgets('não repete a copy local quando a canônica chega',
        (tester) async {
      await tester.pumpWidget(_card(ressalva: _ressalvaBackend));

      expect(find.text(_fallbackLocal), findsNothing);
    });

    testWidgets('mantém a copy local quando o backend não manda a ressalva',
        (tester) async {
      await tester.pumpWidget(_card());

      expect(find.text(_fallbackLocal), findsOneWidget);
    });
  });

  // O card só pode mostrar R$ nas linhas de retenção quando o preview foi
  // pedido COM tomador — zero por falta de avaliação não é zero apurado, e um
  // líquido que já desconta retenção não é "Valor da NFS-e".
  group('PreviewFiscalCnpjCard — retenções avaliadas', () {
    Widget cardComRetencoes({required bool avaliadas}) => MaterialApp(
          home: Scaffold(
            body: PreviewFiscalCnpjCard(
              bruto: 1000,
              retemIss: true,
              retemIrrf: true,
              liquido: avaliadas ? 918.50 : 1000,
              backendCalculado: true,
              retencoesAvaliadas: avaliadas,
              issRetido: 20,
              irrfRetido: 15,
              csrfRetido: 46.50,
            ),
          ),
        );

    testWidgets('avaliadas: exibe os valores retidos e a linha de CSRF',
        (tester) async {
      await tester.pumpWidget(cardComRetencoes(avaliadas: true));

      // `textContaining`: o NumberFormat pt_BR separa símbolo e valor com NBSP.
      expect(find.textContaining('20,00'), findsOneWidget);
      expect(find.textContaining('15,00'), findsOneWidget);
      expect(find.text('PIS/COFINS/CSLL retidos'), findsOneWidget);
      expect(find.textContaining('46,50'), findsOneWidget);
      expect(find.text('a definir no envio'), findsNothing);
    });

    testWidgets('avaliadas: o total deixa de se chamar "Valor da NFS-e"',
        (tester) async {
      await tester.pumpWidget(cardComRetencoes(avaliadas: true));

      // 1000 − 20 − 15 − 46,50 = 918,50 ≠ valor da nota: rotular de "Valor da
      // NFS-e" afirmaria que a nota sai por 918,50, e ela sai por 1.000.
      expect(find.text('Líquido a receber'), findsOneWidget);
      expect(find.text('Valor da NFS-e'), findsNothing);
    });

    testWidgets('não avaliadas: mantém "a definir no envio" e o rótulo da nota',
        (tester) async {
      await tester.pumpWidget(cardComRetencoes(avaliadas: false));

      expect(find.text('a definir no envio'), findsNWidgets(2));
      expect(find.text('PIS/COFINS/CSLL retidos'), findsNothing);
      expect(find.text('Valor da NFS-e'), findsOneWidget);
      expect(find.textContaining('20,00'), findsNothing);
    });

    testWidgets('tomador que não retém segue como "Não retém", não R\$ 0,00',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: PreviewFiscalCnpjCard(
            bruto: 1000,
            retemIss: false,
            retemIrrf: false,
            liquido: 1000,
            backendCalculado: true,
            retencoesAvaliadas: true,
          ),
        ),
      ));

      // "Não retém" é a informação; "R$ 0,00" pareceria um valor apurado.
      expect(find.text('Não retém'), findsNWidgets(2));
      expect(find.text('PIS/COFINS/CSLL retidos'), findsNothing);
    });
  });

  group('AtendimentoFiscalPreview.fromJson — ressalvaEscopo', () {
    test('lê o campo do backend', () {
      final preview = AtendimentoFiscalPreview.fromJson(
        <String, dynamic>{'bruto': 1000, 'ressalvaEscopo': _ressalvaBackend},
      );

      expect(preview.ressalvaEscopo, _ressalvaBackend);
    });

    test('campo ausente vira string vazia (contrato pré-A4)', () {
      final preview =
          AtendimentoFiscalPreview.fromJson(<String, dynamic>{'bruto': 1000});

      expect(preview.ressalvaEscopo, isEmpty);
    });

    test('campo só com espaços é normalizado para vazio', () {
      final preview = AtendimentoFiscalPreview.fromJson(
        <String, dynamic>{'bruto': 1000, 'ressalvaEscopo': '   '},
      );

      // Evita o card exibir uma linha de ressalva em branco no lugar da frase.
      expect(preview.ressalvaEscopo, isEmpty);
    });
  });

  // Guard de WIRING: o defeito clássico deste bloco é a frase existir no
  // contrato e a tela não a repassar ao card — e, do outro lado, a tela não
  // mandar o `tomadorId` que faz o backend avaliar as retenções.
  group('AtendimentoCnpjFlow — wiring do preview até o card', () {
    late _MockApi api;
    late OnboardingProvider onboarding;

    final tomador = Tomador(
      id: 'tom-1',
      cnpj: '11222333000181',
      razaoSocial: 'Hospital Santa Casa',
      municipio: 'São Paulo',
      uf: 'SP',
      retemIss: true,
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      api = _MockApi();
      final storage = _MockSecureStorage();
      when(() => storage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);
      when(() => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'))).thenAnswer((_) async {});
      when(() => storage.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});
      when(
        () => api.previewAtendimentoPf(
          cnpjProprioId: any(named: 'cnpjProprioId'),
          valor: any(named: 'valor'),
          competencia: any(named: 'competencia'),
          tomadorId: any(named: 'tomadorId'),
        ),
      ).thenAnswer((_) async => const AtendimentoFiscalPreview(
            bruto: 1000,
            issRetido: 20,
            irrfRetido: 15,
            csrfRetido: 46.50,
            liquidoEstimado: 918.50,
            ressalvaEscopo: _ressalvaBackend,
          ));
      onboarding = OnboardingProvider(api: api, secureStorage: storage)
        ..tomadoresAtual = <Tomador>[tomador];
    });

    Future<void> montarFluxo(WidgetTester tester, {Tomador? tomadorInicial}) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
            ChangeNotifierProvider<ServicoProvider>(
              create: (_) => ServicoProvider(api: api),
            ),
            ChangeNotifierProvider<NotaFiscalProvider>(
              create: (_) => NotaFiscalProvider(api),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AtendimentoCnpjFlow(
                  cnpjProprioId: 'guid-cnpj',
                  cnpjEmissor: '11222333000181',
                  tomadorInicial: tomadorInicial,
                  onConcluido: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('cnpj-valor')), '1000');
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }

    PreviewFiscalCnpjCard cardEmTela(WidgetTester tester) =>
        tester.widget<PreviewFiscalCnpjCard>(
          find.byType(PreviewFiscalCnpjCard),
        );

    testWidgets('ressalva do preview chega ao card exibido no fluxo',
        (tester) async {
      await montarFluxo(tester);

      expect(cardEmTela(tester).ressalvaEscopo, _ressalvaBackend);
    });

    testWidgets('sem tomador escolhido, não manda tomadorId nem afirma avaliação',
        (tester) async {
      await montarFluxo(tester);

      verify(
        () => api.previewAtendimentoPf(
          cnpjProprioId: any(named: 'cnpjProprioId'),
          valor: any(named: 'valor'),
          competencia: any(named: 'competencia'),
          tomadorId: null,
        ),
      ).called(greaterThanOrEqualTo(1));
      expect(cardEmTela(tester).retencoesAvaliadas, isFalse);
    });

    testWidgets('com tomador, envia o tomadorId e repassa as retenções ao card',
        (tester) async {
      await montarFluxo(tester, tomadorInicial: tomador);

      verify(
        () => api.previewAtendimentoPf(
          cnpjProprioId: any(named: 'cnpjProprioId'),
          valor: any(named: 'valor'),
          competencia: any(named: 'competencia'),
          tomadorId: 'tom-1',
        ),
      ).called(greaterThanOrEqualTo(1));

      final card = cardEmTela(tester);
      expect(card.retencoesAvaliadas, isTrue);
      expect(card.issRetido, 20);
      expect(card.irrfRetido, 15);
      expect(card.csrfRetido, 46.50);
    });
  });
}
