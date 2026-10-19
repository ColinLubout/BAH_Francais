import 'package:flutter_test/flutter_test.dart';

import '../../../tool/src/content/svg_rules.dart';

/// An SVG with a square viewBox around [body].
String svg(String body, {String attributes = ''}) =>
    '<svg xmlns="http://www.w3.org/2000/svg" '
    'xmlns:xlink="http://www.w3.org/1999/xlink" '
    'viewBox="0 0 160 160" $attributes>$body</svg>';

void main() {
  test('shapes, groups, gradients and internal references pass', () {
    expect(
      svgProblems(
        svg(
          [
            '<defs><linearGradient id="g"><stop offset="0"/></linearGradient>',
            '<circle id="dot" r="4"/></defs>',
            '<g fill="url(#g)"><rect width="10" height="10"/></g>',
            '<use href="#dot"/><use xlink:href="#dot"/>',
            '<style>circle { fill: url(#g); }</style>',
          ].join(),
        ),
      ),
      isEmpty,
    );
  });

  test('it parses', () {
    expect(svgProblems('<svg viewBox="0 0 1 1">'), [
      startsWith('does not parse'),
    ]);
  });

  test('it is an SVG', () {
    expect(svgProblems('<html/>'), ['its root element is <html>, not <svg>']);
  });

  group('the viewBox', () {
    test('is there', () {
      expect(svgProblems('<svg xmlns="http://www.w3.org/2000/svg"/>'), [
        'has no viewBox',
      ]);
    });

    test('has four numbers', () {
      expect(svgProblems('<svg viewBox="0 0 160"/>'), [
        'has a malformed viewBox, "0 0 160"',
      ]);
      expect(svgProblems('<svg viewBox="0 0 a b"/>'), [
        startsWith('has a malformed viewBox'),
      ]);
    });

    test('is square', () {
      expect(svgProblems('<svg viewBox="0 0 160 120"/>'), [
        'is not square: viewBox "0 0 160 120"',
      ]);
      expect(svgProblems('<svg viewBox="0,0,48,48"/>'), isEmpty);
    });
  });

  test('no embedded images', () {
    expect(svgProblems(svg('<image href="photo.png"/>')), [
      'embeds an image (<image>)',
      'refers to another file (href="photo.png")',
    ]);
    expect(svgProblems(svg('<use href="data:image/png;base64,AAAA"/>')), [
      'embeds a file (href="data:…")',
    ]);
  });

  test('no scripts', () {
    expect(svgProblems(svg('<script>alert(1)</script>')), [
      'has a script (<script>)',
    ]);
    expect(svgProblems(svg('', attributes: 'onload="alert(1)"')), [
      'has a script (onload)',
    ]);
  });

  test('no text', () {
    expect(svgProblems(svg('<text>chat</text>')), ['has text (<text>)']);
    expect(svgProblems(svg('<g><tspan>a</tspan></g>')), ['has text (<tspan>)']);
    expect(svgProblems(svg('<textPath>a</textPath>')), [
      'has text (<textPath>)',
    ]);
  });

  test('no fonts', () {
    expect(svgProblems(svg('<font/>')), ['embeds a font (<font>)']);
    expect(svgProblems(svg('<font-face/>')), ['embeds a font (<font-face>)']);
    expect(svgProblems(svg('<style>@font-face { font-family: x; }</style>')), [
      'embeds a font (@font-face)',
    ]);
  });

  test('no other content or files', () {
    expect(svgProblems(svg('<foreignObject/>')), [
      'embeds other content (<foreignObject>)',
    ]);
    expect(svgProblems(svg('<style>@import "a.css";</style>')), [
      'imports a stylesheet (@import)',
    ]);
    expect(svgProblems(svg('<rect style="fill: url(\'a.png\')"/>')), [
      'refers to another file (url(…))',
    ]);
    expect(svgProblems(svg('<a href="https://example.com"/>')), [
      'refers to another file (href="https://example.com")',
    ]);
  });

  test('each problem is listed once', () {
    expect(svgProblems(svg('<text>a</text><text>b</text>')), [
      'has text (<text>)',
    ]);
  });
}
