/// Reads a content directory and the JSON Schemas from disk. Everything
/// else works on what this returns, so it can be tested without files.
library;

import 'dart:io';

import 'package:json_schema/json_schema.dart';
import 'package:path/path.dart' as p;

/// A content file: its path, relative to the content directory and with `/`
/// separators, and its text.
class SourceFile {
  const SourceFile(this.path, this.text);

  final String path;
  final String text;
}

/// Everything a content directory holds.
class ContentFiles {
  const ContentFiles({
    this.verbCategories,
    this.nouns = const [],
    this.verbs = const [],
    this.images = const {},
  });

  /// Reads `verb-categories.json`, `nouns/*.json`, `verbs/*.json` and the
  /// files under `images/` in [root]. Anything else there (such as a
  /// `sample/` or `schema/` folder) is not content.
  factory ContentFiles.read(Directory root) {
    String relative(File file) =>
        p.split(p.relative(file.path, from: root.path)).join('/');

    List<SourceFile> jsonFiles(String folder) {
      final dir = Directory(p.join(root.path, folder));
      if (!dir.existsSync()) return const [];
      final files =
          dir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.json'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      return [
        for (final f in files) SourceFile(relative(f), f.readAsStringSync()),
      ];
    }

    final categories = File(p.join(root.path, 'verb-categories.json'));
    final imagesDir = Directory(p.join(root.path, 'images'));
    return ContentFiles(
      verbCategories: categories.existsSync()
          ? SourceFile(relative(categories), categories.readAsStringSync())
          : null,
      nouns: jsonFiles('nouns'),
      verbs: jsonFiles('verbs'),
      images: {
        if (imagesDir.existsSync())
          for (final f in imagesDir.listSync(recursive: true).whereType<File>())
            relative(f): f.readAsBytesSync(),
      },
    );
  }

  /// `verb-categories.json`, if there is one.
  final SourceFile? verbCategories;
  final List<SourceFile> nouns;
  final List<SourceFile> verbs;

  /// Image files by path: `images/fourchette/fourchette-1.svg`.
  final Map<String, List<int>> images;
}

/// The JSON Schema for each kind of content file (`content/schema/`).
class ContentSchemas {
  const ContentSchemas({
    required this.nounCategory,
    required this.verb,
    required this.verbCategories,
  });

  /// Reads the schemas from [dir].
  factory ContentSchemas.read(Directory dir) {
    JsonSchema schema(String name) =>
        JsonSchema.create(File(p.join(dir.path, name)).readAsStringSync());
    return ContentSchemas(
      nounCategory: schema('noun-category.schema.json'),
      verb: schema('verb.schema.json'),
      verbCategories: schema('verb-categories.schema.json'),
    );
  }

  final JsonSchema nounCategory;
  final JsonSchema verb;
  final JsonSchema verbCategories;
}
