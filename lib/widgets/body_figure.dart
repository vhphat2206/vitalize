import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:path_drawing/path_drawing.dart';

import '../app/theme.dart';
import '../data/catalog.dart';
import '../data/models.dart';

/// How a muscle is painted.
/// - [primary]: solid green, dark fibre lines (what a movement is built for, or the selection)
/// - [secondary]: idle fill with green fibre lines (helps out)
/// - [vol1]–[vol3]: logged weekly volume, from a green tint to solid green
enum Tone { primary, secondary, vol1, vol2, vol3 }

enum _Ink { idle, deep, green }

const _fibreGap = 13.0;
const _fibreWidth = 3.4;

/// The body map: the outline, the non-muscle parts and every muscle as its own shape, painted by
/// [tones]. With [onSelect] the muscles can be tapped. `full` detail hatches the muscles along
/// their fibres like an anatomy plate; `compact` (thumbnails) uses flat fills only. With [intro]
/// the outline draws itself once and the muscles settle in head to toe.
class BodyFigure extends StatefulWidget {
  const BodyFigure({
    super.key,
    required this.side,
    this.tones = const {},
    this.onSelect,
    this.compact = false,
    this.intro = false,
    this.label,
  });

  final BodySide side;
  final Map<MuscleId, Tone> tones;
  final ValueChanged<MuscleId>? onSelect;
  final bool compact;
  final bool intro;
  final String? label;

  @override
  State<BodyFigure> createState() => _BodyFigureState();
}

class _BodyFigureState extends State<BodyFigure> with SingleTickerProviderStateMixin {
  AnimationController? _intro;
  MuscleId? _pressed;

  @override
  void initState() {
    super.initState();
    if (widget.intro) {
      _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
        ..forward();
    }
  }

  @override
  void dispose() {
    _intro?.dispose();
    super.dispose();
  }

  BodyView get _view => catalog.body[widget.side]!;

  /// The muscle under a point in the artwork, with a little slack around thin muscles.
  MuscleId? _hit(Offset p) {
    final muscles = _view.parts.where((part) => catalog.muscleById.containsKey(part.slug));
    for (final slack in [0.0, 7.0]) {
      final probes = slack == 0
          ? [p]
          : [for (var i = 0; i < 8; i++) p + Offset.fromDirection(i * math.pi / 4, slack)];
      for (final part in muscles) {
        for (final d in [...part.left, ...part.right, ...part.common]) {
          final path = _paths.of(d);
          if (probes.any(path.contains)) return part.slug;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final vb = _view.viewBox;
    final aspect = vb[2] / vb[3];
    Widget figure = AspectRatio(
      aspectRatio: aspect,
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = box.maxWidth / vb[2];
          Offset toArt(Offset local) => Offset(local.dx / scale + vb[0], local.dy / scale + vb[1]);
          final paint = AnimatedBuilder(
            animation: _intro ?? const AlwaysStoppedAnimation(1.0),
            builder: (context, _) => CustomPaint(
              size: Size(box.maxWidth, box.maxHeight),
              painter: _FigurePainter(
                view: _view,
                side: widget.side,
                tones: widget.tones,
                compact: widget.compact,
                pressed: _pressed,
                interactive: widget.onSelect != null,
                progress: _intro == null ? 1 : _intro!.value * 1.5,
              ),
            ),
          );
          if (widget.onSelect == null) return paint;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => setState(() => _pressed = _hit(toArt(d.localPosition))),
            onTapCancel: () => setState(() => _pressed = null),
            onTapUp: (d) {
              final id = _hit(toArt(d.localPosition));
              setState(() => _pressed = null);
              if (id != null) widget.onSelect!(id);
            },
            child: paint,
          );
        },
      ),
    );
    return Semantics(
      label: widget.label ?? (widget.side == 'front' ? 'Cơ thể, mặt trước' : 'Cơ thể, mặt sau'),
      child: figure,
    );
  }
}

/// Parsed SVG paths, shared by every figure.
class _PathCache {
  final _map = <String, Path>{};
  Path of(String d) => _map.putIfAbsent(d, () => parseSvgPathData(d));
}

final _paths = _PathCache();

class _FigurePainter extends CustomPainter {
  _FigurePainter({
    required this.view,
    required this.side,
    required this.tones,
    required this.compact,
    required this.pressed,
    required this.interactive,
    required this.progress,
  });

  final BodyView view;
  final BodySide side;
  final Map<MuscleId, Tone> tones;
  final bool compact;
  final MuscleId? pressed;
  final bool interactive;

  /// Intro timeline in seconds, 1.5 when settled.
  final double progress;

  static const _height = 1448.0;

  _Ink? _inkFor(Tone? tone) {
    if (tone == null) return _Ink.idle;
    if (tone == Tone.primary || tone == Tone.vol3) return _Ink.deep;
    if (tone == Tone.secondary) return _Ink.green;
    return null; // vol1/vol2: flat tint, the hatching would muddy it
  }

  Color _fill(MuscleId id, Tone? tone) {
    if (tone == Tone.primary || tone == Tone.vol3) return V.accent;
    if (tone == Tone.vol2) return V.mix(V.accent, 0.62, V.muscle);
    if (tone == Tone.vol1) return V.mix(V.accent, 0.32, V.muscle);
    if (tone == Tone.secondary && compact) return V.mix(V.accent, 0.4, V.muscle);
    if (interactive && pressed == id) return V.musclePressed;
    return V.muscle;
  }

  Color _inkColor(_Ink ink) => switch (ink) {
    _Ink.idle => V.ink.withValues(alpha: 0.07),
    _Ink.deep => V.accentDeep.withValues(alpha: 0.55),
    _Ink.green => V.accent.withValues(alpha: 0.9),
  };

  /// Fade-in of a part that starts at height [top] in the artwork.
  double _fade(double top) {
    final delay = 0.35 + 0.7 * (top / _height);
    return ((progress - delay) / 0.55).clamp(0.0, 1.0);
  }

  static double _topOf(BodyPart part) {
    final d = part.left.firstOrNull ?? part.common.firstOrNull ?? part.right.firstOrNull ?? 'M0 0';
    final m = RegExp(r'M\s*[-\d.]+[ ,]([-\d.]+)').firstMatch(d);
    return m == null ? 0 : double.parse(m.group(1)!);
  }

  /// Fibre hatching: parallel lines along [angle] degrees, 13 apart, clipped to [path].
  void _hatch(Canvas canvas, Path path, double angle, Paint paint) {
    final a = angle * math.pi / 180;
    final dir = Offset(math.cos(a), math.sin(a));
    final nrm = Offset(-math.sin(a), math.cos(a));
    final b = path.getBounds();
    final corners = [b.topLeft, b.topRight, b.bottomLeft, b.bottomRight];
    double across(Offset p) => p.dx * nrm.dx + p.dy * nrm.dy;
    final lo = corners.map(across).reduce(math.min);
    final hi = corners.map(across).reduce(math.max);
    final reach = b.longestSide + 10;
    canvas.save();
    canvas.clipPath(path);
    for (var k = ((lo - _fibreGap / 2) / _fibreGap).floor(); ; k++) {
      final c = _fibreGap / 2 + k * _fibreGap;
      if (c > hi) break;
      final base = nrm * c;
      final mid = b.center - nrm * across(b.center) + base;
      canvas.drawLine(mid - dir * reach, mid + dir * reach, paint);
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final vb = view.viewBox;
    final scale = size.width / vb[2];
    canvas.save();
    canvas.scale(scale);
    canvas.translate(-vb[0], -vb[1]);

    final outline = _paths.of(view.outline);
    final settled = progress >= 1.5;

    // silhouette
    final silhouetteAlpha = settled ? 1.0 : ((progress - 0.2) / 0.9).clamp(0.0, 1.0);
    canvas.drawPath(outline, Paint()..color = V.silhouette.withValues(alpha: silhouetteAlpha));

    for (final part in view.parts) {
      final alpha = settled ? 1.0 : _fade(_topOf(part));
      if (alpha <= 0) continue;
      final isMuscle = catalog.muscleById.containsKey(part.slug);
      if (!isMuscle) {
        final paint = Paint()
          ..color = (part.slug == 'hair' ? const Color(0xFF111819) : const Color(0xFF1A2425))
              .withValues(alpha: alpha);
        for (final d in [...part.common, ...part.left, ...part.right]) {
          canvas.drawPath(_paths.of(d), paint);
        }
        continue;
      }
      final id = part.slug;
      final tone = tones[id];
      final ink = compact ? null : _inkFor(tone);
      final angle = catalog.muscleById[id]!.fibre[side] ?? 90;
      final fill = Paint()..color = _fill(id, tone).withValues(alpha: alpha);
      final line = ink == null
          ? null
          : (Paint()
              ..color = _inkColor(ink).withValues(alpha: _inkColor(ink).a * alpha)
              ..strokeWidth = _fibreWidth
              ..style = PaintingStyle.stroke);
      for (final (paths, a) in [
        (part.left, angle),
        (part.right, 180 - angle),
        (part.common, 90.0),
      ]) {
        for (final d in paths) {
          final path = _paths.of(d);
          canvas.drawPath(path, fill);
          if (line != null) _hatch(canvas, path, a, line);
        }
      }
    }

    // outline, drawn once around the body during the intro
    final stroke = Paint()
      ..color = V.ink.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;
    final drawn = settled ? 1.0 : V.easeDraw.transform(((progress - 0.08) / 1.4).clamp(0.0, 1.0));
    if (drawn >= 1) {
      canvas.drawPath(outline, stroke);
    } else if (drawn > 0) {
      final metrics = outline.computeMetrics().toList();
      final total = metrics.fold(0.0, (s, m) => s + m.length);
      var left = total * drawn;
      for (final m in metrics) {
        if (left <= 0) break;
        canvas.drawPath(m.extractPath(0, math.min(left, m.length)), stroke);
        left -= m.length;
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.progress != progress ||
      old.pressed != pressed ||
      old.compact != compact ||
      old.side != side ||
      !_sameTones(old.tones, tones);

  static bool _sameTones(Map<MuscleId, Tone> a, Map<MuscleId, Tone> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}
