// The drills' integration tests, on a device: run with
// `flutter test integration_test`.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'flows.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('completes a Vocabulaire session', completesASession);
  testWidgets(
    'a force-close mid-session loses no answered card',
    forceCloseLosesNothing,
  );
  testWidgets('completes a Genre session', completesAGenderSession);
  testWidgets('completes a Conjugaison session', completesAConjugationSession);
  testWidgets('completes a mixed session', completesAMixedSession);
}
