import 'package:flutter/widgets.dart';

import '../app/theme.dart';
import 'icons.dart';
import 'pressable.dart';

/// Section heading inside long screens: sentence case, quiet, ruled underneath.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(bottom: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: V.line)),
    ),
    child: Row(
      children: [
        Expanded(child: Text(text, style: VT.sectionTitle)),
        ?trailing,
      ],
    ),
  );
}

/// Primary action: flat brand green with dark ink. No glow, no gradient.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final VGlyph? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Pressable(
        onTap: onPressed,
        scale: 0.98,
        builder: (pressed) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: V.easeSwift,
          height: 54,
          decoration: BoxDecoration(
            color: pressed ? V.accentPressed : V.accent,
            borderRadius: BorderRadius.circular(V.rControl),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                VIcon(icon!, size: 22, color: V.accentInk),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: VT.ui(16, weight: FontWeight.w600, height: 1, color: V.accentInk, em: -0.01),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quiet bordered button; [danger] for destructive actions.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.danger = false,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool danger;
  final VGlyph? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final color = danger ? V.danger : V.ink;
    return Pressable(
      onTap: onPressed,
      builder: (pressed) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: V.easeSwift,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: pressed ? V.bg3 : const Color(0x00000000),
          borderRadius: BorderRadius.circular(V.rControl),
          border: Border.all(color: danger ? const Color(0x66EF7A6A) : V.lineStrong),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[VIcon(icon!, size: 20, color: color), const SizedBox(width: 8)],
            Text(
              label,
              style: VT.ui(14, weight: FontWeight.w500, height: 1, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// 44×44 icon button.
class IconBtn extends StatelessWidget {
  const IconBtn(this.glyph, {super.key, required this.onPressed, this.label, this.color});

  final VGlyph glyph;
  final VoidCallback onPressed;
  final String? label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Pressable(
      onTap: onPressed,
      builder: (pressed) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: pressed ? V.bg3 : const Color(0x00000000),
          borderRadius: BorderRadius.circular(V.rControl),
        ),
        alignment: Alignment.center,
        child: VIcon(glyph, color: color ?? V.ink),
      ),
    ),
  );
}

/// A row with a label (and hint) on the left; ruled with a hairline inset to the text column.
class _Row extends StatelessWidget {
  const _Row({required this.onTap, required this.children});

  final VoidCallback onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    builder: (pressed) => AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      constraints: const BoxConstraints(minHeight: 58),
      color: pressed ? V.bg3 : const Color(0x00000000),
      child: Stack(
        // Centred in the 58 px minimum, as the web row's `align-items: center`.
        alignment: AlignmentDirectional.centerStart,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: V.pad, vertical: 10),
            child: Row(children: children),
          ),
          const Positioned(
            left: V.pad,
            right: V.pad,
            bottom: 0,
            child: SizedBox(height: 1, child: ColoredBox(color: V.line)),
          ),
        ],
      ),
    ),
  );
}

Widget _rowText(String label, String? hint, {Color color = V.ink}) => Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: VT.ui(15.5, weight: FontWeight.w500, height: 1.35, color: color),
      ),
      if (hint != null) ...[const SizedBox(height: 2), Text(hint, style: VT.hint)],
    ],
  ),
);

/// On/off switch. The whole row is the hit target, not just the track.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.label,
    this.hint,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    label: label,
    child: _Row(
      onTap: () => onChanged(!value),
      children: [
        _rowText(label, hint),
        const SizedBox(width: 12),
        VSwitch(value: value),
      ],
    ),
  );
}

/// The switch track and knob drawn by [ToggleRow].
class VSwitch extends StatelessWidget {
  const VSwitch({super.key, required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    curve: V.easeSwift,
    width: 48,
    height: 28,
    decoration: BoxDecoration(
      color: value ? V.accent : V.bg3,
      borderRadius: BorderRadius.circular(999),
      border: value ? null : Border.all(color: V.lineStrong),
    ),
    child: AnimatedAlign(
      duration: const Duration(milliseconds: 300),
      curve: V.easeExpo,
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.all(3),
        width: 22,
        height: 22,
        decoration: BoxDecoration(color: value ? V.accentInk : V.muted, shape: BoxShape.circle),
      ),
    ),
  );
}

/// Tappable row: label on the left, current value on the right, a chevron.
class ValueRow extends StatelessWidget {
  const ValueRow({
    super.key,
    required this.label,
    this.value,
    this.hint,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final Widget? value;
  final String? hint;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => _Row(
    onTap: onTap,
    children: [
      _rowText(label, hint, color: danger ? V.danger : V.ink),
      if (value != null) ...[
        const SizedBox(width: 12),
        DefaultTextStyle(
          style: VT.ui(14.5, color: V.muted),
          child: value!,
        ),
      ],
      const SizedBox(width: 8),
      Transform.translate(
        offset: const Offset(4, 0),
        child: const VIcon(VIcons.chevronRight, size: 18, color: V.faint),
      ),
    ],
  );
}

/// A small set of mutually exclusive options.
class Segmented<K> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged});

  final List<(K, String)> options;
  final K? value;
  final ValueChanged<K> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: V.bg3, borderRadius: BorderRadius.circular(V.rControl)),
    child: Row(
      children: [
        for (final (k, label) in options)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(k),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: V.easeSwift,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == k ? V.ink : const Color(0x00000000),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  label,
                  style: VT.ui(
                    14,
                    weight: FontWeight.w500,
                    height: 1,
                    color: value == k ? V.bg : V.muted,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// A list of options with a sentence under each, for choices that need explaining.
class ChoiceList<K> extends StatelessWidget {
  const ChoiceList({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(K, String, String)> options;
  final K value;
  final ValueChanged<K> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: V.line)),
    ),
    child: Column(
      children: [
        for (final (k, label, hint) in options)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(k),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: V.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: value == k ? V.accent : V.lineStrong,
                          width: value == k ? 6 : 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  _rowText(label, hint),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

/// Ruled group with a quiet heading, used to section long screens.
class Group extends StatelessWidget {
  const Group({super.key, required this.title, required this.children, this.note});

  final String title;
  final List<Widget> children;
  final String? note;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: V.pad),
        child: SectionTitle(title),
      ),
      ...children,
      if (note != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(V.pad, 10, V.pad, 0),
          child: Text(note!, style: VT.ui(13, color: V.muted)),
        ),
    ],
  );
}
