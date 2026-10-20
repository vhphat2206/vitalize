import 'package:flutter/widgets.dart';

import '../../app/theme.dart';
import '../../logic/meals.dart';
import '../../state/log_store.dart';
import '../../widgets/back_bar.dart';
import '../../widgets/controls.dart';
import 'entrance.dart';

/// Title of a meal screen (`.meal-title`).
final mealTitleStyle = VT.display(28, height: 1.2);

/// A pushed meal screen: a scrolling body under the back bar (which turns solid once the content
/// scrolls under it), and an optional footer pinned to the bottom.
class MealScaffold extends StatelessWidget {
  const MealScaffold({super.key, required this.children, this.title, this.footer});

  final List<Widget> children;
  final String? title;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return CssLeading(
      child: ScrolledPast(
        threshold: 40,
        builder: (context, scrolled, controller) => Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      controller: controller,
                      padding: EdgeInsets.fromLTRB(V.pad, pad.top + 60, V.pad, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: BackBar(title: title, solid: scrolled),
                  ),
                ],
              ),
            ),
            if (footer != null)
              Container(
                padding: EdgeInsets.fromLTRB(V.pad, 12, V.pad, pad.bottom + 12),
                decoration: const BoxDecoration(
                  color: V.bg,
                  // a hairline above, outside the box (`box-shadow: 0 -1px 0 var(--line)`)
                  boxShadow: [BoxShadow(color: V.line, offset: Offset(0, -1))],
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

/// A pushed meal screen with nothing to show but a sentence (`.meal-message`).
class MealMessage extends StatelessWidget {
  const MealMessage(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => CssLeading(
    child: Stack(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(V.pad, MediaQuery.paddingOf(context).top + 70, V.pad, 0),
          child: Text(text, style: VT.ui(15.5)),
        ),
        const Positioned(top: 0, left: 0, right: 0, child: BackBar()),
      ],
    ),
  );
}

/// The meal slot to save in: a quiet label over the four slots.
class SlotPicker extends StatelessWidget {
  const SlotPicker({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final MealSlot value;
  final ValueChanged<MealSlot> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Bữa ăn',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: VT.ui(13, weight: FontWeight.w600, height: 1, color: V.muted),
        ),
        const SizedBox(height: 8),
        Segmented<MealSlot>(options: slotOptions, value: value, onChanged: onChanged),
      ],
    ),
  );
}
