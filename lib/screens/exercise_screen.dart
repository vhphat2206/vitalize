import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../app/haptics.dart';
import '../app/theme.dart';
import '../app/toast.dart';
import '../data/catalog.dart';
import '../data/models.dart';
import '../demo/exercise_demo_for.dart';
import '../logic/format.dart';
import '../logic/week.dart';
import '../state/log_store.dart';
import '../widgets/back_bar.dart';
import '../widgets/controls.dart';
import '../widgets/exercise_row.dart';
import '../widgets/icons.dart';
import '../widgets/level_mark.dart';
import '../widgets/modal_sheet.dart';
import '../widgets/muscle_plate.dart';
import '../widgets/ref_list.dart';
import '../widgets/stepper.dart';
import 'body/appear.dart';

/// Equipment you load with plates or a pin, so a logged set records kilograms.
bool _isLoaded(String equipment) => equipment != 'bodyweight' && equipment != 'bar';

/// The leading whole number of a target like "8–12", as `Number.parseInt` reads it.
int? _leadingInt(String s) {
  final m = RegExp(r'^\s*[+-]?\d+').firstMatch(s);
  return m == null ? null : int.parse(m.group(0)!.trim());
}

/// One exercise: equipment and level, the animated demo, the muscles it works, the dose, how
/// to do it and what goes wrong, the guides behind it and others for the same muscles. The
/// footer logs a set; today's sets show above the button.
class ExerciseScreen extends StatelessWidget {
  const ExerciseScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final ex = catalog.exerciseById[id];
    // An id that is no exercise (a set logged before it was renamed, say): just the way back.
    if (ex == null) return const Align(alignment: Alignment.topCenter, child: BackBar());
    final sets = context.watch<LogStore>().sets;
    final now = DateTime.now();
    final today = [
      for (final s in sets)
        if (s.exerciseId == id && isSameDay(s.at, now)) s,
    ];
    final top = MediaQuery.paddingOf(context).top;
    return ScrolledPast(
      threshold: 60,
      builder: (context, scrolled, controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    controller: controller,
                    padding: EdgeInsets.only(top: top + 64, bottom: 32),
                    child: _Body(ex: ex),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: BackBar(title: ex.name, solid: scrolled),
                ),
              ],
            ),
          ),
          _Footer(today: today, onLog: () => _logSet(context, ex, sets)),
        ],
      ),
    );
  }

  void _logSet(BuildContext context, Exercise ex, List<LoggedSet> sets) {
    final loaded = _isLoaded(ex.equipment);
    final timed = ex.dose.unit == 'seconds';
    final first = _leadingInt(ex.dose.target);
    final target = first == null || first == 0 ? 10 : first;
    // the form starts from the last set of this exercise, any day
    final last = sets.where((s) => s.exerciseId == ex.id).lastOrNull;
    showModalSheet<void>(
      context,
      title: 'Ghi một hiệp',
      builder: (sheet) => _LogSetForm(
        loaded: loaded,
        timed: timed,
        initial: (kg: last?.kg ?? 20, reps: last?.reps ?? target, seconds: last?.seconds ?? target),
        onSave: (v) {
          final log = context.read<LogStore>();
          final saved = log.addSet(
            exerciseId: ex.id,
            seconds: timed ? v.seconds : null,
            reps: timed ? null : v.reps,
            kg: loaded && !timed ? v.kg : null,
          );
          Haptics.success();
          Navigator.of(sheet).pop();
          Toast.show(
            context,
            'Đã ghi ${setTextOf(saved)}',
            actionLabel: 'Hoàn tác',
            onAction: () => log.removeSet(saved.id),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.ex});

  final Exercise ex;

  @override
  Widget build(BuildContext context) {
    final related = catalog.exercises
        .where((e) => e.id != ex.id && e.primary.any(ex.primary.contains))
        .take(4)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: V.pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Appear(AppearKind.soft, delay: 0.05, child: _Meta(ex: ex)),
              // 12 px, and the mask line's 0.08em of room above the name
              const SizedBox(height: 12 + 0.08 * 31),
              Semantics(
                header: true,
                child: MaskLine(
                  fontSize: 31,
                  child: Appear(
                    AppearKind.mask,
                    delay: 0.1,
                    child: _WrappedText(
                      ex.name,
                      style: VT.display(31, height: 1.18),
                      wrap: _Wrap.balance,
                    ),
                  ),
                ),
              ),
              if (ex.nameEn != ex.name) ...[
                const SizedBox(height: 6),
                Text(
                  ex.nameEn,
                  style: VT.mono(12, height: 1.3, color: V.muted).copyWith(letterSpacing: -0.06),
                ),
              ],
              const SizedBox(height: 24),
              Appear(
                AppearKind.fade,
                delay: 0.2,
                duration: 0.8,
                child: ExerciseDemoFor(id: ex.id, primary: ex.primary, secondary: ex.secondary),
              ),
              const SizedBox(height: 26),
              Appear(
                AppearKind.fade,
                delay: 0.25,
                duration: 0.8,
                child: MusclePlate(primary: ex.primary, secondary: ex.secondary),
              ),
              const SizedBox(height: 22),
              _Dose(dose: ex.dose),
              if (ex.note case final note?) ...[const SizedBox(height: 18), _Note(note)],
              const SizedBox(height: 34),
              const SectionTitle('Cách làm'),
              for (final (i, step) in ex.steps.indexed) _Step(number: i + 1, text: step),
              const SizedBox(height: 34),
              const SectionTitle('Lỗi hay gặp'),
              for (final m in ex.mistakes) _Mistake(m),
              if (ex.refs.isNotEmpty) ...[
                const SizedBox(height: 34),
                const SectionTitle('Tài liệu tham khảo'),
                RefList(refs: ex.refs),
              ],
            ],
          ),
        ),
        if (related.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(V.pad, 34, V.pad, 0),
            child: SectionTitle('Cùng nhóm cơ'),
          ),
          for (final r in related)
            ExerciseRow(
              exercise: r,
              quiet: true,
              onOpen: () => Navigator.of(context).push(vRoute(ExerciseScreen(id: r.id))),
            ),
        ],
      ],
    );
  }
}

/// Equipment and level, above the name.
class _Meta extends StatelessWidget {
  const _Meta({required this.ex});

  final Exercise ex;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      VIcon(VIcons.equipment(ex.equipment), size: 20, color: V.muted),
      const SizedBox(width: 7),
      Text(catalog.equipmentLabel[ex.equipment]!, style: VT.ui(13, color: V.muted)),
      const SizedBox(width: 18),
      LevelMark(level: ex.level, withLabel: true),
    ],
  );
}

/// How [_WrappedText] picks its line breaks, as CSS `text-wrap` does.
enum _Wrap {
  /// Lines of even length: as narrow as the text can be without taking another line.
  balance,

  /// No single word left alone on the last line: words come down from the line above.
  pretty,
}

/// Text broken into lines the way the web's `text-wrap` does it.
class _WrappedText extends StatelessWidget {
  const _WrappedText(this.text, {required this.style, required this.wrap});

  final String text;
  final TextStyle style;
  final _Wrap wrap;

  /// The narrowest width that keeps the line count.
  static double _balanced(TextPainter p, double max) {
    p.layout(maxWidth: max);
    final lines = p.computeLineMetrics().length;
    if (lines < 2) return max;
    var lo = 0.0;
    var hi = max;
    while (hi - lo > 1) {
      final mid = (lo + hi) / 2;
      p.layout(maxWidth: mid);
      if (p.computeLineMetrics().length > lines) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return hi.ceilToDouble();
  }

  /// The widest width that leaves company on the last line, keeping the line count.
  static double _pretty(TextPainter p, String text, double max) {
    bool alone() {
      final last = p.getLineBoundary(TextPosition(offset: text.length));
      return !text.substring(last.start, last.end).trim().contains(' ');
    }

    p.layout(maxWidth: max);
    final lines = p.computeLineMetrics().length;
    if (lines < 2 || !alone()) return max;
    // Narrow past the widest line, one word at a time.
    for (var i = 0; i < 6; i++) {
      final widest = p.computeLineMetrics().fold(0.0, (w, l) => math.max(w, l.width));
      p.layout(maxWidth: widest - 0.5);
      if (p.computeLineMetrics().length != lines) return max;
      if (!alone()) return widest - 0.5;
    }
    return max;
  }

  @override
  Widget build(BuildContext context) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: effective),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        );
        final width = switch (wrap) {
          _Wrap.balance => _balanced(painter, box.maxWidth),
          _Wrap.pretty => _pretty(painter, text, box.maxWidth),
        };
        painter.dispose();
        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: math.min(width, box.maxWidth),
            child: Text(text, style: effective),
          ),
        );
      },
    );
  }
}

/// The prescription, set like a line on a gym whiteboard: three ruled columns.
class _Dose extends StatelessWidget {
  const _Dose({required this.dose});

  final Dose dose;

  Widget _cell(String label, String value, {bool first = false}) => Container(
    padding: EdgeInsets.fromLTRB(first ? 0 : 14, 12, 0, 14),
    decoration: first
        ? null
        : const BoxDecoration(
            border: Border(left: BorderSide(color: V.line)),
          ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: VT.ui(12.5, height: 1.3, color: V.muted)),
        const SizedBox(height: 6),
        Text(value, style: VT.mono(22, weight: FontWeight.w500, height: 1.1)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final each = unitLabel(dose.unit) == 'lần' ? 'Lần mỗi hiệp' : 'Giây mỗi hiệp';
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: V.lineStrong),
          bottom: BorderSide(color: V.line),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 8, child: _cell('Hiệp', dose.sets, first: true)),
            Expanded(
              flex: 13,
              child: _cell('$each${dose.perSide ? ', mỗi bên' : ''}', dose.target),
            ),
            Expanded(flex: 10, child: _cell('Nghỉ', restText(dose.rest))),
          ],
        ),
      ),
    );
  }
}

/// An easier or safer way in, ruled in ink down the left.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(left: 14),
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: V.ink, width: 2)),
    ),
    child: Text(text, style: VT.ui(14.5, height: 1.5)),
  );
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: V.line)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('$number', style: VT.mono(13, height: 1.5, color: V.muted)),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _WrappedText(text, style: VT.ui(15.5, height: 1.5), wrap: _Wrap.pretty),
        ),
      ],
    ),
  );
}

/// A common mistake, marked with a struck-out tally rather than an icon.
class _Mistake extends StatelessWidget {
  const _Mistake(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: V.line)),
    ),
    child: Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 0, 12),
          child: Text(text, style: VT.ui(15, height: 1.5)),
        ),
        Positioned(
          left: 2,
          top: 21,
          child: Transform.rotate(
            angle: -35 * math.pi / 180,
            child: const SizedBox(width: 14, height: 2, child: ColoredBox(color: V.muted)),
          ),
        ),
      ],
    ),
  );
}

/// Today's sets of this exercise and the button that logs one.
class _Footer extends StatelessWidget {
  const _Footer({required this.today, required this.onLog});

  final List<LoggedSet> today;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: V.bg,
      boxShadow: [BoxShadow(color: V.line, offset: Offset(0, -1))],
    ),
    child: Padding(
      padding: EdgeInsets.fromLTRB(V.pad, 12, V.pad, MediaQuery.paddingOf(context).bottom + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (today.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hôm nay', style: VT.ui(13, color: V.muted)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      // sits on the label's baseline
                      padding: const EdgeInsets.only(top: 1),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final (i, s) in today.indexed) ...[
                              if (i > 0) const SizedBox(width: 12),
                              Text(setTextOf(s), style: VT.mono(12.5, height: 1.5)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          PrimaryButton(label: 'Ghi một hiệp', onPressed: onLog),
        ],
      ),
    ),
  );
}

typedef _SetValues = ({double kg, int reps, int seconds});

/// The steppers for one set: weight for loaded equipment, then reps, or time for holds.
class _LogSetForm extends StatefulWidget {
  const _LogSetForm({
    required this.loaded,
    required this.timed,
    required this.initial,
    required this.onSave,
  });

  final bool loaded;
  final bool timed;
  final _SetValues initial;
  final ValueChanged<_SetValues> onSave;

  @override
  State<_LogSetForm> createState() => _LogSetFormState();
}

class _LogSetFormState extends State<_LogSetForm> {
  late _SetValues _v = widget.initial;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.loaded && !widget.timed) ...[
        VStepper(
          label: 'Mức tạ',
          unit: 'kg',
          value: _v.kg,
          step: 2.5,
          max: 500,
          format: formatKg,
          onChanged: (kg) => setState(() => _v = (kg: kg, reps: _v.reps, seconds: _v.seconds)),
        ),
        const SizedBox(height: 18),
      ],
      if (widget.timed)
        VStepper(
          label: 'Thời gian',
          unit: 'giây',
          value: _v.seconds.toDouble(),
          step: 5,
          min: 5,
          max: 600,
          onChanged: (s) => setState(() => _v = (kg: _v.kg, reps: _v.reps, seconds: s.round())),
        )
      else
        VStepper(
          label: 'Số lần',
          unit: 'lần',
          value: _v.reps.toDouble(),
          step: 1,
          min: 1,
          max: 100,
          onChanged: (r) => setState(() => _v = (kg: _v.kg, reps: r.round(), seconds: _v.seconds)),
        ),
      const SizedBox(height: 18 + 6),
      PrimaryButton(label: 'Lưu hiệp', onPressed: () => widget.onSave(_v)),
    ],
  );
}
