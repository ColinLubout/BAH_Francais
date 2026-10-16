/// Reads an lcov file and works out the domain layer's line coverage.
library;

/// Line coverage of the files whose path passes [include], from lcov [text].
({int hit, int found, List<({String path, int hit, int found})> files})
lineCoverage(String text, bool Function(String path) include) {
  final files = <({String path, int hit, int found})>[];
  String? path;
  var hit = 0;
  var found = 0;

  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('SF:')) {
      path = line.substring(3).replaceAll(r'\', '/');
      hit = 0;
      found = 0;
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      found++;
      if (parts.length > 1 && (int.tryParse(parts[1]) ?? 0) > 0) hit++;
    } else if (line == 'end_of_record' && path != null) {
      if (include(path)) files.add((path: path, hit: hit, found: found));
      path = null;
    }
  }

  return (
    hit: files.fold(0, (sum, f) => sum + f.hit),
    found: files.fold(0, (sum, f) => sum + f.found),
    files: files,
  );
}

/// Whether [path] is in a feature's domain layer.
bool isDomainFile(String path) =>
    RegExp('(^|/)lib/features/[^/]+/domain/').hasMatch(path) &&
    !path.endsWith('.g.dart');
