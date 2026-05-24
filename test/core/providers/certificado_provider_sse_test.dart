// test/core/providers/certificado_provider_sse_test.dart

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medvie/core/errors/api_error.dart';
import 'package:medvie/core/errors/api_exception.dart';
import 'package:medvie/core/models/certificado_alerta.dart';
import 'package:medvie/core/models/certificado_metadata.dart';
import 'package:medvie/core/models/medico.dart';
import 'package:medvie/core/providers/certificado_provider.dart';
import 'package:medvie/core/services/medvie_api_service.dart';
import 'package:medvie/core/services/sse_service.dart';

/// Stub manual de [MedvieApiService] focado em `consultarCertificado`.
///
/// - `response`: valor retornado por padrão.
/// - `pendingPorCnpj`: se contém o cnpjId, devolve `future` desse completer
///   (permite controlar timing de resolução, simulando race entre chamadas).
/// - `throwsPorCnpj`: lança a exceção fornecida em vez de resolver.
class _StubApi extends Fake implements MedvieApiService {
  CertificadoMetadata? response;
  int chamadas = 0;
  final List<String> cnpjsChamados = [];
  final Map<String, Completer<CertificadoMetadata?>> pendingPorCnpj = {};
  final Map<String, ApiException> throwsPorCnpj = {};

  @override
  Future<CertificadoMetadata?> consultarCertificado(String cnpjId) async {
    chamadas++;
    cnpjsChamados.add(cnpjId);
    final erro = throwsPorCnpj[cnpjId];
    if (erro != null) throw erro;
    final pend = pendingPorCnpj[cnpjId];
    if (pend != null) return pend.future;
    return response;
  }
}

/// Fake de [SseService] que expõe apenas o controller de alertas. Os demais
/// membros caem em `noSuchMethod` — não exercitados nos testes do provider.
class _FakeSseService implements SseService {
  final StreamController<CertificadoAlerta> controller =
      StreamController<CertificadoAlerta>.broadcast();

  @override
  Stream<CertificadoAlerta> get certificadoAlertas => controller.stream;

  Future<void> disposeFake() async {
    if (!controller.isClosed) await controller.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CertificadoAlerta _alerta(String cnpj, [int dias = 7]) => CertificadoAlerta(
      cnpjProprioId: cnpj,
      diasRestantes: dias,
      recebidoEm: DateTime.utc(2026, 5, 24, 13, 45, 21),
    );

CertificadoMetadata _meta(String cnpj) => CertificadoMetadata(
      status: StatusCertificado.ativo,
      subjectCnpj: cnpj,
      issuerName: 'Test CA',
      validFrom: DateTime.utc(2026, 1, 1),
      validUntil: DateTime.utc(2027, 1, 1),
      fingerprintSha256: 'f' * 64,
      restritoAoCnpj: false,
      diasParaVencer: 222,
    );

ApiException _apiErro(int status, String code) => ApiException(ApiError(
      statusCode: status,
      code: code,
      description: 'erro $code',
    ));

/// Pulsa o event loop algumas vezes para permitir que microtasks de
/// `Future.then`/`await` e o broadcast da stream propaguem.
Future<void> _pump([int ticks = 3]) async {
  for (var i = 0; i < ticks; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _StubApi api;
  late _FakeSseService sse;
  late CertificadoProvider provider;

  setUp(() {
    api = _StubApi();
    sse = _FakeSseService();
    provider = CertificadoProvider(api);
  });

  tearDown(() async {
    provider.dispose();
    await sse.disposeFake();
  });

  test('1. sem CNPJ ativo → alerta NÃO dispara carregar', () async {
    provider.bindSse(sse);

    sse.controller.add(_alerta('A'));
    await _pump();

    expect(api.chamadas, 0);
  });

  test('2. carregar("A") prévio + alerta "A" → carregar chamado 2x total',
      () async {
    api.response = _meta('A');
    provider.bindSse(sse);

    await provider.carregar('A');
    expect(api.chamadas, 1);

    sse.controller.add(_alerta('A'));
    await _pump();

    expect(api.chamadas, 2);
    expect(api.cnpjsChamados, ['A', 'A']);
  });

  test('3. carregar("A") prévio + alerta "B" → listener ignora (1x total)',
      () async {
    api.response = _meta('A');
    provider.bindSse(sse);

    await provider.carregar('A');

    sse.controller.add(_alerta('B'));
    await _pump();

    expect(api.chamadas, 1);
    expect(api.cnpjsChamados, ['A']);
  });

  test('4. bindSse 2x mesma instância → 1 subscription (não duplica)',
      () async {
    api.response = _meta('A');
    provider.bindSse(sse);
    provider.bindSse(sse); // idempotente

    await provider.carregar('A');
    sse.controller.add(_alerta('A'));
    await _pump();

    expect(api.chamadas, 2); // 1 carregar inicial + 1 do listener (não 3)
  });

  test('5. bindSse com instância diferente → cancela primeira, escuta segunda',
      () async {
    final sseA = _FakeSseService();
    final sseB = _FakeSseService();
    addTearDown(() async {
      await sseA.disposeFake();
      await sseB.disposeFake();
    });

    api.response = _meta('A');
    provider.bindSse(sseA);
    provider.bindSse(sseB);

    await provider.carregar('A');

    sseA.controller.add(_alerta('A')); // ignorado — sub cancelada
    await _pump();
    expect(api.chamadas, 1, reason: 'sseA não deve disparar');

    sseB.controller.add(_alerta('A'));
    await _pump();
    expect(api.chamadas, 2, reason: 'sseB deve disparar');
  });

  test('6. race coalesce: alerta durante carregar pending → NÃO duplica',
      () async {
    final pend = Completer<CertificadoMetadata?>();
    api.pendingPorCnpj['A'] = pend;
    provider.bindSse(sse);

    final fut = provider.carregar('A'); // não await — fica pending
    await _pump();
    expect(api.chamadas, 1);
    expect(provider.carregando, isTrue);

    sse.controller.add(_alerta('A'));
    await _pump();
    expect(api.chamadas, 1, reason: 'alerta deve ser coalescido');

    pend.complete(_meta('A'));
    await fut;
    expect(api.chamadas, 1);
  });

  test('7. stale: carregar(A) → carregar(B) durante voo → state final = B',
      () async {
    final pendA = Completer<CertificadoMetadata?>();
    final pendB = Completer<CertificadoMetadata?>();
    api.pendingPorCnpj['A'] = pendA;
    api.pendingPorCnpj['B'] = pendB;

    final futA = provider.carregar('A');
    await _pump();
    final futB = provider.carregar('B');
    await _pump();

    // B resolve primeiro com metaB; A resolve depois com metaA (stale).
    pendB.complete(_meta('B'));
    await futB;
    pendA.complete(_meta('A'));
    await futA;

    expect(provider.state, isA<CertificadoSuccess>());
    expect((provider.state as CertificadoSuccess).metadata.subjectCnpj, 'B');
  });

  test('8. dispose → alerta posterior não lança e não dispara carregar',
      () async {
    api.response = _meta('A');
    provider.bindSse(sse);
    await provider.carregar('A');
    final chamadasAntes = api.chamadas;

    provider.dispose();

    sse.controller.add(_alerta('A'));
    await _pump();

    expect(api.chamadas, chamadasAntes);

    // O tearDown chamará dispose novamente em outras instâncias; aqui
    // substituímos provider por um descartável para evitar dispose 2x.
    provider = CertificadoProvider(api);
  });

  test('9. burst de 5 alertas durante carregar pending → coalesce (1 fetch)',
      () async {
    final pend = Completer<CertificadoMetadata?>();
    api.pendingPorCnpj['A'] = pend;
    provider.bindSse(sse);

    final fut = provider.carregar('A');
    await _pump();

    for (var i = 0; i < 5; i++) {
      sse.controller.add(_alerta('A'));
    }
    await _pump();

    expect(api.chamadas, 1, reason: 'todos coalescidos durante carga');

    pend.complete(_meta('A'));
    await fut;
    await _pump();

    expect(api.chamadas, 1, reason: 'sem fetch extra depois da resolução');
  });

  test('propagação de erro ApiException → state vira CertificadoErro',
      () async {
    api.throwsPorCnpj['A'] = _apiErro(422, 'Certificado.SenhaInvalida');
    provider.bindSse(sse);

    await provider.carregar('A');

    expect(provider.state, isA<CertificadoErro>());
    final erro = provider.state as CertificadoErro;
    expect(erro.codigo, 'Certificado.SenhaInvalida');
  });
}
