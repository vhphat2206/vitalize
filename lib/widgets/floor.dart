import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../app/theme.dart';

/// The gym-floor texture behind every screen: a dark tile scattered with the small grey and
/// green rubber flecks of real EPDM gym flooring. Built once from a fixed seed (the same flecks
/// as the web app), so it is identical on every launch and costs no image download.
class Floor extends StatelessWidget {
  const Floor({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: const _FloorPainter(), child: child);
}

class _Fleck {
  const _Fleck(this.x, this.y, this.r, this.color);
  final double x, y, r;
  final Color color;
}

const _tile = 180.0;

final List<_Fleck> _flecks = () {
  var seed = 20251020;
  // mulberry32, on unsigned 32-bit integers
  int imul(int a, int b) => (a * b) & 0xFFFFFFFF;
  double rand() {
    seed = (seed + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = imul(seed ^ (seed >> 15), 1 | seed);
    t = ((t + imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t;
    return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296;
  }

  const palette = [Color(0x0AF1F4F2), Color(0x06F1F4F2), Color(0x0F5FC774), Color(0x59000000)];
  return [
    for (var i = 0; i < 260; i++)
      () {
        final x = rand() * _tile;
        final y = rand() * _tile;
        final r = 0.5 + rand() * 0.9;
        return _Fleck(x, y, r, palette[(rand() * palette.length).floor()]);
      }(),
  ];
}();

ui.Picture? _tilePicture;

ui.Picture _tileOnce() => _tilePicture ??= () {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  final paint = Paint()..isAntiAlias = true;
  for (final f in _flecks) {
    c.drawCircle(Offset(f.x, f.y), f.r, paint..color = f.color);
  }
  return rec.endRecording();
}();

class _FloorPainter extends CustomPainter {
  const _FloorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = V.bg);
    final tile = _tileOnce();
    for (var y = 0.0; y < size.height; y += _tile) {
      for (var x = 0.0; x < size.width; x += _tile) {
        canvas.save();
        canvas.translate(x, y);
        canvas.drawPicture(tile);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_FloorPainter old) => false;
}
