import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app/haptics.dart';
import '../app/theme.dart';
import '../data/catalog.dart';
import '../data/models.dart';
import '../demo/exercise_demo_for.dart';
import '../logic/format.dart';
import '../state/log_store.dart';
import '../state/prefs_store.dart';
import '../widgets/controls.dart';
import '../widgets/icons.dart';
import '../widgets/pressable.dart';
import 'routines/appear.dart';
import 'routines/text_wrap.dart';

/// The workout player: a short get-ready, then each move against the clock with a rest after it,
/// round after round. The demo of the move fills the middle; the last seconds tick under your
/// thumb. Finishing writes the session into the week.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.id});

  final String id;

  /// Wall-clock time, for the time actually spent. Tests put their fake clock here.
  @visibleForTesting
  static DateTime Function() wallClock = DateTime.now;

  /// Keeps the screen on, or lets it sleep again. Tests put a recorder here.
  @visibleForTesting
  static Future<void> Function(bool on) wakelock = _wakelock;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

Future<void> _wakelock(bool on) => WakelockPlus.toggle(enable: on);

const _readySeconds = 5;

/// One stretch of the clock.
sealed class _Step {
  const _Step(this.seconds);

  final int seconds;
}

/// Get ready, with the first move shown.
class _Ready extends _Step {
  const _Ready(this.next) : super(_readySeconds);

  final RoutineMove next;
}

class _Work extends _Step {
  _Work({required this.move, required this.index, required this.round, required this.workIndex})
    : super(move.seconds);

  final RoutineMove move;

  /// Position of the move in the round, from 0.
  final int index;

  /// Round, from 1.
  final int round;

  /// Position among all the moves of the session, from 0.
  final int workIndex;
}

/// Rest, with the next move shown.
class _Rest extends _Step {
  const _Rest(super.seconds, this.next);

  final RoutineMove next;
}

List<_Step> _buildSteps(Routine r) {
  final steps = <_Step>[_Ready(r.moves.first)];
  var workIndex = 0;
  for (var round = 1; round <= r.rounds; round++) {
    for (final (index, move) in r.moves.indexed) {
      steps.add(_Work(move: move, index: index, round: round, workIndex: workIndex++));
      final isLast = round == r.rounds && index == r.moves.length - 1;
      if (!isLast) steps.add(_Rest(r.rest, r.moves[(index + 1) % r.moves.length]));
    }
  }
  return steps;
}

Duration _seconds(num s) => Duration(microseconds: (s * 1e6).round());

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  Routine? _routine;
  List<_Step> _steps = const [];
  List<int> _workIndexes = const [];

  // The clock runs on frame time stamps, so a dropped frame or a stretch in the background never
  // makes the routine run long: when frames come back, the step that ran out simply ends.
  late final Ticker _ticker = createTicker((_) => _onFrame());
  int _index = 0;

  /// Frame time when the current step ends; null before the first frame.
  Duration? _endsAt;

  /// Seconds left in the current step while paused.
  double _pausedLeft = _readySeconds.toDouble();
  bool _paused = false;
  Duration _now = Duration.zero;

  // Wall-clock bookkeeping for the time actually spent.
  DateTime? _startedAt;
  Duration _pausedFor = Duration.zero;
  DateTime? _pausedSince;

  /// Seconds spent, set once the last step ends.
  int? _spent;

  /// Seconds left in the current step, every frame (the progress bar paints from it).
  final _left = ValueNotifier<double>(_readySeconds.toDouble());

  /// The same rounded up, as the clock shows it; changes once a second.
  final _whole = ValueNotifier<int>(_readySeconds);
  int? _lastWhole;

  bool _keepAwake = true;
  bool _awake = false;
  bool _logged = false;

  bool get _done => _spent != null;

  @override
  void initState() {
    super.initState();
    final r = catalog.routineById[widget.id];
    if (r == null || r.moves.isEmpty) return;
    _routine = r;
    _steps = _buildSteps(r);
    _workIndexes = [
      for (final (i, s) in _steps.indexed)
        if (s is _Work) i,
    ];
    _publish();
    // Start the clock on the first frame.
    _atFrame((now) {
      _now = now;
      _endsAt = now + _seconds(_readySeconds);
      _startedAt = PlayerScreen.wallClock();
      _sync();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _keepAwake = Provider.of<PrefsStore>(context).settings.keepAwake;
    _syncWakelock();
  }

  @override
  void dispose() {
    _ticker.dispose();
    if (_awake) _setAwake(false);
    _left.dispose();
    _whole.dispose();
    super.dispose();
  }

  /// Runs [action] at the start of the next frame, with that frame's time stamp, so taps and the
  /// clock read the same time line.
  void _atFrame(void Function(Duration now) action) {
    SchedulerBinding.instance.scheduleFrameCallback((now) {
      if (mounted) action(now);
    });
  }

  double _leftAt(Duration now) {
    if (_paused) return _pausedLeft;
    final endsAt = _endsAt;
    if (endsAt == null) return _steps[_index].seconds.toDouble();
    return math.max(0, (endsAt - now).inMicroseconds / 1e6);
  }

  void _onFrame() {
    final t = SchedulerBinding.instance.currentFrameTimeStamp;
    final endsAt = _endsAt;
    if (endsAt != null && t >= endsAt) {
      _goTo(_index + 1, t);
    } else {
      _now = t;
      _publish();
    }
  }

  /// Hands the time left to the clock and the progress bar, with a light tick on each of the
  /// last three seconds.
  void _publish() {
    final left = _leftAt(_now);
    _left.value = left;
    final whole = left.ceil();
    if (whole != _lastWhole) {
      final last = _lastWhole;
      if (last != null && whole <= 3 && whole > 0 && whole < last) Haptics.tick();
      _lastWhole = whole;
      _whole.value = whole;
    }
  }

  /// The ticker runs while the clock does; the screen stays on while it runs.
  void _sync() {
    final running = !_paused && !_done && _endsAt != null;
    if (running && !_ticker.isActive) {
      _ticker.start();
    } else if (!running && _ticker.isActive) {
      _ticker.stop();
    }
    _syncWakelock();
  }

  void _syncWakelock() {
    final want = _keepAwake && !_paused && !_done && _routine != null;
    if (want != _awake) _setAwake(want);
  }

  void _setAwake(bool on) {
    _awake = on;
    unawaited(PlayerScreen.wakelock(on).catchError((Object _) {}));
  }

  void _goTo(int i, Duration now) {
    if (i >= _steps.length) {
      _finish();
      return;
    }
    final target = math.max(0, i);
    final seconds = _steps[target].seconds;
    setState(() {
      _index = target;
      _now = now;
      _endsAt = now + _seconds(seconds);
      _pausedLeft = seconds.toDouble();
    });
    _publish();
    _sync();
    Haptics.bump();
  }

  void _finish() {
    final wall = PlayerScreen.wallClock();
    final spent = wall.difference(_startedAt ?? wall) - _pausedFor;
    setState(() => _spent = (spent.inMilliseconds / 1000).round());
    _sync();
    // Record the session once.
    if (!_logged) {
      _logged = true;
      context.read<LogStore>().addSession(routineId: _routine!.id, seconds: _spent!);
    }
  }

  void _togglePause() => _atFrame((now) {
    if (_done) return;
    final wall = PlayerScreen.wallClock();
    if (_paused) {
      final since = _pausedSince;
      setState(() {
        _paused = false;
        _now = now;
        _endsAt = now + _seconds(_pausedLeft);
        if (since != null) _pausedFor += wall.difference(since);
        _pausedSince = null;
      });
    } else {
      setState(() {
        _pausedLeft = math.max(0, ((_endsAt ?? now) - now).inMicroseconds / 1e6);
        _paused = true;
        _now = now;
        _pausedSince = wall;
      });
    }
    _publish();
    _sync();
  });

  void _nextMove() => _atFrame((now) {
    if (_done) return;
    _goTo(_workIndexes.firstWhere((i) => i > _index, orElse: () => _steps.length), now);
  });

  void _previousMove() => _atFrame((now) {
    if (_done) return;
    final step = _steps[_index];
    // Restart the current move if it has run a few seconds, otherwise go back one move.
    if (step is _Work && step.seconds - _leftAt(now) > 3) return _goTo(_index, now);
    final earlier = _workIndexes.where((i) => i < _index);
    _goTo(earlier.isEmpty ? 0 : earlier.last, now);
  });

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final r = _routine;
    if (r == null) return const SizedBox.shrink();
    final pad = MediaQuery.paddingOf(context);
    final step = _steps[_index];
    // Rest and get-ready read as a breath: the floor goes a step darker.
    final calm = !_done && step is! _Work;
    return DefaultTextHeightBehavior(
      textHeightBehavior: cssLeading,
      child: AnimatedContainer(
        duration: motion(context, 500),
        curve: V.easeSwift,
        color: calm ? const Color(0xFF071011) : const Color(0x00071011),
        padding: EdgeInsets.only(bottom: pad.bottom + 14),
        child: _done ? _finished(r) : _session(r, step, pad.top),
      ),
    );
  }

  Widget _session(Routine r, _Step step, double top) {
    final workCount = r.moves.length * r.rounds;
    final workDone = switch (step) {
      _Work(:final workIndex) => workIndex,
      _Rest() => _steps.take(_index).whereType<_Work>().length,
      _Ready() => 0,
    };
    // The move being done, or during a rest or the get-ready the one coming up.
    final shown = switch (step) {
      _Work(:final move) => move,
      _Rest(:final next) || _Ready(:final next) => next,
    };
    final working = step is _Work;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(8, top + 6, V.pad, 0),
          child: Row(
            children: [
              IconBtn(VIcons.close, label: 'Dừng buổi tập', onPressed: _close),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  label: 'Động tác ${workDone + 1} trên $workCount',
                  // Repainted every frame, on its own.
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: const Size.fromHeight(3),
                      painter: _ProgressPainter(
                        count: workCount,
                        done: workDone,
                        working: working,
                        seconds: step.seconds,
                        left: _left,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(V.pad, 20, V.pad, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _kicker(r, step),
                // `margin-top: 8px` above the line's mask, which reaches 0.08em above the text
                const SizedBox(height: 8 + 0.08 * 34),
                MaskLine(
                  fontSize: 34,
                  heading: true,
                  child: Appear.mask(
                    key: ValueKey('$_index-name'),
                    duration: 0.7,
                    child: WrappedText(
                      shown.name,
                      wrap: WrapStyle.balance,
                      style: VT.display(
                        34,
                        height: 1.15,
                        em: -0.02,
                        color: working ? V.ink : V.muted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.topStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 28 * 16),
                    child: Appear.soft(
                      key: ValueKey('$_index-cue'),
                      delay: 0.12,
                      duration: 0.7,
                      child: WrappedText(
                        shown.cue,
                        wrap: WrapStyle.pretty,
                        style: VT.ui(16).copyWith(letterSpacing: bodyTracking),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 6),
                    child: ExerciseDemoFor(
                      key: ValueKey(shown.id),
                      id: shown.id,
                      primary: shown.muscles,
                      secondary: const [],
                      fill: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 10),
          child: RepaintBoundary(
            child: ValueListenableBuilder<int>(
              valueListenable: _whole,
              // Each new second rises into place.
              builder: (context, whole, _) => Center(
                child: MaskLine(
                  fontSize: 15,
                  child: Appear.mask(
                    key: ValueKey(whole),
                    duration: 0.24,
                    child: Text(
                      clock(whole),
                      style: VT
                          .mono(
                            84,
                            weight: FontWeight.w500,
                            height: 1,
                            color: _paused ? V.muted : V.ink,
                          )
                          .copyWith(letterSpacing: -0.04 * 84),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ControlButton(VIcons.skipPrev, label: 'Động tác trước', onTap: _previousMove),
            const SizedBox(width: 36),
            _PlayButton(paused: _paused, onTap: _togglePause),
            const SizedBox(width: 36),
            _ControlButton(VIcons.skipNext, label: 'Bỏ qua động tác', onTap: _nextMove),
          ],
        ),
      ],
    );
  }

  Widget _kicker(Routine r, _Step step) {
    final text = VT.ui(14, color: V.muted).copyWith(letterSpacing: bodyTracking);
    final number = VT.mono(13, height: 1.5);
    Widget count(String label, int n, int of) => Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label '),
          TextSpan(text: '$n', style: number),
          const TextSpan(text: ' trên '),
          TextSpan(text: '$of', style: number),
        ],
      ),
      style: text,
    );
    return Row(
      children: switch (step) {
        _Work(:final index, :final round) => [
          count('Động tác', index + 1, r.moves.length),
          if (r.rounds > 1) ...[const SizedBox(width: 16), count('Vòng', round, r.rounds)],
        ],
        _Ready() => [Text('Chuẩn bị', style: text)],
        _Rest() => [Text('Nghỉ, rồi tới', style: text)],
      },
    );
  }

  Widget _finished(Routine r) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(V.pad, 0, V.pad, 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MaskLine(
                fontSize: 64,
                heading: true,
                child: Appear.mask(
                  child: Text('Xong.', style: VT.display(64, height: 1.1, em: -0.03)),
                ),
              ),
              const SizedBox(height: 14),
              Appear.soft(
                delay: 0.2,
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 24 * 17),
                    child: Text(
                      'Bạn vừa tập hết ${r.name.toLowerCase()} trong ${minutesText(_spent!)}. '
                      'Buổi này đã được ghi vào tuần của bạn.',
                      style: VT.ui(17).copyWith(letterSpacing: bodyTracking),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: V.pad),
        child: PrimaryButton(label: 'Về danh sách', onPressed: _close),
      ),
    ],
  );
}

/// One thin segment per move of the session: done ones full, the current one filling up.
class _ProgressPainter extends CustomPainter {
  _ProgressPainter({
    required this.count,
    required this.done,
    required this.working,
    required this.seconds,
    required this.left,
  }) : super(repaint: left);

  final int count;
  final int done;
  final bool working;
  final int seconds;
  final ValueListenable<double> left;

  static const _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final width = (size.width - _gap * (count - 1)) / count;
    final fraction = seconds == 0 ? 1.0 : 1 - left.value / seconds;
    final track = Paint()..color = V.line;
    final fill = Paint()..color = V.ink;
    for (var i = 0; i < count; i++) {
      final x = i * (width + _gap);
      canvas.drawRect(Rect.fromLTWH(x, 0, width, size.height), track);
      final scale = i < done
          ? 1.0
          : i == done && working
          ? fraction.clamp(0.0, 1.0)
          : 0.0;
      if (scale > 0) canvas.drawRect(Rect.fromLTWH(x, 0, width * scale, size.height), fill);
    }
  }

  @override
  bool shouldRepaint(_ProgressPainter old) =>
      old.count != count ||
      old.done != done ||
      old.working != working ||
      old.seconds != seconds ||
      old.left != left;
}

/// 56×56 icon button beside the play button.
class _ControlButton extends StatelessWidget {
  const _ControlButton(this.glyph, {required this.label, required this.onTap});

  final VGlyph glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Pressable(
      onTap: onTap,
      builder: (pressed) => AnimatedContainer(
        duration: motion(context, 200),
        curve: V.easeSwift,
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: pressed ? V.bg3 : const Color(0x00182324),
          borderRadius: BorderRadius.circular(V.rControl),
        ),
        alignment: Alignment.center,
        child: VIcon(glyph, size: 28, color: V.ink),
      ),
    ),
  );
}

/// The round green play / pause button.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.paused, required this.onTap});

  final bool paused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: paused ? 'Tiếp tục' : 'Tạm dừng',
    child: Pressable(
      onTap: onTap,
      scale: 0.95,
      builder: (_) => Container(
        width: 76,
        height: 76,
        decoration: const BoxDecoration(color: V.accent, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: VIcon(paused ? VIcons.play : VIcons.pause, size: 30, color: V.accentInk),
      ),
    ),
  );
}
