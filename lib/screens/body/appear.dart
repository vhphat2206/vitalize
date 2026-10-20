import 'package:flutter/widgets.dart';

import '../../app/theme.dart';

/// The web app's entrance vocabulary (styles/motion.css). Each `.appear` element animates from a
/// start state to its own resting state after a delay, on the expo ease, and holds the start
/// state until its delay has passed.
enum AppearKind {
  /// Rises into view from below, under a [MaskLine] (`in-mask`).
  mask,

  /// Fades in while rising 12 px (`in-soft`).
  soft,

  /// Fades in while growing from 86 % (`in-scale`).
  scale,

  /// Fades in (`in-fade`).
  fade,
}

/// Plays one entrance on [child]: [delay] and [duration] in seconds, like `--d` and `--dur`.
/// Changing [replay] plays it again from the start (a tab being shown again does this on the
/// web, where hidden tabs restart their animations).
class Appear extends StatefulWidget {
  const Appear(
    this.kind, {
    super.key,
    required this.child,
    this.delay = 0,
    this.duration = 1.05,
    this.replay,
  });

  final AppearKind kind;
  final Widget child;
  final double delay;
  final double duration;
  final Object? replay;

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.duration;
    _c = AnimationController(
      vsync: this,
      duration: Duration(microseconds: (total * 1e6).round()),
    );
    _t = CurvedAnimation(
      parent: _c,
      curve: Interval(total == 0 ? 0 : widget.delay / total, 1, curve: V.easeExpo),
    );
    _c.forward();
  }

  @override
  void didUpdateWidget(Appear old) {
    super.didUpdateWidget(old);
    if (old.replay != widget.replay) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // prefers-reduced-motion: the web cuts every animation to nothing.
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      // The same widgets at every step (identity values at rest), so the child keeps its state.
      builder: (context, child) {
        final t = still ? 1.0 : _t.value;
        return switch (widget.kind) {
          AppearKind.mask => FractionalTranslation(
            translation: Offset(0, 1.05 * (1 - t)),
            child: child,
          ),
          AppearKind.soft => Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
          ),
          AppearKind.scale => Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.86 + 0.14 * t, child: child),
          ),
          AppearKind.fade => Opacity(opacity: t, child: child),
        };
      },
    );
  }
}

/// Clips a line of text so it can rise into view ([AppearKind.mask]), with room around the
/// line for Vietnamese stacked marks: 0.08em above, 0.06em below, 0.04em either side
/// (`.mask-line` on the web). [fontSize] is the em.
class MaskLine extends StatelessWidget {
  const MaskLine({super.key, required this.fontSize, required this.child});

  final double fontSize;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(clipper: _MaskClip(fontSize), child: child);
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
