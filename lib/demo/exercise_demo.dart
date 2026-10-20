import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../app/theme.dart';
import '../data/models.dart';
import 'demo_data.dart';
import 'demo_painter.dart';
import 'motion.dart';

/// The movement, drawn as a figure that loops between its start and end positions. Muscles the
/// exercise works are painted like the body map: primary in solid green with fibre lines,
/// secondary as green fibre lines. Tap to pause.
///
/// The loop runs only while the demo is on screen, its route and tab are showing, and the system
/// isn't asking for reduced motion (then, as with [still], it shows one frame).
class ExerciseDemo extends StatefulWidget {
  const ExerciseDemo({
    super.key,
    required this.demo,
    required this.primary,
    required this.secondary,
    this.still,
    this.fill = false,
  });

  final Demo demo;
  final List<MuscleId> primary;
  final List<MuscleId> secondary;

  /// Freeze at a point in the move (0 = start, 1 = end) instead of looping.
  final double? still;

  /// Fill the parent's height and leave out the captions (the workout player shows its own cue).
  final bool fill;

  @override
  State<ExerciseDemo> createState() => _ExerciseDemoState();
}

class _ExerciseDemoState extends State<ExerciseDemo> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  late final _phase = ValueNotifier<double>(_still ?? 0);
  late final _atEnd = ValueNotifier<bool>(_phase.value > 0.5);

  /// Seconds into the loop, and where it was when the ticker last started.
  double _t = 0;
  double _base = 0;
  bool _paused = false;
  bool _reduceMotion = false;

  /// The tab holding the demo is showing (an IndexedStack hides the others).
  bool _shown = true;

  /// Some of the demo was inside the screen when last measured (each tick measures it).
  bool _onScreen = true;
  Size _screen = Size.zero;

  /// Things that move the demo around the screen: the scroll views it sits in and its route's
  /// transitions. When one moves, a demo stopped off screen takes another look.
  final _movers = <Listenable>[];

  /// A fixed frame instead of the loop: a still, or reduced motion.
  double? get _still => widget.still ?? (_reduceMotion ? 1 : null);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _shown = Visibility.of(context);
    _screen = MediaQuery.maybeSizeOf(context) ?? Size.zero;
    _listenToMovers();
    _onScreen = true;
    _show();
    _sync();
  }

  @override
  void didUpdateWidget(ExerciseDemo old) {
    super.didUpdateWidget(old);
    if (old.demo != widget.demo) {
      _t = 0;
      _base = 0;
      if (_ticker.isActive) _ticker.stop();
    }
    _show();
    _sync();
  }

  @override
  void dispose() {
    for (final m in _movers) {
      m.removeListener(_wake);
    }
    _ticker.dispose();
    _phase.dispose();
    _atEnd.dispose();
    super.dispose();
  }

  void _listenToMovers() {
    final found = <Listenable>[];
    var ctx = context;
    while (true) {
      final s = Scrollable.maybeOf(ctx);
      if (s == null) break;
      found.add(s.position);
      ctx = s.context;
    }
    final route = ModalRoute.of(context);
    if (route?.animation != null) found.add(route!.animation!);
    if (route?.secondaryAnimation != null) found.add(route!.secondaryAnimation!);
    for (final m in _movers) {
      m.removeListener(_wake);
    }
    _movers
      ..clear()
      ..addAll(found);
    for (final m in _movers) {
      m.addListener(_wake);
    }
  }

  /// Whether any of the demo is inside the screen, as last laid out.
  bool _measureOnScreen() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize || _screen.isEmpty) return true;
    final at = box.localToGlobal(Offset.zero);
    return (at & box.size).overlaps(Offset.zero & _screen);
  }

  /// Something moved: a demo stopped off screen runs again, and its next tick checks where it is.
  void _wake() {
    if (_onScreen) return;
    _onScreen = true;
    _sync();
  }

  /// Start or stop the loop to match what the demo should be doing.
  void _sync() {
    final run = _still == null && !_paused && _shown && _onScreen;
    if (run && !_ticker.isActive) {
      _base = _t;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    if (!mounted) return;
    if (!_measureOnScreen()) {
      _onScreen = false;
      _ticker.stop();
      return;
    }
    _t = (_base + elapsed.inMicroseconds / 1e6) % periodOf(widget.demo);
    _show();
  }

  /// Show the frame for the current time (or the still).
  void _show() {
    final p = _still ?? phaseAt(widget.demo, _t);
    _phase.value = p;
    _atEnd.value = p > 0.5;
  }

  void _toggle() {
    setState(() => _paused = !_paused);
    _sync();
  }

  Widget _stage({double? height}) => Semantics(
    container: true,
    button: true,
    label: _paused ? 'Tiếp tục chuyển động' : 'Dừng chuyển động',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: V.bg2,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: V.line),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: RepaintBoundary(
              child: Semantics(
                container: true,
                image: true,
                label: 'Hình minh hoạ động tác',
                child: CustomPaint(
                  size: Size.infinite,
                  painter: DemoPainter(
                    demo: widget.demo,
                    primary: widget.primary,
                    secondary: widget.secondary,
                    phase: _phase,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.fill) {
      return LayoutBuilder(
        builder: (context, c) => _stage(height: c.hasBoundedHeight ? c.maxHeight : 300),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stage(height: 300),
        const SizedBox(height: 12),
        ValueListenableBuilder<bool>(
          valueListenable: _atEnd,
          builder: (context, atEnd, _) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Phase(n: 1, text: widget.demo.phases[0], on: !atEnd),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Phase(n: 2, text: widget.demo.phases[1], on: atEnd),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A caption under the stage, lit while the figure is in that half of the move.
class _Phase extends StatelessWidget {
  const _Phase({required this.n, required this.text, required this.on});

  final int n;
  final String text;
  final bool on;

  @override
  Widget build(BuildContext context) => AnimatedDefaultTextStyle(
    // The page's letter spacing (-0.005em of the body's 15 px, inherited as a length) and the
    // CSS way of placing a line in its line height.
    style: VT
        .ui(13, height: 1.4, color: on ? V.ink : V.faint)
        .copyWith(letterSpacing: -0.075, leadingDistribution: TextLeadingDistribution.even),
    duration: const Duration(milliseconds: 300),
    curve: V.easeSwift,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: _Badge(n: n, on: on),
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

/// The phase number in a ring, filled green when lit.
class _Badge extends StatelessWidget {
  const _Badge({required this.n, required this.on});

  final int n;
  final bool on;

  @override
  Widget build(BuildContext context) {
    // Off, the ring and the digit take the caption's (fading) colour.
    final color = DefaultTextStyle.of(context).style.color ?? V.faint;
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? V.accent : null,
        border: on ? null : Border.all(color: color),
      ),
      child: Text(
        '$n',
        style: VT.mono(11, weight: FontWeight.w500, height: 1, color: on ? V.accentInk : color),
      ),
    );
  }
}
