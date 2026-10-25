import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../state/log_store.dart';
import 'jpeg_encoder.dart';

/// Photos are taken or picked through image_picker as a JPEG with the long edge capped at this:
/// enough for a plate to stay readable for the analysis, and sharp on the scan screen.
const mealPhotoEdge = 1024.0;

/// JPEG quality of picked photos (the web app re-encodes at 0.82).
const mealPhotoQuality = 82;

/// Small thumbnail for the meal log, base64 JPEG (no `data:` prefix): long edge 220 px at 72 %,
/// small enough to keep inside the meal's Firestore document.
Future<String> mealThumbnail(Uint8List photo, {int maxEdge = 220, int quality = 72}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(photo);
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (w, h) {
      final scale = math.min(1.0, maxEdge / math.max(w, h));
      return ui.TargetImageSize(
        width: math.max(1, (w * scale).round()),
        height: math.max(1, (h * scale).round()),
      );
    },
  );
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final jpeg = encodeJpeg(
        data!.buffer.asUint8List(),
        image.width,
        image.height,
        quality: quality,
      );
      return base64Encode(jpeg);
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

/// Cheap stable fingerprint of a photo's bytes (FNV-1a over a sample), as the web app computes it.
int photoFingerprint(Uint8List bytes) {
  final n = math.min(bytes.length, 64 * 1024);
  var h = 0x811c9dc5;
  for (var i = 0; i < n; i += 7) {
    h ^= bytes[i];
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

/// The bytes of a stored photo: base64, with or without a `data:` URL prefix.
Uint8List? decodeMealPhoto(String photo) {
  final comma = photo.indexOf(',');
  try {
    return base64Decode(comma >= 0 ? photo.substring(comma + 1) : photo);
  } on FormatException {
    return null;
  }
}

final _images = <String, (String, MemoryImage)>{};

/// A meal's photo as an image provider, decoded once per meal so rebuilds don't flash it.
ImageProvider? mealPhotoImage(LoggedMeal meal) {
  final photo = meal.photo;
  if (photo == null || photo.isEmpty) return null;
  final hit = _images[meal.id];
  if (hit != null && hit.$1 == photo) return hit.$2;
  final bytes = decodeMealPhoto(photo);
  if (bytes == null) return null;
  if (_images.length >= 64) _images.remove(_images.keys.first);
  final image = MemoryImage(bytes);
  _images[meal.id] = (photo, image);
  return image;
}
