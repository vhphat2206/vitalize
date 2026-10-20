import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/theme.dart';
import '../data/models.dart';
import 'icons.dart';

/// The guides a movement was drawn from, each opening in the browser.
class RefList extends StatelessWidget {
  const RefList({super.key, required this.refs});

  final List<Reference> refs;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final r in refs)
        Semantics(
          link: true,
          label: '${r.title}, ${r.source}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: V.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.title, style: VT.ui(15, weight: FontWeight.w500, height: 1.4)),
                        const SizedBox(height: 2),
                        Text(r.source, style: VT.ui(13, color: V.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const VIcon(VIcons.external, size: 18, color: V.muted),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}
