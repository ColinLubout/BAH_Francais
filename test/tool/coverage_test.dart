import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/coverage.dart';

const lcov = r'''
SF:lib/features/drills/domain/a.dart
DA:1,1
DA:2,0
DA:3,4
end_of_record
SF:lib\features\drills\domain\b.dart
DA:1,1
end_of_record
SF:lib/features/drills/presentation/c.dart
DA:1,0
end_of_record
SF:lib/features/drills/domain/d.g.dart
DA:1,0
end_of_record
''';

void main() {
  test('counts hit and found lines of the included files', () {
    final coverage = lineCoverage(lcov, isDomainFile);
    expect(coverage.found, 4);
    expect(coverage.hit, 3);
    expect(coverage.files.map((f) => f.path), [
      'lib/features/drills/domain/a.dart',
      'lib/features/drills/domain/b.dart',
    ]);
  });

  test('isDomainFile', () {
    expect(isDomainFile('lib/features/x/domain/y.dart'), isTrue);
    expect(isDomainFile('/repo/lib/features/x/domain/sub/y.dart'), isTrue);
    expect(isDomainFile('lib/features/x/data/y.dart'), isFalse);
    expect(isDomainFile('lib/features/x/domain/y.g.dart'), isFalse);
    expect(isDomainFile('lib/core/time/clock.dart'), isFalse);
  });

  test('an empty report has nothing', () {
    final coverage = lineCoverage('', isDomainFile);
    expect(coverage.found, 0);
    expect(coverage.files, isEmpty);
  });
}
