import 'package:flutter/widgets.dart';

import '../app/theme.dart';

/// A tap target that tells its child when it is held down (for the `:active` tint the web app
/// uses everywhere), optionally shrinking a touch.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.builder, this.onTap, this.scale = 1});

  final Widget Function(bool pressed) builder;
  final VoidCallback? onTap;

  /// Scale while held, e.g. 0.98 for the primary button.
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool v) {
    if (widget.onTap == null || v == _pressed) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => _set(true),
    onTapUp: (_) => _set(false),
    onTapCancel: () => _set(false),
    onTap: widget.onTap,
    child: AnimatedScale(
      scale: _pressed ? widget.scale : 1,
      duration: const Duration(milliseconds: 200),
      curve: V.easeSwift,
      child: widget.builder(_pressed),
    ),
  );
}
