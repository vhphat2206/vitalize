import 'package:flutter/widgets.dart';
import 'package:path_drawing/path_drawing.dart';

/// A 24×24 line glyph drawn for this app: square ends and mitred joins, like stamped steel.
class VGlyph {
  const VGlyph(this.d, {this.filled = false});

  /// SVG path data in a 24×24 box.
  final String d;

  /// Filled shapes (play, pause) instead of 1.7-wide strokes.
  final bool filled;
}

String _circle(double cx, double cy, double r) =>
    'M${cx - r} ${cy}a$r $r 0 1 0 ${2 * r} 0a$r $r 0 1 0 ${-2 * r} 0';

abstract final class VIcons {
  static const back = VGlyph('M15 4.5 7.5 12l7.5 7.5');
  static const close = VGlyph('m6 6 12 12M18 6 6 18');
  static const plus = VGlyph('M12 5v14M5 12h14');
  static const minus = VGlyph('M5 12h14');
  static const play = VGlyph('M8 5.2v13.6L19 12z', filled: true);
  static const pause = VGlyph('M7 5h3.6v14H7zM13.4 5H17v14h-3.6z', filled: true);
  static const skipNext = VGlyph('M6 6.5 13 12l-7 5.5zM17 6v12');
  static const skipPrev = VGlyph('M18 6.5 11 12l7 5.5zM7 6v12');
  static const trash = VGlyph('M5 7h14M9.5 7V4.5h5V7M7 7l.8 12.5h8.4L17 7');

  /// Turn the body around.
  static const turn = VGlyph(
    'M4.5 12a7.5 7.5 0 0 1 13-5.1M19.5 12a7.5 7.5 0 0 1-13 5.1'
    'M17.8 3.5v3.6h-3.6M6.2 20.5v-3.6h3.6',
  );

  /// A standing figure: the body map.
  static final tabBody = VGlyph(
    '${_circle(12, 4.3, 2.1)}M8.2 8.3h7.6l-1 7H9.2z'
    'M8.2 8.3 6.4 14.6M15.8 8.3l1.8 6.3M10 15.3 9.6 21M14 15.3l.4 5.7',
  );

  /// A stopwatch: short sessions on the clock.
  static final tabRoutines = VGlyph(
    '${_circle(12, 13.5, 7.5)}M10 3h4M12 3v3M12 13.5V9.5M18.2 7.3l1.4-1.4',
  );

  /// A bowl with chopsticks resting across it: what you ate.
  static const tabFood = VGlyph(
    'M3.5 11.5h17c0 4.4-3.8 8-8.5 8s-8.5-3.6-8.5-8z'
    'M9.5 21h5M12.5 9.5 20.5 3M15.5 10.5l6-4.5',
  );

  /// A bust in a circle: your profile.
  static final tabProfile = VGlyph(
    '${_circle(12, 12, 9)}${_circle(12, 10, 3)}'
    'M6.6 18.4c1.3-2.3 3.1-3.4 5.4-3.4s4.1 1.1 5.4 3.4',
  );

  /// Seven daily bars: the week at a glance.
  static const tabWeek = VGlyph(
    'M3.5 20.5h17M5 18v-4M7.8 18v-7M10.6 18v-2M13.4 18v-9M16.2 18v-5M19 18V6',
  );

  static final camera = VGlyph('M3.5 8h4l1.5-2.5h6L16.5 8h4v11h-17z${_circle(12, 13.3, 3.6)}');
  static final image = VGlyph(
    'M4 5h16v14H4zm0 11 4.5-4.5L12 15l2.5-2.5L20 18${_circle(15.5, 9.3, 1.4)}',
  );

  /// Three sliders: settings.
  static final sliders = VGlyph(
    'M4 7h9M18 7h2M4 12h3M11 12h9M4 17h11M19 17h1'
    '${_circle(15.5, 7, 2)}${_circle(9, 12, 2)}${_circle(17, 17, 2)}',
  );

  /// Opens outside the app.
  static const external = VGlyph('M13.5 4.5h6v6M19.5 4.5 11 13M17 13.5v6h-12v-12h6');
  static const chevronDown = VGlyph('M5.5 9 12 15.5 18.5 9');
  static const chevronRight = VGlyph('M9 5.5 15.5 12 9 18.5');

  static final _equipment = <String, VGlyph>{
    'barbell': const VGlyph(
      'M1.5 12h21M5 6.5h2.2v11H5zM16.8 6.5H19v11h-2.2zM7.2 8.5h1.3v7H7.2zM15.5 8.5h1.3v7h-1.3z',
    ),
    'dumbbell': const VGlyph('M8.5 12h7M4 8h4.5v8H4zM15.5 8H20v8h-4.5z'),
    'kettlebell': const VGlyph(
      'M8.6 10.2V8a3.4 3.4 0 0 1 6.8 0v2.2'
      'M12 9.5a5.6 5.6 0 0 1 5.4 7.2L16.6 20H7.4l-.8-3.3A5.6 5.6 0 0 1 12 9.5z',
    ),
    'cable': VGlyph('${_circle(12, 5, 2.4)}M12 7.4v8.1M8.5 15.5h7l-1.2 4.5H9.7z'),
    'machine': const VGlyph('M7 3.5h10v17H7zM7 8.5h10M7 12h10M7 15.5h10M17 12h3.5'),
    'bar': const VGlyph('M3 21V4.5h18V21M8.5 4.5v3M15.5 4.5v3'),
    'bodyweight': VGlyph('${_circle(19.6, 9.6, 1.8)}M17.6 11.1 4 17.2M16 11.8V18M3 19.5h18'),
  };

  /// barbell, dumbbell, kettlebell, cable, machine, bar or bodyweight.
  static VGlyph equipment(String kind) => _equipment[kind] ?? _equipment['bodyweight']!;
}

/// Draws a [VGlyph] in the current icon colour (or [color]).
class VIcon extends StatelessWidget {
  const VIcon(this.glyph, {super.key, this.size = 24, this.color});

  final VGlyph glyph;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? const Color(0xFFF1F4F2);
    return CustomPaint(size: Size.square(size), painter: _GlyphPainter(glyph, c));
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color);

  final VGlyph glyph;
  final Color color;

  static final _cache = <String, Path>{};

  @override
  void paint(Canvas canvas, Size size) {
    final path = _cache.putIfAbsent(glyph.d, () => parseSvgPathData(glyph.d));
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = true
        ..style = glyph.filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.square
        ..strokeJoin = StrokeJoin.miter,
    );
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.glyph != glyph || old.color != color;
}
