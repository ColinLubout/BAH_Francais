/// Validates a content directory and builds its content pack.
///
/// Run from the repo root:
///
///     dart run tool/content_build.dart content/sample
///     dart run tool/content_build.dart content --version 14 --out pack.sqlite
///
/// `--version` is the pack's content version (0, the default, for a
/// development build) and `--out` the pack file
/// (`build/content/content-pack.sqlite` by default).
///
/// Exits with 1, listing every problem, if the content is invalid. Warnings
/// are listed but don't fail the build.
library;

import 'dart:io';

import 'package:bah_francais/features/content/domain/content.dart';

import 'src/content/content_files.dart';
import 'src/content/content_validator.dart';
import 'src/content/pack_builder.dart';

const _usage =
    'Usage: dart run tool/content_build.dart <content dir> '
    '[--version <n>] [--out <file>]';

Future<void> main(List<String> args) async {
  String? dir;
  var version = 0;
  var out = 'build/content/content-pack.sqlite';
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    final value = i + 1 < args.length ? args[i + 1] : null;
    if (arg == '--version' && value != null && int.tryParse(value) != null) {
      version = int.parse(value);
      i++;
    } else if (arg == '--out' && value != null) {
      out = value;
      i++;
    } else if (!arg.startsWith('--') && dir == null) {
      dir = arg;
    } else {
      _fail(_usage, code: 2);
    }
  }
  if (dir == null) _fail(_usage, code: 2);

  final root = Directory(dir);
  final schemaDir = Directory('content/schema');
  if (!root.existsSync()) _fail('$dir not found.', code: 2);
  if (!schemaDir.existsSync()) {
    _fail('content/schema not found. Run this from the repo root.', code: 2);
  }

  final report = validateContent(
    ContentFiles.read(root),
    ContentSchemas.read(schemaDir),
  );
  for (final warning in report.warnings) {
    stdout.writeln('warning: $warning');
  }
  if (!report.isValid) {
    stderr.writeln('$dir has ${report.errors.length} problem(s):');
    for (final error in report.errors) {
      stderr.writeln('  $error');
    }
    exit(1);
  }

  final content = report.content;
  final now = DateTime.now().toUtc();
  final released = '${now.year}-${_two(now.month)}-${_two(now.day)}';
  await buildPack(
    content,
    ContentInfo(version: version, releasedAt: released),
    File(out),
    now: now,
  );

  stdout
    ..writeln(
      'Checked $dir, teaching ${content.tenses.map((t) => t.id).join(', ')}: '
      '${content.categories.length} categories, '
      '${content.nouns.length} nouns, ${content.verbs.length} verbs, '
      '${content.sentences.length} sentences, ${content.images.length} images.',
    )
    ..writeln('Wrote $out (content version $version).');
}

String _two(int n) => n.toString().padLeft(2, '0');

Never _fail(String message, {required int code}) {
  stderr.writeln(message);
  exit(code);
}
