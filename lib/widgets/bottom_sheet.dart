import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../app/theme.dart';
import 'modal_sheet.dart' show SheetGrabber;

/// Resting states of a [VBottomSheet].
enum SheetSnap { closed, half, full }

/// A draggable sheet with three resting states (BottomSheet.tsx on the web). Dragging only
/// starts from the header, so the list inside keeps normal scrolling; a tap on the header
/// toggles half and full, a flick down closes it. The list gets bottom padding equal to the
/// part of the sheet hidden below the screen, so its last row is always reachable.
///
/// Put it in a [Stack], sized to the area it covers when full: on the body map that is from
/// 10 px under the safe area down to the tab bar.
class VBottomSheet extends StatefulWidget {
  const VBottomSheet({
    super.key,
    required this.snap,
    required this.onSnap,
    required this.header,
    required this.children,
    required this.label,
    this.halfRatio = 0.56,
    this.controller,
  });

  final SheetSnap snap;
  final ValueChanged<SheetSnap> onSnap;

  /// Drag region under the grabber. It lays out its own side padding, so it can run to the
  /// edges.
  final Widget header;

  /// The scrolling list.
  final List<Widget> children;

  /// What the sheet is, for screen readers.
  final String label;

  /// Height of the half state as a fraction of the sheet's full height.
  final double halfRatio;

  /// Scroll controller of the list.
  final ScrollController? controller;

  @override
  State<VBottomSheet> createState() => _VBottomSheetState();
}

class _VBottomSheetState extends State<VBottomSheet> with SingleTickerProviderStateMixin {
  /// A release faster than this (px per ms) is a flick.
  static const _flick = 0.55;

  // The sheet moves from [_from] to the rest offset of [_target] along [_move].
  late final AnimationController _move = AnimationController(vsync: this, value: 1);
  Curve _curve = V.easeExpo;
  double _from = 0;
  late SheetSnap _target = widget.snap;

  /// Height of the sheet when fully open; known after layout.
  double _fullH = 0;

  /// Offset while a finger holds the header.
  double? _drag;

  // The finger on the header, from its own events, like the pointer bookkeeping on the web.
  int? _pointer;
  Duration _downAt = Duration.zero;
  Duration _lastAt = Duration.zero;
  double _downY = 0;
  double _lastY = 0;
  double _startOffset = 0;

  double get _halfOffset => (_fullH * (1 - widget.halfRatio)).roundToDouble();

  double _restOf(SheetSnap s) => switch (s) {
    SheetSnap.full => 0,
    SheetSnap.half => _halfOffset,
    SheetSnap.closed => _fullH + 24,
  };

  /// How far the sheet sits below its fully open position right now.
  double get _offset {
    final rest = _restOf(_target);
    return _drag ?? _from + (rest - _from) * _curve.transform(_move.value);
  }

  @override
  void didUpdateWidget(VBottomSheet old) {
    super.didUpdateWidget(old);
    if (widget.snap != _target) _go(widget.snap);
  }

  @override
  void dispose() {
    _move.dispose();
    super.dispose();
  }

  /// Slides to [to]: 0.45 s on the expo ease, or 0.32 s easing in when it closes.
  void _go(SheetSnap to) {
    _from = _offset;
    _target = to;
    final closing = to == SheetSnap.closed;
    _curve = closing ? V.easeIn : V.easeExpo;
    _move.duration = Duration(milliseconds: closing ? 320 : 450);
    _move.forward(from: 0);
  }

  void _onPointer(PointerEvent e) {
    if (e is PointerDownEvent) {
      if (_pointer != null) return;
      _pointer = e.pointer;
      _downAt = e.timeStamp;
      _downY = e.position.dy;
    } else if (e.pointer != _pointer) {
      return;
    }
    _lastAt = e.timeStamp;
    _lastY = e.position.dy;
    if (e is PointerUpEvent || e is PointerCancelEvent) _pointer = null;
  }

  void _onStart(DragStartDetails d) {
    if (_target == SheetSnap.closed) return;
    _startOffset = _offset;
    _move.stop();
    setState(() => _drag = _startOffset);
  }

  void _onUpdate(DragUpdateDetails d) {
    if (_drag == null) return;
    setState(() => _drag = (_startOffset + d.globalPosition.dy - _downY).clamp(0, _fullH));
  }

  void _onRelease() {
    final drag = _drag;
    if (drag == null) return;
    // average speed since the finger went down, px per ms
    final dt = math.max(1, (_lastAt - _downAt).inMicroseconds / 1000);
    final velocity = (_lastY - _downY) / dt;
    final moved = (_lastY - _downY).abs();
    final snap = widget.snap;
    final SheetSnap next;
    if (moved < 6) {
      // barely moved: a tap on the header
      next = snap == SheetSnap.full ? SheetSnap.half : SheetSnap.full;
    } else if (velocity > _flick) {
      next = snap == SheetSnap.full && drag < _halfOffset ? SheetSnap.half : SheetSnap.closed;
    } else if (velocity < -_flick) {
      next = SheetSnap.full;
    } else {
      next = [
        SheetSnap.full,
        SheetSnap.half,
        SheetSnap.closed,
      ].reduce((a, b) => (_restOf(a) - drag).abs() <= (_restOf(b) - drag).abs() ? a : b);
    }
    _go(next);
    setState(() => _drag = null);
    widget.onSnap(next);
  }

  void _onTap() {
    if (widget.snap == SheetSnap.closed) return;
    widget.onSnap(widget.snap == SheetSnap.full ? SheetSnap.half : SheetSnap.full);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      _fullH = box.maxHeight;
      final hidden = _drag ?? _restOf(_target);
      final sheet = DecoratedBox(
        decoration: const BoxDecoration(
          color: V.bg2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(V.rSheet)),
          boxShadow: [BoxShadow(color: V.lineStrong, offset: Offset(0, -1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Listener(
              onPointerDown: _onPointer,
              onPointerMove: _onPointer,
              onPointerUp: _onPointer,
              onPointerCancel: _onPointer,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                dragStartBehavior: DragStartBehavior.down,
                onTap: _onTap,
                onVerticalDragStart: _onStart,
                onVerticalDragUpdate: _onUpdate,
                onVerticalDragEnd: (_) => _onRelease(),
                onVerticalDragCancel: _onRelease,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [const SheetGrabber(), const SizedBox(height: 10), widget.header],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: widget.controller,
                padding: EdgeInsets.only(bottom: hidden + 24),
                children: widget.children,
              ),
            ),
          ],
        ),
      );
      return AnimatedBuilder(
        animation: _move,
        child: Semantics(container: true, label: widget.label, child: sheet),
        builder: (context, child) {
          final closed = _target == SheetSnap.closed;
          return Offstage(
            // hidden once it has slid away, like `visibility: hidden` on the web
            offstage: closed && _drag == null && !_move.isAnimating,
            child: IgnorePointer(
              ignoring: closed,
              child: Transform.translate(offset: Offset(0, _offset), child: child),
            ),
          );
        },
      );
    },
  );
}
