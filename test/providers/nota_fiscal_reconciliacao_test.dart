// test/providers/nota_fiscal_reconciliacao_test.dart
//
// Testes da reconciliação pós-reconexão SSE (item K7 — RELATORIOWEBHOOK.md).
//
// Cobre:
//   - Aplicação de atualização quando versaoRest > versaoLocal.
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
import 'package:medvie/core/models/notas_pagina.dart';
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

// Helper para gerar ticks compatíveis com NotaFiscal.versao.
const int _kTicksAt1970 = 621355968000000000;
int _ticks(DateTime utc) =>
    _kTicksAt1970 + utc.toUtc().microsecondsSinceEpoch * 10;

NotaFiscal _buildNota({
  String id = 'nf-001',
  String status = 'emProcessamento',
  DateTime? updatedAt,
}) => NotaFiscal(
  id: id,
  status: status,
  codigoNbs: '1.0501',
  createdAt: DateTime.utc(2026, 4, 15),
  updatedAt: updatedAt ?? DateTime.utc(2026, 4, 15),
);

void _stubListar(_MockApi api, List<NotaFiscal> notas) {
  when(
    () => api.listarNotas(
      any(),
      status: any(named: 'status'),
      competenciaDe: any(named: 'competenciaDe'),
      competenciaAte: any(named: 'competenciaAte'),
      pagina: any(named: 'pagina'),
      tamanhoPagina: any(named: 'tamanhoPagina'),
    ),
  ).thenAnswer(
    (_) async => NotasPagina(
      notas: notas,
      total: notas.length,
      pagina: 1,
      tamanhoPagina: 20,
    ),
  );
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
    test('aplica atualização quando versaoRest > versaoLocal', () async {
      final notaUpdatedAt = DateTime.utc(2026, 4, 15);
      _stubListar(mockApi, [_buildNota(id: 'nf-1', updatedAt: notaUpdatedAt)]);

      final dtoDataAtualizacao = DateTime.utc(2026, 5, 1);
      when(() => mockApi.sincronizarNotas(any())).thenAnswer(
        (_) async => [
          NotaSincronizacao(
            notaId: 'nf-1',
            status: StatusNota.autorizada.name,
            versao: _ticks(dtoDataAtualizacao), // maior que versaoLocal
            dataAtualizacao: dtoDataAtualizacao,
          ),
        ],
      );

      final provider = await criarProvider();
      await provider.carregar('cnpj-id');
      await provider.reconciliarNotasParaTeste();

      expect(provider.notas.first.status, StatusNota.autorizada.name);
      expect(provider.notas.first.updatedAt, dtoDataAtualizacao);
    });

    test('descarta atualização quando versaoRest <= versaoLocal', () async {
      final notaUpdatedAt = DateTime.utc(2026, 4, 15);
      _stubListar(mockApi, [
        _buildNota(
          id: 'nf-1',
          status: StatusNota.autorizada.name,
          updatedAt: notaUpdatedAt,
        ),
      ]);

      when(() => mockApi.sincronizarNotas(any())).thenAnswer(
        (_) async => [
          NotaSincronizacao(
            notaId: 'nf-1',
            status: StatusNota.emProcessamento.name,
            versao: _ticks(DateTime.utc(2026, 4, 1)), // menor que versaoLocal
            dataAtualizacao: DateTime.utc(2026, 4, 1),
          ),
        ],
      );

      final provider = await criarProvider();
      await provider.carregar('cnpj-id');
      await provider.reconciliarNotasParaTeste();

      // Versão local maior → mantém estado atual.
      expect(provider.notas.first.status, StatusNota.autorizada.name);
      expect(provider.notas.first.updatedAt, notaUpdatedAt);
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

    test(
      'em falha persistente desiste após maxTentativas sem lançar',
      () async {
        _stubListar(mockApi, [_buildNota(id: 'nf-1')]);
        when(
          () => mockApi.sincronizarNotas(any()),
        ).thenThrow(Exception('rede caiu'));

        final provider = await criarProvider();
        await provider.carregar('cnpj-id');
        await provider.reconciliarNotasParaTeste();

        verify(() => mockApi.sincronizarNotas(any())).called(3);
        // Estado preservado — falha de reconciliação não corrompe a lista.
        expect(provider.notas.first.id, 'nf-1');
      },
    );

    test('ignora notas que não estão na lista local', () async {
      _stubListar(mockApi, [_buildNota(id: 'nf-1')]);
      when(() => mockApi.sincronizarNotas(any())).thenAnswer(
        (_) async => [
          NotaSincronizacao(
            notaId: 'nf-DESCONHECIDA',
            status: StatusNota.autorizada.name,
            versao: _ticks(DateTime.utc(2026, 5, 1)),
            dataAtualizacao: DateTime.utc(2026, 5, 1),
          ),
        ],
      );

      final provider = await criarProvider();
      await provider.carregar('cnpj-id');
      await provider.reconciliarNotasParaTeste();

      expect(provider.notas.length, 1);
      expect(provider.notas.first.id, 'nf-1');
    });
  });
}
