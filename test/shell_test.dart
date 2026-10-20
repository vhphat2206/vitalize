import 'package:flutter_test/flutter_test.dart';
import 'package:vitalize/app/shell.dart';

import 'support/harness.dart';

void main() {
  setUpAll(setUpApp);

  testWidgets('shell shows the five tabs', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(await appFrame(const Shell()));
    await tester.pump(const Duration(seconds: 2));
    for (final t in ['Cơ thể', 'Bài tập', 'Ăn uống', 'Tuần này', 'Hồ sơ']) {
      expect(find.text(t), findsWidgets);
    }
    await expectLater(find.byType(Shell), matchesGoldenFile('goldens/shell.png'));
  });
}
