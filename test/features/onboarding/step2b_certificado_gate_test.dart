// test/features/onboarding/step2b_certificado_gate_test.dart
//
// Widget tests do gate de avanço do step 2b (Assinatura Digital).
// Cobre os 3 cenários da regra `podeAvancarStep2b`:
//   (a) método A1 + CertificadoIdle  → CTA "Próximo" DESABILITADO.
//   (b) método A1 + CertificadoSuccess → CTA "Próximo" HABILITADO.
//   (c) método govBr (sem certificado) → CTA "Próximo" HABILITADO sempre.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medvie/core/models/certificado_metadata.dart';
import 'package:medvie/core/models/medico.dart';
import 'package:medvie/core/providers/certificado_provider.dart';
import 'package:medvie/core/providers/onboarding_provider.dart';
import 'package:medvie/core/services/medvie_api_service.dart';
import 'package:medvie/features/onboarding/screens/step2b_assinatura_screen.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockApi extends Mock implements MedvieApiService {}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

// ── Fake CertificadoProvider ─────────────────────────────────────────────────

class _FakeCertificadoProvider extends ChangeNotifier
    implements CertificadoProvider {
  _FakeCertificadoProvider(this._s);

  CertificadoState _s;

  @override
  CertificadoState get state => _s;

  set state(CertificadoState v) {
    _s = v;
    notifyListeners();
  }

  // No-op: evita qualquer chamada HTTP do CertificadoProvider real.
  @override
  Future<void> carregar(String cnpjId) async {}

  @override
  Future<void> enviar(
    String cnpjId,
    Uint8List bytes,
    String senha,
    bool restritoAoCnpj,
  ) async {}

  @override
  Future<void> remover(String cnpjId) async {}

  @override
  void bindSse(Object sse) {}

  @override
  bool get carregando => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Helpers ──────────────────────────────────────────────────────────────────

CertificadoMetadata _buildMetadata() => CertificadoMetadata(
      status: StatusCertificado.ativo,
      subjectCnpj: '11222333000181',
      issuerName: 'AC TESTE',
      validFrom: DateTime.utc(2026, 1, 1),
      validUntil: DateTime.utc(2027, 1, 1),
      fingerprintSha256: 'a' * 64,
      restritoAoCnpj: true,
      diasParaVencer: 220,
    );

Future<OnboardingProvider> _buildProvider({
  required _MockApi mockApi,
  required _MockSecureStorage mockSecureStorage,
  required MetodoAssinatura metodo,
  required CertificadoProvider cert,
}) async {
  final provider = OnboardingProvider(
    api: mockApi,
    secureStorage: mockSecureStorage,
  );
  // Aguarda _restaurarSessao() concluir antes de ajustar estado de teste.
  await Future<void>.value();
  provider.cnpjAtual = '11222333000181';
  provider.cnpjProprioIdsPorCnpj = {'11222333000181': 'cnpj-uuid-1'};
  provider.metodoAssinaturaAtual = metodo;
  provider.attachCertificado(cert);
  return provider;
}

Widget _wrap({
  required OnboardingProvider onboarding,
  required CertificadoProvider cert,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
      ChangeNotifierProvider<CertificadoProvider>.value(value: cert),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Step2bAssinaturaScreen(onNext: () {}),
      ),
    ),
  );
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockApi mockApi;
  late _MockSecureStorage mockSecureStorage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockApi = _MockApi();
    mockSecureStorage = _MockSecureStorage();
    when(
      () => mockSecureStorage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    when(
      () => mockSecureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockSecureStorage.delete(key: any(named: 'key')),
    ).thenAnswer((_) async {});
  });

  testWidgets(
    '(a) método A1 + CertificadoIdle → CTA "Próximo" desabilitado',
    (tester) async {
      final cert = _FakeCertificadoProvider(const CertificadoIdle());
      final onboarding = await _buildProvider(
        mockApi: mockApi,
        mockSecureStorage: mockSecureStorage,
        metodo: MetodoAssinatura.certificadoA1,
        cert: cert,
      );

      await tester.pumpWidget(_wrap(onboarding: onboarding, cert: cert));
      await tester.pumpAndSettle();

      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Próximo'),
      );
      expect(btn.onPressed, isNull);
    },
  );

  testWidgets(
    '(b) método A1 + CertificadoSuccess → CTA "Próximo" habilitado',
    (tester) async {
      final cert =
          _FakeCertificadoProvider(CertificadoSuccess(_buildMetadata()));
      final onboarding = await _buildProvider(
        mockApi: mockApi,
        mockSecureStorage: mockSecureStorage,
        metodo: MetodoAssinatura.certificadoA1,
        cert: cert,
      );

      await tester.pumpWidget(_wrap(onboarding: onboarding, cert: cert));
      await tester.pumpAndSettle();

      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Próximo'),
      );
      expect(btn.onPressed, isNotNull);
    },
  );

  testWidgets(
    '(c) método govBr → CTA "Próximo" habilitado independente do certificado',
    (tester) async {
      final cert = _FakeCertificadoProvider(const CertificadoIdle());
      final onboarding = await _buildProvider(
        mockApi: mockApi,
        mockSecureStorage: mockSecureStorage,
        metodo: MetodoAssinatura.govBr,
        cert: cert,
      );

      await tester.pumpWidget(_wrap(onboarding: onboarding, cert: cert));
      await tester.pumpAndSettle();

      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Próximo'),
      );
      expect(btn.onPressed, isNotNull);
    },
  );
}
