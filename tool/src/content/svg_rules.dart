/// The artwork rules for official SVGs (Activities → Images) that a program
/// can check. "Readable at 160 px" and "legible on light and dark" are left
/// to whoever reviews the artwork.
library;

import 'package:xml/xml.dart';

/// The size official images should stay under. Bigger ones get a warning,
/// not an error, until the real limit is known.
const int svgSizeTarget = 20 * 1024;

/// Every rule [markup] breaks; empty when it passes.
List<String> svgProblems(String markup) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(markup);
  } on XmlException catch (e) {
    return ['does not parse: ${e.message}'];
  }
  final root = document.rootElement;
  if (root.name.local != 'svg') {
    return ['its root element is <${root.name.qualified}>, not <svg>'];
  }

  final problems = <String>{};
  final viewBox = root.getAttribute('viewBox');
  if (viewBox == null) {
    problems.add('has no viewBox');
  } else {
    final sides = viewBox.trim().split(RegExp(r'[\s,]+')).map(double.tryParse);
    if (sides.length != 4 || sides.contains(null)) {
      problems.add('has a malformed viewBox, "$viewBox"');
    } else if (sides.elementAt(2) != sides.elementAt(3)) {
      problems.add('is not square: viewBox "$viewBox"');
    }
  }

  for (final element in [root, ...root.descendantElements]) {
    switch (element.name.local) {
      case 'image':
        problems.add('embeds an image (<image>)');
      case 'script':
        problems.add('has a script (<script>)');
      case 'text' || 'tspan' || 'textPath':
        problems.add('has text (<${element.name.local}>)');
      case 'font' || 'font-face':
        problems.add('embeds a font (<${element.name.local}>)');
      case 'foreignObject':
        problems.add('embeds other content (<foreignObject>)');
      case 'style':
        _checkCss(element.innerText, problems);
    }
    for (final attribute in element.attributes) {
      final name = attribute.name.local;
      final value = attribute.value.trim();
      if (name.toLowerCase().startsWith('on')) {
        problems.add('has a script (${attribute.name.qualified})');
      } else if (name == 'href') {
        if (value.toLowerCase().startsWith('data:')) {
          problems.add('embeds a file (href="data:…")');
        } else if (!value.startsWith('#')) {
          problems.add('refers to another file (href="$value")');
        }
      } else {
        _checkCss(value, problems);
      }
    }
  }
  return problems.toList();
}

void _checkCss(String css, Set<String> problems) {
  if (css.contains('@font-face')) problems.add('embeds a font (@font-face)');
  if (css.contains('@import')) problems.add('imports a stylesheet (@import)');
  if (RegExp(r'''url\(\s*['"]?(?!#)''').hasMatch(css)) {
    problems.add('refers to another file (url(…))');
  }
}
