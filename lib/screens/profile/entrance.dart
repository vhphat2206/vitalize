import 'package:flutter/widgets.dart';

import '../../app/theme.dart';

/// Length of one entrance animation: `.appear` in the web app's motion.css (`--dur`).
const appearSeconds = 1.05;

/// The clock of a screen's entrance: seconds since the screen came into view. [Appear]
/// children read it and animate in at their own delay, like `.appear` with `--d`.
class Entrance extends InheritedWidget {
  const Entrance({super.key, required this.clock, required super.child});

  final EntranceClock clock;

  static Animation<double>? _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Entrance>()?.clock.seconds;

  @override
  bool updateShouldNotify(Entrance old) => old.clock != clock;
}

/// Counts the seconds of a screen's entrance, up to the [lastDelay] plus one animation.
class EntranceClock {
  EntranceClock(TickerProvider vsync, {required double lastDelay})
    : _controller = AnimationController(
        vsync: vsync,
        upperBound: lastDelay + appearSeconds,
        duration: Duration(milliseconds: ((lastDelay + appearSeconds) * 1000).round()),
      );

  final AnimationController _controller;

  Animation<double> get seconds => _controller;

  /// Plays the entrance from the start; shows the end state at once when the phone asks for
  /// reduced motion (as the web app's `prefers-reduced-motion` rule does).
  void play(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = _controller.upperBound;
    } else {
      _controller.forward(from: 0);
    }
  }

  void dispose() => _controller.dispose();
}

enum _Kind { mask, soft, scale }

/// An element that animates in when its screen appears, as the web app's `.appear` classes:
/// [Appear.mask] rises from under a clip ([MaskLine]), [Appear.soft] fades in while moving up
/// 12 px, [Appear.scale] fades in growing from 86 %. Each runs 1.05 s on the expo ease after
/// [delay] seconds and shows its start state until then.
class Appear extends StatelessWidget {
  const Appear.mask({super.key, this.delay = 0, required this.child}) : _kind = _Kind.mask;
  const Appear.soft({super.key, this.delay = 0, required this.child}) : _kind = _Kind.soft;
  const Appear.scale({super.key, this.delay = 0, required this.child}) : _kind = _Kind.scale;

  final double delay;
  final Widget child;
  final _Kind _kind;

  @override
  Widget build(BuildContext context) {
    final clock = Entrance._of(context);
    if (clock == null) return child;
    return AnimatedBuilder(
      animation: clock,
      child: child,
      // The same widgets wrap the child on every frame, so its state survives the animation.
      builder: (context, child) {
        final t = V.easeExpo.transform(((clock.value - delay) / appearSeconds).clamp(0.0, 1.0));
        return switch (_kind) {
          _Kind.mask => FractionalTranslation(translation: Offset(0, 1.05 * (1 - t)), child: child),
          _Kind.soft => Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
          ),
          _Kind.scale => Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.86 + 0.14 * t, child: child),
          ),
        };
      },
    );
  }
}

/// A line of text that rises into place from under a clip (`.mask-line` with an
/// `.appear.mask` span). The clip reaches 0.08 em above and 0.06 em below the line, and
/// 0.04 em to the sides, so Vietnamese stacked marks are not cut off.
class MaskLine extends StatelessWidget {
  const MaskLine({super.key, required this.fontSize, this.delay = 0, required this.child});

  final double fontSize;
  final double delay;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    clipper: _MaskClip(fontSize),
    child: Appear.mask(delay: delay, child: child),
  );
}

class _MaskClip extends CustomClipper<Rect> {
  const _MaskClip(this.em);

  final double em;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-0.04 * em, -0.08 * em, size.width + 0.04 * em, size.height + 0.06 * em);

  @override
  bool shouldReclip(_MaskClip old) => old.em != em;
}
