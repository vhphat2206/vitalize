import 'package:flutter/widgets.dart';

import '../app/theme.dart';
import '../data/catalog.dart';
import '../data/models.dart';
import '../logic/format.dart';
import '../widgets/back_bar.dart';
import '../widgets/body_figure.dart';
import '../widgets/pressable.dart';
import 'routine_screen.dart';
import 'routines/appear.dart';
import 'routines/text_wrap.dart';

/// Bài tập: the short sessions on the clock. No muscles to pick: choose by the time you have,
/// press start and follow the timer.
class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The tab sits in the shell's IndexedStack. Like the web app's hidden tab panels, it plays
    // its entrance each time it is shown, and not while it is out of sight.
    final shown = Visibility.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return DefaultTextHeightBehavior(
      textHeightBehavior: cssLeading,
      // Every row is built up front, so a row scrolled into view later doesn't replay its entrance.
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(V.pad, top + 22, V.pad, 22),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: V.lineStrong)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MaskLine(
                    fontSize: 34,
                    heading: true,
                    child: Appear.mask(
                      active: shown,
                      child: Text('Buổi tập ngắn', style: VT.display(34, height: 1.15, em: -0.025)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Appear.soft(
                    delay: 0.15,
                    active: shown,
                    child: Align(
                      alignment: AlignmentDirectional.topStart,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 30 * 15),
                        child: Text(
                          'Không cần chọn cơ. Chọn theo thời gian bạn có, bấm bắt đầu và làm theo '
                          'đồng hồ.',
                          style: VT.ui(15, color: V.muted).copyWith(letterSpacing: bodyTracking),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final (i, r) in catalog.routines.indexed)
              Appear.soft(
                delay: 0.2 + i * 0.07,
                duration: 0.7,
                active: shown,
                child: _RoutineRow(
                  routine: r,
                  onOpen: () => Navigator.of(context).push(vRoute(RoutineScreen(id: r.id))),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({required this.routine, required this.onOpen});

  final Routine routine;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final r = routine;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Pressable(
          onTap: onOpen,
          builder: (pressed) => AnimatedContainer(
            duration: motion(context, 200),
            curve: V.easeSwift,
            padding: const EdgeInsets.symmetric(horizontal: V.pad, vertical: 16),
            decoration: BoxDecoration(
              color: pressed ? V.bg3 : const Color(0x00182324),
              border: const Border(bottom: BorderSide(color: V.line)),
            ),
            child: Row(
              children: [
                _RoutineThumb(routine: r),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, style: VT.display(18, height: 1.25, em: -0.015)),
                      const SizedBox(height: 4),
                      WrappedText(
                        r.purpose,
                        wrap: WrapStyle.pretty,
                        style: VT.ui(14, height: 1.45, color: V.muted, em: 0),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 14,
                        children: [
                          Text(minutesText(r.seconds), style: VT.mono(12.5, height: 1.5)),
                          Text('${r.moves.length} động tác', style: VT.ui(13, em: 0)),
                          if (r.rounds > 1) Text('${r.rounds} vòng', style: VT.ui(13, em: 0)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small figure with every muscle the routine works, from the side where most of it is.
class _RoutineThumb extends StatelessWidget {
  const _RoutineThumb({required this.routine});

  final Routine routine;

  static const _backHeavy = ['upper-back', 'lower-back', 'gluteal', 'hamstring'];

  @override
  Widget build(BuildContext context) {
    final muscles = routine.muscles;
    final back = muscles.where(_backHeavy.contains).length * 2 > muscles.length;
    return ExcludeSemantics(
      child: SizedBox(
        width: 52,
        height: 104,
        // The figure is drawn 104 tall, a hair wider than its column, centred like on the web.
        child: OverflowBox(
          maxWidth: double.infinity,
          child: BodyFigure(
            side: back ? 'back' : 'front',
            tones: {for (final m in muscles) m: Tone.primary},
            compact: true,
          ),
        ),
      ),
    );
  }
}
