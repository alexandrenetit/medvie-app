// integration_test/app_test.dart
//
// Suite de integração E2E do Medvie.
// Agrega todos os fluxos de teste:
//   - welcome_flow_test.dart  (WF-01..WF-07)
//   - auth_flow_test.dart     (AF-01..AF-05)
//   - navigation_flow_test.dart (NF-01..NF-06)
//
// Executar:
//   flutter test integration_test/app_test.dart -d emulator-5554

import 'flows/welcome_flow_test.dart' as welcome;
import 'flows/auth_flow_test.dart' as auth;
import 'flows/navigation_flow_test.dart' as navigation;

void main() {
  welcome.main();
  auth.main();
  navigation.main();
}
