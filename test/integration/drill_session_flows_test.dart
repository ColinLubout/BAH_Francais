// The drills' integration flows, on the host, so every run of the test
// suite covers them too; integration_test/ runs the same flows on a device.

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/flows.dart';

void main() {
  testWidgets('completes a Vocabulaire session', completesASession);
  testWidgets(
    'a force-close mid-session loses no answered card',
    forceCloseLosesNothing,
  );
  testWidgets('completes a Genre session', completesAGenderSession);
  testWidgets('completes a Conjugaison session', completesAConjugationSession);
  testWidgets('completes a mixed session', completesAMixedSession);
}
