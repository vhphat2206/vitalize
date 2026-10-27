# Phần 4: Xem lại các tuần trước

> Gặp cú pháp lạ thì tra [00-kien-thuc-nen.md](00-kien-thuc-nen.md). Phần này chỉ sửa **một
> file**, là phần dễ nhất.

## Vì sao cần

Tab **Tuần này** chỉ xem được tuần hiện tại. Sang thứ Hai là số liệu tuần trước "biến mất" khỏi
màn hình, dù vẫn còn trên Firestore. Người tập cần so sánh với tuần trước để biết mình tiến bộ hay
không.

## Làm xong phần này, app sẽ có

- Cạnh dòng ngày tháng (`20/10 – 26/10`) có nút **‹** (tuần trước). Khi đang xem tuần cũ thì có
  thêm nút **›** (tuần sau).
- Tiêu đề đổi theo: **Tuần này** → **Tuần trước** → **2 tuần trước** → …
- Hình cơ thể tô màu, các ngày có tập, danh sách hiệp: tất cả hiện theo tuần đang xem.
- Ô *hôm nay* vẫn chỉ được đánh dấu khi đang xem tuần này.

## Hiểu code hiện tại trước khi sửa

`lib/logic/week.dart` có sẵn các hàm:

| Hàm | Nhận | Trả |
|---|---|---|
| `weekDays(d)` | một ngày `d` bất kỳ | 7 ngày (Thứ Hai → Chủ Nhật) **của tuần chứa `d`** |
| `inWeek(at, d)` | thời điểm `at`, ngày `d` | `at` có nằm trong tuần chứa `d` không |
| `isSameDay(a, b)` | 2 ngày | có cùng ngày không |

Trong `week_screen.dart`, mọi chỗ đều truyền `now` (hôm nay), nên luôn ra tuần này. **Ý tưởng:**
thay `now` bằng **một ngày nằm trong tuần muốn xem**, gọi là `shown`:

```
shown = hôm nay − 7 × _back ngày
_back = 0 → tuần này · 1 → tuần trước · 2 → 2 tuần trước …
```

Riêng phần đánh dấu "hôm nay" vẫn dùng `now`.

---

## Bước 0: Tạo nhánh

```bash
git switch main
```

```bash
git pull
```

```bash
git switch -c feature/week-history
```

---

## Bước 1: Thêm biến `_back`

Mở `lib/screens/week_screen.dart`. **Dòng 33**:

```dart
class _WeekScreenState extends State<WeekScreen> with TabEntrance {
```

Thêm **ngay dưới**:

```dart
  /// How many weeks back from this one: 0 this week, 1 last week …
  int _back = 0;

```

Biến nằm trong `State`, nên đổi giá trị bằng `setState` thì màn hình vẽ lại. Chuyển sang tab khác
rồi quay lại vẫn giữ tuần đang xem, vì các tab trong `IndexedStack` (xem `lib/app/shell.dart`)
không bị huỷ.

---

## Bước 2: Lọc dữ liệu theo tuần đang xem

Trong `build`, **dòng 50–59**:

```dart
    final now = widget.now ?? DateTime.now();
    final days = weekDays(now);
    final sets = [
      for (final s in log.sets)
        if (inWeek(s.at, now)) s,
    ];
    final sessions = [
      for (final s in log.sessions)
        if (inWeek(s.at, now)) s,
    ];
```

Thay bằng:

```dart
    final now = widget.now ?? DateTime.now();
    // A day in the week on show; "today" stays [now].
    final shown = DateTime(now.year, now.month, now.day - 7 * _back);
    final days = weekDays(shown);
    final sets = [
      for (final s in log.sets)
        if (inWeek(s.at, shown)) s,
    ];
    final sessions = [
      for (final s in log.sessions)
        if (inWeek(s.at, shown)) s,
    ];
```

**Thay đổi:** thêm dòng `shown`, và đổi `now` thành `shown` ở **3 chỗ**: `weekDays(...)` và hai lần
`inWeek(...)`.

**Vì sao `DateTime(năm, tháng, ngày - 7)` mà không dùng `now.subtract(Duration(days: 7))`?**
- `DateTime(2026, 11, 3 - 7)` Dart tự hiểu là 27/10/2026, lùi qua tháng và qua năm đều đúng.
- `subtract(Duration(...))` trừ đúng `7×24` giờ, nên có thể lệch giờ ở những nước đổi giờ mùa
  hè. Project này cũng dùng cách `DateTime(y, m, d ± n)` trong `week.dart`.

Dòng `today: isSameDay(d, now)` ở phía dưới **giữ nguyên `now`**. Khi xem tuần cũ, không ô nào là
"hôm nay", đúng như mong muốn.

---

## Bước 3: Tiêu đề và nút chuyển tuần

Khoảng **dòng 88–95**:

```dart
            TabHead(
              title: 'Tuần này',
              replay: entrance,
              subtitle: Text(
                '${first.day}/${first.month} – ${last.day}/${last.month}',
                style: VT.mono(13, height: 1.5, color: V.muted),
              ),
            ),
```

Thay **cả khối** bằng:

```dart
            TabHead(
              title: switch (_back) {
                0 => 'Tuần này',
                1 => 'Tuần trước',
                _ => '$_back tuần trước',
              },
              replay: entrance,
              subtitle: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${first.day}/${first.month} – ${last.day}/${last.month}',
                      style: VT.mono(13, height: 1.5, color: V.muted),
                    ),
                  ),
                  IconBtn(
                    VIcons.back,
                    label: 'Tuần trước',
                    onPressed: () => setState(() => _back++),
                  ),
                  if (_back > 0)
                    IconBtn(
                      VIcons.chevronRight,
                      label: 'Tuần sau',
                      onPressed: () => setState(() => _back--),
                    ),
                ],
              ),
            ),
```

### Đọc hiểu

- `TabHead` (trong `lib/screens/food/entrance.dart`) nhận `subtitle` là **một widget bất kỳ**.
  Trước đây là `Text`, giờ là `Row` gồm chữ ngày + các nút.
- `Expanded` cho chữ ngày chiếm hết chỗ trống, đẩy nút sang phải.
- `IconBtn(glyph, label:, onPressed:)`: nút icon 44×44 có sẵn trong `controls.dart`. `label` để
  trình đọc màn hình (TalkBack) đọc tên nút.
- `VIcons.back` (‹) và `VIcons.chevronRight` (›) đã có trong `icons.dart`.
- `if (_back > 0) IconBtn(...)`: đang ở tuần này thì không có nút "tuần sau" (không xem được tương
  lai).
- `switch (_back) { 0 => ..., 1 => ..., _ => ... }`: switch biểu thức, `_` là "các số còn lại".
- File đã import `controls.dart` và `icons.dart` sẵn, nên **không cần thêm import**.

---

## Bước 4: Câu tóm tắt khi tuần cũ trống

Hàm `weekSentence` khi không có gì sẽ trả về *"Tuần này chưa có gì. Mở một bài tập và bấm…"*. Với
tuần cũ thì câu đó sai. **Khoảng dòng 118** (trong `build`):

```dart
                weekSentence(sets.length, sessions.length, volume),
```

Thay bằng:

```dart
                _back > 0 && sets.isEmpty && sessions.isEmpty
                    ? 'Tuần đó bạn chưa ghi hiệp hay buổi tập nào.'
                    : weekSentence(sets.length, sessions.length, volume),
```

`điều kiện ? A : B`: đúng thì dùng A, sai thì dùng B.

---

## Bước 5: Kiểm tra, thử, commit, push

```bash
flutter analyze
```

```bash
flutter test
```

Ảnh golden của tab Tuần này sẽ fail vì có thêm nút ‹. Tạo lại:

```bash
flutter test --update-goldens
```

Thử trên app (`r` là đủ, vì chỉ sửa giao diện):

| # | Thao tác | Kết quả đúng |
|---|---|---|
| 1 | Tab Tuần này | Tiêu đề *Tuần này*, có nút ‹, **không** có › |
| 2 | Bấm ‹ | Tiêu đề *Tuần trước*, ngày lùi 7 ngày, có thêm › |
| 3 | Bấm ‹ lần nữa | *2 tuần trước* |
| 4 | Bấm › 2 lần | Về *Tuần này*, nút › biến mất |
| 5 | Ở tuần trống | Câu *Tuần đó bạn chưa ghi hiệp hay buổi tập nào.* |

Muốn có dữ liệu tuần trước để chụp ảnh báo cáo: Firebase Console → Firestore →
`users/<UID>/sets` → mở một document → sửa trường `at` lùi về tuần trước.

```bash
git add lib/screens/week_screen.dart test/goldens
```

```bash
git commit -m "feat: xem lai cac tuan truoc trong tab Tuan nay"
```

```bash
git push -u origin feature/week-history
```

Tạo Pull Request → merge → `git switch main` → `git pull`.

---

## Tự kiểm tra

1. Vì sao dòng `today: isSameDay(d, now)` phải giữ `now` chứ không đổi thành `shown`?
2. Muốn giới hạn chỉ xem tối đa 52 tuần, bạn sửa dòng nào? *(Gợi ý: `onPressed` của nút ‹.)*
3. Thử thêm vào bên dưới tiêu đề một câu so sánh "Tuần này hơn tuần trước 5 hiệp". Bạn cần lọc
   những `sets` nào?
