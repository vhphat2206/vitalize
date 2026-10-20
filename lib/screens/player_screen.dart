import 'package:flutter/widgets.dart';

import '../app/theme.dart';

/// Placeholder until the screen is ported from the web app.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => Center(child: Text('Đang tập', style: VT.display(28)));
}
