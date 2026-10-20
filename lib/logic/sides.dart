import '../data/models.dart';

const _frontOnly = ['chest', 'biceps', 'abs', 'obliques', 'quadriceps', 'tibialis'];
const _backOnly = ['upper-back', 'lower-back', 'gluteal', 'hamstring'];

/// Which views show the muscles that matter. Muscles drawn on both views need both.
List<BodySide> sidesFor(List<MuscleId> primary, List<MuscleId> secondary) {
  final all = [...primary, ...secondary];
  final front = all.any(_frontOnly.contains);
  final back = all.any(_backOnly.contains);
  if (front && !back) return ['front'];
  if (back && !front) return ['back'];
  return ['front', 'back'];
}
