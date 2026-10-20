import 'dart:ui' show Offset;

import 'demo_data.dart';
import 'rig.dart';

/// The pose at a point in the move (0 = start, 1 = end), between the keys either side of it.
Pose poseAt(List<DemoKey> keys, double t) {
  var i = 1;
  while (i < keys.length - 1 && t > keys[i].at) {
    i++;
  }
  final a = keys[i - 1];
  final b = keys[i];
  final span = b.at - a.at == 0 ? 1.0 : b.at - a.at;
  return lerpPose(a.pose, b.pose, ((t - a.at) / span).clamp(0.0, 1.0));
}

/// Where a grip point is on screen, on the near or the other side.
Offset gripPoint(Demo demo, Frame f, Grip g, [Side side = Side.near]) {
  final p = pointOn(f, g.bone, g.u, g.v, side);
  return side == Side.other && f.view == Facing.side ? p + demo.far : p;
}

/// Smooth in-out, so the figure eases into each end of the movement.
double easeInOutCubic(double t) {
  if (t < 0.5) return 4 * t * t * t;
  final u = -2 * t + 2;
  return 1 - u * u * u / 2;
}

/// The point in the move [t] seconds into the loop: hold at the start, ease to the end, hold,
/// ease back. A cycle just runs round.
double phaseAt(Demo demo, double t) {
  final hold = demo.hold;
  final move = demo.move;
  if (demo.cycle) return t / move;
  if (t < hold) return 0;
  if (t < hold + move) return easeInOutCubic((t - hold) / move);
  if (t < 2 * hold + move) return 1;
  return 1 - easeInOutCubic((t - 2 * hold - move) / move);
}

/// Length of one loop of the demo, seconds.
double periodOf(Demo demo) => demo.cycle ? demo.move : 2 * (demo.hold + demo.move);
