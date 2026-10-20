import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../app/theme.dart';

/// Brand gradient, top to bottom: the green of the head down to the teal of the feet.
const _gradient = [Color(0xFF5FC774), Color(0xFF3E885B), Color(0xFF245A5E)];

/// The V-shaped figure, a head and two raised arms, filled with the brand gradient. Traced
/// from the brand board (components/brand/mark.ts on the web).
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.width = 34, this.height = 25});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(width, height), painter: const _MarkPainter());
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  static final _left = parseSvgPathData(
    'M5.3 23.6 14.2 16.9h7.2l-2.3 4.8 27.6 13.6c1.9 1.3 2.5 3.5 1.9 6.3L40.2 60.6'
    'C35.9 52.5 31.5 46.6 25.8 40.6Z',
  );
  static final _right = parseSvgPathData(
    'M77.2 16.9H92l-4.2 4.2L70 35.6C66.4 44 61.9 53.6 47.8 69.8L42 63.9'
    'c6.6-8.1 11.9-16.5 15.6-26.1.4-4.2.7-7.1 2.9-10.6Z',
  );

  @override
  void paint(Canvas canvas, Size size) {
    // viewBox 4 5 90 66, centred and scaled to fit (preserveAspectRatio meet)
    const vb = Rect.fromLTWH(4, 5, 90, 66);
    final s = (size.width / vb.width) < (size.height / vb.height)
        ? size.width / vb.width
        : size.height / vb.height;
    canvas.translate((size.width - vb.width * s) / 2, (size.height - vb.height * s) / 2);
    canvas.scale(s);
    canvas.translate(-vb.left, -vb.top);
    final paint = Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.linear(const Offset(0, 8), const Offset(0, 70), _gradient, const [
        0,
        0.55,
        1,
      ]);
    canvas.drawCircle(const Offset(47.6, 15.6), 9.8, paint);
    canvas.drawPath(_left, paint);
    canvas.drawPath(_right, paint);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => false;
}

/// "Vitalize" set in Prompt SemiBold, in ink, with the second i's dot in brand green as on the
/// original logo. Sized by [height]; the width follows.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.height = 19, this.color = V.ink});

  final double height;
  final Color color;

  /// viewBox 0 -74.9 348.9 77.4
  static const _box = Rect.fromLTWH(0, -74.9, 348.9, 77.4);

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Vitalize',
    image: true,
    child: CustomPaint(
      size: Size(_box.width * height / _box.height, height),
      painter: _WordPainter(color),
    ),
  );
}

class _WordPainter extends CustomPainter {
  const _WordPainter(this.color);

  final Color color;

  static final _ink = parseSvgPathData(
    'M31.2 0L3.2 -69.9L19.4 -69.9L38.6 -20.2L57.9 -69.9L74 -69.9L46.1 0L31.2 0M83 -55.4'
    'Q79.5 -55.4 77.1 -57.7Q74.7 -60 74.7 -63.5L74.7 -63.5Q74.7 -66.9 77.1 -69.25'
    'Q79.5 -71.6 83 -71.6L83 -71.6Q86.5 -71.6 88.9 -69.25Q91.3 -66.9 91.3 -63.5L91.3 -63.5'
    'Q91.3 -60 88.9 -57.7Q86.5 -55.4 83 -55.4L83 -55.4M75.4 0L75.4 -48L90.6 -48L90.6 0L75.4 0'
    'M120.6 1.5Q112.2 1.5 107.85 -3.15Q103.5 -7.8 103.5 -16.1L103.5 -16.1L103.5 -37.1L96.5 -37.1'
    'L96.5 -48L103.5 -48L103.5 -62.4L118.6 -62.4L118.6 -48L129.9 -48L129.9 -37.1L118.6 -37.1'
    'L118.6 -18.1Q118.6 -13.9 120.2 -12.05Q121.8 -10.2 125.9 -10.2L125.9 -10.2'
    'Q129.2 -10.2 132.2 -11.8L132.2 -11.8L132.2 -0.5Q127.6 1.5 120.6 1.5L120.6 1.5M154.4 1.5'
    'Q145.6 1.5 140.05 -2.95Q134.5 -7.4 134.5 -15.1L134.5 -15.1Q134.5 -23.1 139.8 -27.55'
    'Q145.1 -32 154.8 -32L154.8 -32Q159.1 -32 163 -31.1Q166.9 -30.2 169.9 -28.6L169.9 -28.6'
    'L169.9 -29.8Q169.9 -34.3 166.7 -36.4Q163.5 -38.5 156.9 -38.5L156.9 -38.5'
    'Q148.1 -38.5 140.7 -35.2L140.7 -35.2L140.7 -46.2Q143.9 -47.6 149 -48.55'
    'Q154.1 -49.5 159.2 -49.5L159.2 -49.5Q172.2 -49.5 178.6 -44.15Q185 -38.8 185 -29.2L185 -29.2'
    'L185 0L170.8 0L170.8 -4.4Q164.7 1.5 154.4 1.5L154.4 1.5M158.5 -8.5Q162.2 -8.5 165.2 -9.9'
    'Q168.2 -11.3 169.9 -13.8L169.9 -13.8L169.9 -18.6Q164.8 -22 158.7 -22L158.7 -22'
    'Q154.5 -22 152.25 -20.25Q150 -18.5 150 -15.1L150 -15.1Q150 -11.9 152.2 -10.2'
    'Q154.4 -8.5 158.5 -8.5L158.5 -8.5M193.8 0L193.8 -73.9L208.9 -73.9L208.9 0L193.8 0M218.9 0'
    'L218.9 -48L234.1 -48L234.1 0L218.9 0M242 0L242 -8.7L266.2 -37.1L242.7 -37.1L242.7 -48'
    'L285.7 -48L285.7 -39.2L261.7 -10.9L286.5 -10.9L286.5 0L242 0M321.3 1.5Q307.5 1.5 299.6 -5.15'
    'Q291.7 -11.8 291.7 -23.8L291.7 -23.8Q291.7 -35.7 298.75 -42.6Q305.8 -49.5 318.9 -49.5'
    'L318.9 -49.5Q327.5 -49.5 333.5 -46.3Q339.5 -43.1 342.6 -37.45Q345.7 -31.8 345.7 -24.7'
    'L345.7 -24.7L345.7 -18.6L306.1 -18.6Q307.7 -9.4 323.3 -9.4L323.3 -9.4Q327.9 -9.4 332.8 -10.2'
    'Q337.7 -11 341.3 -12.4L341.3 -12.4L341.3 -1.8Q337.8 -0.3 332.3 0.6Q326.8 1.5 321.3 1.5'
    'L321.3 1.5M306.1 -28.4L331.4 -28.4Q331.1 -33.2 327.8 -35.85Q324.5 -38.5 318.7 -38.5'
    'L318.7 -38.5Q313 -38.5 309.7 -35.8Q306.4 -33.1 306.1 -28.4L306.1 -28.4',
  );
  static final _dot = parseSvgPathData(
    'M226.5 -55.4Q223 -55.4 220.6 -57.7Q218.2 -60 218.2 -63.5L218.2 -63.5'
    'Q218.2 -66.9 220.6 -69.25Q223 -71.6 226.5 -71.6L226.5 -71.6Q230 -71.6 232.4 -69.25'
    'Q234.8 -66.9 234.8 -63.5L234.8 -63.5Q234.8 -60 232.4 -57.7Q230 -55.4 226.5 -55.4L226.5 -55.4',
  );

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height / Wordmark._box.height;
    canvas.scale(s);
    canvas.translate(-Wordmark._box.left, -Wordmark._box.top);
    canvas.drawPath(_ink, Paint()..color = color);
    canvas.drawPath(_dot, Paint()..color = V.accent);
  }

  @override
  bool shouldRepaint(_WordPainter old) => old.color != color;
}
