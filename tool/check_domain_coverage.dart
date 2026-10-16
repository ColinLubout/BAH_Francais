/// Fails if the domain layer's line coverage is under 90%.
///
/// Run after `flutter test --coverage`:
///
///     dart run tool/check_domain_coverage.dart [coverage/lcov.info]
library;

import 'dart:io';

import 'src/coverage.dart';

const _target = 90.0;

void main(List<String> args) {
  final file = File(args.isEmpty ? 'coverage/lcov.info' : args.first);
  if (!file.existsSync()) {
    stderr.writeln(
      '${file.path} not found. Run flutter test --coverage first.',
    );
    exit(2);
  }

  final coverage = lineCoverage(file.readAsStringSync(), isDomainFile);
  if (coverage.found == 0) {
    stderr.writeln('No domain files in ${file.path}.');
    exit(1);
  }

  final percent = 100 * coverage.hit / coverage.found;
  final sorted = [...coverage.files]
    ..sort((a, b) => (a.hit / a.found).compareTo(b.hit / b.found));
  for (final f in sorted) {
    final p = (100 * f.hit / f.found).toStringAsFixed(1).padLeft(5);
    stdout.writeln('$p%  ${f.path}');
  }
  stdout.writeln(
    'Domain coverage: ${percent.toStringAsFixed(1)}% '
    '(${coverage.hit}/${coverage.found} lines, target $_target%)',
  );
  if (percent < _target) exit(1);
}
