import 'package:flutter/widgets.dart';

import '../../app/theme.dart';

/// The web app's entrance vocabulary (src/styles/motion.css) for the Ăn uống and Tuần này tabs
/// and the meal screens: `.appear.mask` rises out of a clip, `.appear.soft` fades up 12 px. Each
/// waits [delay] (`--d`) in its start state, then runs [duration] (`--dur`, 1.05 s) on the expo
/// ease. It plays when first built with a [replay] above zero and again whenever [replay]
/// changes.
class Appear extends StatefulWidget {
  const Appear.soft({
    super.key,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 1050),
    this.replay = 1,
    required this.child,
  }) : mask = false;

  /// Put it inside a [MaskLine].
  const Appear.mask({
    super.key,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 1050),
    this.replay = 1,
    required this.child,
  }) : mask = true;

  final bool mask;
  final Duration delay;
  final Duration duration;
  final int replay;
  final Widget child;

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: _total);
  late var _t = _curve();

  Duration get _total => widget.delay + widget.duration;

  CurvedAnimation _curve() => CurvedAnimation(
    parent: _controller,
    curve: Interval(widget.delay.inMicroseconds / _total.inMicroseconds, 1, curve: V.easeExpo),
  );

  @override
  void initState() {
    super.initState();
    if (widget.replay > 0) _play(first: true);
  }

  @override
  void didUpdateWidget(Appear old) {
    super.didUpdateWidget(old);
    if (old.delay != widget.delay || old.duration != widget.duration) {
      _controller.duration = _total;
      _t.dispose();
      _t = _curve();
    }
    if (old.replay != widget.replay && widget.replay > 0) _play();
  }

  void _play({bool first = false}) {
    // prefers-reduced-motion: show the end state at once.
    final still = first
        ? WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations
        : MediaQuery.disableAnimationsOf(context);
    if (still) {
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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    child: widget.child,
    builder: (context, child) {
      final t = _t.value;
      if (widget.mask) {
        return FractionalTranslation(translation: Offset(0, 1.05 * (1 - t)), child: child);
      }
      return Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
      );
    },
  );
}

/// The clip a masked line rises through (`.mask-line`): the child's box grown by the room the web
/// app leaves for Vietnamese stacked marks (0.08em above, 0.04em at the sides, 0.06em below),
/// without changing the layout.
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

/// Counts the times a tab screen has come into view. Tabs stay mounted in the shell (hidden while
/// another tab is shown), and the web app replays a tab's entrance each time its panel is shown
/// again, so [entrance] goes up each time the tab becomes visible; pass it to [Appear.replay].
mixin TabEntrance<T extends StatefulWidget> on State<T> {
  int entrance = 0;
  bool _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shown = Visibility.of(context);
    if (shown && !_shown) entrance++;
    _shown = shown;
  }
}

/// Heading of a tab (`.tab-head`): the title rising out of its mask, a line under it fading up,
/// ruled off from the content below. Handles the top safe area.
class TabHead extends StatelessWidget {
  const TabHead({super.key, required this.title, required this.subtitle, required this.replay});

  final String title;
  final Widget subtitle;
  final int replay;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(V.pad, MediaQuery.paddingOf(context).top + 22, V.pad, 22),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: V.lineStrong)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: MaskLine(
            fontSize: 34,
            child: Appear.mask(
              replay: replay,
              child: Text(title, style: VT.display(34, height: 1.15, em: -0.025)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Appear.soft(delay: const Duration(milliseconds: 120), replay: replay, child: subtitle),
      ],
    ),
  );
}

/// Lines share their extra height (or overlap, below a line height of about 1.3) evenly above and
/// below the glyphs, as CSS does; Flutter's default gives the part above the baseline more. Put
/// around a screen so its text sits where it does in the web app.
class CssLeading extends StatelessWidget {
  const CssLeading({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DefaultTextHeightBehavior(
    textHeightBehavior: const TextHeightBehavior(leadingDistribution: TextLeadingDistribution.even),
    child: child,
  );
}
