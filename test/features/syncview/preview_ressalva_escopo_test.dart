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
  // contrato e a tela não a repassar ao card.
  group('AtendimentoCnpjFlow — wiring do preview até o card', () {
    testWidgets('ressalva do preview chega ao card exibido no fluxo',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = _MockApi();
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
        ),
      ).thenAnswer((_) async => const AtendimentoFiscalPreview(
            bruto: 1000,
            liquidoEstimado: 1000,
            ressalvaEscopo: _ressalvaBackend,
          ));

      final onboarding = OnboardingProvider(api: api, secureStorage: storage)
        ..tomadoresAtual = <Tomador>[
          Tomador(
            id: 'tom-1',
            cnpj: '11222333000181',
            razaoSocial: 'Hospital Santa Casa',
            municipio: 'São Paulo',
            uf: 'SP',
          ),
        ];

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
                  onConcluido: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('cnpj-valor')), '1000');
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final card = tester.widget<PreviewFiscalCnpjCard>(
        find.byType(PreviewFiscalCnpjCard),
      );
      expect(card.ressalvaEscopo, _ressalvaBackend);
    });
  });
}
