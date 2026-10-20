import 'package:flutter/material.dart';

import '../app/theme.dart';

/// A short task sheet over a dimmed screen, with a grabber and a title. Tap outside or swipe
/// down to dismiss. Returns what the sheet pops with.
Future<T?> showModalSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  backgroundColor: V.bg2,
  barrierColor: const Color(0x99080809),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(V.rSheet)),
    side: BorderSide(color: V.lineStrong, width: 0.5),
  ),
  builder: (context) => Padding(
    padding: EdgeInsets.only(
      left: V.pad,
      right: V.pad,
      top: 8,
      bottom: MediaQuery.paddingOf(context).bottom + 20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetGrabber(),
        const SizedBox(height: 14),
        Text(title, style: VT.display(22)),
        const SizedBox(height: 18),
        Builder(builder: builder),
      ],
    ),
  ),
);

/// The little handle at the top of a sheet.
class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(color: V.lineStrong, borderRadius: BorderRadius.circular(2)),
    ),
  );
}
