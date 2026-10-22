import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// [text]'s width on one line in [style], at the user's text size.
double textWidth(String text, TextStyle style, TextScaler scaler) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// A sentence with the answer box in place of its noun (decision 70), below
/// a [header].
///
/// The box's line holds as many of the words around it as fit across the
/// width, taken on whichever side is shorter so the box stays as near the
/// middle as it can, and is centred; the rest wrap onto lines above and
/// below. The box's line is as near the middle of the height as the header
/// and the lines above allow. When everything is taller than the space, it
/// scrolls.
class BlankSentence extends StatelessWidget {
  const BlankSentence({
    required this.header,
    required this.before,
    required this.after,
    required this.style,
    required this.field,
    required this.fieldWidth,
    super.key,
  });

  /// The prompt, above the sentence.
  final Widget header;

  /// The words before and after the box. Both are empty when there is no
  /// sentence, and the box is alone.
  final String before;
  final String after;

  /// The sentence's text style, which the box's text shares.
  final TextStyle style;

  final Widget field;

  /// The box's width, before it is capped to the width there is.
  final double fieldWidth;

  static const _padding = 16.0;

  /// The gap between the box and a word that touches it.
  static const _touching = 2.0;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    double measure(String text) => textWidth(text, style, scaler);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - 2 * _padding;
        final box = math.min(fieldWidth, width);
        // A space between the box and the words beside it, unless they
        // touch, as after *l’* or before a full stop.
        final space = measure(' ');
        final gapBefore = before.endsWith(' ') ? space : _touching;
        final gapAfter = after.startsWith(' ') ? space : _touching;
        final (:above, :left, :right, :below) = _fitAround(
          _words(before),
          _words(after),
          room: width - box,
          measure: measure,
          gapBefore: gapBefore,
          gapAfter: gapAfter,
        );
        Widget lines(String text) => text.isEmpty
            ? const SizedBox.shrink()
            : Text(text, textAlign: TextAlign.center, style: style);
        Widget beside(String text) =>
            Text(text, style: style, maxLines: 1, softWrap: false);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(_padding),
          child: _CentredLineLayout(
            height: constraints.maxHeight - 2 * _padding,
            gap: _padding,
            children: [
              header,
              lines(above),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  if (left.isNotEmpty) ...[
                    beside(left),
                    SizedBox(width: gapBefore),
                  ],
                  SizedBox(width: box, child: field),
                  if (right.isNotEmpty) ...[
                    SizedBox(width: gapAfter),
                    beside(right),
                  ],
                ],
              ),
              lines(below),
            ],
          ),
        );
      },
    );
  }
}

/// The words of [text]. The punctuation French puts a space before (*?*,
/// *!*, *:*, *;*) is joined to the word before it with a no-break space, so
/// it never starts a line.
List<String> _words(String text) {
  final words = <String>[];
  for (final word in text.split(' ')) {
    if (word.isEmpty) continue;
    if (words.isNotEmpty && _spacedPunctuation.hasMatch(word)) {
      words.last = '${words.last} $word';
    } else {
      words.add(word);
    }
  }
  return words;
}

final _spacedPunctuation = RegExp(r'^[?!:;]+$');

/// The words [before] and [after] the box, split into those on the lines
/// above, beside it on the left and right, and on the lines below.
///
/// The box's line takes words one at a time while they fit in [room]: from
/// the end of [before] or the start of [after], whichever side is shorter,
/// so the box stays near the middle. A side with words takes its gap too.
({String above, String left, String right, String below}) _fitAround(
  List<String> before,
  List<String> after, {
  required double room,
  required double Function(String) measure,
  required double gapBefore,
  required double gapAfter,
}) {
  String left(int n) => before.sublist(before.length - n).join(' ');
  String right(int n) => after.sublist(0, n).join(' ');
  double used(int l, int r) =>
      (l > 0 ? measure(left(l)) + gapBefore : 0) +
      (r > 0 ? measure(right(r)) + gapAfter : 0);
  var l = 0;
  var r = 0;
  while (true) {
    final canLeft = l < before.length && used(l + 1, r) <= room;
    final canRight = r < after.length && used(l, r + 1) <= room;
    if (!canLeft && !canRight) break;
    if (canLeft && (!canRight || measure(left(l)) <= measure(right(r)))) {
      l++;
    } else {
      r++;
    }
  }
  return (
    above: before.sublist(0, before.length - l).join(' '),
    left: left(l),
    right: right(r),
    below: after.sublist(r).join(' '),
  );
}

/// Lays out four children, each centred across the width: a header at the
/// top, then the lines above a line, the line, and the lines below it. The
/// line sits as near the middle of [height] as the header and the lines
/// above allow, and as the lines below need. It is taller than [height]
/// when its children are, for a scroll view.
class _CentredLineLayout extends MultiChildRenderObjectWidget {
  /// [children]: the header, the lines above, the line, the lines below.
  const _CentredLineLayout({
    required this.height,
    required this.gap,
    required super.children,
  });

  final double height;

  /// The space below the header.
  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCentredLine(height: height, gap: gap);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderCentredLine renderObject,
  ) {
    renderObject
      ..height = height
      ..gap = gap;
  }
}

class _CentredLineParentData extends ContainerBoxParentData<RenderBox>;

class _RenderCentredLine extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CentredLineParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CentredLineParentData> {
  _RenderCentredLine({required this._height, required this._gap});

  double _height;
  double get height => _height;
  set height(double value) {
    if (value == _height) return;
    _height = value;
    markNeedsLayout();
  }

  double _gap;
  double get gap => _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CentredLineParentData) {
      child.parentData = _CentredLineParentData();
    }
  }

  /// Each child's top, from their sizes, and the height they take.
  (List<double>, double) _place(List<Size> sizes) {
    final [header, above, line, below] = sizes;
    final gap = header.height > 0 ? _gap : 0.0;
    final middle = (_height - line.height) / 2;
    final highest = header.height + gap + above.height;
    final lowest = _height - line.height - below.height;
    final top = math.max(highest, math.min(middle, lowest));
    return (
      [0, top - above.height, top, top + line.height],
      math.max(_height, top + line.height + below.height),
    );
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final loose = BoxConstraints(maxWidth: width);
    final children = getChildrenAsList();
    for (final child in children) {
      child.layout(loose, parentUsesSize: true);
    }
    final (tops, height) = _place([for (final c in children) c.size]);
    for (final (i, child) in children.indexed) {
      (child.parentData! as _CentredLineParentData).offset = Offset(
        (width - child.size.width) / 2,
        tops[i],
      );
    }
    size = constraints.constrain(Size(width, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
