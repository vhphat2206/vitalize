import '../data/models.dart';
import '../state/log_store.dart';

const _weekdays = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ nhật'];

/// Short weekday labels, Monday first.
const weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

String unitLabel(String unit) => unit == 'seconds' ? 'giây' : 'lần';

/// "3 hiệp × 8–12 lần mỗi bên"
String doseText(Dose d) =>
    '${d.sets} hiệp × ${d.target} ${unitLabel(d.unit)}${d.perSide ? ' mỗi bên' : ''}';

/// 90 → "90 giây", 120 → "2 phút", 150 → "2 phút 30 giây" (gyms say "nghỉ 90 giây").
String restText(int seconds) {
  if (seconds < 120) return '$seconds giây';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return s > 0 ? '$m phút $s giây' : '$m phút';
}

/// 0:32, 12:05
String clock(num totalSeconds) {
  final s = totalSeconds.ceil().clamp(0, 1 << 31);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// 367 → "6 phút", 45 → "45 giây"
String minutesText(int totalSeconds) {
  if (totalSeconds < 60) return '$totalSeconds giây';
  return '${(totalSeconds / 60).round()} phút';
}

/// "60 kg × 8", "12 lần", "40 giây"
String setText({double? kg, int? reps, int? seconds}) {
  if (seconds != null) return '$seconds giây';
  final r = reps ?? 0;
  return kg != null ? '${formatKg(kg)} kg × $r' : '$r lần';
}

String setTextOf(LoggedSet s) => setText(kg: s.kg, reps: s.reps, seconds: s.seconds);

String formatKg(double kg) =>
    kg == kg.roundToDouble() ? kg.toInt().toString() : kg.toStringAsFixed(1);

/// "Thứ Hai 20/10"
String dayTitle(DateTime d) => '${_weekdays[d.weekday - 1]} ${d.day}/${d.month}';

/// "07:45"
String timeText(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// 1240 → "1.240" (Vietnamese thousands separator).
String formatNumber(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}
