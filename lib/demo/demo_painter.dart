import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:path_drawing/path_drawing.dart';

import '../app/theme.dart';
import '../data/models.dart';
import 'demo_data.dart';
import 'motion.dart';
import 'rig.dart';
import 'rig_parts.dart';

/// Space above and below the scene inside the stage (the web stage's `padding: 10px 0`).
const _padY = 10.0;

/// A 2D affine transform, as in SVG: x' = a x + c y + e, y' = b x + d y + f.
class _Aff {
  const _Aff(this.a, this.b, this.c, this.d, this.e, this.f);

  final double a, b, c, d, e, f;

  _Aff operator *(_Aff o) => _Aff(
    a * o.a + c * o.b,
    b * o.a + d * o.b,
    a * o.c + c * o.d,
    b * o.c + d * o.d,
    a * o.e + c * o.f + e,
    b * o.e + d * o.f + f,
  );

  _Aff translate(double x, double y) => this * _Aff(1, 0, 0, 1, x, y);

  _Aff rotate(double deg) {
    final r = deg * math.pi / 180;
    final cs = math.cos(r);
    final sn = math.sin(r);
    return this * _Aff(cs, sn, -sn, cs, 0, 0);
  }

  _Aff scale(double sx, double sy) => this * _Aff(sx, 0, 0, sy, 0, 0);

  Offset apply(Offset p) => Offset(a * p.dx + c * p.dy + e, b * p.dx + d * p.dy + f);

  Float64List get storage => Float64List.fromList([a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, e, f, 0, 1]);

  bool same(_Aff o) => a == o.a && b == o.b && c == o.c && d == o.d && e == o.e && f == o.f;
}

// Materials, as in ExerciseDemo.css. Outlines and props keep their width in screen pixels
// whatever the scale (`vector-effect: non-scaling-stroke`); fibre lines scale with the limb.

Paint _fill(Color c) => Paint()..color = c;

Paint _stroke(Color c, double width, {StrokeCap cap = StrokeCap.butt, bool roundJoin = false}) =>
    Paint()
      ..style = PaintingStyle.stroke
      ..color = c
      ..strokeWidth = width
      ..strokeCap = cap
      ..strokeJoin = roundJoin ? StrokeJoin.round : StrokeJoin.miter;

Color _ink(double alpha) => V.ink.withValues(alpha: alpha);

final _bodyFill = _fill(V.muscle);
final _skinFill = _fill(const Color(0xFF1F2A2B));
final _farFill = _fill(const Color(0xFF121A1B));
final _outline = _stroke(_ink(0.45), 1.1, roundJoin: true);
final _farOutline = _stroke(_ink(0.22), 1.1, roundJoin: true);
final _zoneFill = _fill(V.accent);
final _fibrePrimary = _stroke(V.accentDeep.withValues(alpha: 0.55), 0.7);
final _fibreSecondary = _stroke(V.accent.withValues(alpha: 0.9), 0.7);

final _floor = _stroke(V.lineStrong, 1);
final _padFill = _fill(V.bg3);
final _padStroke = _stroke(_ink(0.35), 1, roundJoin: true);
final _benchStroke = _stroke(_ink(0.35), 1);
final _tube = _stroke(_ink(0.3), 1.4);
final _frame = _stroke(_ink(0.3), 1.4, cap: StrokeCap.round, roundJoin: true);
final _dashedFrame = _stroke(_ink(0.45), 1.4, cap: StrokeCap.round, roundJoin: true);
final _inkFill = _fill(V.ink);
final _hbar = _stroke(_ink(0.8), 2.6, cap: StrokeCap.round);
final _metal = _stroke(_ink(0.7), 1.4, roundJoin: true);
final _metalInner = _stroke(_ink(0.25), 1.4, roundJoin: true);
final _handle = _stroke(_ink(0.7), 2, cap: StrokeCap.round, roundJoin: true);
final _cable = _stroke(_ink(0.55), 0.9);
final _cableRing = _stroke(_ink(0.55), 1);
final _lever = _stroke(_ink(0.45), 3, cap: StrokeCap.round);
final _leverRing = _stroke(_ink(0.45), 1);

/// The far hand's props in a side view are see-through (`opacity: 0.45` on the group).
final _farLayer = Paint()..color = const Color.fromRGBO(0, 0, 0, 0.45);

enum _Ink { primary, secondary }

/// Paints one moment of a demo: the props, the mannequin with the worked muscles painted on it,
/// in the web app's order, fitted into the stage like the SVG viewBox (`xMidYMid meet`, inside
/// the stage's vertical padding; drawing may spill into the padding as `overflow: visible` does).
class DemoPainter extends CustomPainter {
  DemoPainter({
    required this.demo,
    required this.primary,
    required this.secondary,
    required this.phase,
  }) : super(repaint: phase);

  final Demo demo;
  final List<MuscleId> primary;
  final List<MuscleId> secondary;

  /// The point in the move, 0 = start, 1 = end.
  final ValueListenable<double> phase;

  @override
  void paint(Canvas canvas, Size size) {
    final vb = demo.view;
    final boxH = size.height - 2 * _padY;
    if (size.width <= 0 || boxH <= 0) return;
    // The SVG is as tall as the stage's content box and as wide as its viewBox makes it (up to
    // the stage's width), centred, its left edge on a whole pixel as the browser lays it out;
    // the viewBox is fitted inside it.
    final svgW = math.min(size.width, boxH * vb.width / vb.height);
    final left = ((size.width - svgW) / 2).roundToDouble();
    final k = math.min(svgW / vb.width, boxH / vb.height);
    final ox = left + (svgW - vb.width * k) / 2 - vb.left * k;
    final oy = _padY + (boxH - vb.height * k) / 2 - vb.top * k;
    _Scene(
      canvas: canvas,
      demo: demo,
      view: _Aff(k, 0, 0, k, ox, oy),
      frame: resolve(poseAt(demo.keys, phase.value), demo.facing),
      primary: primary,
      secondary: secondary,
    ).paint();
  }

  @override
  bool shouldRepaint(DemoPainter old) =>
      old.demo != demo ||
      old.phase != phase ||
      !listEquals(old.primary, primary) ||
      !listEquals(old.secondary, secondary);
}

/// Screen-space copies of the fixed shapes (pads, frames), kept per prop for the last scale.
final _fixed = Expando<(_Aff, ui.Path)>();

class _Scene {
  _Scene({
    required this.canvas,
    required this.demo,
    required this.view,
    required this.frame,
    required this.primary,
    required this.secondary,
  }) : sideView = demo.facing == Facing.side,
       parts = RigParts.instance.views[demo.facing]!;

  final Canvas canvas;
  final Demo demo;

  /// From the demo's centimetres to the stage's pixels.
  final _Aff view;
  final Frame frame;
  final List<MuscleId> primary;
  final List<MuscleId> secondary;
  final bool sideView;
  final Map<Bone, List<RigPart>> parts;

  /// Pixels per centimetre.
  double get k => view.a;

  Offset s(Offset p) => view.apply(p);

  Offset grip(Grip g, [Side side = Side.near]) => gripPoint(demo, frame, g, side);

  void paint() {
    final props = demo.props;
    // Props held or moved by a limb are drawn in front of the body; the rest stand behind it.
    for (final p in props) {
      if (p.held) continue;
      if (p.paired) {
        _prop(p, Side.other);
        _prop(p, Side.near);
      } else {
        _prop(p, Side.near);
      }
    }
    // In a side view the far limbs sit behind the body, and the far hand's props between them.
    if (sideView) {
      for (final b in arm) {
        _bone(b, Side.other);
      }
      for (final b in leg) {
        _bone(b, Side.other);
      }
      for (final p in props) {
        if (p.held && p.paired) _prop(p, Side.other);
      }
    }
    // Back to front. Bones listed in `behind` move to the very back, keeping their order, and an
    // arm whose shoulder the twisting trunk turns away goes behind even those.
    final order = <(Bone, Side)>[
      if (sideView) ...[
        for (final b in leg) (b, Side.near),
        (Bone.spine, Side.near),
        (Bone.neck, Side.near),
        for (final b in arm) (b, Side.near),
      ] else ...[
        for (final b in leg) (b, Side.other),
        for (final b in leg) (b, Side.near),
        (Bone.spine, Side.near),
        (Bone.neck, Side.near),
        for (final b in arm) (b, Side.other),
        for (final b in arm) (b, Side.near),
      ],
    ];
    final Side? away = sideView || frame.twist.abs() < 10
        ? null
        : frame.twist > 0
        ? Side.near
        : Side.other;
    int depth((Bone, Side) e) => e.$2 == away && arm.contains(e.$1)
        ? 0
        : demo.behind.contains(e.$1)
        ? 1
        : 2;
    for (var d = 0; d < 3; d++) {
      for (final e in order) {
        if (depth(e) == d) _bone(e.$1, e.$2);
      }
    }
    for (final p in props) {
      if (!p.held) continue;
      if (p.paired && !sideView) {
        _prop(p, Side.other);
        _prop(p, Side.near);
      } else {
        _prop(p, Side.near);
      }
    }
  }

  _Ink? _tone(MuscleId? m) => m == null
      ? null
      : primary.contains(m)
      ? _Ink.primary
      : secondary.contains(m)
      ? _Ink.secondary
      : null;

  void _bone(Bone bone, Side side) {
    final pl = place(frame, bone, side);
    final dim = sideView && side == Side.other;
    final at = dim ? pl.at + demo.far : pl.at;
    final curl = bone == Bone.spine ? frame.curl : 0.0;
    final twist = bone == Bone.spine ? frame.twist : 0.0;
    final m = view
        .translate(at.dx, at.dy)
        .rotate(pl.angle + 180)
        .scale(pl.mirror ? -1 : 1, drawnScale(pl.scale));
    for (final part in parts[bone]!) {
      final moving = (curl != 0 || twist != 0) && part.shapes != null;
      final local = moving ? shapePath(part.shapes!, curl, twist, frame.lean) : part.path;
      if (part.kind != PartKind.muscle) {
        var shape = local;
        var mh = m;
        if (part.turns && frame.twist != 0) shape = turnedHead(demo.facing, frame.twist);
        if (part.head) {
          // The head keeps its shape when the neck is foreshortened, and nods on top of it.
          final sc = pl.scale;
          const neck = 20.0; // Bone.neck.length
          if ((sc - 1).abs() > 0.01 && sc != 0) {
            mh = mh.translate(0, neck).scale(1, 1 / sc).translate(0, -neck);
          }
          if (frame.nod != 0) {
            mh = mh.translate(0, skullBase).rotate(frame.nod).translate(0, -skullBase);
          }
        }
        final screen = shape.transform(mh.storage);
        canvas.drawPath(
          screen,
          dim ? _farFill : (part.kind == PartKind.body ? _bodyFill : _skinFill),
        );
        canvas.drawPath(screen, dim ? _farOutline : _outline);
        continue;
      }
      if (dim) continue;
      final ink = _tone(part.muscle);
      if (ink == null) continue;
      canvas.save();
      canvas.transform(m.storage);
      if (ink == _Ink.primary) canvas.drawPath(local, _zoneFill);
      canvas.clipPath(local);
      canvas.drawRawPoints(
        ui.PointMode.lines,
        moving ? fibreLines(local.getBounds(), part.fibre) : part.hatch,
        ink == _Ink.primary ? _fibrePrimary : _fibreSecondary,
      );
      canvas.restore();
    }
  }

  ui.Path _line(List<Offset> pts) {
    final p = ui.Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final q in pts.skip(1)) {
      p.lineTo(q.dx, q.dy);
    }
    return p;
  }

  /// A rectangle centred on [c], [len] long in direction [angle] and [thick] across it, on
  /// screen.
  ui.Path _slab(Offset c, double angle, double len, double thick) {
    final a = dir(angle, len / 2);
    final b = dir(angle + 90, thick / 2);
    Offset p(double s, double t) => this.s(c + a * s + b * t);
    return _line([p(-1, -1), p(1, -1), p(1, 1), p(-1, 1)])..close();
  }

  /// A fixed shape from the demo data, on screen (and dashed when asked).
  ui.Path _fixedPath(DemoProp p, {bool dashed = false}) {
    final cached = _fixed[p];
    if (cached != null && cached.$1.same(view)) return cached.$2;
    var path = svgPath(p.d!).transform(view.storage);
    if (dashed) path = dashPath(path, dashArray: CircularIntervalList<double>(const [3, 4]));
    _fixed[p] = (view, path);
    return path;
  }

  void _circle(Offset c, double r, Paint paint) => canvas.drawCircle(s(c), r * k, paint);

  void _prop(DemoProp p, Side side) {
    final far = sideView && side == Side.other;
    if (far) canvas.saveLayer(null, _farLayer);
    _drawProp(p, side);
    if (far) canvas.restore();
  }

  void _drawProp(DemoProp p, Side side) {
    final vb = demo.view;
    switch (p.type) {
      case PropType.floor:
        canvas.drawLine(s(Offset(vb.left, p.y)), s(Offset(vb.right, p.y)), _floor);
      case PropType.bench:
        final top = s(Offset(p.x, p.y));
        final rect = RRect.fromLTRBR(
          top.dx,
          top.dy,
          top.dx + p.w * k,
          top.dy + 6 * k,
          Radius.circular(2 * k),
        );
        canvas.drawRRect(rect, _padFill);
        canvas.drawRRect(rect, _benchStroke);
        final legs = ui.Path();
        for (final (a, b) in [
          (Offset(p.x + 14, p.y + 6), Offset(p.x + 14, 0)),
          (Offset(p.x + p.w - 14, p.y + 6), Offset(p.x + p.w - 14, 0)),
          (Offset(p.x + 6, 0), Offset(p.x + 22, 0)),
          (Offset(p.x + p.w - 22, 0), Offset(p.x + p.w - 6, 0)),
        ]) {
          legs
            ..moveTo(s(a).dx, s(a).dy)
            ..lineTo(s(b).dx, s(b).dy);
        }
        canvas.drawPath(legs, _tube);
      case PropType.pad:
        final path = _fixedPath(p);
        canvas.drawPath(path, _padFill);
        canvas.drawPath(path, _padStroke);
      case PropType.frame:
        canvas.drawPath(_fixedPath(p, dashed: p.dashed), p.dashed ? _dashedFrame : _frame);
      case PropType.bar:
        canvas.drawLine(s(Offset(p.x, p.y)), s(Offset(p.x, p.postDown ? 0 : vb.top)), _tube);
        _circle(Offset(p.x, p.y), 2.2, _inkFill);
      case PropType.hbar:
        canvas.drawLine(s(Offset(p.x1, vb.top)), s(Offset(p.x1, p.y)), _tube);
        canvas.drawLine(s(Offset(p.x2, vb.top)), s(Offset(p.x2, p.y)), _tube);
        canvas.drawLine(s(Offset(p.x1, p.y)), s(Offset(p.x2, p.y)), _hbar);
      case PropType.rail:
        for (final x in p.posts) {
          canvas.drawLine(s(Offset(x, p.y)), s(Offset(x, p.to)), _tube);
        }
        canvas.drawLine(s(Offset(p.x1, p.y)), s(Offset(p.x2, p.y)), _hbar);
      case PropType.barbell:
        final c = grip(p.at!);
        final r = p.r ?? 0;
        _circle(c, r, _metal);
        _circle(c, r * 0.72, _metalInner);
        _circle(c, 2.4, _inkFill);
      case PropType.wbar:
        // a bar seen from the front, through both hands, plates at the ends when loaded
        final a = grip(p.at!, Side.near);
        final b = grip(p.at!, Side.other);
        final c = (a + b) / 2;
        var len = (a - b).distance;
        if (len == 0) len = 1;
        final u = (a - b) / len;
        Offset at(double t) => c + u * t;
        final ang = angleOf(u);
        canvas.drawLine(s(at(-p.half)), s(at(p.half)), _handle);
        final r = p.r;
        if (r != null && r != 0) {
          for (final k in const [-1.0, 1.0]) {
            canvas.drawPath(_slab(at(k * (p.half - 9)), ang, 7, r * 2), _metal);
            canvas.drawPath(_slab(at(k * (p.half - 15.5)), ang, 3, 7), _metal);
          }
        }
      case PropType.dumbbell:
        final pl = place(frame, p.at!.bone, side);
        final c = grip(p.at!, side);
        final r = p.size;
        if (p.look == DumbbellLook.end) {
          _circle(c, r, _metal);
          _circle(c, r * 0.55, _metalInner);
          return;
        }
        // seen side-on: a handle through the fist and a head at each end
        final along = switch (p.look) {
          DumbbellLook.upright => 0.0,
          DumbbellLook.along => pl.angle,
          _ => pl.angle + 90,
        };
        final h = dir(along, 1);
        Offset head(double t) => c + h * t;
        canvas.drawLine(s(head(-7)), s(head(7)), _handle);
        canvas.drawPath(_slab(head(-9.5), along, 5, r * 2), _metal);
        canvas.drawPath(_slab(head(9.5), along, 5, r * 2), _metal);
      case PropType.kettlebell:
        final pl = place(frame, p.at!.bone, side);
        final c = grip(p.at!, side);
        final angle = p.swing ? pl.angle : 180.0;
        final bell = c + dir(angle, 1) * 12;
        canvas.drawPath(_slab(c, angle, 8, 13), _handle);
        _circle(bell, 8.5, _metal);
      case PropType.cable:
        final from = side == Side.other ? (p.otherFrom ?? p.from!) : p.from!;
        final a = grip(p.at!, side);
        final b = p.mid ? grip(p.at!, Side.other) : a;
        final c = (a + b) / 2;
        canvas.drawLine(s(from), s(c), _cable);
        _circle(from, 2.6, _padFill);
        _circle(from, 2.6, _cableRing);
      case PropType.lever:
        final from = side == Side.other ? (p.otherFrom ?? p.from!) : p.from!;
        final c = grip(p.at!, side);
        canvas.drawLine(s(from), s(c), _lever);
        _circle(from, 2.6, _padFill);
        _circle(from, 2.6, _leverRing);
      case PropType.roller:
        final c = grip(p.at!, side);
        _circle(c, p.r ?? 0, _padFill);
        _circle(c, p.r ?? 0, _padStroke);
      case PropType.board:
        final pl = place(frame, p.at!.bone, side);
        final c = grip(p.at!, side);
        final path = _slab(c, pl.angle + p.turn, p.len, p.thick);
        canvas.drawPath(path, _padFill);
        canvas.drawPath(path, _padStroke);
    }
  }
}
