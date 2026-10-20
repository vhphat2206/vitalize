import 'package:flutter/widgets.dart';

import '../../app/theme.dart';

/// The web app's entrance vocabulary (src/styles/motion.css), for the routines screens.
///
/// Each kind animates only from its start state to the widget as laid out, with the expo ease,
/// after [Appear.delay] (`--d`) over [Appear.duration] (`--dur`, 1.05 s by default). Before the
/// delay the child sits in the start state, like `animation-fill-mode: both`.
enum AppearKind {
  /// Rises from below its own height (`translate: 0 105%`); put it inside a [MaskLine].
  mask,

  /// Fades in from 12 px lower.
  soft,

  /// Fades in.
  fade,
}

class Appear extends StatefulWidget {
  const Appear.mask({
    super.key,
    this.delay = 0,
    this.duration = 1.05,
    this.active = true,
    required this.child,
  }) : kind = AppearKind.mask;

  const Appear.soft({
    super.key,
    this.delay = 0,
    this.duration = 1.05,
    this.active = true,
    required this.child,
  }) : kind = AppearKind.soft;

  const Appear.fade({
    super.key,
    this.delay = 0,
    this.duration = 1.05,
    this.active = true,
    required this.child,
  }) : kind = AppearKind.fade;

  final AppearKind kind;

  /// Seconds before it starts.
  final double delay;

  /// Seconds it runs.
  final double duration;

  /// Held in the start state while false, played from the start each time it turns true (a tab
  /// that is shown again replays its entrance, as `display: none` does on the web).
  final bool active;

  final Widget child;

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  late CurvedAnimation _t;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _configure();
  }

  void _configure() {
    final total = widget.delay + widget.duration;
    _controller.duration = Duration(microseconds: (total * 1e6).round());
    _t = CurvedAnimation(
      parent: _controller,
      curve: Interval(total == 0 ? 0 : widget.delay / total, 1, curve: V.easeExpo),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _play();
    }
  }

  @override
  void didUpdateWidget(Appear old) {
    super.didUpdateWidget(old);
    if (old.delay != widget.delay || old.duration != widget.duration) {
      _t.dispose();
      _configure();
    }
    if (old.active != widget.active) _play();
  }

  void _play() {
    if (!widget.active) {
      _controller.value = 0;
    } else if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      // prefers-reduced-motion: no entrance at all.
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _t.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (widget.kind) {
    AppearKind.mask => SlideTransition(
      position: _t.drive(Tween(begin: const Offset(0, 1.05), end: Offset.zero)),
      child: widget.child,
    ),
    AppearKind.soft => FadeTransition(
      opacity: _t,
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, 12 * (1 - _t.value)), child: child),
        child: widget.child,
      ),
    ),
    AppearKind.fade => FadeTransition(opacity: _t, child: widget.child),
  };
}

/// Clips a rising line (`.mask-line`): the box of [child], grown by the room the web app leaves
/// for Vietnamese stacked marks (0.08em above, 0.04em at the sides, 0.06em below) without
/// changing the layout.
class MaskLine extends StatelessWidget {
  const MaskLine({super.key, required this.fontSize, this.heading = false, required this.child});

  /// The `em` the room is measured in: the font size of the masking element.
  final double fontSize;

  /// The line is a heading (an `h1` on the web), for screen readers.
  final bool heading;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    header: heading ? true : null,
    child: ClipRect(clipper: _MaskClipper(fontSize), child: child),
  );
}

class _MaskClipper extends CustomClipper<Rect> {
  const _MaskClipper(this.em);

  final double em;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-0.04 * em, -0.08 * em, size.width + 0.04 * em, size.height + 0.06 * em);

  @override
  bool shouldReclip(_MaskClipper old) => old.em != em;
}

/// A transition's length, or none when the system asks for reduced motion, like the web app's
/// `prefers-reduced-motion` rule.
Duration motion(BuildContext context, int milliseconds) =>
    (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);
