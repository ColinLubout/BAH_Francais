/// Tags sentences with the grammar concepts they use and their level
/// (decision 65), from `grammar.json`.
///
/// Run from the repo root:
///
///     dart run tool/grammar_tag.dart content
///
/// A sentence with no tags gets the concepts the detection finds. One that
/// has tags keeps them, since they may have been corrected by hand; where the
/// detection disagrees, the difference is listed to look at. Then
/// `tool/content_build.dart` checks every sentence is within the content's
/// `max_level`.
library;

import 'dart:convert';
import 'dart:io';

import 'src/content/content_files.dart';
import 'src/content/content_validator.dart';
import 'src/content/grammar.dart';

const _usage = 'Usage: dart run tool/grammar_tag.dart <content dir>';

void main(List<String> args) {
  if (args.length != 1) _fail(_usage);
  final dir = Directory(args.single);
  final grammarFile = File('${dir.path}/grammar.json');
  if (!grammarFile.existsSync()) _fail('${grammarFile.path} not found.');
  final concepts = conceptsFromJson(
    jsonDecode(grammarFile.readAsStringSync()) as Map<String, Object?>,
  );
  final known = {for (final c in concepts) c.id};

  // The content as parsed; the grammar tags themselves may not be valid yet.
  final content = validateContent(
    ContentFiles.read(dir),
    ContentSchemas.read(Directory('content/schema')),
  ).content;
  final context = GrammarContext(content);
  final byId = {for (final s in content.sentences) s.id: s};

  var tagged = 0;
  final differences = <String>[];
  final sentenceFiles =
      Directory('${dir.path}/sentences').listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in sentenceFiles) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    final sentences = (json['sentences']! as List).cast<Map<String, Object?>>();
    var changed = false;
    for (var i = 0; i < sentences.length; i++) {
      final sentence = byId[sentences[i]['id']];
      if (sentence == null) continue;
      final detected = detectGrammar(sentence, context);
      final unknown = detected.difference(known);
      if (unknown.isNotEmpty) {
        _fail('The detection found concepts grammar.json lacks: $unknown');
      }
      final tags = (sentences[i]['grammar'] as List?)?.cast<String>();
      if (tags == null) {
        sentences[i] = withGrammar(sentences[i], detected, concepts);
        tagged++;
        changed = true;
        continue;
      }
      final missing = detected.difference(tags.toSet());
      final extra = tags.toSet().difference(detected);
      if (missing.isNotEmpty || extra.isNotEmpty) {
        final what = [
          if (missing.isNotEmpty)
            'detected but not tagged: ${missing.join(', ')}',
          if (extra.isNotEmpty) 'tagged but not detected: ${extra.join(', ')}',
        ];
        differences.add(
          '${sentence.id} "${sentence.text}": ${what.join('; ')}',
        );
      }
    }
    if (changed) {
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(json)}\n',
      );
    }
  }

  stdout.writeln('Tagged $tagged sentence(s).');
  if (differences.isNotEmpty) {
    stdout.writeln(
      '\n${differences.length} tagged sentence(s) where the detection '
      'disagrees (the tags are kept; look at them):',
    );
    for (final d in differences) {
      stdout.writeln('  $d');
    }
  }
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(2);
}
