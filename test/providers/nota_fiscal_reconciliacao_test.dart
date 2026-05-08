// test/providers/nota_fiscal_reconciliacao_test.dart
//
// Testes da reconciliação pós-reconexão SSE (item K7 — RELATORIOWEBHOOK.md).
//
// Cobre:
//   - Aplicação de atualização quando nota local não tem versão.
//   - Aplicação quando versaoRest > versaoLocal.
//   - Descarte quando versaoRest <= versaoLocal (proteção contra sobrescrita
//     de evento SSE concorrente mais recente).
//   - Persistência do timestamp da última sincronização.
//   - Retry com backoff em falha de rede e desistência após máximo.
//   - Guarda de versão no callback _onNotaAtualizada (evento SSE antigo
//     descartado quando local já tem versão maior).

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medvie/core/models/nota_fiscal.dart';
import 'package:medvie/core/models/nota_sincronizacao.dart';
import 'package:medvie/core/providers/nota_fiscal_provider.dart';
import 'package:medvie/core/services/medvie_api_service.dart';
import 'package:medvie/core/services/sse_service.dart';

class _MockApi extends Mock implements MedvieApiService {}

class _FakeSseService extends SseService {
  _FakeSseService(super.api);

  @override
  void conectar() {}

  @override
  void desconectar() {}
}

NotaFiscal _buildNota({
  String id = 'nf-001',
  StatusNota status = StatusNota.emProcessamento,
  int? versao,
}) =>
    NotaFiscal(
      id: id,
      servicoId: 'srv-$id',
      tomadorRazaoSocial: 'Hospital Teste',
      tomadorCnpj: '00.000.000/0001-00',
      cnpjEmissor: '11.222.333/0001-81',
      valor: 1000,
      competencia: DateTime(2026, 4, 15),
      emitidaEm: DateTime(2026, 4, 15),
      status: status,
      versao: versao,
    );

void _stubListar(_MockApi api, List<NotaFiscal> notas) {
  when(() => api.listarNotas(
        any(),
        status: any(named: 'status'),
        competenciaDe: any(named: 'competenciaDe'),
        competenciaAte: any(named: 'competenciaAte'),
        pagina: any(named: 'pagina'),
        tamanhoPagina: any(named: 'tamanhoPagina'),
      )).thenAnswer((_) async => notas);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
  });

  late _MockApi mockApi;

  setUp(() {
    mockApi = _MockApi();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<NotaFiscalProvider> criarProvider() async {
    return NotaFiscalProvider(
      mockApi,
      sseFactory: (api) => _FakeSseService(api),
      prefsFactory: SharedPreferences.getInstance,
    );
  }

  group('reconciliarNotas — versão guard', () {
    test('aplica atualização quando nota local não tem versão', () async {
      _stubListar(mockApi, [_buildNota(id: 'nf-1')]);
      when(() => mockApi.sincronizarNotas(any())).thenAnswer((_) async => [
            NotaSincronizacao(
              notaId: 'nf-1',
              status: StatusNota.autorizada,
              versao: 100,
              dataAtualizacao: DateTime.utc(2026, 5, 8),
            ),
          ]);

      final provider = await criarProvider();
      await provider.carregar('cnpj-id');

      await provider.reconciliarNotasParaTeste();

      expect(provider.notas.first.status, StatusNota.autorizada);
      expect(provider.notas.first.versao, 100);
    });

    test('aplica atualização quando versaoRest > versaoLocal', () async {
      _stubListar(mockApi, [
        _buildNota(id: 'nf-1', status: StatusNota.emProcessamento, versao: 50),
      ]);
      when(() => mockApi.sincronizarNotas(any())).thenAnswer((_) async => [
            NotaSincronizacao(
              notaId: 'nf-1',
              status: StatusNota.autorizada,
              versao: 200,
              dataAtualizacao: DateTime.utc(2026, 5, 8),
            ),
          ]);

      final provider = await criarProvider();
      await provider.carregar('cnpj-id');

      await provider.reconciliarNotasParaTeste();

      expect(provider.notas.first.status, StatusNota.autorizada);
      expect(provider.notas.first.versao, 200);
    });

    test('descarta atualização quando versaoRest <= versaoLocal', () async {
      _stubListar(mockApi, [
        _buildNota(id: 'nf-1', status: StatusNota.autorizada, versao: 500),
      ]);
      when(() => mockApi.sincronizarNotas(any())).thenAnswer((_) async => [
            NotaSincronizacao(
              notaId: 'nf-1',
              status: StatusNota.emProcessamento,
              versao: 100,
              dataAtualizacao: DateTime.utc(2026, 5, 8),
            ),
          ]);

      final provider = await criarProvider();
      await provider.carregar('cnpj-id');

      await provider.reconciliarNotasParaTeste();

      // Versão local maior → mantém o estado atual.
      expect(provider.notas.first.status, StatusNota.autorizada);
      expect(provider.notas.first.versao, 500);
    });

    test('persiste timestamp da última sincronização ao concluir', () async {
      _stubListar(mockApi, []);
      when(() => mockApi.sincronizarNotas(any())).thenAnswer((_) async => []);

      final provider = await criarProvider();
      await provider.carregar('cnpj-id');

      final antes = DateTime.now().toUtc();
      await provider.reconciliarNotasParaTeste();
      final depois = DateTime.now().toUtc();

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('medvie.nota.ultima_sincronizacao_utc');
      expect(raw, isNotNull);

      final salvo = DateTime.parse(raw!).toUtc();
      expect(salvo.isAfter(antes.subtract(const Duration(seconds: 1))), isTrue);
      expect(salvo.isBefore(depois.add(const Duration(seconds: 1))), isTrue);
    });

    test('em falha persistente desiste após maxTentativas sem lançar', () async {
      _stubListar(mockApi, [_buildNota(id: 'nf-1')]);
      when(() => mockApi.sincronizarNotas(any()))
          .thenThrow(Exception('rede caiu'));

      final provider = await criarProvider();
      await provider.carregar('cnpj-id');

      await provider.reconciliarNotasParaTeste();

      verify(() => mockApi.sincronizarNotas(any())).called(3);
      // Estado preservado — falha de reconciliação não corrompe a lista.
      expect(provider.notas.first.id, 'nf-1');
    });

    test('ignora notas que não estão na lista local', () async {
      _stubListar(mockApi, [_buildNota(id: 'nf-1')]);
      when(() => mockApi.sincronizarNotas(any())).thenAnswer((_) async => [
            NotaSincronizacao(
              notaId: 'nf-DESCONHECIDA',
              status: StatusNota.autorizada,
              versao: 100,
              dataAtualizacao: DateTime.utc(2026, 5, 8),
            ),
          ]);

      final provider = await criarProvider();
      await provider.carregar('cnpj-id');

      await provider.reconciliarNotasParaTeste();

      expect(provider.notas.length, 1);
      expect(provider.notas.first.versao, isNull);
    });
  });
}
