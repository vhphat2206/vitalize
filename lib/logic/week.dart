import '../data/catalog.dart';
import '../data/models.dart';
import '../state/log_store.dart';
import '../widgets/body_figure.dart';

/// Monday 00:00 local time of the week containing [now].
DateTime startOfWeek(DateTime now) {
  final d = DateTime(now.year, now.month, now.day);
  return DateTime(d.year, d.month, d.day - (d.weekday - 1));
}

List<DateTime> weekDays(DateTime now) {
  final start = startOfWeek(now);
  return [for (var i = 0; i < 7; i++) DateTime(start.year, start.month, start.day + i)];
}

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

bool inWeek(DateTime at, DateTime now) {
  final start = startOfWeek(now);
  final end = DateTime(start.year, start.month, start.day + 7);
  return !at.isBefore(start) && at.isBefore(end);
}

/// Weekly volume per muscle. A logged set counts 1 for each primary muscle of the exercise and
/// 0.5 for each secondary one, the usual way coaches tally indirect work.
Map<MuscleId, double> muscleVolume(Iterable<LoggedSet> sets) {
  final out = <MuscleId, double>{};
  for (final set in sets) {
    final ex = catalog.exerciseById[set.exerciseId];
    if (ex == null) continue;
    for (final m in ex.primary) {
      out[m] = (out[m] ?? 0) + 1;
    }
    for (final m in ex.secondary) {
      out[m] = (out[m] ?? 0) + 0.5;
    }
  }
  return out;
}

/// Three steps of weekly volume: 1–5, 6–11 and 12+ sets.
Tone? volumeTone(double? v) {
  if (v == null || v == 0) return null;
  if (v >= 12) return Tone.vol3;
  if (v >= 6) return Tone.vol2;
  return Tone.vol1;
}
