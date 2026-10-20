import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Path, Rect;

import '../data/catalog.dart';
import '../data/models.dart';
import 'rig.dart';

enum PartKind { body, skin, muscle }

/// One shape of the mannequin, in its bone's local frame (x across the bone, y along it).
class RigPart {
  RigPart._({
    required this.d,
    required this.shapes,
    required this.kind,
    required this.muscle,
    required this.fibre,
    required this.head,
    required this.turns,
  });

  factory RigPart._fromJson(Map<String, dynamic> j) => RigPart._(
    d: j['d'] as String,
    shapes: (j['shapes'] as List?)?.map((s) {
      final m = s as Map<String, dynamic>;
      return Shape(
        [
          for (final p in m['pts'] as List)
            Offset(((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()),
        ],
        (m['tension'] as num).toDouble(),
        surface: m['surface'] as bool? ?? false,
      );
    }).toList(),
    kind: PartKind.values.byName(j['kind'] as String),
    muscle: j['muscle'] as String?,
    fibre: (j['fibre'] as num?)?.toDouble() ?? 0,
    head: j['head'] as bool? ?? false,
    turns: j['turns'] as bool? ?? false,
  );

  /// SVG path data at rest.
  final String d;

  /// Torso parts keep their points so they can bend when the spine curls or turns.
  final List<Shape>? shapes;

  /// `body` and `skin` are always drawn; a `muscle` zone only when the exercise works it.
  final PartKind kind;

  /// Muscle painted on this region.
  final MuscleId? muscle;

  /// Fibre direction relative to the bone, degrees (0 = along it).
  final double fibre;

  /// The head: tilts on the neck by the pose's `nod`.
  final bool head;

  /// A head from the front or back that turns with the chest.
  final bool turns;

  /// The shape at rest, parsed once.
  late final Path path = svgPath(d);

  /// The fibre lines across the shape at rest.
  late final Float32List hatch = fibreLines(path.getBounds(), fibre);
}

/// The mannequin's body parts per view and bone, as exported from the web app.
class RigParts {
  RigParts._(Map<String, dynamic> json) : views = _read(json['views'] as Map<String, dynamic>);

  static Map<Facing, Map<Bone, List<RigPart>>> _read(Map<String, dynamic> views) => {
    for (final view in Facing.values)
      view: {
        for (final bone in Bone.values)
          bone: [
            for (final p in (views[view.name] as Map<String, dynamic>)[bone.name] as List)
              RigPart._fromJson(p as Map<String, dynamic>),
          ],
      },
  };

  static RigParts? _instance;

  /// Built from [Catalog.rigParts] the first time a demo is drawn.
  static RigParts get instance => _instance ??= RigParts._(catalog.rigParts);

  final Map<Facing, Map<Bone, List<RigPart>>> views;
}

/// The head drawn for a part that [RigPart.turns], turned by [twist] degrees.
Path turnedHead(Facing view, double twist) => (view == Facing.front ? face : backHead).path(twist);

/// Space between fibre lines, in the bone's local units.
const fibreGap = 2.6;

/// The fibre hatch of a muscle zone: parallel lines [fibreGap] apart at [fibre] degrees to the
/// bone, covering [bounds], as pairs of end points for `drawRawPoints`. The lines sit where the
/// web app's SVG pattern puts them (a tile of [fibreGap] with its line through the middle,
/// rotated by 90 + [fibre]), so the hatching matches line for line.
Float32List fibreLines(Rect bounds, double fibre) {
  final a = rad(90 + fibre);
  final ux = math.cos(a);
  final uy = math.sin(a);
  final nx = -uy;
  final ny = ux;
  final corners = [bounds.topLeft, bounds.topRight, bounds.bottomLeft, bounds.bottomRight];
  var lo = double.infinity;
  var hi = -double.infinity;
  var along0 = double.infinity;
  var along1 = -double.infinity;
  for (final c in corners) {
    final across = c.dx * nx + c.dy * ny;
    final along = c.dx * ux + c.dy * uy;
    lo = math.min(lo, across);
    hi = math.max(hi, across);
    along0 = math.min(along0, along);
    along1 = math.max(along1, along);
  }
  along0 -= 1;
  along1 += 1;
  const half = fibreGap / 2;
  final first = ((lo - half) / fibreGap).floor();
  final last = ((hi - half) / fibreGap).ceil();
  final out = Float32List(math.max(0, last - first + 1) * 4);
  var i = 0;
  for (var k = first; k <= last; k++) {
    final c = half + k * fibreGap;
    out[i++] = nx * c + ux * along0;
    out[i++] = ny * c + uy * along0;
    out[i++] = nx * c + ux * along1;
    out[i++] = ny * c + uy * along1;
  }
  return out;
}
