import 'dart:async';

import 'package:flutter/widgets.dart';

import '../app/haptics.dart';
import '../app/theme.dart';
import '../logic/format.dart';
import 'controls.dart';

/// Rest between sets, counting down to [until]: a tick in the last 3 seconds, a bump at zero.
/// [onChanged] gets a later end ("+15 giây") or null when the rest is over or skipped.
class RestTimer extends StatefulWidget {
  const RestTimer({super.key, required this.until, required this.onChanged});

  final DateTime until;
  final ValueChanged<DateTime?> onChanged;

  @override
  State<RestTimer> createState() => _RestTimerState();
}

class _RestTimerState extends State<RestTimer> {
  late final Timer _timer;
  late int _left = _remaining();

  int _remaining() => (widget.until.difference(DateTime.now()).inMilliseconds / 1000).ceil();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  @override
  void didUpdateWidget(RestTimer old) {
    super.didUpdateWidget(old);
    if (old.until != widget.until) _left = _remaining();
  }

  void _tick() {
    final left = _remaining();
    if (left <= 0) {
      _timer.cancel();
      Haptics.bump();
      widget.onChanged(null);
      return;
    }
    if (left == _left) return;
    if (left <= 3) Haptics.tick();
    setState(() => _left = left);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Nghỉ, còn ${clock(_left)}',
    child: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text('Nghỉ', style: VT.ui(13, color: V.muted)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(clock(_left), style: VT.mono(20, weight: FontWeight.w500, height: 1)),
          ),
          GhostButton(
            label: '+15 giây',
            onPressed: () => widget.onChanged(widget.until.add(const Duration(seconds: 15))),
          ),
          const SizedBox(width: 8),
          GhostButton(label: 'Bỏ qua', onPressed: () => widget.onChanged(null)),
        ],
      ),
    ),
  );
}
