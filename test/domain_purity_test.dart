import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The domain layer is pure Dart: no Flutter, no platform, no network or
/// files. It has to be testable without a widget tree and work offline.
void main() {
  final forbidden = RegExp(
    r'''^import\s+['"](package:flutter/|package:flutter_[a-z_]+/|dart:ui|dart:io|package:http/|package:drift)''',
    multiLine: true,
  );

  final domainFiles = [
    ...Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.dart') && f.uri.pathSegments.contains('domain'),
        ),
    // The clock and study day are used by the domain, so they are pure too.
    File('lib/core/time/clock.dart'),
    File('lib/core/time/study_day.dart'),
  ];

  test('there are domain files to check', () {
    expect(domainFiles.length, greaterThan(10));
  });

  for (final file in domainFiles) {
    test('${file.path} imports no Flutter, platform, network or database', () {
      final imports = forbidden
          .allMatches(file.readAsStringSync())
          .map((m) => m.group(0));
      expect(imports, isEmpty);
    });
  }
}
