import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../app/haptics.dart';
import '../app/theme.dart';
import '../app/toast.dart';
import '../logic/format.dart';
import '../logic/meal_analyzer.dart';
import '../logic/meal_photo.dart';
import '../logic/meals.dart';
import '../state/log_store.dart';
import '../widgets/controls.dart';
import '../widgets/meal_editor.dart';
import '../widgets/pressable.dart';
import 'food/entrance.dart';
import 'food/meal_parts.dart';

const _confidence = {
  MealConfidence.high: 'khá chắc',
  MealConfidence.medium: 'vừa phải',
  MealConfidence.low: 'chưa chắc',
};

enum _Phase { analyzing, done, error }

/// A meal photo being analysed, then what's in it: adjust the portions, pick the slot, save.
class MealScanScreen extends StatefulWidget {
  const MealScanScreen({super.key, required this.photo, this.now, this.analyze});

  /// The photo as a JPEG, from the camera or the library.
  final Uint8List? photo;

  /// Pins the time that picks the default slot, for tests.
  @visibleForTesting
  final DateTime? now;

  /// Stands in for the analysis service, for tests.
  @visibleForTesting
  final Future<MealAnalysis> Function(Uint8List photo)? analyze;

  @override
  State<MealScanScreen> createState() => _MealScanScreenState();
}

class _MealScanScreenState extends State<MealScanScreen> {
  var _phase = _Phase.analyzing;
  MealAnalysis? _result;
  String _error = '';
  List<MealItem> _items = const [];
  late MealSlot _slot = slotForTime(widget.now ?? DateTime.now());
  bool _saving = false;
  MealAnalysisCall? _call;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  @override
  void dispose() {
    _call?.cancel();
    super.dispose();
  }

  void _analyze() {
    final photo = widget.photo;
    if (photo == null) return;
    final attempt = ++_attempt;
    _call?.cancel();
    _call = null;
    final Future<MealAnalysis> work;
    if (widget.analyze case final analyze?) {
      work = analyze(photo);
    } else {
      final call = _call = MealAnalysisCall(photo);
      work = call.result;
    }
    work.then(
      (r) {
        if (!mounted || attempt != _attempt) return;
        setState(() {
          _items = [for (final f in r.items) MealItem(food: f)];
          _result = r;
          _phase = _Phase.done;
        });
      },
      onError: (Object e) {
        if (!mounted || attempt != _attempt) return;
        setState(() {
          _error = e is MealAnalysisError ? e.message : 'Không phân tích được ảnh, thử lại nhé.';
          _phase = _Phase.error;
        });
      },
    );
  }

  void _retry() {
    setState(() {
      _phase = _Phase.analyzing;
      _result = null;
    });
    _analyze();
  }

  Future<void> _save() async {
    final photo = widget.photo;
    final result = _result;
    if (photo == null || result == null || _phase != _Phase.done || _saving) return;
    setState(() => _saving = true);
    final log = context.read<LogStore>();
    final slot = _slot;
    String? thumb;
    try {
      thumb = await mealThumbnail(photo);
    } catch (_) {
      // Saved without a photo rather than not at all.
    }
    final meal = log.addMeal(slot: slot, items: _items, photo: thumb, source: result.source);
    Haptics.success();
    if (!mounted) return;
    Toast.show(
      context,
      'Đã lưu ${mealSlotLabel[slot]!.toLowerCase()}, ${formatNumber(mealTotals(meal).kcal)} kcal',
      actionLabel: 'Hoàn tác',
      onAction: () => log.removeMeal(meal.id),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    if (photo == null) return const MealMessage('Không tìm thấy ảnh. Quay lại và chụp lại nhé.');
    final result = _phase == _Phase.done ? _result : null;
    final food = result != null && result.isFood;

    return MealScaffold(
      footer: food
          ? PrimaryButton(
              label: 'Lưu vào ${mealSlotLabel[_slot]!.toLowerCase()}',
              onPressed: _saving ? null : _save,
            )
          : null,
      children: [
        _ScanPhoto(photo: photo, scanning: _phase == _Phase.analyzing),
        if (_phase == _Phase.analyzing)
          _Status(
            children: [
              Semantics(
                liveRegion: true,
                child: Text('Đang xem ảnh, thường mất vài giây.', style: VT.ui(15, color: V.muted)),
              ),
              const _ScanBar(),
            ],
          ),
        if (_phase == _Phase.error)
          _Status(
            children: [
              Text(_error, style: VT.ui(15.5, color: V.muted)),
              _StatusButton(label: 'Thử lại', onTap: _retry),
            ],
          ),
        if (result != null && !result.isFood)
          _Status(
            children: [
              Text(
                'Ảnh này không giống món ăn. Thử chụp gần hơn, đủ sáng và thấy rõ cả đĩa.',
                style: VT.ui(15.5, color: V.muted),
              ),
              _StatusButton(label: 'Chụp lại', onTap: () => Navigator.of(context).maybePop()),
            ],
          ),
        if (result != null && result.isFood)
          Appear.soft(
            duration: const Duration(milliseconds: 600),
            child: Padding(
              padding: const EdgeInsets.only(top: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (result.source == 'demo')
                    Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.only(left: 12),
                      decoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: V.ink, width: 2)),
                      ),
                      child: Text(
                        'Chế độ thử: đây là kết quả mẫu, chưa phải AI phân tích ảnh của bạn.',
                        style: VT.ui(14),
                      ),
                    ),
                  Semantics(header: true, child: Text('Trong ảnh có', style: mealTitleStyle)),
                  const SizedBox(height: 14),
                  MealEditor(items: _items, onChanged: (items) => setState(() => _items = items)),
                  const SizedBox(height: 16),
                  Text(
                    'Mức chắc chắn: ${_confidence[result.confidence]}. ${result.note}',
                    style: VT.ui(13.5, color: V.muted),
                  ),
                  const SizedBox(height: 22),
                  SlotPicker(
                    label: 'Lưu vào',
                    value: _slot,
                    onChanged: (slot) => setState(() => _slot = slot),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The photo, 4:3, framed by measuring brackets that close in and breathe while the AI looks.
class _ScanPhoto extends StatelessWidget {
  const _ScanPhoto({required this.photo, required this.scanning});

  final Uint8List photo;
  final bool scanning;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: V.bg3),
          Image.memory(
            photo,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            semanticLabel: 'Ảnh món ăn vừa chụp',
          ),
          _Brackets(scanning: scanning),
        ],
      ),
    ),
  );
}

class _Brackets extends StatefulWidget {
  const _Brackets({required this.scanning});

  final bool scanning;

  @override
  State<_Brackets> createState() => _BracketsState();
}

class _BracketsState extends State<_Brackets> with TickerProviderStateMixin {
  /// The corners drawing themselves in, 0.9 s.
  late final _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  /// Then breathing in to 96 % and back, every 1.6 s.
  late final _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  /// Shown while scanning, faded out (0.4 s) once done.
  late final _shown = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
    value: widget.scanning ? 1 : 0,
  );

  late final _frame = Listenable.merge([_draw, _breathe, _shown]);

  bool get _still =>
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  @override
  void initState() {
    super.initState();
    if (widget.scanning) _start();
  }

  void _start() {
    if (_still) {
      _draw.value = 1;
      return;
    }
    _draw.forward(from: 0).then((_) {
      if (mounted && widget.scanning) _breathe.repeat();
    });
  }

  @override
  void didUpdateWidget(_Brackets old) {
    super.didUpdateWidget(old);
    if (old.scanning == widget.scanning) return;
    if (widget.scanning) {
      _shown.animateTo(1, curve: V.easeSwift);
      _start();
    } else {
      _draw.stop();
      _breathe.stop();
      _shown.animateBack(0, curve: V.easeSwift);
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    _breathe.dispose();
    _shown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _frame,
      builder: (context, _) {
        final scanning = widget.scanning;
        var scale = 1.0;
        if (scanning && _breathe.isAnimating) {
          final u = _breathe.value;
          const ease = Cubic(0.42, 0, 0.58, 1);
          scale = u < 0.5
              ? 1 - 0.04 * ease.transform(u / 0.5)
              : 0.96 + 0.04 * ease.transform((u - 0.5) / 0.5);
        }
        return CustomPaint(
          painter: _BracketPainter(
            drawn: scanning ? V.easeDraw.transform(_draw.value) : 1,
            scale: scale,
            opacity: 0.9 * _shown.value,
            width: scanning ? 2 : 1.2,
          ),
        );
      },
    ),
  );
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter({
    required this.drawn,
    required this.scale,
    required this.opacity,
    required this.width,
  });

  /// How much of each corner is drawn, 0–1; each corner starts at its own end.
  final double drawn;
  final double scale;
  final double opacity;
  final double width;

  /// The corners in a 100 × 75 box, stretched to the photo: `M4 18V4h14M82 4h14v14M96 57v14H82M18
  /// 71H4V57`.
  static const _corners = [
    [Offset(4, 18), Offset(4, 4), Offset(18, 4)],
    [Offset(82, 4), Offset(96, 4), Offset(96, 18)],
    [Offset(96, 57), Offset(96, 71), Offset(82, 71)],
    [Offset(18, 71), Offset(4, 71), Offset(4, 57)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || drawn <= 0) return;
    final c = size.center(Offset.zero);
    // Points are scaled, not the canvas, so the stroke keeps its width (non-scaling stroke).
    Offset at(Offset p) {
      final q = Offset(p.dx * size.width / 100, p.dy * size.height / 75);
      return c + (q - c) * scale;
    }

    final paint = Paint()
      ..color = V.ink.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.miter;
    for (final corner in _corners) {
      final path = Path()
        ..moveTo(at(corner[0]).dx, at(corner[0]).dy)
        ..lineTo(at(corner[1]).dx, at(corner[1]).dy)
        ..lineTo(at(corner[2]).dx, at(corner[2]).dy);
      if (drawn >= 1) {
        canvas.drawPath(path, paint);
      } else {
        final m = path.computeMetrics().first;
        canvas.drawPath(m.extractPath(0, m.length * drawn), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BracketPainter old) =>
      old.drawn != drawn || old.scale != scale || old.opacity != opacity || old.width != width;
}

/// What's happening under the photo (`.scan-status`).
class _Status extends StatelessWidget {
  const _Status({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, c) in children.indexed) ...[if (i > 0) const SizedBox(height: 14), c],
      ],
    ),
  );
}

/// A 2 px rail with a green segment sliding across it, while the analysis runs.
class _ScanBar extends StatefulWidget {
  const _ScanBar();

  @override
  State<_ScanBar> createState() => _ScanBarState();
}

class _ScanBarState extends State<_ScanBar> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  static const _ease = Cubic(0.65, 0, 0.35, 1);

  @override
  void initState() {
    super.initState();
    if (!WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 2,
      child: ClipRect(
        child: ColoredBox(
          color: V.line,
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth * 0.4;
              return AnimatedBuilder(
                animation: _c,
                builder: (context, _) => Stack(
                  children: [
                    Positioned(
                      left: (-1 + 3.5 * _ease.transform(_c.value)) * w,
                      top: 0,
                      bottom: 0,
                      width: w,
                      child: const ColoredBox(color: V.accent),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// The ghost button under a status line; its label takes the status's muted colour.
class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Pressable(
      onTap: onTap,
      builder: (pressed) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: V.easeSwift,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: pressed ? V.bg3 : const Color(0x00000000),
          borderRadius: BorderRadius.circular(V.rControl),
          border: Border.all(color: V.lineStrong),
        ),
        child: Text(
          label,
          style: VT.ui(14, weight: FontWeight.w500, height: 1, color: V.muted),
        ),
      ),
    ),
  );
}
