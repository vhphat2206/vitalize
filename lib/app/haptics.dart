import 'package:flutter/services.dart';

/// Haptic feedback, following the "Rung khi đếm giờ" setting (kept in sync by the prefs store).
abstract final class Haptics {
  static bool enabled = true;

  /// Light tick: selecting a muscle, the last seconds of a timer.
  static void tick() {
    if (enabled) HapticFeedback.lightImpact();
  }

  /// Firmer bump: a timer phase changes.
  static void bump() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  /// Something was saved.
  static void success() {
    if (enabled) HapticFeedback.heavyImpact();
  }
}
