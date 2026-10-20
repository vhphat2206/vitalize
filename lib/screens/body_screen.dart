import 'dart:async';

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/widgets.dart';

import '../app/haptics.dart';
import '../app/theme.dart';
import '../data/catalog.dart';
import '../data/models.dart';
import '../widgets/back_bar.dart';
import '../widgets/body_figure.dart';
import '../widgets/bottom_sheet.dart';
import '../widgets/controls.dart';
import '../widgets/exercise_row.dart';
import '../widgets/icons.dart';
import 'body/appear.dart';
import 'body/brand.dart';
import 'exercise_screen.dart';

/// Height of the half-open sheet, as a fraction of its full height.
const _half = 0.56;

/// Gap between the safe area and the top of the fully open sheet.
const _sheetTopGap = 10.0;

const _stripH = 50.0;

/// Exercises built for [m], in catalogue order.
List<Exercise> _mainFor(Muscle m) => [
  for (final e in catalog.exercises)
    if (e.primary.contains(m.id)) e,
];

/// Other exercises that work [m] as a helper.
List<Exercise> _helpersFor(Muscle m) => [
  for (final e in catalog.exercises)
    if (e.secondary.contains(m.id)) e,
];

/// The Cơ thể tab: the body map. Tap a muscle, on the figure or in the strip of names under
/// it, for a sheet of the exercises built for it and the ones it helps; turn the body round
/// to reach the back.
class BodyScreen extends StatefulWidget {
  const BodyScreen({super.key});

  @override
  State<BodyScreen> createState() => _BodyScreenState();
}

class _BodyScreenState extends State<BodyScreen> with SingleTickerProviderStateMixin {
  BodySide _side = 'front';
  MuscleId? _selected;
  SheetSnap _snap = SheetSnap.closed;
  String _filter = 'all';

  /// The outline draws itself once; later turns of the body just swap the figure.
  bool _intro = true;

  /// The muscle the sheet lists. It outlives the selection, which clears while the sheet is
  /// still sliding away.
  MuscleId? _listed;

  /// Bumped when the tab is shown again: like the web's hidden tabs, it plays its entrance
  /// animations again.
  int _epoch = 0;
  bool _visible = true;

  /// Horizontal scale of the figure: it squeezes to an edge, swaps side, opens back out.
  late final AnimationController _turn = AnimationController(vsync: this, value: 1);
  bool _turning = false;

  Timer? _introTimer;
  Timer? _clearTimer;

  final _strip = ScrollController();
  final _stripKeys = <MuscleId, GlobalKey>{};
  final _list = ScrollController();

  // A tap on the stage that lands on no muscle closes the sheet.
  Offset? _stageDown;
  bool _stageHit = false;

  bool get _open => _snap != SheetSnap.closed && _selected != null;

  @override
  void initState() {
    super.initState();
    _introTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _intro = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = Visibility.of(context);
    if (visible && !_visible) _epoch++;
    _visible = visible;
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _clearTimer?.cancel();
    _turn.dispose();
    _strip.dispose();
    _list.dispose();
    super.dispose();
  }

  void _select(MuscleId id) {
    _stageHit = true;
    Haptics.tick();
    _clearTimer?.cancel();
    final opening = _snap == SheetSnap.closed;
    setState(() {
      _selected = id;
      _listed = id;
      _filter = 'all';
      if (opening) _snap = SheetSnap.half;
    });
    if (opening && _list.hasClients) _list.jumpTo(0);
    // Keep the selected name in view in the strip.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _stripKeys[id]?.currentContext;
      if (ctx == null || !mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  void _setSnap(SheetSnap snap) {
    if (snap == _snap) return;
    setState(() => _snap = snap);
    _clearTimer?.cancel();
    // Clear the selection once the sheet has gone, so the muscle goes back with it.
    if (snap == SheetSnap.closed) {
      _clearTimer = Timer(const Duration(milliseconds: 260), () {
        if (mounted) setState(() => _selected = null);
      });
    }
  }

  void _close() => _setSnap(SheetSnap.closed);

  void _turnTo(BodySide next) {
    if (next == _side || _turning) return;
    Haptics.tick();
    _turning = true;
    _turn
        .animateTo(0, duration: const Duration(milliseconds: 170), curve: V.easeIn)
        .whenCompleteOrCancel(() {
          if (!mounted) return;
          setState(() => _side = next);
          final selected = _selected;
          if (selected != null && !catalog.muscleById[selected]!.sides.contains(next)) _close();
          _turn
              .animateTo(1, duration: const Duration(milliseconds: 340), curve: V.easeExpo)
              .whenCompleteOrCancel(() => _turning = false);
        });
  }

  void _openExercise(String id) => Navigator.of(context).push(vRoute(ExerciseScreen(id: id)));

  void _stagePointerUp(PointerUpEvent e) {
    final down = _stageDown;
    _stageDown = null;
    if (down == null || (e.position - down).distance > kTouchSlop) return;
    // The figure reports a muscle hit in this same event; check once it has had its say.
    scheduleMicrotask(() {
      if (mounted && !_stageHit) _close();
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final selected = _selected == null ? null : catalog.muscleById[_selected];
    final listed = _listed == null ? null : catalog.muscleById[_listed];
    return LayoutBuilder(
      builder: (context, root) => Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(V.pad, safeTop + 10, V.pad, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Appear(AppearKind.scale, delay: 0.05, replay: _epoch, child: const _Brand()),
                    Appear(
                      AppearKind.scale,
                      delay: 0.18,
                      replay: _epoch,
                      child: _SideToggle(side: _side, onTurn: _turnTo),
                    ),
                  ],
                ),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.fromLTRB(V.pad, 12, V.pad, 0),
                // the line rises by its own height, not the prompt's
                alignment: Alignment.topLeft,
                child: MaskLine(
                  fontSize: 14,
                  child: Appear(
                    AppearKind.mask,
                    delay: 0.3,
                    replay: _epoch,
                    child: Text(
                      selected?.role ?? 'Chạm vào nhóm cơ bạn muốn tập.',
                      style: VT.ui(14, height: 1.4, color: V.muted),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 4),
                  child: LayoutBuilder(
                    builder: (context, area) => _stage(area, _fit(root, area, safeTop)),
                  ),
                ),
              ),
              _muscleStrip(),
            ],
          ),
          Positioned(
            top: safeTop + _sheetTopGap,
            left: 0,
            right: 0,
            bottom: 0,
            child: VBottomSheet(
              snap: _open ? _snap : SheetSnap.closed,
              onSnap: _setSnap,
              halfRatio: _half,
              controller: _list,
              label: listed == null ? 'Bài tập' : 'Bài tập cho ${listed.name}',
              header: listed == null
                  ? const SizedBox.shrink()
                  : _MuscleHead(
                      muscle: listed,
                      filter: _filter,
                      onFilter: (f) => setState(() => _filter = f),
                      onClose: _close,
                      replay: _epoch,
                    ),
              children: listed == null ? const [] : _sheetRows(listed),
            ),
          ),
        ],
      ),
    );
  }

  /// Scale for the figure so it fits between the header and the half-open sheet.
  double _fit(BoxConstraints root, BoxConstraints area, double safeTop) {
    final screenH = root.maxHeight;
    final areaTop = screenH - _stripH - 4 - area.maxHeight;
    final sheetFull = screenH - safeTop - _sheetTopGap;
    final sheetTop = screenH - sheetFull * _half;
    final available = sheetTop - areaTop - 14;
    return (available / area.maxHeight).clamp(0.3, 1.0);
  }

  Widget _stage(BoxConstraints area, double fit) {
    final labels = _side == 'front' ? const ['PHẢI', 'TRÁI'] : const ['TRÁI', 'PHẢI'];
    // Anatomical orientation, set vertically down the sides like a plate in an atlas.
    final labelTop = 0.22 * area.maxWidth;
    return AnimatedScale(
      scale: _open ? fit : 1,
      duration: const Duration(milliseconds: 450),
      curve: V.easeExpo,
      alignment: Alignment.topCenter,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          _stageDown = e.position;
          _stageHit = false;
        },
        onPointerUp: _stagePointerUp,
        onPointerCancel: (_) => _stageDown = null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: labelTop),
              child: _SideLabel(labels[0], upward: true),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: area.maxHeight,
              child: AnimatedBuilder(
                animation: _turn,
                builder: (context, child) => Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(_turn.value, 1, 1),
                  child: child,
                ),
                child: BodyFigure(
                  key: ValueKey(_side),
                  side: _side,
                  tones: _selected == null ? const {} : {_selected!: Tone.primary},
                  onSelect: _select,
                  intro: _intro,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: EdgeInsets.only(top: labelTop),
              child: _SideLabel(labels[1]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _muscleStrip() => IgnorePointer(
    ignoring: _open,
    child: ExcludeSemantics(
      excluding: _open,
      child: AnimatedOpacity(
        opacity: _open ? 0 : 1,
        duration: const Duration(milliseconds: 250),
        curve: V.easeSwift,
        child: Appear(
          AppearKind.soft,
          delay: 1.1,
          replay: _epoch,
          child: Semantics(
            container: true,
            label: 'Danh sách nhóm cơ',
            child: Container(
              height: _stripH,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: V.line)),
              ),
              child: SingleChildScrollView(
                controller: _strip,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: V.pad - 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, id) in catalog.muscleOrder[_side]!.indexed) ...[
                      if (i > 0) const SizedBox(width: 2),
                      _StripName(
                        key: _stripKeys.putIfAbsent(id, GlobalKey.new),
                        name: catalog.muscleById[id]!.name,
                        on: _selected == id,
                        onTap: () => _select(id),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  List<Widget> _sheetRows(Muscle muscle) {
    bool shown(Exercise e) => _filter == 'all' || e.equipment == _filter;
    final main = _mainFor(muscle).where(shown).toList();
    final helpers = _helpersFor(muscle).where(shown).toList();
    return [
      // A new muscle or filter plays the rows in again, one after another.
      KeyedSubtree(
        key: ValueKey('${muscle.id}-$_filter'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, ex) in main.indexed)
              Appear(
                AppearKind.soft,
                delay: 0.06 * i,
                duration: 0.6,
                replay: _epoch,
                child: ExerciseRow(exercise: ex, onOpen: () => _openExercise(ex.id)),
              ),
          ],
        ),
      ),
      if (helpers.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(V.pad, 28, V.pad, 0),
          child: SectionTitle('Bài khác cũng dùng tới ${muscle.name.toLowerCase()}'),
        ),
        for (final ex in helpers)
          ExerciseRow(exercise: ex, quiet: true, onOpen: () => _openExercise(ex.id)),
      ],
    ];
  }
}

/// The logo: the mark and the wordmark.
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      // optical: the mark's arms reach above the cap line, so centred it looks low
      Transform.translate(offset: const Offset(0, -1), child: const LogoMark()),
      const SizedBox(width: 9),
      const Wordmark(),
    ],
  );
}

/// Trước / Sau: which side of the body is shown.
class _SideToggle extends StatelessWidget {
  const _SideToggle({required this.side, required this.onTurn});

  final BodySide side;
  final ValueChanged<BodySide> onTurn;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Mặt cơ thể',
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: V.bg2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: V.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (s, label) in const [('front', 'Trước'), ('back', 'Sau')])
              Semantics(
                inMutuallyExclusiveGroup: true,
                checked: side == s,
                button: true,
                label: label,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTurn(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: V.easeSwift,
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: side == s ? V.ink : V.ink.withValues(alpha: 0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      curve: V.easeSwift,
                      style: VT.ui(
                        14,
                        weight: FontWeight.w500,
                        height: 1,
                        color: side == s ? V.bg : V.muted,
                      ),
                      child: Text(label),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// PHẢI / TRÁI, set vertically beside the figure; the left one reads upwards.
class _SideLabel extends StatelessWidget {
  const _SideLabel(this.text, {this.upward = false});

  final String text;
  final bool upward;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RotatedBox(
      quarterTurns: upward ? 3 : 1,
      child: Text(
        text,
        style: VT
            .mono(11, weight: FontWeight.w500, height: 1, color: V.faint)
            .copyWith(letterSpacing: 0.14 * 11),
      ),
    ),
  );
}

/// A muscle's name in the strip under the figure; the selected one is ink with a green tick
/// on the rule above it.
class _StripName extends StatelessWidget {
  const _StripName({super.key, required this.name, required this.on, required this.onTap});

  final String name;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: on,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              child: Text(
                name,
                style: VT.ui(14, weight: FontWeight.w500, height: 1, color: on ? V.ink : V.muted),
              ),
            ),
          ),
          if (on)
            // 2 px tall from 1 px above the button; the strip clips the half over its rule.
            const Positioned(
              left: 10,
              right: 10,
              top: 0,
              height: 1,
              child: ColoredBox(color: V.accent),
            ),
        ],
      ),
    ),
  );
}

/// Head of the sheet: the muscle's name and Latin name, the close button, and the equipment
/// filter when its exercises use more than one kind.
class _MuscleHead extends StatelessWidget {
  const _MuscleHead({
    required this.muscle,
    required this.filter,
    required this.onFilter,
    required this.onClose,
    required this.replay,
  });

  final Muscle muscle;
  final String filter;
  final ValueChanged<String> onFilter;
  final VoidCallback onClose;
  final Object replay;

  @override
  Widget build(BuildContext context) {
    final main = _mainFor(muscle);
    final counts = <String, int>{};
    for (final e in main) {
      counts[e.equipment] = (counts[e.equipment] ?? 0) + 1;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // the close button reaches 10 px into the margin, so its glyph lines up
          padding: const EdgeInsets.only(left: V.pad, right: V.pad - 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: MaskLine(
                        fontSize: 36,
                        child: Appear(
                          AppearKind.mask,
                          key: ValueKey(muscle.id),
                          duration: 0.8,
                          replay: replay,
                          child: Text(muscle.name, style: VT.display(36, height: 1.15, em: -0.025)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      muscle.latin,
                      style: VT.mono(12, height: 1.3, color: V.muted).copyWith(letterSpacing: 0.24),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconBtn(VIcons.close, label: 'Đóng', onPressed: onClose),
            ],
          ),
        ),
        if (counts.length > 1)
          Container(
            margin: const EdgeInsets.only(top: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: V.line)),
            ),
            child: Semantics(
              container: true,
              label: 'Lọc theo dụng cụ',
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(V.pad, 0, V.pad, 12),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Tất cả',
                      count: main.length,
                      on: filter == 'all',
                      onTap: () => onFilter('all'),
                    ),
                    for (final MapEntry(key: eq, value: n) in counts.entries) ...[
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: catalog.equipmentLabel[eq]!,
                        count: n,
                        on: filter == eq,
                        onTap: () => onFilter(eq),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.on,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: on,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // an inset hairline that takes no room, gone at once when selected
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: on
              ? const BoxDecoration()
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(V.rControl),
                  border: Border.all(color: V.line),
                ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: V.easeSwift,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: on ? V.ink : V.ink.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(V.rControl),
            ),
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: on ? V.bg : V.muted),
              duration: const Duration(milliseconds: 200),
              curve: V.easeSwift,
              builder: (context, color, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: VT.ui(13, weight: FontWeight.w500, height: 1, color: color!),
                  ),
                  const SizedBox(width: 6),
                  Opacity(
                    opacity: 0.8,
                    child: Text(
                      '$count',
                      style: VT.mono(11.5, weight: FontWeight.w500, height: 1, color: color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
