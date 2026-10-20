import 'package:flutter/widgets.dart';

import '../app/theme.dart';
import '../data/catalog.dart';
import '../data/models.dart';
import '../demo/exercise_demo_for.dart';
import '../logic/format.dart';
import '../widgets/back_bar.dart';
import '../widgets/controls.dart';
import '../widgets/icons.dart';
import '../widgets/muscle_plate.dart';
import '../widgets/ref_list.dart';
import 'player_screen.dart';
import 'routines/appear.dart';
import 'routines/text_wrap.dart';

/// One routine: what it is for, the muscles it works, and its moves, each of which opens to show
/// how it is done. The start button sits under the list.
class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key, required this.id});

  final String id;

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  /// One move open at a time shows how it's done.
  int? _open;

  @override
  Widget build(BuildContext context) {
    final r = catalog.routineById[widget.id];
    if (r == null) return const SizedBox.shrink();
    final pad = MediaQuery.paddingOf(context);
    return DefaultTextHeightBehavior(
      textHeightBehavior: cssLeading,
      child: ScrolledPast(
        threshold: 60,
        builder: (context, scrolled, controller) => Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller,
                    padding: EdgeInsets.fromLTRB(V.pad, pad.top + 64, V.pad, 28),
                    child: _body(r),
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(V.pad, 12, V.pad, pad.bottom + 12),
                  decoration: const BoxDecoration(
                    color: V.bg,
                    // A hairline above the footer, outside its box (`box-shadow: 0 -1px 0`).
                    boxShadow: [BoxShadow(color: V.line, offset: Offset(0, -1))],
                  ),
                  child: PrimaryButton(
                    label: 'Bắt đầu',
                    onPressed: () => Navigator.of(context).push(vRoute(PlayerScreen(id: r.id))),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: BackBar(title: r.name, solid: scrolled),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(Routine r) {
    final plain = VT.ui(14, height: 1.55, color: V.muted).copyWith(letterSpacing: bodyTracking);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MaskLine(
          fontSize: 31,
          heading: true,
          child: Appear.mask(
            delay: 0.08,
            child: WrappedText(
              r.name,
              wrap: WrapStyle.balance,
              style: VT.display(31, height: 1.18, em: -0.02),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Appear.soft(
          delay: 0.2,
          child: Text(r.purpose, style: VT.ui(16).copyWith(letterSpacing: bodyTracking)),
        ),
        const SizedBox(height: 8),
        Appear.soft(
          delay: 0.28,
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Khoảng '),
                TextSpan(text: minutesText(r.seconds), style: VT.mono(13.5, height: 1.55)),
                TextSpan(
                  text:
                      '. ${r.moves.length} động tác'
                      '${r.rounds > 1 ? ', lặp lại ${r.rounds} vòng' : ''}'
                      ', nghỉ ${r.rest} giây giữa các động tác. ${r.equipment}.',
                ),
              ],
            ),
            style: plain,
          ),
        ),
        const SizedBox(height: 26),
        Appear.fade(
          delay: 0.35,
          duration: 0.8,
          child: MusclePlate(primary: const [], secondary: r.muscles, height: 230, legend: false),
        ),
        const SizedBox(height: 30),
        SectionTitle(r.rounds > 1 ? 'Mỗi vòng' : 'Các động tác'),
        for (final (i, m) in r.moves.indexed)
          _Move(
            number: i + 1,
            move: m,
            open: _open == i,
            onToggle: () => setState(() => _open = _open == i ? null : i),
          ),
      ],
    );
  }
}

/// A move in the list. Tapping it opens the demo and the guides it was checked against.
class _Move extends StatelessWidget {
  const _Move({
    required this.number,
    required this.move,
    required this.open,
    required this.onToggle,
  });

  final int number;
  final RoutineMove move;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final m = move;
    final refs = catalog.refsFor(m.id);
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: V.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MergeSemantics(
            child: Semantics(
              button: true,
              expanded: open,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Stack(
                      children: [
                        // number, name and cue, time: on one baseline (26px 1fr auto 18px grid)
                        Padding(
                          padding: const EdgeInsets.only(right: 8 + 18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              SizedBox(
                                width: 26,
                                child: Text(
                                  '$number',
                                  style: VT.mono(13, height: 1.5, color: V.muted),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.name,
                                      style: VT.ui(
                                        16,
                                        weight: FontWeight.w600,
                                        height: 1.35,
                                        em: 0,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    WrappedText(
                                      m.cue,
                                      wrap: WrapStyle.pretty,
                                      style: VT.ui(14, height: 1.45, color: V.muted, em: 0),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${m.seconds} giây',
                                softWrap: false,
                                style: VT.mono(12.5, height: 1.5, color: V.muted),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          bottom: 0,
                          child: Center(
                            child: AnimatedRotation(
                              turns: open ? 0.5 : 0,
                              duration: motion(context, 300),
                              curve: V.easeSwift,
                              child: const VIcon(VIcons.chevronDown, size: 18, color: V.muted),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExerciseDemoFor(id: m.id, primary: m.muscles, secondary: const []),
                  if (refs.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Semantics(
                      header: true,
                      child: Text(
                        'Tài liệu tham khảo',
                        style: VT
                            .ui(13, weight: FontWeight.w600, height: 1.3, color: V.muted)
                            .copyWith(letterSpacing: bodyTracking),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // The web app's `.moves li` rule also rules each guide's own `li`, so here
                    // every guide sits on a double hairline.
                    for (final ref in refs) ...[
                      RefList(refs: [ref]),
                      const SizedBox(height: 1, child: ColoredBox(color: V.line)),
                    ],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
