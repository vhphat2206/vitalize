import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vitalize/logic/meal_analyzer.dart';
import 'package:vitalize/logic/meal_photo.dart';
import 'package:vitalize/screens/meal_detail_screen.dart';
import 'package:vitalize/screens/meal_scan_screen.dart';
import 'package:vitalize/state/log_store.dart';
import 'package:vitalize/widgets/back_bar.dart';
import 'package:vitalize/widgets/icons.dart';
import 'package:vitalize/widgets/meal_editor.dart';

import 'food_week_support.dart';
import 'support/harness.dart';

/// A home screen that opens [screen] the way the app does, so it can be popped.
Widget _host(Widget screen) => Builder(
  builder: (context) => Center(
    child: GestureDetector(
      onTap: () => Navigator.of(context).push(vRoute(screen)),
      child: const Text('mở'),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('mở'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

LogStore _log(WidgetTester tester) =>
    Provider.of<LogStore>(tester.element(find.byType(Navigator)), listen: false);

Finder _glyph(VGlyph g) => find.byWidgetPredicate((w) => w is VIcon && w.glyph == g);

void main() {
  setUpAll(setUpApp);

  testWidgets('scanning, then the demo result', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(await appFrame(MealScanScreen(photo: mealPhotoBytes, now: testNow)));
    await loadImages(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await snap(tester, 'scan-drawing');
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Đang xem ảnh, thường mất vài giây.'), findsOneWidget);
    await snap(tester, 'scan-analyzing');
    await expectLater(find.byType(MealScanScreen), matchesGoldenFile('goldens/meal_scan.png'));

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Trong ảnh có'), findsOneWidget);
    expect(
      find.text('Chế độ thử: đây là kết quả mẫu, chưa phải AI phân tích ảnh của bạn.'),
      findsOneWidget,
    );
    expect(find.text('Lưu vào bữa trưa'), findsOneWidget);
    await snap(tester, 'scan-result');
    await expectLater(
      find.byType(MealScanScreen),
      matchesGoldenFile('goldens/meal_scan_result.png'),
    );

    expect(tester.widget<BackBar>(find.byType(BackBar)).solid, isFalse);
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -2000));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Mức chắc chắn: vừa phải.'), findsOneWidget);
    expect(tester.widget<BackBar>(find.byType(BackBar)).solid, isTrue);
    await tester.pump(const Duration(milliseconds: 300)); // the bar fades to solid
    await snap(tester, 'scan-result-bottom');
    await expectLater(
      find.byType(MealScanScreen),
      matchesGoldenFile('goldens/meal_scan_result_bottom.png'),
    );
  });

  testWidgets('adjust, pick the slot and save, with undo', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(
      await appFrame(
        _host(
          MealScanScreen(
            photo: mealPhotoBytes,
            now: testNow,
            analyze: (_) async => MealAnalysis(
              isFood: true,
              items: [sample('Ức gà áp chảo'), sample('Cơm trắng'), sample('Bông cải xanh luộc')],
              confidence: MealConfidence.high,
              note: 'Phần cơm hơi khó ước lượng.',
              source: 'ai',
            ),
          ),
        ),
      ),
    );
    await _open(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('Chế độ thử: đây là kết quả mẫu, chưa phải AI phân tích ảnh của bạn.'),
      findsNothing,
    );
    expect(find.text('Mức chắc chắn: khá chắc. Phần cơm hơi khó ước lượng.'), findsOneWidget);
    expect(find.text('495 kcal'), findsOneWidget);

    // one more half portion of chicken: 250 × 1.5
    await tester.tap(find.bySemanticsLabel('Thêm nửa phần').first);
    await tester.pump();
    expect(find.text('1,5 phần'), findsOneWidget);
    expect(find.text('375 kcal'), findsOneWidget);
    // drop the broccoli
    await tester.ensureVisible(find.text('Bỏ món này').last);
    await tester.tap(find.text('Bỏ món này').last);
    await tester.pump();
    expect(find.text('Bông cải xanh luộc'), findsNothing);
    expect(find.text('585 kcal'), findsOneWidget);
    // save as dinner
    await tester.ensureVisible(find.text('Tối'));
    await tester.tap(find.text('Tối'));
    await tester.pump();
    expect(find.text('Lưu vào bữa tối'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Lưu vào bữa tối'));
      for (var i = 0; i < 50 && _log(tester).meals.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();
    final meal = _log(tester).meals.single;
    expect(meal.slot, MealSlot.dinner);
    expect(meal.source, 'ai');
    expect(
      [for (final i in meal.items) (i.food.name, i.servings)],
      [('Ức gà áp chảo', 1.5), ('Cơm trắng', 1.0)],
    );
    // the thumbnail is a small JPEG, long edge 220 px
    final thumb = decodeMealPhoto(meal.photo!)!;
    expect(thumb.sublist(0, 2), [0xFF, 0xD8]);
    expect(thumb.length, lessThan(20000));
    expect(find.text('Đã lưu bữa tối, 585 kcal'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(MealScanScreen), findsNothing);

    await tester.tap(find.text('Hoàn tác'));
    await tester.pump();
    expect(_log(tester).meals, isEmpty);
  });

  testWidgets('not food, then a failed analysis and a retry', (tester) async {
    await usePhone(tester);
    var calls = 0;
    await tester.pumpWidget(
      await appFrame(
        _host(
          MealScanScreen(
            photo: mealPhotoBytes,
            now: testNow,
            analyze: (_) async {
              calls++;
              if (calls == 1) {
                return const MealAnalysis(
                  isFood: false,
                  items: [],
                  confidence: MealConfidence.low,
                  note: '',
                  source: 'ai',
                );
              }
              if (calls == 2) throw const MealAnalysisError('Đang quá tải, thử lại sau ít phút.');
              return Future.delayed(const Duration(seconds: 1), () => throw StateError('x'));
            },
          ),
        ),
      ),
    );
    await _open(tester);
    await loadImages(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('Ảnh này không giống món ăn. Thử chụp gần hơn, đủ sáng và thấy rõ cả đĩa.'),
      findsOneWidget,
    );
    expect(find.text('Chụp lại'), findsOneWidget);
    expect(find.text('Trong ảnh có'), findsNothing);
    await snap(tester, 'scan-not-food');
    await tester.tap(find.text('Chụp lại'));
    await tester.pumpAndSettle();
    expect(find.byType(MealScanScreen), findsNothing);

    await _open(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Đang quá tải, thử lại sau ít phút.'), findsOneWidget);
    await snap(tester, 'scan-error');
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    expect(find.text('Đang xem ảnh, thường mất vài giây.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    // anything that isn't a service error gets the general message
    expect(find.text('Không phân tích được ảnh, thử lại nhé.'), findsOneWidget);
  });

  testWidgets('no photo', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(await appFrame(const MealScanScreen(photo: null)));
    expect(find.text('Không tìm thấy ảnh. Quay lại và chụp lại nhé.'), findsOneWidget);
  });

  testWidgets('a saved meal: portions and slot save as you go', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(
      await appFrame(
        _host(const MealDetailScreen(id: 'm-lunch')),
        seed: (log, _) => seedMeals().forEach(log.restoreMeal),
      ),
    );
    await _open(tester);
    await loadImages(tester);
    expect(find.text('Thứ Ba 20/10, 12:15, kết quả mẫu', findRichText: true), findsOneWidget);
    expect(find.text('1,5 phần'), findsOneWidget);
    await snap(tester, 'meal-detail');
    await expectLater(find.byType(MealDetailScreen), matchesGoldenFile('goldens/meal_detail.png'));

    await tester.tap(find.bySemanticsLabel('Bớt nửa phần').last);
    await tester.pump();
    LoggedMeal lunch() => _log(tester).meals.firstWhere((m) => m.id == 'm-lunch');
    expect(lunch().items.last.servings, 1.0);

    expect(tester.widget<BackBar>(find.byType(BackBar)).title, 'Bữa trưa');
    await tester.tap(find.text('Tối'));
    await tester.pump();
    expect(lunch().slot, MealSlot.dinner);
    expect(tester.widget<BackBar>(find.byType(BackBar)).title, 'Bữa tối');
  });

  testWidgets('deleting a meal, and undo', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(
      await appFrame(
        _host(const MealDetailScreen(id: 'm-breakfast')),
        seed: (log, _) => seedMeals().forEach(log.restoreMeal),
      ),
    );
    await _open(tester);
    await tester.tap(find.text('Xoá bữa ăn này'));
    await tester.pump();
    // still shown while it slides away
    expect(find.text('Bánh mì thịt'), findsOneWidget);
    expect(find.text('Bữa ăn này đã bị xoá.'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(MealDetailScreen), findsNothing);
    expect(_log(tester).meals.any((m) => m.id == 'm-breakfast'), isFalse);
    expect(find.text('Đã xoá bữa ăn'), findsOneWidget);
    await tester.tap(find.text('Hoàn tác'));
    await tester.pump();
    expect(_log(tester).meals.any((m) => m.id == 'm-breakfast'), isTrue);
  });

  testWidgets('a meal deleted elsewhere', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(await appFrame(const MealDetailScreen(id: 'gone')));
    expect(find.text('Bữa ăn này đã bị xoá.'), findsOneWidget);
    expect(_glyph(VIcons.back), findsOneWidget);
  });

  testWidgets('editor limits: half to four servings, the last dish stays', (tester) async {
    await usePhone(tester);
    var items = [MealItem(food: sample('Phở bò tái'), servings: 3.5)];
    await tester.pumpWidget(
      await appFrame(
        StatefulBuilder(
          builder: (context, setState) => Padding(
            padding: const EdgeInsets.all(20),
            child: MealEditor(items: items, onChanged: (v) => setState(() => items = v)),
          ),
        ),
      ),
    );
    expect(find.text('Bỏ món này'), findsNothing, reason: 'a meal keeps at least one dish');
    await tester.tap(find.bySemanticsLabel('Thêm nửa phần'));
    await tester.pump();
    expect(items.single.servings, 4);
    await tester.tap(find.bySemanticsLabel('Thêm nửa phần'));
    await tester.pump();
    expect(items.single.servings, 4, reason: 'disabled at four');
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.bySemanticsLabel('Bớt nửa phần'));
      await tester.pump();
    }
    expect(items.single.servings, 0.5);
    expect(find.text('0,5 phần'), findsOneWidget);
    expect(find.text('225 kcal'), findsNWidgets(2), reason: 'dish and total');
  });

  test('servings text', () {
    expect(servingsText(1), '1 phần');
    expect(servingsText(1.5), '1,5 phần');
    expect(servingsText(0.5), '0,5 phần');
  });

  test('the demo picks the same sample for the same photo', () async {
    final a = await MealAnalysisCall(mealPhotoBytes).result;
    final b = await MealAnalysisCall(Uint8List.fromList(mealPhotoBytes)).result;
    expect(a.source, 'demo');
    expect(a.confidence, MealConfidence.medium);
    expect([for (final f in a.items) f.name], [for (final f in b.items) f.name]);
    // FNV-1a as the web app computes it (Math.imul, then >>> 0)
    expect(photoFingerprint(Uint8List.fromList([1, 2, 3])), 0x040c5b8c);
    expect(photoFingerprint(mealPhotoBytes), 134425600);
    expect(a.items.first.name, 'Ức gà áp chảo');
  });

  test('service answers are parsed', () {
    final r = parseMealAnalysis({
      'isFood': true,
      'items': [sample('Bún chả').toJson()],
      'confidence': 'low',
      'note': 'Ảnh hơi tối.',
    });
    expect(r.source, 'ai');
    expect(r.confidence, MealConfidence.low);
    expect(r.items.single.kcal, 560);
  });
}
