import 'package:flutter/widgets.dart';

/// Lays out [text] in [style] the way a [Text] in [context] would, at [width].
TextPainter _layout(BuildContext context, String text, TextStyle style, double width) =>
    TextPainter(
      text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width);

/// [text] laid out at most [width] wide, at the start of the space it is given (also when a
/// stretching parent hands it a tight width).
Widget _narrowed(double width, Widget text) => Align(
  alignment: AlignmentDirectional.topStart,
  heightFactor: 1,
  child: ConstrainedBox(
    constraints: BoxConstraints(maxWidth: width),
    child: text,
  ),
);

/// Text wrapped like CSS `text-wrap: balance`: as many lines as it needs at full width, but
/// evened out (the narrowest width that does not add a line), instead of a long first line
/// and a short last one.
class BalancedText extends StatelessWidget {
  const BalancedText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      int lines(double width) {
        final p = _layout(context, text, style, width);
        final n = p.computeLineMetrics().length;
        p.dispose();
        return n;
      }

      var width = constraints.maxWidth;
      final target = width.isFinite ? lines(width) : 1;
      if (target > 1) {
        // Binary search for the narrowest width that still fits in `target` lines.
        var lo = width / target - 1;
        var hi = width;
        while (hi - lo > 0.5) {
          final mid = (lo + hi) / 2;
          if (lines(mid) > target) {
            lo = mid;
          } else {
            hi = mid;
          }
        }
        width = hi.ceilToDouble();
      }
      return _narrowed(width, Text(text, style: style));
    },
  );
}

/// Text wrapped like CSS `text-wrap: pretty` in Chrome for short paragraphs: when the last
/// line would hold a single word, the line above gives it its last word, so no word is left
/// alone at the end.
class PrettyText extends StatelessWidget {
  const PrettyText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final narrower = width.isFinite ? _withoutOrphan(context, width) : null;
      return _narrowed(narrower ?? width, Text(text, style: style));
    },
  );

  /// A width just narrow enough to bring a second word down to the last line, keeping the
  /// number of lines; null when the text has no lone last word or cannot lose it.
  double? _withoutOrphan(BuildContext context, double width) {
    final full = _layout(context, text, style, width);
    try {
      final lines = full.computeLineMetrics().length;
      if (lines < 2) return null;
      final last = full.getLineBoundary(TextPosition(offset: text.length - 1));
      if (_words(last) > 1) return null;
      // The line above: it must keep at least one word after giving up its last.
      final above = full.getLineBoundary(TextPosition(offset: last.start - 1));
      final aboveText = text.substring(above.start, above.end).trimRight();
      if (!aboveText.contains(' ')) return null;
      // Just short of where that line's last word ends, so the word no longer fits.
      final boxes = full.getBoxesForSelection(
        TextSelection(baseOffset: above.start, extentOffset: above.start + aboveText.length),
      );
      final right = boxes.fold(0.0, (r, b) => b.right > r ? b.right : r);
      final narrower = right - 0.5;
      final check = _layout(context, text, style, narrower);
      final ok =
          check.computeLineMetrics().length == lines &&
          _words(check.getLineBoundary(TextPosition(offset: text.length - 1))) > 1;
      check.dispose();
      return ok ? narrower : null;
    } finally {
      full.dispose();
    }
  }

  int _words(TextRange line) =>
      text.substring(line.start, line.end).trim().split(RegExp(r'\s+')).length;
}
