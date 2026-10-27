import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../app/tabs.dart';
import '../app/theme.dart';
import '../app/toast.dart';
import '../logic/format.dart';
import '../logic/meal_analyzer.dart';
import '../logic/meal_photo.dart';
import '../logic/meals.dart';
import '../logic/nutrition.dart';
import '../logic/week.dart';
import '../state/log_store.dart';
import '../state/prefs_store.dart';
import '../widgets/back_bar.dart';
import '../widgets/controls.dart';
import '../widgets/icons.dart';
import '../widgets/modal_sheet.dart';
import '../widgets/pressable.dart';
import 'food/entrance.dart';
import 'food/meal_thumb.dart';
import 'food_pick_screen.dart';
import 'meal_detail_screen.dart';
import 'meal_scan_screen.dart';

const _slots = [MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner, MealSlot.snack];

/// The Ăn uống tab: what you ate today against your daily targets, the button to photograph a
/// meal, and today's meals by slot.
class FoodScreen extends StatefulWidget {
  const FoodScreen({super.key, this.now, this.pickPhoto});

  /// Pins "today", for tests.
  @visibleForTesting
  final DateTime? now;

  /// Stands in for the camera and the photo library, for tests.
  @visibleForTesting
  final Future<Uint8List?> Function(ImageSource source)? pickPhoto;

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> with TabEntrance {
  /// A picker is open; a second tap would only fail.
  bool _picking = false;

  Future<void> _capture(ImageSource source) async {
    if (_picking) return;
    _picking = true;
    try {
      final pick = widget.pickPhoto;
      final photo = pick != null ? await pick(source) : await pickMealPhoto(context, source);
      if (photo == null || !mounted) return;
      Navigator.of(context).push(vRoute(MealScanScreen(photo: photo)));
    } finally {
      _picking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final meals = context.watch<LogStore>().meals;
    final profile = context.watch<PrefsStore>().profile;
    final now = widget.now ?? DateTime.now();
    final today = [
      for (final m in meals)
        if (isSameDay(m.at, now)) m,
    ];
    final eaten = sumMacros(today.map(mealTotals));
    final targets = dailyTargets(profile, year: now.year);

    return CssLeading(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabHead(
              title: 'Ăn uống',
              replay: entrance,
              subtitle: Text(
                'Hôm nay, ${dayTitle(now).toLowerCase()}',
                style: VT.ui(15, color: V.muted),
              ),
            ),
            Appear.soft(
              delay: const Duration(milliseconds: 180),
              replay: entrance,
              child: _Intake(eaten: eaten, targets: targets),
            ),
            Appear.soft(
              delay: const Duration(milliseconds: 260),
              replay: entrance,
              child: _Capture(
                onCamera: () => _capture(ImageSource.camera),
                onLibrary: () => _capture(ImageSource.gallery),
                onManual: () => Navigator.of(context).push(vRoute(const FoodPickScreen())),
              ),
            ),
            const SizedBox(height: 30),
            if (today.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: V.pad),
                child: Text('Chưa có bữa nào hôm nay.', style: VT.ui(14.5, color: V.muted)),
              )
            else
              for (final (i, slot) in _slots.where((s) => today.any((m) => m.slot == s)).indexed)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 22),
                  child: _SlotGroup(
                    slot: slot,
                    meals: [
                      for (final m in today)
                        if (m.slot == slot) m,
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Today's intake: a sentence, the energy bar and three macro bars (or, without body data, a link
/// to the profile).
class _Intake extends StatelessWidget {
  const _Intake({required this.eaten, required this.targets});

  final Macros eaten;
  final Macros? targets;

  static TextSpan _strong(String text) => TextSpan(
    text: text,
    style: VT.mono(16, weight: FontWeight.w500, height: 1.5),
  );

  @override
  Widget build(BuildContext context) {
    final t = targets;
    final line = VT.ui(17, height: 1.5);
    return Semantics(
      container: true,
      label: 'Lượng ăn hôm nay',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(V.pad, 20, V.pad, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: t != null
              ? [
                  Text.rich(
                    TextSpan(
                      style: line,
                      children: [
                        const TextSpan(text: 'Đã ăn '),
                        _strong(formatNumber(eaten.kcal)),
                        const TextSpan(text: ' trong '),
                        _strong('${formatNumber(t.kcal)} kcal'),
                        TextSpan(
                          text: eaten.kcal <= t.kcal
                              ? '. Còn khoảng ${formatNumber(t.kcal - eaten.kcal)} kcal.'
                              : '. Đã vượt ${formatNumber(eaten.kcal - t.kcal)} kcal.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Meter(value: eaten.kcal, max: t.kcal, label: 'Năng lượng', big: true),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _Meter(
                          value: eaten.protein,
                          max: t.protein,
                          label: 'Đạm',
                          unit: 'g',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _Meter(value: eaten.carb, max: t.carb, label: 'Tinh bột', unit: 'g'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _Meter(value: eaten.fat, max: t.fat, label: 'Béo', unit: 'g'),
                      ),
                    ],
                  ),
                ]
              : [
                  Text.rich(
                    TextSpan(
                      style: line,
                      children: [
                        const TextSpan(text: 'Đã ăn '),
                        _strong('${formatNumber(eaten.kcal)} kcal'),
                        const TextSpan(text: ' hôm nay.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      button: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => context.read<TabNav>().go(AppTab.profile),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: _UnderlinedText(
                            'Nhập chiều cao, cân nặng để biết mỗi ngày nên ăn bao nhiêu',
                            style: VT.ui(14.5, height: 1.4, color: V.accent),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
        ),
      ),
    );
  }
}

/// A thin bar: how much of today's target is eaten. Turns ink once the target is passed.
class _Meter extends StatelessWidget {
  const _Meter({
    required this.value,
    required this.max,
    required this.label,
    this.unit = 'kcal',
    this.big = false,
  });

  final double value;
  final double max;
  final String label;
  final String unit;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final ratio = max > 0 ? value / max : 0.0;
    final track = Semantics(
      label: label,
      value: '${value.round()} / ${max.round()} $unit',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(big ? 1 : 0),
        child: Container(
          height: big ? 8 : 4,
          color: V.line,
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: ratio.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 600),
            curve: V.easeExpo,
            builder: (context, fill, _) => FractionallySizedBox(
              widthFactor: fill,
              heightFactor: 1,
              child: ColoredBox(color: ratio > 1 ? V.ink : V.accent),
            ),
          ),
        ),
      ),
    );
    if (big) return track;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(label, style: VT.ui(13, color: V.muted)),
        ),
        const SizedBox(height: 2),
        ExcludeSemantics(
          child: Text(
            '${formatNumber(value)}/${formatNumber(max)} $unit',
            style: VT.mono(12, height: 1.5),
          ),
        ),
        const SizedBox(height: 8),
        track,
      ],
    );
  }
}

/// Text with the web app's link underline: 1 px, 3 px under the baseline
/// (`text-underline-offset: 3px`), on every line.
class _UnderlinedText extends StatelessWidget {
  const _UnderlinedText(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final full = DefaultTextStyle.of(context).style.merge(style);
      final painter = TextPainter(
        text: TextSpan(text: text, style: full),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        textHeightBehavior: DefaultTextHeightBehavior.maybeOf(context),
      )..layout(maxWidth: box.maxWidth);
      final lines = [
        for (final l in painter.computeLineMetrics())
          Rect.fromLTWH(l.left, l.baseline + 3, l.width, 1),
      ];
      painter.dispose();
      return CustomPaint(
        foregroundPainter: _Underline(lines, style.color ?? V.accent),
        child: Text(text, style: style),
      );
    },
  );
}

class _Underline extends CustomPainter {
  const _Underline(this.lines, this.color);

  final List<Rect> lines;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final r in lines) {
      canvas.drawRect(r, paint);
    }
  }

  @override
  bool shouldRepaint(_Underline old) => !listEquals(old.lines, lines) || old.color != color;
}

/// The two ways in: take a photo, or pick one, and what the analysis can and can't do.
class _Capture extends StatelessWidget {
  const _Capture({required this.onCamera, required this.onLibrary, required this.onManual});

  final VoidCallback onCamera;
  final VoidCallback onLibrary;
  final VoidCallback onManual;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(V.pad, 28, V.pad, 0),
    padding: const EdgeInsets.only(top: 24),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: V.line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryButton(label: 'Chụp món ăn', icon: VIcons.camera, onPressed: onCamera),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: GhostButton(
            label: 'Chọn ảnh có sẵn',
            icon: VIcons.image,
            expand: true,
            onPressed: onLibrary,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: GhostButton(
            label: 'Nhập món thủ công',
            icon: VIcons.plus,
            expand: true,
            onPressed: onManual,
          ),
        ),
        const SizedBox(height: 14),

        Text(
          'AI nhìn ảnh, đoán món và khẩu phần rồi ước tính calo. Sai số thường 15–25%, bạn chỉnh '
          'lại được trước khi lưu.${aiEnabled ? '' : ' Hiện app đang ở chế độ thử, kết quả là mẫu.'}',
          style: VT.ui(13.5, color: V.muted),
        ),
      ],
    ),
  );
}

/// One meal slot of today: its total, then its meals.
class _SlotGroup extends StatelessWidget {
  const _SlotGroup({required this.slot, required this.meals});

  final MealSlot slot;
  final List<LoggedMeal> meals;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: V.pad),
        child: Semantics(
          header: true,
          child: SectionTitle(
            mealSlotLabel[slot]!,
            trailing: _SyntheticBold(
              '${formatNumber(sumMacros(meals.map(mealTotals)).kcal)} kcal',
              style: VT.mono(12.5, weight: FontWeight.w500, height: 1.2),
            ),
          ),
        ),
      ),
      for (final m in meals)
        _MealRow(
          meal: m,
          onOpen: () => Navigator.of(context).push(vRoute(MealDetailScreen(id: m.id))),
        ),
    ],
  );
}

/// Text drawn heavier than its face, as browsers do when a weight is asked for that the font
/// doesn't ship: the section title asks for 600 and JetBrains Mono comes in 400 and 500, so the
/// web app shows the slot totals in a synthetic bold. Like Skia's, the outline is stroked by about
/// 1/24 of the size; the advances don't change.
class _SyntheticBold extends StatelessWidget {
  const _SyntheticBold(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _Stroke(
      text: text,
      style: style,
      direction: Directionality.of(context),
      scaler: MediaQuery.textScalerOf(context),
      heightBehavior: DefaultTextHeightBehavior.maybeOf(context),
    ),
    child: Text(text, style: style),
  );
}

/// The outline of [text], stroked under the glyphs the Text draws on top.
class _Stroke extends CustomPainter {
  const _Stroke({
    required this.text,
    required this.style,
    required this.direction,
    required this.scaler,
    required this.heightBehavior,
  });

  final String text;
  final TextStyle style;
  final TextDirection direction;
  final TextScaler scaler;
  final TextHeightBehavior? heightBehavior;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: style.fontFamily,
          fontSize: style.fontSize,
          fontWeight: style.fontWeight,
          height: style.height,
          letterSpacing: style.letterSpacing,
          fontFeatures: style.fontFeatures,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = style.fontSize! / 24
            ..strokeJoin = StrokeJoin.round
            ..color = style.color ?? V.ink,
        ),
      ),
      textDirection: direction,
      textScaler: scaler,
      textHeightBehavior: heightBehavior,
    )..layout(maxWidth: size.width);
    painter.paint(canvas, Offset.zero);
    painter.dispose();
  }

  @override
  bool shouldRepaint(_Stroke old) =>
      old.text != text || old.style != style || old.scaler != scaler || old.direction != direction;
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.meal, required this.onOpen});

  final LoggedMeal meal;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Pressable(
      onTap: onOpen,
      builder: (pressed) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: V.easeSwift,
        padding: const EdgeInsets.symmetric(horizontal: V.pad, vertical: 10),
        decoration: BoxDecoration(
          color: pressed ? V.bg3 : const Color(0x00000000),
          border: const Border(bottom: BorderSide(color: V.line)),
        ),
        child: Row(
          children: [
            MealThumb(meal: meal, size: 52, radius: V.rControl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.items.map((i) => i.food.name).join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: VT.ui(15, weight: FontWeight.w500, height: 1.35),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(timeText(meal.at), style: VT.mono(12, height: 1.5, color: V.muted)),
                      if (meal.source == 'demo') ...[
                        const SizedBox(width: 10),
                        Text('kết quả mẫu', style: VT.ui(12.5, color: V.muted)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Text('${formatNumber(mealTotals(meal).kcal)} kcal', style: VT.mono(13.5, height: 1.5)),
          ],
        ),
      ),
    ),
  );
}

final _picker = ImagePicker();

/// Takes a photo with the camera (asking for it first) or picks one from the library, as a JPEG
/// no larger than [mealPhotoEdge]. Returns null when cancelled or not allowed; a refused
/// permission shows a sheet that leads to the phone's settings.
///
/// iOS asks for the camera once and after that only Settings can change it, so it's asked here
/// first and a refusal gets the explanation. Android's camera app needs no permission from this
/// app (none is declared; image_picker asks by itself if one ever is), and the library picker
/// needs none on either.
Future<Uint8List?> pickMealPhoto(BuildContext context, ImageSource source) async {
  final camera = source == ImageSource.camera;
  if (camera && defaultTargetPlatform == TargetPlatform.iOS) {
    PermissionStatus? status;
    try {
      status = await Permission.camera.request();
    } on Exception {
      // Can't tell (plugin unavailable): let the picker ask for itself.
    }
    if (status != null && !status.isGranted && !status.isLimited) {
      if (context.mounted) await _showAccessSheet(context, camera: true);
      return null;
    }
  }
  try {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: mealPhotoEdge,
      maxHeight: mealPhotoEdge,
      imageQuality: mealPhotoQuality,
      requestFullMetadata: false,
    );
    return await file?.readAsBytes();
  } on PlatformException catch (e) {
    if (!context.mounted) return null;
    if (e.code == 'camera_access_denied' || e.code == 'photo_access_denied') {
      await _showAccessSheet(context, camera: camera);
    } else if (e.code == 'no_available_camera') {
      Toast.show(context, 'Máy này không có camera. Hãy chọn ảnh có sẵn.');
    } else {
      Toast.show(context, 'Không mở được ảnh, thử lại nhé.');
    }
    return null;
  } catch (_) {
    if (context.mounted) Toast.show(context, 'Không mở được ảnh, thử lại nhé.');
    return null;
  }
}

/// Explains a refused camera or photo permission, with a way to the app's page in Settings.
Future<void> _showAccessSheet(BuildContext context, {required bool camera}) => showModalSheet<void>(
  context,
  title: camera ? 'Chưa được dùng camera' : 'Chưa được xem ảnh',
  builder: (context) => CssLeading(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          camera
              ? 'Để chụp món ăn, hãy cho Vitalize dùng camera trong Cài đặt của máy.'
              : 'Để chọn ảnh có sẵn, hãy cho Vitalize xem ảnh trong Cài đặt của máy.',
          style: VT.ui(15.5),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: GhostButton(
                  label: 'Để sau',
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 50,
                child: PrimaryButton(
                  label: 'Mở Cài đặt',
                  onPressed: () {
                    Navigator.of(context).pop();
                    openAppSettings();
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  ),
);
