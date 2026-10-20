import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:vitalize/logic/jpeg_encoder.dart';
import 'package:vitalize/logic/meal_photo.dart';

import 'food_week_support.dart';

Future<(ui.Image, Uint8List)> _decode(Uint8List jpeg) async {
  final codec = await ui.instantiateImageCodec(jpeg);
  final image = (await codec.getNextFrame()).image;
  final px = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  return (image, px);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('standard Huffman tables are complete prefix codes', () {
    for (final spec in [jpegDcLuma, jpegDcChroma, jpegAcLuma, jpegAcChroma]) {
      expect(spec.counts.length, 16);
      expect(spec.counts.fold(0, (a, b) => a + b), spec.symbols.length);
      expect(spec.symbols.toSet().length, spec.symbols.length, reason: 'no repeats');
    }
    final ac = {
      0x00,
      0xF0,
      for (var run = 0; run < 16; run++)
        for (var size = 1; size <= 10; size++) run << 4 | size,
    };
    expect(jpegAcLuma.symbols.toSet(), ac);
    expect(jpegAcChroma.symbols.toSet(), ac);
    expect(jpegZigzag.toSet().length, 64);
    expect(jpegZigzag.take(10), [0, 1, 8, 16, 9, 2, 3, 10, 17, 24]);
  });

  test('a gradient survives the round trip, odd sizes included', () async {
    const w = 37, h = 23;
    final rgba = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final o = (y * w + x) * 4;
        rgba[o] = (x * 255 / (w - 1)).round();
        rgba[o + 1] = (y * 255 / (h - 1)).round();
        rgba[o + 2] = 90;
        rgba[o + 3] = 255;
      }
    }
    final jpeg = encodeJpeg(rgba, w, h, quality: 90);
    expect(jpeg.sublist(0, 2), [0xFF, 0xD8]);
    expect(jpeg.sublist(jpeg.length - 2), [0xFF, 0xD9]);
    final (image, px) = await _decode(jpeg);
    expect((image.width, image.height), (w, h));
    var err = 0;
    for (var i = 0; i < px.length; i++) {
      if (i % 4 != 3) err += (px[i] - rgba[i]).abs();
    }
    expect(err / (w * h * 3), lessThan(4), reason: 'mean error per channel');
  });

  test('a meal photo becomes a small thumbnail', () async {
    final b64 = await mealThumbnail(mealPhotoBytes);
    final jpeg = decodeMealPhoto(b64)!;
    final (image, px) = await _decode(jpeg);
    expect((image.width, image.height), (220, 165));
    expect(jpeg.length, lessThan(16000));
    // the plate's warm brown background is still brown in a corner
    expect(px[0], greaterThan(px[2] + 20));
    expect(decodeMealPhoto('data:image/jpeg;base64,$b64'), jpeg);
    expect(decodeMealPhoto('not base64 at all!'), isNull);
  });
}
