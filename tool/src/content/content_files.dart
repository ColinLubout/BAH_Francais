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
    this.tenses,
    this.grammar,
    this.verbCategories,
    this.nouns = const [],
    this.verbs = const [],
    this.sentences = const [],
    this.images = const {},
  });

  /// Reads `tenses.json`, `grammar.json`, `verb-categories.json`,
  /// `nouns/*.json`,
  /// `verbs/*.json`, `sentences/*.json` and the files under `images/` in
  /// [root]. Anything else there (such as a `sample/` or `schema/` folder) is
  /// not content.
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

    SourceFile? file(String name) {
      final f = File(p.join(root.path, name));
      return f.existsSync()
          ? SourceFile(relative(f), f.readAsStringSync())
          : null;
    }

    final imagesDir = Directory(p.join(root.path, 'images'));
    return ContentFiles(
      tenses: file('tenses.json'),
      grammar: file('grammar.json'),
      verbCategories: file('verb-categories.json'),
      nouns: jsonFiles('nouns'),
      verbs: jsonFiles('verbs'),
      sentences: jsonFiles('sentences'),
      images: {
        if (imagesDir.existsSync())
          for (final f in imagesDir.listSync(recursive: true).whereType<File>())
            relative(f): f.readAsBytesSync(),
      },
    );
  }

  /// `tenses.json`, if there is one: the tenses the content teaches.
  final SourceFile? tenses;

  /// `grammar.json`, if there is one: the grammar concepts sentences are
  /// tagged with, and the highest level they may reach.
  final SourceFile? grammar;

  /// `verb-categories.json`, if there is one.
  final SourceFile? verbCategories;
  final List<SourceFile> nouns;
  final List<SourceFile> verbs;
  final List<SourceFile> sentences;

  /// Image files by path: `images/fourchette/fourchette-1.svg`.
  final Map<String, List<int>> images;
}

/// The JSON Schema for each kind of content file (`content/schema/`).
class ContentSchemas {
  const ContentSchemas({
    required this.tenses,
    required this.grammar,
    required this.nounCategory,
    required this.verb,
    required this.verbCategories,
    required this.sentences,
  });

  /// Reads the schemas from [dir].
  factory ContentSchemas.read(Directory dir) {
    JsonSchema schema(String name) =>
        JsonSchema.create(File(p.join(dir.path, name)).readAsStringSync());
    return ContentSchemas(
      tenses: schema('tenses.schema.json'),
      grammar: schema('grammar.schema.json'),
      nounCategory: schema('noun-category.schema.json'),
      verb: schema('verb.schema.json'),
      verbCategories: schema('verb-categories.schema.json'),
      sentences: schema('sentences.schema.json'),
    );
  }

  final JsonSchema tenses;
  final JsonSchema grammar;
  final JsonSchema nounCategory;
  final JsonSchema verb;
  final JsonSchema verbCategories;
  final JsonSchema sentences;
}
