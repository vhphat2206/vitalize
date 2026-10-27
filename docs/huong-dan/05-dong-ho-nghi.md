# Phần 5: Đồng hồ nghỉ giữa hiệp

> Gặp cú pháp lạ thì tra [00-kien-thuc-nen.md](00-kien-thuc-nen.md), đặc biệt mục 5 (vòng đời
> `StatefulWidget`).

## Vì sao cần

Mỗi bài tập đã có thời gian nghỉ khuyến nghị (`ex.dose.rest`, hiện ở ô **Nghỉ** trong màn bài tập,
ví dụ *90 giây*). Nhưng app chỉ hiện con số, người tập phải tự canh đồng hồ.

## Làm xong phần này, app sẽ có

Sau khi bấm **Lưu hiệp**, phía trên nút *Ghi một hiệp* hiện một dòng:

```
Nghỉ   1:30                    [+15 giây]  [Bỏ qua]
```

- Số giây đếm ngược, rung nhẹ ở 3 giây cuối, rung mạnh khi hết giờ (theo cài đặt **Rung khi đếm
  giờ**).
- **+15 giây**: nghỉ thêm. **Bỏ qua**: tắt đồng hồ.
- Ghi tiếp hiệp mới thì đồng hồ bắt đầu lại.

## Bản đồ việc cần làm

| Bước | Việc | File | Commit |
|---|---|---|---|
| 0 | Tạo nhánh | — | — |
| 1 | Widget đếm ngược | `lib/widgets/rest_timer.dart` (mới) | ✔ |
| 2 | Màn bài tập nhớ "nghỉ đến lúc nào" | `lib/screens/exercise_screen.dart` | ✔ |
| 3 | Thử, push, PR | — | — |

**Vì sao đặt `RestTimer` ở `widgets/` chứ không ở `screens/`?** Nó là mảnh giao diện dùng lại được
(ví dụ sau này cho màn buổi tập), không phải một màn hình.

---

## Bước 0: Tạo nhánh

```bash
git switch main
```

```bash
git pull
```

```bash
git switch -c feature/rest-timer
```

---

## Bước 1: Tạo `lib/widgets/rest_timer.dart`

```dart
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../app/haptics.dart';
import '../app/theme.dart';
import '../logic/format.dart';
import 'controls.dart';

/// Rest between sets, counting down to [until]: a tick in the last 3 seconds, a bump at zero.
/// [onChanged] gets a later end ("+15 giây") or null when the rest is over or skipped.
class RestTimer extends StatefulWidget {
  const RestTimer({super.key, required this.until, required this.onChanged});

  final DateTime until;
  final ValueChanged<DateTime?> onChanged;

  @override
  State<RestTimer> createState() => _RestTimerState();
}

class _RestTimerState extends State<RestTimer> {
  late final Timer _timer;
  late int _left = _remaining();

  int _remaining() => (widget.until.difference(DateTime.now()).inMilliseconds / 1000).ceil();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  @override
  void didUpdateWidget(RestTimer old) {
    super.didUpdateWidget(old);
    if (old.until != widget.until) _left = _remaining();
  }

  void _tick() {
    final left = _remaining();
    if (left <= 0) {
      _timer.cancel();
      Haptics.bump();
      widget.onChanged(null);
      return;
    }
    if (left == _left) return;
    if (left <= 3) Haptics.tick();
    setState(() => _left = left);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Nghỉ, còn ${clock(_left)}',
    child: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text('Nghỉ', style: VT.ui(13, color: V.muted)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(clock(_left), style: VT.mono(20, weight: FontWeight.w500, height: 1)),
          ),
          GhostButton(
            label: '+15 giây',
            onPressed: () => widget.onChanged(widget.until.add(const Duration(seconds: 15))),
          ),
          const SizedBox(width: 8),
          GhostButton(label: 'Bỏ qua', onPressed: () => widget.onChanged(null)),
        ],
      ),
    ),
  );
}
```

### Đọc hiểu: ý tưởng chính

**Lưu "thời điểm hết nghỉ" (`until`) chứ không lưu "còn bao nhiêu giây".** Mỗi lần cần thì tính
`còn lại = until − bây giờ`. Vì sao?
- Nếu đếm kiểu "mỗi giây trừ 1", app bị chậm hay màn hình tắt một lúc thì đồng hồ chạy sai.
- Tính theo giờ thật thì luôn đúng, kể cả khi người dùng thoát ra màn khác rồi quay lại.

### Đọc hiểu từng phần

| Phần | Ý nghĩa |
|---|---|
| `final DateTime until;` | widget cha truyền vào: nghỉ đến lúc nào |
| `final ValueChanged<DateTime?> onChanged;` | báo cho cha: `until` mới (bấm +15 giây) hoặc `null` (hết giờ / bỏ qua). `ValueChanged<T>` là kiểu hàm `void Function(T)` |
| `late int _left = _remaining();` | số giây còn lại đang hiện. `late` để được gọi `_remaining()` (cần `widget`) lúc khởi tạo |
| `_remaining()` | `until − now` tính bằng mili giây, chia 1000 rồi `ceil()` (làm tròn lên: còn 0,3 giây vẫn hiện 1) |
| `initState` | tạo `Timer.periodic` 250 ms. Kiểm tra 4 lần mỗi giây để số đổi đúng lúc, nhưng chỉ `setState` khi số giây thực sự đổi |
| `didUpdateWidget` | khi cha truyền `until` mới (bấm +15 giây, hoặc ghi hiệp mới) thì tính lại `_left` ngay |
| `_tick` | hết giờ (`<= 0`): dừng timer, rung, báo `null`. Còn ≤ 3 giây: rung nhẹ mỗi giây |
| `dispose` | **bắt buộc** `cancel()` timer. Không huỷ thì timer chạy mãi sau khi thoát màn hình, gọi `setState` trên widget đã chết, gây lỗi |
| `clock(_left)` | hàm có sẵn trong `lib/logic/format.dart`: `90 → "1:30"` |
| `Semantics(liveRegion: true, …)` | TalkBack tự đọc khi số thay đổi (hỗ trợ người khiếm thị) |
| `Haptics.tick()` / `bump()` | rung, đã tự tôn trọng công tắc **Rung khi đếm giờ** trong Cài đặt |

**Vì sao `RestTimer` không tự giữ `until`, mà để cha giữ?** Khi hết giờ, chính **cha** phải quyết
định bỏ widget này khỏi màn hình. Cha giữ `until`, con chỉ hiển thị và báo lại. Kiểu "cha giữ trạng
thái, con báo sự kiện" xuất hiện khắp project (`MealEditor`, `Segmented`, `SlotPicker`…).

### Kiểm tra và commit

`flutter analyze` → `No issues found!`.

```bash
git add lib/widgets/rest_timer.dart
```

```bash
git commit -m "feat: widget dem nguoc thoi gian nghi"
```

---

## Bước 2: Gắn vào màn bài tập (`lib/screens/exercise_screen.dart`)

### Vì sao phải đổi sang `StatefulWidget`

`ExerciseScreen` hiện là `StatelessWidget`, không nhớ được gì. Giờ màn hình cần **nhớ**
`_restUntil` (nghỉ đến lúc nào, hoặc `null` khi không nghỉ), nên phải thành `StatefulWidget`.

> **Lưu ý:** từ 2.2 đến 2.5, `flutter analyze` sẽ **báo lỗi giữa chừng** (ví dụ thiếu tham số
> `restUntil`). Đó là bình thường. Làm hết 6 chỗ rồi mới kiểm tra.

**2.1 Import.** **Dòng 22** là `import '../widgets/ref_list.dart';`. Thêm **ngay dưới**:

```dart
import '../widgets/rest_timer.dart';
```

**2.2 Đổi sang StatefulWidget.** **Dòng 38–45**:

```dart
class ExerciseScreen extends StatelessWidget {
  const ExerciseScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final ex = catalog.exerciseById[id];
```

Thay bằng:

```dart
class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key, required this.id});

  final String id;

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  /// When the rest after the last logged set ends; null while not resting.
  DateTime? _restUntil;

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final ex = catalog.exerciseById[id];
```

Đọc hiểu:
- Phần trên (`ExerciseScreen`) giờ chỉ giữ tham số `id` và tạo `State`.
- Phần dưới (`_ExerciseScreenState`) chứa `build` cũ và hàm `_logSet` cũ (vẫn nằm nguyên phía dưới,
  **không cần di chuyển**: dấu `}` cuối của class cũ giờ là dấu đóng của `_ExerciseScreenState`).
- Trong `State`, tham số của widget đọc qua `widget.id`. Dòng `final id = widget.id;` giúp phần code
  cũ bên dưới (đang dùng `id`) chạy mà không phải sửa.

**2.3 Truyền trạng thái nghỉ xuống `_Footer`.** **Dòng ~89** (cũ là dòng 79):

```dart
          _Footer(today: today, onLog: () => _logSet(context, ex, sets)),
```

Thay bằng:

```dart
          _Footer(
            today: today,
            restUntil: _restUntil,
            onRest: (until) => setState(() => _restUntil = until),
            onLog: () => _logSet(context, ex, sets),
          ),
```

`onRest` là hàm `RestTimer` sẽ gọi (qua `_Footer`). Nó nhận `until` mới hoặc `null`, rồi
`setState` để vẽ lại.

**2.4 Bắt đầu nghỉ khi lưu hiệp.** Trong hàm `_logSet`, tìm (khoảng **dòng 117–118**):

```dart
          Haptics.success();
          Navigator.of(sheet).pop();
```

Thêm **ngay sau** hai dòng đó:

```dart
          // The rest from the dose starts as the set is saved.
          if (ex.dose.rest > 0) {
            setState(() => _restUntil = DateTime.now().add(Duration(seconds: ex.dose.rest)));
          }
```

`ex.dose.rest` là số giây nghỉ của bài (từ `exercises.json`). Bài nào có `rest` bằng 0 thì không
bật đồng hồ.

**2.5 Thêm tham số cho `_Footer`.** Tìm `class _Footer extends StatelessWidget {` (khoảng **dòng
461**). Ngay dưới là:

```dart
  const _Footer({required this.today, required this.onLog});

  final List<LoggedSet> today;
  final VoidCallback onLog;
```

Thay bằng:

```dart
  const _Footer({
    required this.today,
    required this.restUntil,
    required this.onRest,
    required this.onLog,
  });

  final List<LoggedSet> today;
  final DateTime? restUntil;
  final ValueChanged<DateTime?> onRest;
  final VoidCallback onLog;
```

**2.6 Vẽ đồng hồ.** Vẫn trong `_Footer`, ở phần `build`, tìm dòng `if (today.isNotEmpty)` (nằm
ngay sau `children: [`). Thêm **phía trên** nó:

```dart
          if (restUntil case final until?) RestTimer(until: until, onChanged: onRest),
```

Đọc: "nếu `restUntil` khác null thì gọi nó là `until` và vẽ `RestTimer`". Khi `onRest(null)` được
gọi, `_restUntil` thành `null`, `_Footer` vẽ lại, dòng này không vẽ gì, và đồng hồ biến mất
(`dispose` của nó tự huỷ timer).

### Luồng hoàn chỉnh

```
Bấm "Lưu hiệp" (_logSet)
  └─ setState(_restUntil = bây giờ + 90 giây)
        └─ _Footer(restUntil: …) ──▶ RestTimer(until: …) bắt đầu đếm
              ├─ bấm "+15 giây" ──▶ onRest(until + 15s) ──▶ setState ──▶ RestTimer.didUpdateWidget
              ├─ bấm "Bỏ qua"   ──▶ onRest(null) ──▶ setState ──▶ RestTimer bị bỏ, dispose()
              └─ hết giờ        ──▶ rung ──▶ onRest(null) ──▶ như trên
```

### Kiểm tra

```bash
flutter analyze
```

```bash
flutter test
```

Nếu ảnh golden `exercise_logged.png` fail (màn sau khi ghi hiệp giờ có thêm đồng hồ):

```bash
flutter test --update-goldens
```

Thử trên app (`r`):

| # | Thao tác | Kết quả đúng |
|---|---|---|
| 1 | Mở một bài (ví dụ Squat), xem ô **Nghỉ** | ví dụ *90 giây* |
| 2 | **Ghi một hiệp** → **Lưu hiệp** | Dòng *Nghỉ 1:30* đếm ngược phía trên nút |
| 3 | **+15 giây** | Thời gian tăng 15 giây |
| 4 | Chờ đến 0 | Rung (nếu bật), dòng Nghỉ biến mất |
| 5 | Ghi hiệp, rồi **Bỏ qua** | Biến mất ngay |
| 6 | Ghi hiệp, bấm quay lại (thoát màn), mở lại bài | Không có đồng hồ (màn mới), **không** có lỗi trong terminal |

**Commit, push:**

```bash
git add lib/screens/exercise_screen.dart test/goldens
```

```bash
git commit -m "feat: dong ho nghi giua hiep sau khi ghi mot hiep"
```

```bash
git push -u origin feature/rest-timer
```

Tạo Pull Request → merge → `git switch main` → `git pull`.

---

## Tự kiểm tra

1. Nếu xoá `_timer.cancel()` trong `dispose`, bước 6 ở bảng thử sẽ báo lỗi gì trong terminal?
   *(Gợi ý: `setState() called after dispose()`.)*
2. Vì sao `_tick` kiểm tra `left <= 0` **trước** `left == _left`? *(Gợi ý: nếu `until` đã qua ngay
   từ đầu thì `_left` và `left` đều ≤ 0.)*
3. Muốn đồng hồ vẫn còn khi thoát màn bài tập rồi quay lại, bạn sẽ chuyển `_restUntil` lên đâu?
