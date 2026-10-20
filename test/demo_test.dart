// The web app's demo checks (src/components/demo/__tests__/demos.test.ts), run against the
// Dart rig: every demo, through the whole move, keeps its hands and feet on what they hold,
// stays above the floor and inside the frame, and bends its knees the way knees bend.

import 'package:flutter_test/flutter_test.dart';
import 'package:vitalize/data/catalog.dart';
import 'package:vitalize/demo/demo_data.dart';
import 'package:vitalize/demo/motion.dart';
import 'package:vitalize/demo/rig.dart';

import 'support/harness.dart';

const _samples = [0.0, 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9, 1.0];

/// Clockwise turn from one bone angle to another, in (-180, 180].
double _turn(double from, double to) {
  final d = (((to - from) % 360) + 360) % 360;
  return d > 180 ? d - 360 : d;
}

Iterable<Offset> _allPoints(Frame f) => [...f.joints.values, ...f.otherJoints.values];

Demo _demo(String id) => demoFor(id)!;
Pose _first(String id) => _demo(id).keys.first.pose;
Pose _last(String id) => _demo(id).keys.last.pose;
Map<Joint, Offset> _joints(String id, Pose p) => resolve(p, _demo(id).facing).joints;

void main() {
  setUpAll(setUpApp);

  group('demo data', () {
    test('only exists for real exercises and routine moves, and every one cites its sources', () {
      for (final id in demoIds) {
        expect(
          catalog.exerciseById.containsKey(id) || catalog.moveById.containsKey(id),
          isTrue,
          reason: id,
        );
        expect(catalog.refsFor(id), isNotEmpty, reason: '$id refs');
      }
    });

    test('covers every exercise and every move in the routines', () {
      for (final ex in catalog.exercises) {
        expect(demoFor(ex.id), isNotNull, reason: ex.id);
      }
      for (final r in catalog.routines) {
        for (final m in r.moves) {
          expect(demoFor(m.id), isNotNull, reason: '${r.id} ${m.id}');
        }
      }
    });

    test('keys run from 0 to 1 in order', () {
      for (final id in demoIds) {
        final at = [for (final k in _demo(id).keys) k.at];
        expect(at.first, 0, reason: id);
        expect(at.last, 1, reason: id);
        expect([...at]..sort(), at, reason: id);
      }
    });

    test('keeps the same fixed joint and the same held points in every key', () {
      for (final id in demoIds) {
        final k0 = _demo(id).keys.first.pose;
        Set<Object> keysOf(Map<Object, Object>? m) => {...?m?.keys};
        for (final k in _demo(id).keys) {
          expect(k.pose.root, k0.root, reason: id);
          expect(keysOf(k.pose.reach), keysOf(k0.reach), reason: id);
          expect(keysOf(k.pose.other), keysOf(k0.other), reason: id);
        }
      }
    });

    test('never swings a bone the long way round between keys', () {
      for (final id in demoIds) {
        final keys = _demo(id).keys;
        for (var i = 1; i < keys.length; i++) {
          for (final b in Bone.values) {
            final a = keys[i - 1].pose.angle(b);
            final c = keys[i].pose.angle(b);
            expect((c - a).abs(), lessThan(180), reason: '$id ${b.name} key $i');
          }
        }
      }
    });
  });

  group('every demo, through the whole move', () {
    test('hands and feet stay on what they hold', () {
      for (final id in demoIds) {
        final d = _demo(id);
        for (final t in _samples) {
          final p = poseAt(d.keys, t);
          final f = resolve(p, d.facing);
          final ends = {
            Limb.arm: f.joints[Joint.wrist]!,
            Limb.leg: f.joints[Joint.ankle]!,
            Limb.otherArm: f.otherJoints[Joint.wrist]!,
            Limb.otherLeg: f.otherJoints[Joint.ankle]!,
          };
          for (final MapEntry(key: limb, value: r) in (p.reach ?? const <Limb, Reach>{}).entries) {
            final e = ends[limb]!;
            final on = r.on;
            final base = on == null ? Offset.zero : pointOn(f, on.bone, on.u, on.v, on.side);
            final target = base + Offset(r.x, r.y);
            // Within a centimetre: a straight arm between two keys can come up a hair short.
            expect((e - target).distance, lessThan(1.2), reason: '$id ${limb.name} at $t');
          }
        }
      }
    });

    test('stays above the floor and inside the frame', () {
      for (final id in demoIds) {
        final d = _demo(id);
        final floor = d.props.where((p) => p.type == PropType.floor).firstOrNull;
        final v = d.view;
        for (final t in _samples) {
          final f = resolve(poseAt(d.keys, t), d.facing);
          for (final pt in _allPoints(f)) {
            if (floor != null) {
              expect(pt.dy, lessThanOrEqualTo(floor.y + 0.5), reason: '$id below floor at $t');
            }
            expect(pt.dx, greaterThan(v.left + 2), reason: '$id x at $t');
            expect(pt.dx, lessThan(v.right - 2), reason: '$id x at $t');
            expect(pt.dy, greaterThan(v.top + 2), reason: '$id y at $t');
            if (!d.cropped) expect(pt.dy, lessThan(v.bottom + 0.5), reason: '$id y at $t');
          }
          final head = f.joints[Joint.head]!;
          expect(head.dx - 10, greaterThan(v.left), reason: '$id head at $t');
          expect(head.dx + 10, lessThan(v.right), reason: '$id head at $t');
          expect(head.dy - 10, greaterThan(v.top), reason: '$id head at $t');
        }
      }
    });

    test('knees only bend the way knees bend (side views)', () {
      for (final id in demoIds) {
        final d = _demo(id);
        if (d.facing != Facing.side) continue;
        for (final t in _samples) {
          final f = resolve(poseAt(d.keys, t), d.facing);
          final near = _turn(f.angle(Bone.thigh), f.angle(Bone.shin));
          final other = _turn(f.otherAngle(Bone.thigh), f.otherAngle(Bone.shin));
          expect(near, inInclusiveRange(-4, 160), reason: '$id near knee at $t');
          if (d.farLegTurnedOut) continue;
          expect(other, inInclusiveRange(-4, 160), reason: '$id far knee at $t');
        }
      }
    });
  });

  // Technique checks taken from the cited guides (ACE exercise library).
  group('back squat', () {
    test('starts standing tall with the hips over the ankles', () {
      final j = _joints('back-squat', _first('back-squat'));
      expect((j[Joint.hip]!.dx - j[Joint.ankle]!.dx).abs(), lessThan(3));
      expect(j[Joint.knee]!.dy, lessThan(j[Joint.ankle]!.dy - 40));
    });

    test('bottoms out with the hips below the knees and the shin parallel to the torso', () {
      final p = _last('back-squat');
      final j = _joints('back-squat', p);
      expect(j[Joint.hip]!.dy, greaterThan(j[Joint.knee]!.dy)); // screen y grows downward
      final shinLean = p.angle(Bone.shin) - 180; // forward lean of the shin from vertical
      expect((shinLean - p.angle(Bone.spine)).abs(), lessThanOrEqualTo(2));
    });

    test('keeps the heels down: the ankle never moves', () {
      expect(_first('back-squat').root, _last('back-squat').root);
      expect(_first('back-squat').rootAt, _last('back-squat').rootAt);
    });
  });

  group('bench press', () {
    test('starts with the arms straight up over the shoulders', () {
      final j = _joints('barbell-bench-press', _first('barbell-bench-press'));
      expect((j[Joint.wrist]!.dx - j[Joint.shoulder]!.dx).abs(), lessThan(2));
      expect(j[Joint.wrist]!.dy, lessThan(j[Joint.shoulder]!.dy - 50));
    });

    test('lowers until the elbows are just below the bench, forearms near vertical', () {
      final p = _last('barbell-bench-press');
      final j = _joints('barbell-bench-press', p);
      const benchTop = -45;
      expect(j[Joint.elbow]!.dy, greaterThan(benchTop - 2));
      expect(p.angle(Bone.forearm).abs(), lessThan(10));
    });
  });

  group('pull-up', () {
    test('starts from a dead hang with straight arms', () {
      final p = _first('pull-up');
      expect(p.angle(Bone.upperArm), p.angle(Bone.forearm));
    });

    test('finishes with the chin over the bar', () {
      final j = _joints('pull-up', _last('pull-up'));
      // The head shape spans u = 9..31 along the neck, centred on the head joint at u = 20,
      // so with the neck upright the chin sits 11 below the head joint.
      final chin = j[Joint.head]!.dy + 11;
      expect(chin, lessThan(0)); // bar at y = 0
    });
  });
}
