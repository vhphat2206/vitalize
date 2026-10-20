import 'package:flutter/widgets.dart';

/// Line height the CSS way: the extra space of `line-height` split evenly above and below the
/// glyphs, so text sits in its line box where the web app puts it.
const cssLeading = TextHeightBehavior(leadingDistribution: TextLeadingDistribution.even);

/// The page's letter spacing (`body { letter-spacing: -0.005em }` at 15 px), which the web app's
/// text inherits as a length whatever its own size. Text inside a `<button>` has none: buttons
/// reset `letter-spacing` and pass that on.
const bodyTracking = -0.075;

/// How a [WrappedText] breaks its lines, after CSS `text-wrap`.
enum WrapStyle {
  /// `balance`: lines of about the same length, for titles.
  balance,

  /// `pretty`: never a single word alone on the last line, for body copy.
  pretty,
}

/// Plain text broken like the web app's `text-wrap: balance` and `text-wrap: pretty`, which
/// Flutter has no switch for. The text is laid out at a narrower width than it is given: the
/// narrowest that keeps its number of lines (balance), or the widest that moves a word down
/// next to a lone last word (pretty, which is what Chrome does to these short texts). The
/// widget itself still takes the full width, like a block on the web.
class WrappedText extends StatelessWidget {
  const WrappedText(this.text, {super.key, required this.style, required this.wrap});

  final String text;
  final TextStyle style;
  final WrapStyle wrap;

  static final _cache = <String, double>{};

  @override
  Widget build(BuildContext context) {
    var merged = DefaultTextStyle.of(context).style.merge(style);
    // Measured as the Text below will draw it.
    if (MediaQuery.boldTextOf(context)) {
      merged = merged.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final child = Text(text, style: style);
        if (!box.hasBoundedWidth) return child;
        final key = '${wrap.name}|${box.maxWidth}|${scaler.scale(100)}|${merged.hashCode}|$text';
        final width = _cache[key] ??= () {
          if (_cache.length > 400) _cache.clear();
          final painter = TextPainter(
            text: TextSpan(text: text, style: merged),
            textDirection: direction,
            textScaler: scaler,
          );
          final w = wrapWidth(painter, box.maxWidth, wrap);
          painter.dispose();
          return w;
        }();
        if (width >= box.maxWidth) return child;
        return Align(
          alignment: AlignmentDirectional.topStart,
          heightFactor: 1,
          child: SizedBox(width: width, child: child),
        );
      },
    );
  }
}

/// The width to lay [painter]'s text out at so its lines break like [wrap]; [maxWidth] when the
/// plain greedy breaks already do.
double wrapWidth(TextPainter painter, double maxWidth, WrapStyle wrap) {
  final lines = linesAt(painter, maxWidth);
  // Chromium only re-wraps text of up to six lines.
  if (lines.length < 2 || lines.length > 6) return maxWidth;
  final count = lines.length;
  final words = _wordCount(lines);
  // A narrower width may move words down but not add a line or split a word.
  bool keeps(List<String> l) => l.length == count && _wordCount(l) == words;

  // The narrowest width that keeps the line count.
  var lo = 0.0;
  var hi = maxWidth;
  while (hi - lo > 0.25) {
    final mid = (lo + hi) / 2;
    if (keeps(linesAt(painter, mid))) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  final balanced = hi;
  if (wrap == WrapStyle.balance) return balanced;

  bool lonely(List<String> l) => !l.last.contains(' ');
  if (!lonely(lines) || lonely(linesAt(painter, balanced))) return maxWidth;
  // The widest width at which the last line has company.
  lo = balanced;
  hi = maxWidth;
  while (hi - lo > 0.25) {
    final mid = (lo + hi) / 2;
    if (lonely(linesAt(painter, mid))) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return lo;
}

/// The text of each line when [painter] is laid out [width] wide.
List<String> linesAt(TextPainter painter, double width) {
  painter.layout(maxWidth: width);
  final text = painter.plainText;
  return [
    for (final line in painter.computeLineMetrics())
      () {
        final at = painter.getPositionForOffset(
          Offset(line.left + 0.5, line.baseline - line.ascent / 2),
        );
        final range = painter.getLineBoundary(at);
        return text.substring(range.start, range.end).trim();
      }(),
  ];
}

int _wordCount(List<String> lines) => lines.join(' ').split(' ').where((w) => w.isNotEmpty).length;
