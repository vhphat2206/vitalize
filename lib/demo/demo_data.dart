import 'dart:ui' show Offset, Rect;

import '../data/catalog.dart';
import 'rig.dart';

double _num(Object? v, [double fallback = 0]) => (v as num?)?.toDouble() ?? fallback;

Offset? _point(Object? v) {
  if (v == null) return null;
  final m = v as Map<String, dynamic>;
  return Offset(_num(m['x']), _num(m['y']));
}

/// A point on a bone: `u` along it from its start, `v` across it (forward on a side-view limb).
class Grip {
  const Grip(this.bone, this.u, this.v);

  factory Grip.fromJson(Map<String, dynamic> j) =>
      Grip(Bone.values.byName(j['bone'] as String), _num(j['u']), _num(j['v']));

  final Bone bone;
  final double u;
  final double v;
}

enum PropType {
  floor,
  bench,
  pad,
  frame,
  bar,
  hbar,
  rail,
  barbell,
  wbar,
  dumbbell,
  kettlebell,
  cable,
  lever,
  roller,
  board,
}

/// How a dumbbell is seen: end-on, side-on across or along the hand, or standing upright
/// whatever the hand does (held by one end overhead).
enum DumbbellLook { end, across, along, upright }

/// Something the figure uses or stands on. Fixed ones are in screen coordinates.
///
/// - floor: a line at [y].
/// - bench: a flat bench on two legs, its top at [y], from [x], [w] long.
/// - pad: upholstery or a block (seat, back rest, step) along [d], drawn behind the body.
/// - frame: tubing, posts and rails of a rack or machine along [d], behind the body; [dashed]
///   for a path a hand traces.
/// - bar: a bar seen end-on at ([x], [y]), its post running up to the top of the view (or down
///   to the floor when [postDown]).
/// - hbar: a pull-up bar seen from behind, from [x1] to [x2] at [y] on two posts.
/// - rail: a dip bar seen side-on, from [x1] to [x2] at [y], on posts at [posts] down to [to].
/// - barbell: a barbell seen end-on, held at [at], plates of radius [r].
/// - wbar: a bar seen from the front or back through both hands at [at], [half] long each way;
///   plates of radius [r] when loaded.
/// - dumbbell: a dumbbell in each hand ([one]: the near hand only), seen as [look], heads of
///   radius [size].
/// - kettlebell: hangs from the hand; [swing] lines it up with the arm instead.
/// - cable: a cable from a pulley at [from] to a handle at [at]; [otherFrom] is the pulley for the
///   other hand, [mid] runs one cable to the middle of a bar held in both hands, [front] draws it
///   across the body.
/// - lever: a machine arm from a fixed pivot at [from] to a handle or pad that moves with a limb.
/// - roller: a round machine pad of radius [r] that moves with a limb.
/// - board: a flat plate ([len] by [thick]) that moves with a limb, along the bone unless
///   [turn]ed.
class DemoProp {
  DemoProp.fromJson(Map<String, dynamic> j)
    : type = PropType.values.byName(j['type'] as String),
      x = _num(j['x']),
      y = _num(j['y']),
      w = _num(j['w']),
      d = j['d'] as String?,
      dashed = j['dashed'] as bool? ?? false,
      postDown = j['post'] == 'down',
      x1 = _num(j['x1']),
      x2 = _num(j['x2']),
      posts = [for (final p in (j['posts'] as List?) ?? const []) _num(p)],
      to = _num(j['to']),
      at = j['at'] == null ? null : Grip.fromJson(j['at'] as Map<String, dynamic>),
      r = (j['r'] as num?)?.toDouble(),
      half = _num(j['half']),
      behind = j['behind'] as bool? ?? false,
      look = j['look'] == null ? DumbbellLook.end : DumbbellLook.values.byName(j['look'] as String),
      size = _num(j['size'], 7.5),
      one = j['one'] as bool? ?? false,
      swing = j['swing'] as bool? ?? false,
      from = _point(j['from']),
      otherFrom = _point(j['otherFrom']),
      mid = j['mid'] as bool? ?? false,
      front = j['front'] as bool? ?? false,
      len = _num(j['len']),
      thick = _num(j['thick']),
      turn = _num(j['turn']);

  final PropType type;
  final double x;
  final double y;
  final double w;
  final String? d;
  final bool dashed;
  final bool postDown;
  final double x1;
  final double x2;
  final List<double> posts;
  final double to;
  final Grip? at;
  final double? r;
  final double half;
  final bool behind;
  final DumbbellLook look;
  final double size;
  final bool one;
  final bool swing;
  final Offset? from;
  final Offset? otherFrom;
  final bool mid;
  final bool front;
  final double len;
  final double thick;
  final double turn;

  /// Held or moved by a limb: drawn in front of the body; the rest stand behind it.
  bool get held => switch (type) {
    PropType.cable => front,
    PropType.wbar || PropType.board => !behind,
    PropType.barbell || PropType.dumbbell || PropType.kettlebell || PropType.roller => true,
    _ => false,
  };

  /// One for each hand or foot, unless it is [one]-handed.
  bool get paired => switch (type) {
    PropType.dumbbell ||
    PropType.kettlebell ||
    PropType.roller ||
    PropType.cable ||
    PropType.lever ||
    PropType.board => !one,
    _ => false,
  };
}

/// A pose at a point in the move: 0 = start pose, 1 = end pose.
class DemoKey {
  const DemoKey(this.at, this.pose);

  final double at;
  final Pose pose;
}

/// An animated exercise demo, as exported from the web app's src/data/demos.
class Demo {
  Demo._({
    required this.view,
    required this.facing,
    required this.props,
    required this.keys,
    required this.far,
    required this.phases,
    required this.hold,
    required this.move,
    required this.cycle,
    required this.behind,
    required this.cropped,
    required this.farLegTurnedOut,
  });

  factory Demo.fromJson(Map<String, dynamic> j) {
    final v = [for (final n in j['view'] as List) _num(n)];
    final timing = j['timing'] as Map<String, dynamic>?;
    final far = j['far'] as Map<String, dynamic>?;
    return Demo._(
      view: Rect.fromLTWH(v[0], v[1], v[2], v[3]),
      facing: j['facing'] == null ? Facing.side : Facing.values.byName(j['facing'] as String),
      props: [for (final p in j['props'] as List) DemoProp.fromJson(p as Map<String, dynamic>)],
      keys: [
        for (final k in j['keys'] as List)
          DemoKey(
            _num((k as Map<String, dynamic>)['at']),
            Pose.fromJson(k['pose'] as Map<String, dynamic>),
          ),
      ],
      far: far == null ? Offset.zero : Offset(_num(far['dx']), _num(far['dy'])),
      phases: List<String>.from(j['phases'] as List),
      hold: _num(timing?['hold'], 0.55),
      move: _num(timing?['move'], 1.35),
      cycle: timing?['cycle'] as bool? ?? false,
      behind: {for (final b in (j['behind'] as List?) ?? const []) Bone.values.byName(b as String)},
      cropped: j['cropped'] as bool? ?? false,
      farLegTurnedOut: j['farLegTurnedOut'] as bool? ?? false,
    );
  }

  /// The SVG viewBox: the part of the scene shown, in centimetres.
  final Rect view;

  /// Side view by default; front and back views suit moves out to the sides.
  final Facing facing;
  final List<DemoProp> props;

  /// Two or more poses; in-between keys shape the path a limb takes.
  final List<DemoKey> keys;

  /// Where the far arm and leg sit relative to the near ones, in a side view.
  final Offset far;

  /// The captions under the start and the end of the move.
  final List<String> phases;

  /// Seconds: hold at each end, and the move between them. A [cycle] (walking) runs from 0 to 1
  /// and starts again, taking [move] seconds, with the first and last keys the same pose.
  final double hold;
  final double move;
  final bool cycle;

  /// Bones drawn behind the torso, e.g. the arms and head of someone bent over, seen from behind.
  final Set<Bone> behind;

  /// The view is a close-up of the upper body; the legs run out of the frame.
  final bool cropped;

  /// The far leg lies turned out on the floor (knee to the side), so seen from the side its knee
  /// looks folded further than a knee bends.
  final bool farLegTurnedOut;
}

final _demos = <String, Demo?>{};

/// The demo for an exercise or routine move, if it has one. Parsed once.
Demo? demoFor(String id) => _demos.putIfAbsent(id, () {
  final j = catalog.demos[id];
  return j == null ? null : Demo.fromJson(j as Map<String, dynamic>);
});

/// Every exercise and move id that has a demo.
Iterable<String> get demoIds => catalog.demos.keys;
