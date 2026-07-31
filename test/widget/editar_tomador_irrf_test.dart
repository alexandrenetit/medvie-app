// test/widget/editar_tomador_irrf_test.dart
//
// F-04 / A6 na tela do tomador: cadastros anteriores não sofreram backfill
// (medvie-api/docs/fiscal/RETENCAO-IRRF-PJ.md, D9), então a divergência do
// art. 714 precisa APARECER em vez de ficar silenciosa — e o Switch precisa
// mostrar o mesmo default legal que o backend aplicaria.

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medvie/core/constants/irrf_cadastro.dart';
import 'package:medvie/core/models/medico.dart';
import 'package:medvie/core/providers/onboarding_provider.dart';
import 'package:medvie/core/services/medvie_api_service.dart';
import 'package:medvie/features/profile/editar_tomador_screen.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

Tomador _tomador({
  bool? retemIrrf = false,
  bool diverge = true,
}) =>
    Tomador(
      id: 'tom-1',
      cnpj: '12.345.678/0001-90',
      razaoSocial: 'Hospital Santa Marta Ltda',
      municipio: 'Sao Paulo',
      uf: 'SP',
      codigoIbge: '3550308',
      retemIrrf: retemIrrf,
      retencaoIrrfDivergeRegraGeral: diverge,
    );

Widget _tela(OnboardingProvider provider, Tomador tomador) => MaterialApp(
      home: ChangeNotifierProvider<OnboardingProvider>.value(
        value: provider,
        child: EditarTomadorScreen(
          cnpjProprio: '98765432000110',
          tomador: tomador,
        ),
      ),
    );

OnboardingProvider _provider() {
  final storage = _MockSecureStorage();
  when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
  when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
  when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
      .thenAnswer((_) async {});
  return OnboardingProvider(
    api: MedvieApiService(client: _MockHttpClient(), secureStorage: storage),
    secureStorage: storage,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => registerFallbackValue(Uri.parse('http://localhost')));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('cadastro divergente exibe o aviso do art. 714', (tester) async {
    final provider = _provider();
    addTearDown(provider.dispose);

    await tester.pumpWidget(_tela(provider, _tomador()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('irrf_divergente')), findsOneWidget);
    expect(find.text(kIrrfDivergenciaTitulo), findsOneWidget);
    expect(find.text(kIrrfDivergenciaTexto), findsOneWidget);
  });

  testWidgets('ligar a retenção resolve o aviso na própria tela',
      (tester) async {
    final provider = _provider();
    addTearDown(provider.dispose);

    await tester.pumpWidget(_tela(provider, _tomador()));
    await tester.pumpAndSettle();

    // Dois Switches na tela (ISS e IRRF); o de IRRF é o último.
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('irrf_divergente')), findsNothing);
  });

  testWidgets('cadastro sem divergência não exibe o aviso', (tester) async {
    final provider = _provider();
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      _tela(provider, _tomador(retemIrrf: true, diverge: false)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('irrf_divergente')), findsNothing);
  });

  testWidgets('cadastro sem declaração mostra o Switch no default legal',
      (tester) async {
    final provider = _provider();
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      _tela(provider, _tomador(retemIrrf: null, diverge: false)),
    );
    await tester.pumpAndSettle();

    final switchIrrf = tester.widget<Switch>(find.byType(Switch).last);
    expect(switchIrrf.value, kRetemIrrfPadraoLegalPj);
  });
}
