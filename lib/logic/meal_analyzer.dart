import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/catalog.dart';
import '../data/models.dart';
import 'meal_photo.dart';

/// Endpoint of the meal analysis service. Not set yet: the service needs a small backend that
/// keeps the model API key off the device (see docs/ai-meal-analysis.md in the web app). Without
/// it the app runs in demo mode and says so on screen. Set it at build time with
/// `--dart-define=MEAL_API_URL=https://…`.
const String? mealApiUrl = bool.hasEnvironment('MEAL_API_URL')
    ? String.fromEnvironment('MEAL_API_URL')
    : null;

bool get aiEnabled => mealApiUrl != null && mealApiUrl!.isNotEmpty;

enum MealConfidence { low, medium, high }

class MealAnalysis {
  const MealAnalysis({
    required this.isFood,
    required this.items,
    required this.confidence,
    required this.note,
    required this.source,
  });

  final bool isFood;
  final List<FoodItem> items;
  final MealConfidence confidence;

  /// One short sentence for the user, e.g. what was hard to judge.
  final String note;

  /// `demo` until an analysis endpoint is configured, then `ai`.
  final String source;
}

/// A failure with a message that can be shown as is.
class MealAnalysisError implements Exception {
  const MealAnalysisError(this.message);

  final String message;

  @override
  String toString() => message;
}

const _failed = 'Không phân tích được ảnh, thử lại nhé.';

/// One analysis of a photo (a JPEG from the picker). [cancel] drops the request when the screen
/// goes away or the user retries; the result then never completes.
class MealAnalysisCall {
  MealAnalysisCall(Uint8List photo, {String? endpoint}) {
    final url = endpoint ?? (aiEnabled ? mealApiUrl : null);
    _run(url == null ? _demo(photo) : _post(url, photo));
  }

  final _done = Completer<MealAnalysis>();
  HttpClient? _client;
  bool _cancelled = false;

  Future<MealAnalysis> get result => _done.future;

  bool get cancelled => _cancelled;

  void cancel() {
    _cancelled = true;
    _client?.close(force: true);
  }

  Future<void> _run(Future<MealAnalysis> work) async {
    try {
      final r = await work;
      if (!_cancelled) _done.complete(r);
    } catch (e) {
      if (_cancelled) return;
      _done.completeError(e is MealAnalysisError ? e : const MealAnalysisError(_failed));
    }
  }

  Future<MealAnalysis> _demo(Uint8List photo) async {
    final samples = catalog.sampleMeals;
    // Same photo, same sample: the demo stays consistent if you retry.
    final pick = samples[photoFingerprint(photo) % samples.length];
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    return MealAnalysis(
      isFood: true,
      items: [for (final f in pick) FoodItem.fromJson(f.toJson())],
      confidence: MealConfidence.medium,
      note: 'Đây là kết quả mẫu để thử giao diện, chưa phải AI xem ảnh của bạn.',
      source: 'demo',
    );
  }

  Future<MealAnalysis> _post(String url, Uint8List photo) async {
    final client = _client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final req = await client.postUrl(Uri.parse(url));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'image': base64Encode(photo), 'mediaType': photoMediaType(photo)}));
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw MealAnalysisError(
          res.statusCode == 429 ? 'Đang quá tải, thử lại sau ít phút.' : _failed,
        );
      }
      return parseMealAnalysis(jsonDecode(text) as Map<String, dynamic>);
    } finally {
      client.close();
    }
  }
}

/// The picker re-encodes photos as JPEG, except PNG and GIF files, which it only resizes.
String photoMediaType(Uint8List bytes) {
  bool starts(List<int> sig) =>
      bytes.length >= sig.length && listEquals(bytes.sublist(0, sig.length), sig);
  if (starts(const [0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (starts(const [0x47, 0x49, 0x46, 0x38])) return 'image/gif';
  return 'image/jpeg';
}

/// The service's JSON answer: `{isFood, items, confidence, note}`.
MealAnalysis parseMealAnalysis(Map<String, dynamic> j) => MealAnalysis(
  isFood: j['isFood'] as bool,
  items: [for (final i in j['items'] as List) FoodItem.fromJson(i as Map<String, dynamic>)],
  confidence: MealConfidence.values.byName(j['confidence'] as String),
  note: j['note'] as String? ?? '',
  source: 'ai',
);
