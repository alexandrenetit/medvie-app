import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:medvie/core/models/medico.dart';
import 'package:medvie/core/providers/nota_fiscal_provider.dart';
import 'package:medvie/core/providers/servico_provider.dart';
import 'package:medvie/core/services/medvie_api_service.dart';
import 'package:medvie/features/syncview/widgets/atendimento_pf_flow.dart';

class _MockApi extends Mock implements MedvieApiService {}

const _cpfValido = '11144477735';

AtendimentoPfResponse _respostaIncompleta() =>
    AtendimentoPfResponse.fromJson(<String, dynamic>{
      'atendimentoId': 'atd-1',
      'servicoId': 'serv-1',
      'tomador': <String, dynamic>{
        'id': 'tom-1',
        'tipo': 'CPF',
        'documentoMascarado': '***.***.***-35',
        'nome': 'Paciente Teste',
        'enderecoFiscalStatus': 'Incompleto',
      },
      'preview': <String, dynamic>{
        'bruto': 500.0,
        'prontoParaEmitir': false,
      },
      'status': 'PendenteDados',
    });

Future<void> _pump(WidgetTester tester, _MockApi api, {VoidCallback? onOk}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
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
            child: AtendimentoPfFlow(
              cnpjProprioId: 'guid-cnpj',
              cnpjEmissor: '12345678000190',
              onConcluido: onOk ?? () {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      AtendimentoPfRequest(
        requisicaoId: 'fb',
        cnpjProprioId: 'fb',
        tomador: const AtendimentoPfTomadorRequest(
          documento: '00000000000',
          nome: 'fb',
          endereco: EnderecoFiscalTomador(),
        ),
        servico: AtendimentoPfServicoRequest(
          tipoServico: 'Consulta',
          codigoNbs: '40101',
          descricao: 'fb',
          valor: 0,
          competencia: DateTime(2020),
          codigoMunicipioPrestacao: '0',
        ),
      ),
    );
  });

  group('AtendimentoPfFlow (T040/T043)', () {
    testWidgets('salva atendimento PF com emitirAgora=false (FR-017)', (
      tester,
    ) async {
      final api = _MockApi();
      AtendimentoPfRequest? enviado;
      var concluiu = false;

      when(
        () => api.lookupTomadorPorCpf(
          cnpjProprioId: any(named: 'cnpjProprioId'),
          documento: any(named: 'documento'),
        ),
      ).thenAnswer((_) async => LookupTomadorResponse.novoPaciente());
      when(
        () => api.previewAtendimentoPf(
          cnpjProprioId: any(named: 'cnpjProprioId'),
          valor: any(named: 'valor'),
          competencia: any(named: 'competencia'),
        ),
      ).thenAnswer((_) async => const AtendimentoFiscalPreview());
      when(() => api.criarAtendimentoPf(any())).thenAnswer((inv) async {
        enviado = inv.positionalArguments[0] as AtendimentoPfRequest;
        return _respostaIncompleta();
      });

      await _pump(tester, api, onOk: () => concluiu = true);

      await tester.enterText(
        find.byKey(const ValueKey('pf-cpf')),
        _cpfValido,
      );
      await tester.enterText(
        find.byKey(const ValueKey('pf-nome')),
        'Paciente Teste',
      );
      await tester.enterText(
        find.byKey(const ValueKey('pf-valor')),
        '50000',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Salvar atendimento'));
      await tester.tap(find.text('Salvar atendimento'));
      await tester.pumpAndSettle();

      expect(enviado, isNotNull);
      expect(enviado!.toJson()['emitirAgora'], isFalse);
      expect(enviado!.tomador.documento, _cpfValido);
      expect(enviado!.tomador.nome, 'Paciente Teste');
      expect(enviado!.servico.valor, 500.0);
      // Endereço incompleto → salva como pendente e conclui (FR-006).
      expect(concluiu, isTrue);
    });

    testWidgets('sem CPF válido → não chama backend (validação)', (
      tester,
    ) async {
      final api = _MockApi();
      when(
        () => api.lookupTomadorPorCpf(
          cnpjProprioId: any(named: 'cnpjProprioId'),
          documento: any(named: 'documento'),
        ),
      ).thenAnswer((_) async => LookupTomadorResponse.novoPaciente());
      when(
        () => api.previewAtendimentoPf(
          cnpjProprioId: any(named: 'cnpjProprioId'),
          valor: any(named: 'valor'),
          competencia: any(named: 'competencia'),
        ),
      ).thenAnswer((_) async => const AtendimentoFiscalPreview());

      await _pump(tester, api);

      await tester.enterText(
        find.byKey(const ValueKey('pf-valor')),
        '50000',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Salvar atendimento'));
      await tester.tap(find.text('Salvar atendimento'));
      await tester.pumpAndSettle();

      verifyNever(() => api.criarAtendimentoPf(any()));
      expect(find.text('Informe um CPF válido do paciente.'), findsOneWidget);
    });
  });
}
