import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vitalize/logic/meal_analyzer.dart';

// No widget binding here: it would replace HttpClient with one that always answers 400.
void main() {
  late HttpServer server;
  late String url;
  (int, Object) Function(Map<String, dynamic> request) handler = (_) => (200, {});
  Map<String, dynamic>? lastRequest;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    url = 'http://127.0.0.1:${server.port}/analyze';
    server.listen((req) async {
      lastRequest = jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>;
      final (status, body) = handler(lastRequest!);
      if (status == 0) return; // never answers
      req.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await req.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  final photo = Uint8List.fromList(List.generate(300, (i) => i % 256));

  test('no endpoint is configured yet: demo mode', () {
    expect(mealApiUrl, isNull);
    expect(aiEnabled, isFalse);
  });

  test('posts the photo and reads the answer', () async {
    handler = (_) => (
      200,
      {
        'isFood': true,
        'items': [
          {
            'name': 'Phở gà',
            'portion': '1 tô',
            'grams': 500,
            'kcal': 420,
            'protein': 28,
            'carb': 52,
            'fat': 9,
          },
        ],
        'confidence': 'high',
        'note': 'Rõ món.',
      },
    );
    final r = await MealAnalysisCall(photo, endpoint: url).result;
    expect(lastRequest!['mediaType'], 'image/jpeg');
    expect(base64Decode(lastRequest!['image'] as String), photo);
    expect(r.source, 'ai');
    expect(r.isFood, isTrue);
    expect(r.items.single.name, 'Phở gà');
    expect(r.confidence, MealConfidence.high);
  });

  test('busy and failed answers have messages for the user', () async {
    handler = (_) => (429, {});
    await expectLater(
      MealAnalysisCall(photo, endpoint: url).result,
      throwsA(
        isA<MealAnalysisError>().having(
          (e) => e.message,
          'message',
          'Đang quá tải, thử lại sau ít phút.',
        ),
      ),
    );
    handler = (_) => (500, {});
    await expectLater(
      MealAnalysisCall(photo, endpoint: url).result,
      throwsA(
        isA<MealAnalysisError>().having(
          (e) => e.message,
          'message',
          'Không phân tích được ảnh, thử lại nhé.',
        ),
      ),
    );
    handler = (_) => (200, {'unexpected': true});
    await expectLater(
      MealAnalysisCall(photo, endpoint: url).result,
      throwsA(isA<MealAnalysisError>()),
    );
  });

  test('the media type follows the bytes', () {
    expect(photoMediaType(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])), 'image/jpeg');
    expect(photoMediaType(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D])), 'image/png');
    expect(photoMediaType(Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39])), 'image/gif');
    expect(photoMediaType(Uint8List(0)), 'image/jpeg');
  });

  test('a cancelled call never completes', () async {
    handler = (_) => (0, {});
    final call = MealAnalysisCall(photo, endpoint: url);
    var done = false;
    call.result.then((_) => done = true, onError: (_) => done = true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    call.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(done, isFalse);
    expect(call.cancelled, isTrue);
  });
}
