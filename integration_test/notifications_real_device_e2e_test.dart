import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // `testWidgets` in this Flutter version only accepts a boolean `skip`,
  // so the defer reason is encoded in the test name and comment.
  testWidgets(
    'notifications full path on real device '
    '(deferred: Firebase/device evidence prerequisites pending)',
    (tester) async {
      // Deferred on purpose. This test documents the scenario list and
      // provides a stable target for future device execution.
      //
      // Deferred until Firebase credentials, operator-triggered pushes,
      // and device-side evidence capture are ready.
    },
    skip: true,
  );
}
