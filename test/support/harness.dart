import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalize/app/tabs.dart';
import 'package:vitalize/app/theme.dart';
import 'package:vitalize/data/catalog.dart';
import 'package:vitalize/state/log_store.dart';
import 'package:vitalize/state/prefs_store.dart';
import 'package:vitalize/widgets/floor.dart';

const _fonts = {
  'Prompt': ['Prompt-Medium.ttf', 'Prompt-SemiBold.ttf'],
  'BeVietnamPro': [
    'BeVietnamPro-Regular.ttf',
    'BeVietnamPro-Medium.ttf',
    'BeVietnamPro-SemiBold.ttf',
    'BeVietnamPro-Bold.ttf',
  ],
  'JetBrainsMono': ['JetBrainsMono-Regular.ttf', 'JetBrainsMono-Medium.ttf'],
};

bool _ready = false;

/// Loads the real fonts (tests otherwise draw boxes) and the content, once per test file.
Future<void> setUpApp() async {
  if (_ready) return;
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final MapEntry(key: family, value: files) in _fonts.entries) {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await loader.load();
  }
  await Catalog.load();
  _ready = true;
}

/// A phone-sized app frame around [child], with fresh stores (optionally pre-filled) on an
/// in-memory Firestore.
Future<Widget> appFrame(
  Widget child, {
  Map<String, Object> prefs = const {},
  void Function(LogStore log, PrefsStore prefs)? seed,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final user = Future.value(FakeFirebaseFirestore().collection('users').doc('tester'));
  final log = LogStore(user);
  final p = PrefsStore(sp, user);
  seed?.call(log, p);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: p),
      ChangeNotifierProvider.value(value: log),
      ChangeNotifierProvider(create: (_) => TabNav()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, c) => Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(style: VT.body, child: c!),
      ),
      home: Floor(child: child),
    ),
  );
}

/// iPhone 17-sized surface (402×874 points, 3x) with its safe areas.
Future<void> usePhone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 186, bottom: 102);
  tester.view.viewPadding = const FakeViewPadding(top: 186, bottom: 102);
  addTearDown(tester.view.reset);
}
