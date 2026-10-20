import 'dart:async';

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// One message at a time near the bottom of the screen, gone after four seconds, with an
/// optional action ("Hoàn tác").
abstract final class Toast {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String text, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    hide();
    final overlay = Overlay.of(context, rootOverlay: true);
    final bottom = MediaQuery.paddingOf(context).bottom + V.tabBarH + 12;
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 12,
        right: 12,
        bottom: bottom,
        child: Center(
          child: _ToastCard(
            text: text,
            actionLabel: actionLabel,
            onAction: onAction == null
                ? null
                : () {
                    onAction();
                    hide();
                  },
          ),
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(const Duration(seconds: 4), hide);
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 450),
    curve: V.easeExpo,
    builder: (context, t, child) => Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
    ),
    child: Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: EdgeInsets.only(left: 16, right: actionLabel == null ? 16 : 8),
      decoration: BoxDecoration(color: V.ink, borderRadius: BorderRadius.circular(V.rControl)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              text,
              style: VT.ui(14, weight: FontWeight.w500, height: 1.3, color: V.bg),
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 16),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAction,
              child: SizedBox(
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Center(
                    child: Text(
                      actionLabel!,
                      style: VT.ui(14, weight: FontWeight.w700, height: 1, color: V.accentDeep),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
