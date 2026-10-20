import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../app/toast.dart';
import '../data/catalog.dart';
import '../data/models.dart';
import '../logic/format.dart';
import '../logic/week.dart';
import '../state/log_store.dart';
import '../widgets/back_bar.dart';
import '../widgets/body_figure.dart';
import '../widgets/controls.dart';
import '../widgets/icons.dart';
import '../widgets/pressable.dart';
import 'exercise_screen.dart';
import 'food/entrance.dart';
import 'routine_screen.dart';

/// The Tuần này tab: the days you trained, the body toned by this week's sets, and what you
/// logged, day by day, newest first.
class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key, this.now});

  /// Pins "now", for tests.
  @visibleForTesting
  final DateTime? now;

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> with TabEntrance {
  void _remove(LoggedSet set) {
    final log = context.read<LogStore>();
    final removed = log.removeSet(set.id);
    if (removed != null) {
      Toast.show(
        context,
        'Đã xoá một hiệp',
        actionLabel: 'Hoàn tác',
        onAction: () => log.restoreSet(removed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = context.watch<LogStore>();
    final now = widget.now ?? DateTime.now();
    final days = weekDays(now);
    final sets = [
      for (final s in log.sets)
        if (inWeek(s.at, now)) s,
    ];
    final sessions = [
      for (final s in log.sessions)
        if (inWeek(s.at, now)) s,
    ];
    final volume = muscleVolume(sets);
    final tones = <MuscleId, Tone>{
      for (final MapEntry(:key, :value) in volume.entries) key: ?volumeTone(value),
    };
    bool trainedOn(DateTime d) =>
        sets.any((s) => isSameDay(s.at, d)) || sessions.any((s) => isSameDay(s.at, d));
    final byDay = [
      for (final d in days.reversed)
        (
          day: d,
          sets: [
            for (final s in sets)
              if (isSameDay(s.at, d)) s,
          ],
          sessions: [
            for (final s in sessions)
              if (isSameDay(s.at, d)) s,
          ],
        ),
    ].where((g) => g.sets.isNotEmpty || g.sessions.isNotEmpty).toList();
    final first = days.first, last = days.last;

    return CssLeading(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabHead(
              title: 'Tuần này',
              replay: entrance,
              subtitle: Text(
                '${first.day}/${first.month} – ${last.day}/${last.month}',
                style: VT.mono(13, height: 1.5, color: V.muted),
              ),
            ),
            Semantics(
              container: true,
              label: 'Các ngày trong tuần',
              child: Padding(
                padding: const EdgeInsets.fromLTRB(V.pad, 18, V.pad, 0),
                child: Row(
                  children: [
                    for (final (i, d) in days.indexed)
                      Expanded(
                        child: _Day(
                          label: weekdayShort[i],
                          on: trainedOn(d),
                          today: isSameDay(d, now),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(V.pad, 20, V.pad, 0),
              child: Text(
                weekSentence(sets.length, sessions.length, volume),
                style: VT.ui(16, height: 1.5),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 330,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BodyFigure(side: 'front', tones: tones),
                  const SizedBox(width: 20),
                  BodyFigure(side: 'back', tones: tones),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _Legend(),
            if (byDay.isNotEmpty) ...[
              const SizedBox(height: 30),
              for (final (i, g) in byDay.indexed)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: V.pad),
                        child: Semantics(header: true, child: SectionTitle(dayTitle(g.day))),
                      ),
                      for (final s in g.sessions)
                        _LogRow(
                          name: catalog.routineById[s.routineId]?.name ?? 'Buổi tập',
                          detail: minutesText(s.seconds),
                          at: s.at,
                          onOpen: () =>
                              Navigator.of(context).push(vRoute(RoutineScreen(id: s.routineId))),
                        ),
                      for (final s in g.sets)
                        _LogRow(
                          name: catalog.exerciseById[s.exerciseId]?.name ?? s.exerciseId,
                          detail: setTextOf(s),
                          at: s.at,
                          onOpen: () =>
                              Navigator.of(context).push(vRoute(ExerciseScreen(id: s.exerciseId))),
                          onDelete: () => _remove(s),
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The week in one or two sentences: how many sets, the muscle with the most, the big muscles
/// with none yet, and the short sessions done.
String weekSentence(int setCount, int sessionCount, Map<MuscleId, double> volume) {
  if (setCount == 0 && sessionCount == 0) {
    return 'Tuần này chưa có gì. Mở một bài tập và bấm “Ghi một hiệp”, cơ bạn tập sẽ đỏ dần trên '
        'hình.';
  }
  final parts = <String>[];
  if (setCount > 0) {
    // The first muscle with the most volume, as a stable sort would give it.
    MapEntry<MuscleId, double>? top;
    for (final e in volume.entries) {
      if (top == null || e.value > top.value) top = e;
    }
    final most = top == null
        ? ''
        : ', nhiều nhất cho ${catalog.muscleById[top.key]!.name.toLowerCase()}';
    parts.add('Bạn đã ghi $setCount hiệp$most.');
    const big = ['chest', 'upper-back', 'quadriceps', 'hamstring', 'gluteal', 'deltoids'];
    final missing = [
      for (final m in catalog.muscles)
        if (big.contains(m.id) && (volume[m.id] ?? 0) == 0) m.name.toLowerCase(),
    ];
    if (missing.isNotEmpty) parts.add('Chưa có hiệp nào cho ${_joinVi(missing)}.');
  }
  if (sessionCount > 0) parts.add('$sessionCount buổi tập ngắn đã xong.');
  return parts.join(' ');
}

/// "a", "a và b", "a, b và c"
String _joinVi(List<String> items) {
  if (items.length <= 1) return items.join();
  return '${items.sublist(0, items.length - 1).join(', ')} và ${items.last}';
}

/// A day in the week strip: a tally box, filled when you trained, ringed in ink today.
class _Day extends StatelessWidget {
  const _Day({required this.label, required this.on, required this.today});

  final String label;
  final bool on;
  final bool today;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label, ${on ? 'có tập' : 'chưa tập'}',
    excludeSemantics: true,
    child: Column(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: on ? V.accent : null,
            borderRadius: BorderRadius.circular(3),
            border: on ? null : Border.all(color: today ? V.ink : V.lineStrong, width: 1.5),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: VT.ui(
            12.5,
            weight: today ? FontWeight.w600 : FontWeight.w400,
            color: today ? V.ink : V.muted,
          ),
        ),
      ],
    ),
  );
}

/// What the three greens on the figures mean.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget entry(Color swatch, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: swatch, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(text, style: VT.ui(12.5, color: V.muted)),
      ],
    );
    return Semantics(
      container: true,
      label: 'Chú thích màu',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          entry(V.mix(V.accent, 0.32, V.muscle), '1–5 hiệp'),
          const SizedBox(width: 18),
          entry(V.mix(V.accent, 0.62, V.muscle), '6–11'),
          const SizedBox(width: 18),
          entry(V.accent, '12 trở lên'),
        ],
      ),
    );
  }
}

/// A logged set or session: opens the exercise or routine; sets can be deleted.
class _LogRow extends StatelessWidget {
  const _LogRow({
    required this.name,
    required this.detail,
    required this.at,
    required this.onOpen,
    this.onDelete,
  });

  final String name;
  final String detail;
  final DateTime at;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(left: V.pad, right: V.pad - 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: V.line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: VT.ui(15, weight: FontWeight.w500, height: 1.35)),
                    const SizedBox(height: 2),
                    Text(detail, style: VT.mono(12.5, height: 1.5, color: V.muted)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(timeText(at), style: VT.mono(12, height: 1.5, color: V.faint)),
        ),
        const SizedBox(width: 4),
        if (onDelete != null)
          Semantics(
            button: true,
            label: 'Xoá hiệp này',
            child: Pressable(
              onTap: onDelete,
              builder: (pressed) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: V.easeSwift,
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: pressed ? V.bg3 : const Color(0x00000000),
                  borderRadius: BorderRadius.circular(V.rControl),
                ),
                child: const VIcon(VIcons.trash, size: 20, color: V.faint),
              ),
            ),
          ),
      ],
    ),
  );
}
