/// Checks content against Wiktionary: genders, plural-only nouns,
/// auxiliaries and every conjugated form.
///
/// Run from the repo root, after downloading Kaikki.org's French dictionary
/// (https://kaikki.org/dictionary/French/kaikki.org-dictionary-French.jsonl)
/// into `data/kaikki/`, which git ignores:
///
///     dart run tool/dictionary_check.dart content
///     dart run tool/dictionary_check.dart content --dictionary <file.jsonl>
///
/// It lists where the content and the dictionary disagree, then notes such
/// as a variant form the content doesn't accept. It only advises: it never
/// fails, and CI doesn't run it, since the dictionary isn't in the repo.
/// Wiktionary can be wrong too, so a disagreement is something to look at,
/// not an automatic fix.
library;

import 'dart:convert';
import 'dart:io';

import 'src/content/content_files.dart';
import 'src/content/content_validator.dart';
import 'src/content/dictionary.dart';

const _defaultDictionary = 'data/kaikki/kaikki.org-dictionary-French.jsonl';
const _usage =
    'Usage: dart run tool/dictionary_check.dart <content dir> '
    '[--dictionary <file.jsonl>]';

Future<void> main(List<String> args) async {
  String? dir;
  var dictionaryPath = _defaultDictionary;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--dictionary' && i + 1 < args.length) {
      dictionaryPath = args[++i];
    } else if (!args[i].startsWith('--') && dir == null) {
      dir = args[i];
    } else {
      _fail(_usage);
    }
  }
  if (dir == null) _fail(_usage);
  final dictionaryFile = File(dictionaryPath);
  if (!dictionaryFile.existsSync()) {
    _fail(
      '$dictionaryPath not found. Download '
      'https://kaikki.org/dictionary/French/kaikki.org-dictionary-French.jsonl '
      'into data/kaikki/.',
    );
  }

  final report = validateContent(
    ContentFiles.read(Directory(dir)),
    ContentSchemas.read(Directory('content/schema')),
  );
  if (!report.isValid) {
    _fail(
      '$dir has ${report.errors.length} problem(s). Fix them first: '
      'dart run tool/content_build.dart $dir',
    );
  }
  final content = report.content;

  stdout.writeln('Reading $dictionaryPath…');
  final dictionary = await Dictionary.read(
    dictionaryFile
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter()),
    words: wordsToLook(content),
  );
  final findings = compare(content, dictionary);
  final differences = [
    for (final f in findings)
      if (f.difference) f,
  ];
  final notes = [
    for (final f in findings)
      if (!f.difference) f,
  ];

  stdout.writeln(
    'Checked ${content.nouns.length} nouns and ${content.verbs.length} verbs '
    'against Wiktionary (via Kaikki.org).',
  );
  if (differences.isEmpty) {
    stdout.writeln('No disagreements.');
  } else {
    stdout.writeln('\n${differences.length} disagreement(s):');
    for (final f in differences) {
      stdout.writeln('  $f');
    }
  }
  if (notes.isNotEmpty) {
    stdout.writeln('\n${notes.length} note(s):');
    for (final f in notes) {
      stdout.writeln('  $f');
    }
  }
  stdout.writeln(
    '\nNot checked: h aspiré and elision before h, which this data does not '
    'mark.',
  );
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(2);
}
