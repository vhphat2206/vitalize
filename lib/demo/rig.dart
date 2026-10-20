/// A 2D mannequin: bones with absolute angles, posed by forward kinematics from one fixed joint
/// (the feet in a squat, the hands in a pull-up). Every body part is drawn in its bone's local
/// frame, so muscle zones and their fibre hatching turn with the limb.
///
/// Seen from the side the figure faces right and its far arm and leg sit behind the body. Seen
/// from the front or the back, the arms hang from the shoulder corners, the legs from the hips,
/// and the left side is drawn as the mirror image of the right.
///
/// Angles are degrees, 0 = up, 90 = right, 180 = down (clockwise, screen coordinates).
/// Units are roughly centimetres of a 178 cm adult.
///
/// A port of the web app's src/components/demo/rig.ts.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Path;

import 'package:path_drawing/path_drawing.dart';

enum Joint { hip, shoulder, head, elbow, wrist, knuckle, knee, ankle, toe }

enum Bone {
  spine(Joint.hip, Joint.shoulder, 50),
  neck(Joint.shoulder, Joint.head, 20),
  upperArm(Joint.shoulder, Joint.elbow, 30),
  forearm(Joint.elbow, Joint.wrist, 26),
  hand(Joint.wrist, Joint.knuckle, 9),
  thigh(Joint.hip, Joint.knee, 44),
  shin(Joint.knee, Joint.ankle, 43),
  foot(Joint.ankle, Joint.toe, 19);

  const Bone(this.from, this.to, this.length);

  final Joint from;
  final Joint to;
  final double length;
}

/// Which way the camera looks at the figure.
enum Facing { side, front, back }

/// `near` is the arm or leg facing the camera in a side view, the right one from the front or
/// back.
enum Side { near, other }

/// The limbs a pose can bend to reach a point.
enum Limb { arm, leg, otherArm, otherLeg }

const arm = [Bone.upperArm, Bone.forearm, Bone.hand];
const leg = [Bone.thigh, Bone.shin, Bone.foot];
const limbBones = [...arm, ...leg];

const _armJoints = [Joint.elbow, Joint.wrist, Joint.knuckle];
const _legJoints = [Joint.knee, Joint.ankle, Joint.toe];

double _num(Object? v, [double fallback = 0]) => (v as num?)?.toDouble() ?? fallback;

/// A point on the body to reach for: `u` along the bone, `v` across it.
class ReachOn {
  const ReachOn(this.bone, this.u, this.v, [this.side = Side.near]);

  factory ReachOn.fromJson(Map<String, dynamic> j) => ReachOn(
    Bone.values.byName(j['bone'] as String),
    _num(j['u']),
    _num(j['v']),
    j['side'] == null ? Side.near : Side.values.byName(j['side'] as String),
  );

  final Bone bone;
  final double u;
  final double v;
  final Side side;
}

/// A wrist or ankle held at a point (a handle, the floor): the limb bends to reach it.
class Reach {
  const Reach({required this.x, required this.y, this.on, required this.bend, this.end});

  factory Reach.fromJson(Map<String, dynamic> j) => Reach(
    x: _num(j['x']),
    y: _num(j['y']),
    on: j['on'] == null ? null : ReachOn.fromJson(j['on'] as Map<String, dynamic>),
    bend: (j['bend'] as num).toInt(),
    end: (j['end'] as num?)?.toDouble(),
  );

  /// The point on screen, or an offset from [on] when given.
  final double x;
  final double y;

  /// Reach for a point on the body instead (hands on the hips, behind the head).
  final ReachOn? on;

  /// Which side of the line from shoulder to wrist (hip to ankle) the elbow (knee) goes. 0 bends
  /// it towards the camera (a soft knee or a squat seen from the front): the lower bone keeps its
  /// length on the line to the target and the upper one looks shorter, pointing back up to the
  /// knee once the hips drop below it.
  final int bend;

  /// Hand or foot angle relative to the forearm or shin; without it, it keeps its own angle.
  final double? end;
}

class Pose {
  const Pose({
    required this.root,
    required this.rootAt,
    required this.angles,
    required this.scale,
    this.other,
    this.otherScale,
    this.absolute = false,
    this.reach,
    this.shrug = 0,
    this.nod = 0,
    this.curl = 0,
    this.twist = 0,
  });

  factory Pose.fromJson(Map<String, dynamic> j) {
    final root = j['root'] as Map<String, dynamic>;
    final angles = j['angles'] as Map<String, dynamic>;
    final scale = j['scale'] as Map<String, dynamic>?;
    Map<Bone, double>? byBone(Object? m) => m == null
        ? null
        : {
            for (final e in (m as Map<String, dynamic>).entries)
              Bone.values.byName(e.key): _num(e.value),
          };
    final reach = j['reach'] as Map<String, dynamic>?;
    return Pose(
      root: Joint.values.byName(root['joint'] as String),
      rootAt: Offset(_num(root['x']), _num(root['y'])),
      angles: [for (final b in Bone.values) _num(angles[b.name])],
      scale: [for (final b in Bone.values) _num(scale?[b.name], 1)],
      other: byBone(j['other']),
      otherScale: byBone(j['otherScale']),
      absolute: j['absolute'] as bool? ?? false,
      reach: reach == null
          ? null
          : {
              for (final e in reach.entries)
                Limb.values.byName(e.key): Reach.fromJson(e.value as Map<String, dynamic>),
            },
      shrug: _num(j['shrug']),
      nod: _num(j['nod']),
      curl: _num(j['curl']),
      twist: _num(j['twist']),
    );
  }

  /// The joint that stays put, and where it is. Always on the near side.
  final Joint root;
  final Offset rootAt;

  /// Bone angles, by [Bone.index].
  final List<double> angles;

  /// Foreshortening along each bone (by [Bone.index], 1 when not set), for limbs that swing
  /// towards or away from the camera.
  final List<double> scale;

  /// The other arm and leg, when they move differently from the near ones. From the front or
  /// back these read like right-side angles and are mirrored about the spine, unless [absolute].
  final Map<Bone, double>? other;
  final Map<Bone, double>? otherScale;

  /// Front or back view: [other] angles are screen angles, not mirrored ones.
  final bool absolute;
  final Map<Limb, Reach>? reach;

  /// How far the shoulders lift towards the ears, cm.
  final double shrug;

  /// Head tilt on top of the neck, degrees; positive drops the chin (facing right).
  final double nod;

  /// The spine bending between the lower back and the ribs, degrees: positive curls forward (a
  /// crunch), negative arches. From the front or back it bends to the side.
  final double curl;

  /// Front or back view: the chest turning about the spine, degrees, towards the near side
  /// (screen right) when positive. The hips stay square and the shoulder turning away goes
  /// behind the body.
  final double twist;

  double angle(Bone b) => angles[b.index];
}

double rad(double deg) => deg * math.pi / 180;

/// A vector of length [len] in direction [deg] (bone convention).
Offset dir(double deg, double len) => Offset(math.sin(rad(deg)) * len, -math.cos(rad(deg)) * len);

/// Angle of a vector in the same convention as bones.
double angleOf(Offset v) => math.atan2(v.dx, -v.dy) * 180 / math.pi;

/// Where a limb bone sits on screen.
class Placed {
  const Placed(this.at, this.angle, this.scale, this.mirror);

  final Offset at;
  final double angle;
  final double scale;

  /// Left side from the front or back: the shape is flipped so its outer edge faces out.
  final bool mirror;
}

/// Where each arm and leg attaches to the trunk.
class Starts {
  const Starts(this.arm, this.leg, this.otherArm, this.otherLeg);

  final Offset arm;
  final Offset leg;
  final Offset otherArm;
  final Offset otherLeg;
}

/// A pose worked out: every joint on screen, and the angles the limbs ended up at.
class Frame {
  Frame._({
    required this.view,
    required this.joints,
    required this.otherJoints,
    required this.angles,
    required this.otherAngles,
    required this.scale,
    required this.otherScale,
    required this.starts,
    required this.nod,
    required this.curl,
    required this.twist,
    required this.lean,
  });

  final Facing view;
  final Map<Joint, Offset> joints;

  /// Elbow, wrist, knuckle, knee, ankle and toe of the other arm and leg.
  final Map<Joint, Offset> otherJoints;

  /// By [Bone.index].
  final List<double> angles;

  /// On-screen angles of the other limbs, by [Bone.index] (limb bones only).
  final List<double> otherAngles;
  final List<double> scale;
  final List<double> otherScale;
  final Starts starts;
  final double nod;
  final double curl;
  final double twist;

  /// How far the trunk leans away from the camera in a front or back view (tan of the angle).
  final double lean;

  double angle(Bone b) => angles[b.index];
  double otherAngle(Bone b) => otherAngles[b.index];
}

/// Two-bone reach: angles of the upper and lower bone so the chain from [base] ends at [t].
(double, double) _reachAngles(Offset base, Offset t, double a, double b, double bend) {
  final v = t - base;
  final d = math.min(math.max(v.distance, (a - b).abs() + 1e-6), a + b - 1e-6);
  final cos = (a * a + d * d - b * b) / (2 * a * d);
  final upper = angleOf(v) + bend * (math.acos(cos.clamp(-1.0, 1.0)) * 180 / math.pi);
  final mid = base + dir(upper, a);
  return (upper, angleOf(t - mid));
}

/// Joint positions and final limb angles for a pose, walking outward from the fixed joint.
Frame resolve(Pose p, [Facing view = Facing.side]) {
  final angles = List<double>.of(p.angles);
  final scale = List<double>.of(p.scale);
  double len(Bone b, double s) => b.length * s;
  final frontal = view != Facing.side;
  final curl = p.curl;
  final spine = angles[Bone.spine.index];
  // The shoulders turn with the upper back when the spine curls; the hips stay with the pelvis.
  final top = spine + curl;
  final shrug = p.shrug;
  final twist = frontal ? p.twist : 0.0;
  // A trunk shortened in a front or back view leans away from the camera, so a turning shoulder
  // dips as it goes back and the other rises.
  final spineScale = math.min(1.0, scale[Bone.spine.index]);
  final tilt = frontal ? math.sqrt(1 - spineScale * spineScale) : 0.0;
  // From the front or back the shoulders and hips are wide; from the side they sit on the spine.
  Offset armAt(double k) => frontal
      ? dir(top + 90, 17 * k * math.cos(rad(twist))) +
            dir(top, shrug - 3 - 17 * k * math.sin(rad(twist)) * tilt)
      : dir(top, shrug);
  Offset legAt(double k) => frontal ? dir(spine + 90, 8.5 * k) + dir(spine, -2) : Offset.zero;
  final offsets = {Bone.upperArm: armAt(1), Bone.thigh: legAt(1)};
  Offset vec(Bone b) {
    if (b != Bone.spine || curl == 0) return dir(angles[b.index], len(b, scale[b.index]));
    final s = curledShoulder(curl);
    return dir(spine, s.dy * scale[Bone.spine.index]) + dir(spine - 90, s.dx);
  }

  final joints = <Joint, Offset>{p.root: p.rootAt};
  var changed = true;
  while (changed) {
    changed = false;
    for (final b in Bone.values) {
      final v = vec(b);
      final o = offsets[b] ?? Offset.zero;
      final a = joints[b.from];
      final c = joints[b.to];
      if (a != null && c == null) {
        joints[b.to] = a + o + v;
        changed = true;
      } else if (c != null && a == null) {
        joints[b.from] = c - v - o;
        changed = true;
      }
    }
  }
  final starts = Starts(
    joints[Joint.shoulder]! + armAt(1),
    joints[Joint.hip]! + legAt(1),
    joints[Joint.shoulder]! + armAt(-1),
    joints[Joint.hip]! + legAt(-1),
  );

  // The other limbs copy the near ones unless told otherwise; frontal views mirror them.
  final otherAngles = List<double>.filled(Bone.values.length, 0);
  final otherScale = List<double>.filled(Bone.values.length, 1);
  void mirrorOther() {
    for (final b in limbBones) {
      final set = p.other?[b];
      final a = set ?? angles[b.index];
      final axis = arm.contains(b) ? top : spine;
      otherAngles[b.index] = frontal && !(p.absolute && set != null) ? 2 * axis - a : a;
      otherScale[b.index] = p.otherScale?[b] ?? scale[b.index];
    }
  }

  mirrorOther();
  final flip = frontal ? -1.0 : 1.0;
  final otherJoints = <Joint, Offset>{};
  final frame = Frame._(
    view: view,
    joints: joints,
    otherJoints: otherJoints,
    angles: angles,
    otherAngles: otherAngles,
    scale: scale,
    otherScale: otherScale,
    starts: starts,
    nod: p.nod,
    curl: curl,
    twist: twist,
    lean: tilt / spineScale,
  );

  // Lay a limb chain from its start with the given angles, after bending it to reach if asked.
  // [full] is the upper bone's scale before any bend towards the camera shortened it.
  void chain(
    List<Bone> bones,
    List<Joint> names,
    Offset start,
    List<double> ang,
    List<double> sc,
    Reach? reach,
    double flip,
    Map<Joint, Offset> out,
    double full,
  ) {
    final upper = bones[0];
    final lower = bones[1];
    final end = bones[2];
    if (reach != null) {
      final on = reach.on;
      final t = on != null
          ? pointOn(frame, on.bone, on.u, on.v, on.side) + Offset(reach.x, reach.y)
          : Offset(reach.x, reach.y);
      if (reach.bend == 0) {
        final a = len(upper, full);
        final b = len(lower, sc[lower.index]);
        final v = t - start;
        final d = v.distance;
        final toward = angleOf(v);
        final rest = math.min((d - b).abs(), a);
        sc[upper.index] = a != 0 ? full * rest / a : full;
        ang[upper.index] = d >= b ? toward : toward + 180;
        ang[lower.index] = toward;
      } else {
        final (u, l) = _reachAngles(
          start,
          t,
          len(upper, sc[upper.index]),
          len(lower, sc[lower.index]),
          reach.bend * flip,
        );
        ang[upper.index] = u;
        ang[lower.index] = l;
      }
      if (reach.end != null) ang[end.index] = ang[lower.index] + reach.end! * flip;
    }
    var at = start;
    for (var i = 0; i < bones.length; i++) {
      final b = bones[i];
      at = at + dir(ang[b.index], len(b, sc[b.index]));
      out[names[i]] = at;
    }
  }

  // Legs first, then arms, so hands can reach for a knee or a hip. A limb on the path from the
  // fixed joint is already placed and can't reach.
  bool rootIn(List<Joint> names) => names.contains(p.root);
  // Upper bones' own scales, before a bend towards the camera shortens them.
  double fullScale(Bone b, bool other) {
    final own = other ? p.otherScale : null;
    return own?[b] ?? p.scale[b.index];
  }

  final reach = p.reach;
  if (reach?[Limb.leg] != null && !rootIn(_legJoints)) {
    chain(
      leg,
      _legJoints,
      starts.leg,
      angles,
      scale,
      reach![Limb.leg],
      1,
      joints,
      fullScale(Bone.thigh, false),
    );
  }
  mirrorOther();
  chain(
    leg,
    _legJoints,
    starts.otherLeg,
    otherAngles,
    otherScale,
    reach?[Limb.otherLeg],
    flip,
    otherJoints,
    fullScale(Bone.thigh, true),
  );
  if (reach?[Limb.arm] != null && !rootIn(_armJoints)) {
    chain(
      arm,
      _armJoints,
      starts.arm,
      angles,
      scale,
      reach![Limb.arm],
      1,
      joints,
      fullScale(Bone.upperArm, false),
    );
  }
  final legAngles = [for (final b in leg) otherAngles[b.index]];
  final legScales = [for (final b in leg) otherScale[b.index]];
  mirrorOther();
  for (var i = 0; i < leg.length; i++) {
    otherAngles[leg[i].index] = legAngles[i];
    otherScale[leg[i].index] = legScales[i];
  }
  chain(
    arm,
    _armJoints,
    starts.otherArm,
    otherAngles,
    otherScale,
    reach?[Limb.otherArm],
    flip,
    otherJoints,
    fullScale(Bone.upperArm, true),
  );
  return frame;
}

const _nowhere = Offset(double.nan, double.nan);

/// Where a bone is drawn: its start, angle, length scale, and whether it is mirrored.
Placed place(Frame f, Bone bone, [Side side = Side.near]) {
  final from = bone.from;
  if (side == Side.other && bone != Bone.spine && bone != Bone.neck) {
    final at = from == Joint.shoulder
        ? f.starts.otherArm
        : from == Joint.hip
        ? f.starts.otherLeg
        : f.otherJoints[from] ?? _nowhere;
    return Placed(at, f.otherAngles[bone.index], f.otherScale[bone.index], f.view != Facing.side);
  }
  final at = bone == Bone.upperArm
      ? f.starts.arm
      : bone == Bone.thigh
      ? f.starts.leg
      : f.joints[from] ?? _nowhere;
  return Placed(at, f.angles[bone.index], f.scale[bone.index], false);
}

/// A point given in a bone's local frame (u along the bone, v across it), on screen.
Offset toScreen(Placed p, double u, double v) =>
    p.at + dir(p.angle, u * p.scale) + dir(p.angle + (p.mirror ? 90 : -90), v);

/// A point on a bone, on screen; on the torso it follows the spine's curl and twist.
Offset pointOn(Frame f, Bone bone, double u, double v, [Side side = Side.near]) {
  final pl = place(f, bone, side);
  if (bone != Bone.spine || (f.curl == 0 && f.twist == 0)) return toScreen(pl, u, v);
  final q = bendPoint(twistPoint(Offset(v, u), f.twist, f.lean, true), f.curl);
  return toScreen(pl, q.dy, q.dx);
}

/// The pose a fraction [t] of the way from [a] to [b].
Pose lerpPose(Pose a, Pose b, double t) {
  double lerp(double x, double y) => x + (y - x) * t;
  final n = Bone.values.length;
  final angles = [for (var i = 0; i < n; i++) lerp(a.angles[i], b.angles[i])];
  final scale = [for (var i = 0; i < n; i++) lerp(a.scale[i], b.scale[i])];
  // Only the other-side bones a key sets; the rest keep following the near side (and its reach).
  Map<Bone, double>? other;
  Map<Bone, double>? otherScale;
  if (a.other != null || b.other != null || a.otherScale != null || b.otherScale != null) {
    other = {};
    otherScale = {};
    for (final k in limbBones) {
      final ao = a.other?[k];
      final bo = b.other?[k];
      if (ao != null || bo != null) {
        other[k] = lerp(ao ?? a.angles[k.index], bo ?? b.angles[k.index]);
      }
      final aScale = a.otherScale?[k];
      final bScale = b.otherScale?[k];
      if (aScale != null || bScale != null) {
        otherScale[k] = lerp(aScale ?? a.scale[k.index], bScale ?? b.scale[k.index]);
      }
    }
  }
  Map<Limb, Reach>? reach;
  final ar = a.reach;
  if (ar != null) {
    reach = {};
    for (final MapEntry(key: k, value: ra) in ar.entries) {
      final rb = b.reach?[k] ?? ra;
      final on = ra.on;
      // A grip can slide along the bone it holds (a bar running down the thighs).
      final slide = on != null && rb.on?.bone == on.bone;
      reach[k] = Reach(
        x: lerp(ra.x, rb.x),
        y: lerp(ra.y, rb.y),
        on: slide ? ReachOn(on.bone, lerp(on.u, rb.on!.u), lerp(on.v, rb.on!.v), on.side) : on,
        bend: ra.bend,
        end: ra.end == null ? null : lerp(ra.end!, rb.end ?? ra.end!),
      );
    }
  }
  return Pose(
    root: a.root,
    rootAt: Offset(lerp(a.rootAt.dx, b.rootAt.dx), lerp(a.rootAt.dy, b.rootAt.dy)),
    angles: angles,
    scale: scale,
    other: other,
    otherScale: otherScale,
    absolute: a.absolute,
    reach: reach,
    shrug: lerp(a.shrug, b.shrug),
    nod: lerp(a.nod, b.nod),
    curl: lerp(a.curl, b.curl),
    twist: lerp(a.twist, b.twist),
  );
}

/// The length scale a bone is drawn with: a bone pointing straight at the camera keeps a little
/// length so it still reads as a limb.
double drawnScale(double scale) => scale.abs() < 0.2 ? (scale < 0 ? -0.2 : 0.2) : scale;

// ——— Shapes, in bone-local coordinates (x across the bone, y along it) ———
// A point is an Offset(x across, u along).

/// A closed torso shape kept as points, so it can bend and turn with the spine.
class Shape {
  const Shape(this.pts, this.tension, {this.surface = false});

  final List<Offset> pts;
  final double tension;

  /// On the body's surface (a muscle zone): swings round when the chest turns.
  final bool surface;
}

/// The torso [shapes] after the spine curls by [curl] and the chest turns by [twist].
Path shapePath(List<Shape> shapes, [double curl = 0, double twist = 0, double lean = 0]) {
  final path = Path();
  for (final s in shapes) {
    var pts = s.pts;
    if (twist != 0) pts = [for (final p in pts) twistPoint(p, twist, lean, s.surface)];
    if (curl != 0) pts = [for (final p in pts) bendPoint(p, curl)];
    addSmooth(path, pts, closed: true, tension: s.tension);
  }
  return path;
}

/// Where the spine bends when the torso curls (a crunch) or arches: between these u values.
const _curlFrom = 16.0;
const _curlTo = 34.0;

/// A torso point after the spine curls by [curl] degrees: below 16 nothing moves, the stretch up
/// to 34 bends into an arc, and everything above turns with its end. Positive curls towards
/// local -x (forward, seen from the side).
Offset bendPoint(Offset p, double curl) {
  final x = p.dx;
  final u = p.dy;
  if (curl.abs() < 0.01 || u <= _curlFrom) return p;
  final th = rad(curl);
  final r = (_curlTo - _curlFrom) / th;
  final phi = (math.min(u, _curlTo) - _curlFrom) / r;
  final px = -r + (r + x) * math.cos(phi);
  final pu = _curlFrom + (r + x) * math.sin(phi);
  final past = math.max(0.0, u - _curlTo);
  return Offset(px - past * math.sin(th), pu + past * math.cos(th));
}

/// The spine's end (the shoulder joint) after a curl, in the spine's local frame.
Offset curledShoulder(double curl) => bendPoint(Offset(0, Bone.spine.length), curl);

/// Where the chest turns when the trunk twists: nothing below 8, fully above 40.
const _twistFrom = 8.0;
const _twistTo = 40.0;

/// Half the ribcage's depth, front to back.
const _chestDepth = 10.0;

/// A torso point seen from the front or back after the chest turns by [twist] degrees (positive
/// towards screen right). A point on the surface swings round the spine; a point on the outline
/// only moves in as the trunk shows its narrower side. [lean] tilts the turning shoulders.
Offset twistPoint(Offset p, double twist, double lean, bool surface) {
  final x = p.dx;
  final u = p.dy;
  final w = ((u - _twistFrom) / (_twistTo - _twistFrom)).clamp(0.0, 1.0);
  if (twist == 0 || w == 0) return p;
  final c = math.cos(rad(twist * w));
  final s = math.sin(rad(twist * w));
  // Local +x runs to screen left; r runs right.
  final r = -x;
  if (!surface) {
    final depth = math.min(_chestDepth, r.abs());
    final h = math.sqrt(r * c * r * c + depth * s * depth * s);
    return Offset(-r.sign * h, u - r * s * lean);
  }
  final half = torsoHalfWidth(u);
  final q = r / half;
  final depth = _chestDepth * math.sqrt(math.max(0.0, 1 - q * q));
  return Offset(-(r * c + depth * s), u + (depth * (c - 1) - r * s) * lean);
}

/// The trunk's outline seen from the front or back, right half: [x, u].
const backTorso = [
  Offset(8, -13),
  Offset(15, -9),
  Offset(17.5, -1),
  Offset(16, 8),
  Offset(14.5, 14),
  Offset(16, 24),
  Offset(19.5, 34),
  Offset(21.5, 42),
  Offset(21, 48),
  Offset(17, 51.5),
  Offset(9.5, 54.5),
  Offset(6, 56),
];

/// Half the trunk's width at [u], seen from the front or back.
double torsoHalfWidth(double u) {
  final i = backTorso.indexWhere((p) => p.dy >= u);
  if (i <= 0) return backTorso[i < 0 ? backTorso.length - 1 : 0].dx;
  final a = backTorso[i - 1];
  final b = backTorso[i];
  return a.dx + (b.dx - a.dx) * (u - a.dy) / (b.dy - a.dy);
}

/// Catmull-Rom through [pts] as cubic Béziers, added to [path].
void addSmooth(Path path, List<Offset> pts, {bool closed = true, double tension = 0.5}) {
  final n = pts.length;
  if (n == 0) return;
  Offset p(int i) => pts[closed ? ((i % n) + n) % n : i.clamp(0, n - 1)];
  path.moveTo(p(0).dx, p(0).dy);
  final last = closed ? n : n - 1;
  final k = tension / 3;
  for (var i = 0; i < last; i++) {
    final p0 = p(i - 1);
    final p1 = p(i);
    final p2 = p(i + 1);
    final p3 = p(i + 2);
    path.cubicTo(
      p1.dx + (p2.dx - p0.dx) * k,
      p1.dy + (p2.dy - p0.dy) * k,
      p2.dx - (p3.dx - p1.dx) * k,
      p2.dy - (p3.dy - p1.dy) * k,
      p2.dx,
      p2.dy,
    );
  }
  if (closed) path.close();
}

/// Parsed SVG path data, shared by every demo: each string is parsed once.
Path svgPath(String d) => _paths.putIfAbsent(d, () => parseSvgPathData(d));
final _paths = <String, Path>{};

/// A head seen from the front or back: its outline, and an ear each side (given for the side at
/// +x, as a start and three Bézier points after it) that moves in as the head turns and drops
/// out once it goes round the back. Positive turns go towards screen right, which is local -x.
class HeadFacing {
  const HeadFacing(this.outline, this.x, this.y, this.ear);

  final String outline;
  final double x;
  final double y;
  final List<Offset> ear;

  /// The head turned by [turn] degrees.
  Path path([double turn = 0]) {
    final path = Path()..addPath(svgPath(outline), Offset.zero);
    for (final k in const [1.0, -1.0]) {
      if (k * x * math.sin(rad(turn)) < -3) continue;
      final at = k * x * math.cos(rad(turn));
      path
        ..moveTo(at, y)
        ..cubicTo(
          at + k * ear[0].dx,
          y + ear[0].dy,
          at + k * ear[1].dx,
          y + ear[1].dy,
          at + k * ear[2].dx,
          y + ear[2].dy,
        );
    }
    return path;
  }
}

/// The back of the head, ears at the sides.
const backHead = HeadFacing(
  'M0 9C6 9 9.5 13.5 9.5 20C9.5 26.5 6 31 0 31C-6 31-9.5 26.5-9.5 20C-9.5 13.5-6 9 0 9Z',
  9.2,
  17.5,
  [Offset(1.8, 0), Offset(2.2, 4.5), Offset(0.4, 6)],
);

/// The face, a little narrower at the jaw, ears at the sides.
const face = HeadFacing(
  'M0 9C5.2 9 8.5 12.8 9.2 18.5C9.8 24.5 6.5 31 0 31C-6.5 31-9.8 24.5-9.2 18.5C-8.5 12.8-5.2 9 0 9Z',
  9.1,
  18,
  [Offset(1.8, 0), Offset(2.1, 4.3), Offset(0.3, 5.6)],
);

/// The point on the neck bone the head tilts about (the base of the skull).
const skullBase = 13.0;
