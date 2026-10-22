// The test font draws every character, space included, as a square as wide
// as the font size: at 20, "aa bb" is 100 wide and a space 20.

import 'package:bah_francais/features/drills/presentation/widgets/blank_sentence.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _style = TextStyle(fontSize: 20);
const _fieldKey = Key('field');

Finder get field => find.byKey(_fieldKey);

/// A sentence in a [width] × [height] space, with padding 16 all round, so
/// [width] 400 leaves 368, and 134 either side of a box 100 wide.
Future<void> pumpSentence(
  WidgetTester tester, {
  String before = '',
  String after = '',
  double width = 400,
  double height = 400,
  double headerHeight = 50,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: height,
            child: BlankSentence(
              header: SizedBox(height: headerHeight, width: 10),
              before: before,
              after: after,
              style: _style,
              fieldWidth: 100,
              field: const TextField(
                key: _fieldKey,
                style: _style,
                decoration: InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('with room, the words sit either side of the box', (
    tester,
  ) async {
    await pumpSentence(tester, before: 'aa bb ', after: ' cc dd');
    final box = tester.getRect(field);
    final left = tester.getRect(find.text('aa bb'));
    final right = tester.getRect(find.text('cc dd'));
    expect(box.left - left.right, 20, reason: 'a space before the box');
    expect(right.left - box.right, 20, reason: 'a space after it');
    expect(left.center.dy, moreOrLessEquals(box.center.dy, epsilon: 6));
    expect(right.center.dy, moreOrLessEquals(box.center.dy, epsilon: 6));
  });

  testWidgets('what does not fit beside it wraps above and below', (
    tester,
  ) async {
    // 268 wide: 84 either side, room for "bb" and its space, not "aa bb".
    await pumpSentence(tester, before: 'aa bb ', after: ' cc dd', width: 300);
    final box = tester.getRect(field);
    expect(tester.getRect(find.text('aa')).bottom, lessThanOrEqualTo(box.top));
    expect(tester.getRect(find.text('bb')).right, lessThan(box.left));
    expect(tester.getRect(find.text('cc')).left, greaterThan(box.right));
    expect(
      tester.getRect(find.text('dd')).top,
      greaterThanOrEqualTo(box.bottom),
    );
  });

  testWidgets('the box is in the middle of the width and the height', (
    tester,
  ) async {
    await pumpSentence(tester, before: 'aa ', after: ' bb');
    final box = tester.getRect(field);
    expect(box.width, 100);
    expect(box.center.dx, 200);
    expect(box.center.dy, moreOrLessEquals(200, epsilon: 1));

    await pumpSentence(tester);
    expect(tester.getRect(field).center, const Offset(200, 200));
  });

  testWidgets('a tall header pushes the box down; taller, it scrolls', (
    tester,
  ) async {
    await pumpSentence(tester, headerHeight: 250);
    // Below the header and its gap, not in the middle.
    expect(tester.getRect(field).top, 16 + 250 + 16);
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scroll.position.maxScrollExtent, 0);

    await pumpSentence(tester, headerHeight: 500);
    final tall = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(tall.position.maxScrollExtent, greaterThan(0));
  });

  testWidgets('a word that touches the noun touches the box', (tester) async {
    await pumpSentence(tester, before: 'l’', after: '.');
    final box = tester.getRect(field);
    expect(box.left - tester.getRect(find.text('l’')).right, 2);
    expect(tester.getRect(find.text('.')).left - box.right, 2);
  });

  testWidgets('? ! : ; stay with the word before them', (tester) async {
    // "cc ?" is 80 wide: with its space, too wide for the 84 beside the box.
    await pumpSentence(tester, after: ' cc ?', width: 300);
    expect(find.text('cc ?'), findsOneWidget);
    expect(
      tester.getRect(find.text('cc ?')).top,
      greaterThanOrEqualTo(tester.getRect(field).bottom),
    );
  });

  testWidgets('the box never gets wider than the space', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 400,
            child: BlankSentence(
              header: SizedBox.shrink(),
              before: 'aa ',
              after: ' bb',
              style: _style,
              fieldWidth: 1000,
              field: TextField(key: _fieldKey, style: _style),
            ),
          ),
        ),
      ),
    );
    expect(tester.getRect(field).width, 168);
    expect(
      tester.getRect(find.text('aa')).bottom,
      lessThanOrEqualTo(tester.getRect(field).top),
    );
    expect(tester.takeException(), isNull);
  });

  test('a text is measured on one line, at the text size', () {
    expect(textWidth('aa bb', _style, TextScaler.noScaling), 100);
    expect(textWidth('aa', _style, const TextScaler.linear(2)), 80);
  });
}
