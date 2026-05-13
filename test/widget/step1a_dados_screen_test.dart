import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medvie/core/providers/onboarding_provider.dart';
import 'package:medvie/core/services/medvie_api_service.dart';
import 'package:medvie/features/onboarding/screens/step1a_dados_screen.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

Widget _buildWidget(OnboardingProvider provider) {
  return MaterialApp(
    home: ChangeNotifierProvider<OnboardingProvider>.value(
      value: provider,
      child: Scaffold(body: Step1aDadosScreen(onNext: () {})),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('perder foco do CPF não chama consulta by-cpf', (tester) async {
    final client = _MockHttpClient();
    final storage = _MockSecureStorage();
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    final provider = OnboardingProvider(
      api: MedvieApiService(client: client, secureStorage: storage),
      secureStorage: storage,
    );
    addTearDown(provider.dispose);

    await tester.pumpWidget(_buildWidget(provider));
    await tester.pump();

    await tester.tap(find.byType(TextFormField).at(1));
    await tester.enterText(find.byType(TextFormField).at(1), '52998224725');
    await tester.tap(find.byType(TextFormField).at(0));
    await tester.pumpAndSettle();

    verifyNever(() => client.get(any(), headers: any(named: 'headers')));
  });
}
