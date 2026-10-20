import 'package:flutter/cupertino.dart';

import '../app/theme.dart';
import 'controls.dart';
import 'floor.dart';
import 'icons.dart';

/// A pushed screen: slides in from the right over the tabs, with the iOS edge swipe to go back.
/// The screen underneath shifts a little to the left, as on the web app.
Route<T> vRoute<T>(Widget screen) => CupertinoPageRoute<T>(builder: (_) => Floor(child: screen));

/// Top bar of a pushed screen: a back button, and a title that appears once the content
/// scrolls under it ([solid]).
class BackBar extends StatelessWidget {
  const BackBar({super.key, this.title, this.solid = false, this.trailing});

  final String? title;
  final bool solid;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: V.easeSwift,
      padding: EdgeInsets.fromLTRB(8, top + 6, 8, 6),
      decoration: BoxDecoration(
        color: solid ? V.bg : const Color(0x00000000),
        border: Border(bottom: BorderSide(color: solid ? V.line : const Color(0x00000000))),
      ),
      child: Row(
        children: [
          IconBtn(
            VIcons.back,
            label: 'Quay lại',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 4),
          if (title != null)
            Expanded(
              child: AnimatedOpacity(
                opacity: solid ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: Text(
                  title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VT.ui(15, weight: FontWeight.w600, height: 1.2),
                ),
              ),
            )
          else
            const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Tracks whether a scroll view has moved past [threshold], for [BackBar.solid].
class ScrolledPast extends StatefulWidget {
  const ScrolledPast({super.key, required this.builder, this.threshold = 8});

  final Widget Function(BuildContext context, bool scrolled, ScrollController controller) builder;
  final double threshold;

  @override
  State<ScrolledPast> createState() => _ScrolledPastState();
}

class _ScrolledPastState extends State<ScrolledPast> {
  final _controller = ScrollController();
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final s = _controller.offset > widget.threshold;
      if (s != _scrolled) setState(() => _scrolled = s);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _scrolled, _controller);
}
