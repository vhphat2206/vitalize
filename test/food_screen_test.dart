import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vitalize/app/tabs.dart';
import 'package:vitalize/screens/food_screen.dart';
import 'package:vitalize/screens/meal_detail_screen.dart';
import 'package:vitalize/screens/meal_scan_screen.dart';
import 'package:vitalize/widgets/icons.dart';

import 'food_week_support.dart';
import 'support/harness.dart';

void main() {
  setUpAll(setUpApp);

  testWidgets('empty day, no body data', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(await appFrame(FoodScreen(now: testNow)));
    await tester.pump(const Duration(milliseconds: 250));
    await snap(tester, 'food-entrance');
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Hôm nay, thứ ba 20/10'), findsOneWidget);
    expect(find.text('Chưa có bữa nào hôm nay.'), findsOneWidget);
    expect(
      find.textContaining('Hiện app đang ở chế độ thử, kết quả là mẫu.', findRichText: true),
      findsOneWidget,
    );
    await snap(tester, 'food-empty');
    await expectLater(find.byType(FoodScreen), matchesGoldenFile('goldens/food_empty.png'));
  });

  testWidgets('targets and today\'s meals by slot', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(
      await appFrame(
        FoodScreen(now: testNow),
        seed: (log, prefs) {
          seedStores(log, prefs, profile: true);
          seedMeals().forEach(log.restoreMeal);
        },
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await loadImages(tester);
    // 420 + 640 + 1.5 × 90 + 190 kcal eaten of 2.230.
    expect(
      find.textContaining('Đã ăn 1.385 trong 2.230 kcal. Còn khoảng 845 kcal.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('70/109 g'), findsOneWidget);
    for (final t in ['Bữa sáng', 'Bữa trưa', 'Bữa phụ']) {
      expect(find.text(t), findsOneWidget);
    }
    expect(find.text('Bữa tối'), findsNothing, reason: 'yesterday\'s dinner is not today');
    expect(find.text('Cơm tấm sườn nướng, Trứng ốp la'), findsOneWidget);
    expect(find.text('775 kcal'), findsNWidgets(2), reason: 'slot total and row');
    await snap(tester, 'food-targets');
    await expectLater(find.byType(FoodScreen), matchesGoldenFile('goldens/food_targets.png'));

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
    await tester.pump(const Duration(seconds: 1));
    await snap(tester, 'food-targets-bottom');
  });

  testWidgets('the link to the profile switches tab', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(await appFrame(FoodScreen(now: testNow)));
    await tester.pump(const Duration(seconds: 2));
    final nav = Provider.of<TabNav>(tester.element(find.byType(FoodScreen)), listen: false);
    await tester.tap(find.text('Nhập chiều cao, cân nặng để biết mỗi ngày nên ăn bao nhiêu'));
    expect(nav.tab, AppTab.profile);
  });

  testWidgets('a meal opens; a photo goes to the scan screen', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(
      await appFrame(
        FoodScreen(now: testNow, pickPhoto: (_) async => mealPhotoBytes),
        seed: (log, _) => seedMeals().forEach(log.restoreMeal),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Bánh mì thịt'));
    await tester.pumpAndSettle();
    expect(find.byType(MealDetailScreen), findsOneWidget);
    await tester.tap(find.byWidgetPredicate((w) => w is VIcon && w.glyph == VIcons.back));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chọn ảnh có sẵn'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(MealScanScreen), findsOneWidget);
    // let the demo analysis finish so no timer is left pending
    await tester.pump(const Duration(seconds: 2));
  });

  group('photos', () {
    const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
    const picker = MethodChannel('plugins.flutter.io/image_picker');

    void mock(WidgetTester tester, MethodChannel channel, Future<Object?> Function(MethodCall) f) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, f);
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
      );
    }

    testWidgets('camera refused on iOS: a sheet leads to Settings', (tester) async {
      final calls = <String>[];
      var pickerOpened = false;
      mock(tester, permissions, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'requestPermissions' => {for (final p in call.arguments as List) p: 4},
          'openAppSettings' => true,
          _ => null,
        };
      });
      mock(tester, picker, (call) async {
        pickerOpened = true;
        return null;
      });
      await usePhone(tester);
      await tester.pumpWidget(await appFrame(FoodScreen(now: testNow)));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Chụp món ăn'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(calls, ['requestPermissions']);
      expect(pickerOpened, isFalse);
      expect(find.text('Chưa được dùng camera'), findsOneWidget);
      expect(
        find.text('Để chụp món ăn, hãy cho Vitalize dùng camera trong Cài đặt của máy.'),
        findsOneWidget,
      );
      await snap(tester, 'camera-refused');
      await tester.tap(find.text('Mở Cài đặt'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(calls, ['requestPermissions', 'openAppSettings']);
      expect(find.text('Chưa được dùng camera'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('on Android the camera opens without asking first', (tester) async {
      var asked = false, opened = false;
      mock(tester, permissions, (call) async {
        asked = true;
        return {for (final p in call.arguments as List) p: 4};
      });
      mock(tester, picker, (call) async {
        opened = true;
        return null; // cancelled
      });
      await usePhone(tester);
      await tester.pumpWidget(await appFrame(FoodScreen(now: testNow)));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Chụp món ăn'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(asked, isFalse);
      expect(opened, isTrue);
      expect(find.byType(MealScanScreen), findsNothing);
    });

    testWidgets('photos refused: the same sheet for the library', (tester) async {
      mock(tester, picker, (call) async {
        throw PlatformException(code: 'photo_access_denied');
      });
      await usePhone(tester);
      await tester.pumpWidget(await appFrame(FoodScreen(now: testNow)));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Chọn ảnh có sẵn'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Chưa được xem ảnh'), findsOneWidget);
      await tester.tap(find.text('Để sau'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Chưa được xem ảnh'), findsNothing);
    });

    testWidgets('the camera is asked for a 1024 px JPEG, which goes to the scan', (tester) async {
      final file = File('${Directory.systemTemp.createTempSync().path}/meal.jpg')
        ..writeAsBytesSync(mealPhotoBytes);
      Map<Object?, Object?>? args;
      mock(tester, permissions, (call) async {
        return {for (final p in call.arguments as List) p: 1};
      });
      mock(tester, picker, (call) async {
        args = call.arguments as Map<Object?, Object?>;
        return file.path;
      });
      await usePhone(tester);
      await tester.pumpWidget(await appFrame(FoodScreen(now: testNow)));
      await tester.pump(const Duration(seconds: 2));
      await tester.runAsync(() async {
        await tester.tap(find.text('Chụp món ăn'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(args, containsPair('source', 0));
      expect(args, containsPair('maxWidth', 1024.0));
      expect(args, containsPair('maxHeight', 1024.0));
      expect(args, containsPair('imageQuality', 82));
      expect(tester.widget<MealScanScreen>(find.byType(MealScanScreen)).photo, mealPhotoBytes);
      await tester.pump(const Duration(seconds: 2));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
