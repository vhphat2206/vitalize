import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitalize/widgets/body_figure.dart';
import 'package:vitalize/widgets/muscle_plate.dart';

import 'support/harness.dart';

void main() {
  setUpAll(setUpApp);

  testWidgets('body figure paints tones and fibres', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(
      await appFrame(
        const Row(
          children: [
            Expanded(
              child: BodyFigure(
                side: 'front',
                tones: {'chest': Tone.primary, 'deltoids': Tone.secondary, 'abs': Tone.vol2},
              ),
            ),
            Expanded(
              child: BodyFigure(
                side: 'back',
                compact: true,
                tones: {'upper-back': Tone.primary, 'trapezius': Tone.secondary},
              ),
            ),
          ],
        ),
      ),
    );
    await expectLater(find.byType(Row).first, matchesGoldenFile('goldens/body_figure.png'));
  });

  testWidgets('muscle plate', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(
      await appFrame(
        const Padding(
          padding: EdgeInsets.all(20),
          child: MusclePlate(primary: ['chest'], secondary: ['triceps', 'deltoids']),
        ),
      ),
    );
    await expectLater(find.byType(MusclePlate), matchesGoldenFile('goldens/muscle_plate.png'));
  });
}
