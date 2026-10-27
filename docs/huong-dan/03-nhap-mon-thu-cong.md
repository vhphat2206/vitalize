# Phần 3: Nhập món ăn thủ công (có tìm kiếm không dấu)

> Gặp cú pháp lạ thì tra [00-kien-thuc-nen.md](00-kien-thuc-nen.md). Làm sau khi Phần 2 đã merge
> vào `main`.

## Vì sao cần

Hiện tại bữa ăn **chỉ** thêm được bằng cách chụp hoặc chọn ảnh, mà AI phân tích ảnh lại đang chạy
**chế độ demo** (trả kết quả mẫu, không phải món thật của bạn). Kết quả là người dùng **không có
cách nào ghi đúng món mình ăn**, và module Ăn uống gần như không dùng thật được.

## Làm xong phần này, app sẽ có

- Tab Ăn uống có thêm nút **Nhập món thủ công**, dưới hai nút chụp và chọn ảnh.
- Màn **Thêm món**:
  - ô tìm kiếm; gõ `pho`, `uc ga`… **không dấu** vẫn ra *Phở*, *Ức gà*;
  - danh sách món kèm khẩu phần và calo; bấm vào món để thêm, bấm lần nữa thì thêm ½ phần;
  - các món đã chọn hiện ở trên: chỉnh ½ phần, bỏ món, xem tổng calo;
  - chọn bữa Sáng/Trưa/Tối/Phụ → **Lưu**.
- Bữa vừa lưu hiện ở tab Ăn uống, cộng vào thanh tiến độ trong ngày.

## Bản đồ việc cần làm

| Bước | Việc | File | Commit |
|---|---|---|---|
| 0 | Tạo nhánh | — | — |
| 1 | Danh sách món | `assets/data/foods.json` (mới) | |
| 2 | Catalog đọc danh sách món | `lib/data/catalog.dart` | ✔ (gộp 1–2) |
| 3 | Hàm bỏ dấu tiếng Việt | `lib/logic/search.dart` (mới) + `test/search_test.dart` (mới) | ✔ |
| 4 | Màn Thêm món | `lib/screens/food_pick_screen.dart` (mới) | ✔ |
| 5 | Nút mở màn Thêm món | `lib/screens/food_screen.dart` | ✔ |
| 6 | Thử, push, PR | — | — |

### Những thứ đã có sẵn và sẽ được dùng lại

| Có sẵn | Ở đâu | Dùng để |
|---|---|---|
| `FoodItem` (tên, khẩu phần, gam, kcal, đạm, tinh bột, béo) | `lib/data/models.dart` | mô tả một món |
| `MealItem` (một `FoodItem` + số phần) | `lib/state/log_store.dart` | một món trong bữa |
| `LogStore.addMeal(slot:, items:, source:)` | `lib/state/log_store.dart` | lưu bữa lên Firestore |
| `MealEditor` | `lib/widgets/meal_editor.dart` | chỉnh ½ phần, bỏ món, hiện tổng |
| `MealScaffold`, `SlotPicker`, `mealTitleStyle` | `lib/screens/food/meal_parts.dart` | khung màn hình, chọn bữa |
| `slotForTime(DateTime)` | `lib/logic/meals.dart` | đoán bữa theo giờ hiện tại |

Màn chụp ảnh (`meal_scan_screen.dart`) cũng dùng đúng các mảnh này. Màn mới chỉ thay phần "AI đoán
món" bằng "người dùng tự chọn món".

---

## Bước 0: Tạo nhánh

```bash
git switch main
```

```bash
git pull
```

```bash
git switch -c feature/manual-food
```

---

## Bước 1: Tạo `assets/data/foods.json`

**Mục tiêu:** một danh sách món phổ biến, **cùng định dạng** với `FoodItem`, để đọc bằng
`FoodItem.fromJson` có sẵn.

**Tạo file:** chuột phải thư mục `assets/data` → **New File** → `foods.json`. Dán:

```json
[
  {"name": "Cơm trắng", "portion": "1 chén", "grams": 150, "kcal": 195, "protein": 4, "carb": 42, "fat": 0.5},
  {"name": "Phở bò tái", "portion": "1 tô vừa", "grams": 520, "kcal": 450, "protein": 26, "carb": 56, "fat": 12},
  {"name": "Bún chả", "portion": "1 suất", "grams": 450, "kcal": 560, "protein": 27, "carb": 64, "fat": 21},
  {"name": "Bánh mì thịt", "portion": "1 ổ", "grams": 230, "kcal": 420, "protein": 18, "carb": 50, "fat": 15},
  {"name": "Cơm tấm sườn nướng", "portion": "1 đĩa", "grams": 420, "kcal": 640, "protein": 30, "carb": 78, "fat": 22},
  {"name": "Mì gói", "portion": "1 gói", "grams": 75, "kcal": 350, "protein": 7, "carb": 47, "fat": 15},
  {"name": "Ức gà luộc", "portion": "100 g", "grams": 100, "kcal": 165, "protein": 31, "carb": 0, "fat": 3.6},
  {"name": "Thịt bò xào", "portion": "100 g", "grams": 100, "kcal": 200, "protein": 26, "carb": 2, "fat": 10},
  {"name": "Cá hồi áp chảo", "portion": "100 g", "grams": 100, "kcal": 208, "protein": 20, "carb": 0, "fat": 13},
  {"name": "Trứng gà luộc", "portion": "1 quả", "grams": 50, "kcal": 70, "protein": 6, "carb": 0.5, "fat": 5},
  {"name": "Đậu phụ", "portion": "100 g", "grams": 100, "kcal": 76, "protein": 8, "carb": 2, "fat": 4.8},
  {"name": "Khoai lang luộc", "portion": "1 củ vừa", "grams": 150, "kcal": 130, "protein": 2.4, "carb": 30, "fat": 0.2},
  {"name": "Yến mạch", "portion": "40 g", "grams": 40, "kcal": 150, "protein": 5, "carb": 27, "fat": 2.6},
  {"name": "Rau luộc", "portion": "1 đĩa", "grams": 150, "kcal": 40, "protein": 3, "carb": 7, "fat": 0.5},
  {"name": "Chuối", "portion": "1 quả", "grams": 120, "kcal": 105, "protein": 1.3, "carb": 27, "fat": 0.4},
  {"name": "Táo", "portion": "1 quả", "grams": 180, "kcal": 95, "protein": 0.5, "carb": 25, "fat": 0.3},
  {"name": "Sữa tươi không đường", "portion": "1 hộp 180 ml", "grams": 180, "kcal": 115, "protein": 6, "carb": 9, "fat": 6},
  {"name": "Sữa chua không đường", "portion": "1 hộp", "grams": 100, "kcal": 60, "protein": 3.5, "carb": 4.7, "fat": 3.3},
  {"name": "Whey protein", "portion": "1 muỗng", "grams": 30, "kcal": 120, "protein": 24, "carb": 3, "fat": 1.5},
  {"name": "Hạnh nhân", "portion": "1 nắm", "grams": 30, "kcal": 170, "protein": 6, "carb": 6, "fat": 15},
  {"name": "Bơ đậu phộng", "portion": "1 muỗng canh", "grams": 16, "kcal": 95, "protein": 3.5, "carb": 3.5, "fat": 8},
  {"name": "Cà phê sữa đá", "portion": "1 ly", "grams": 200, "kcal": 150, "protein": 2, "carb": 25, "fat": 4}
]
```

**Lưu ý:**
- Số liệu là **ước tính tham khảo**. Nên đối chiếu với *Bảng thành phần thực phẩm Việt Nam* (Viện
  Dinh dưỡng) và ghi nguồn vào báo cáo.
- Thêm món thì chép một dòng, sửa giá trị, và **nhớ dấu phẩy** giữa các dòng (dòng cuối không có
  phẩy).
- Không cần sửa `pubspec.yaml`: thư mục `assets/data/` đã được khai báo nguyên thư mục.

---

## Bước 2: Cho catalog đọc danh sách món (`lib/data/catalog.dart`)

### Hiểu catalog trước khi sửa

`Catalog` là "kho nội dung" của app, đọc **một lần** khi mở app (`Catalog.load()` trong
`main.dart`). Mọi màn hình dùng chung qua biến `catalog`, ví dụ `catalog.exercises`,
`catalog.sampleMeals`.

Trong `load()`, hàm `read(name)` lấy dữ liệu theo thứ tự: **Firestore** (nếu có) → nếu không có thì
**`assets/data/<name>.json`**. `foods` chưa có trên Firestore, nên sẽ đọc từ file vừa tạo.

Muốn thêm `foods` vào catalog cần sửa **3 chỗ**: khai báo tham số, khai báo field, đọc dữ liệu.

**2.1** Trong constructor `Catalog._({ ... })`, **dòng 23** là `required this.sampleMeals,`. Thêm
**ngay dưới**:

```dart
    required this.foods,
```

**2.2** **Dòng 52** là `final List<List<FoodItem>> sampleMeals;`. Thêm **ngay dưới**:

```dart

  /// Common foods to add by hand, one usual portion each (assets/data/foods.json).
  final List<FoodItem> foods;
```

**2.3** Trong hàm `load()`, **dòng 104** là `demos: await read('demos') as Map<String, dynamic>,`.
Thêm **ngay phía trên** nó:

```dart
      foods: [
        for (final f in await read('foods') as List) FoodItem.fromJson(f as Map<String, dynamic>),
      ],
```

Đọc hiểu dòng này: `await read('foods')` trả về dữ liệu JSON (một `List`). Với mỗi phần tử `f` (một
`Map`), tạo `FoodItem.fromJson(f)`. Kết quả là `List<FoodItem>`.

### Kiểm tra

```bash
flutter analyze
```

Nếu báo `The named parameter 'foods' is required` thì bạn làm 2.1 mà quên 2.3, hoặc ngược lại.

```bash
flutter test
```

Test cũng dựng catalog từ `assets/data`, nên nếu `foods.json` sai cú pháp thì test sẽ báo lỗi
`FormatException`.

**Commit:**

```bash
git add assets/data/foods.json lib/data/catalog.dart
```

```bash
git commit -m "feat: danh sach mon an pho bien trong catalog"
```

---

## Bước 3: Hàm tìm kiếm không dấu (`lib/logic/search.dart`)

**Mục tiêu:** gõ `pho` tìm ra `Phở`, gõ `uc ga` ra `Ức gà luộc`. Người dùng gõ trên điện thoại hay
lười gõ dấu.

**Vì sao đặt ở `logic/`:** đây là hàm thuần (vào chuỗi, ra chuỗi), không có giao diện. Đặt riêng
thì dễ viết test, và sau này dùng lại được để tìm bài tập theo tên.

**Tạo** `lib/logic/search.dart`:

```dart
/// Vietnamese letters with their marks, by the plain letter they fold to.
const _marked = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final _plain = {
  for (final MapEntry(key: plain, value: letters) in _marked.entries)
    for (final letter in letters.split('')) letter: plain,
};

/// Lower case without the marks, so "pho" finds "Phở": "Bánh Mì" → "banh mi".
String foldVi(String s) => s.toLowerCase().split('').map((c) => _plain[c] ?? c).join();

/// Whether every word of [query] appears in [text], marks and case aside.
bool matchesVi(String text, String query) {
  final haystack = foldVi(text);
  return foldVi(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).every(haystack.contains);
}
```

### Đọc hiểu

1. `_marked`: với mỗi chữ cái gốc, liệt kê mọi chữ có dấu của nó.
2. `_plain`: đảo ngược thành bảng tra `{'à': 'a', 'á': 'a', …, 'đ': 'd'}`. Hai vòng `for` lồng nhau
   **trong** dấu `{ }` tạo ra một `Map`. `MapEntry(key: plain, value: letters)` là pattern tách
   khoá và giá trị.
3. `foldVi`: chữ thường → tách từng ký tự → ký tự nào có trong bảng thì thay bằng chữ gốc → ghép
   lại.
4. `matchesVi`: tách câu tìm thành từng từ; **mọi** từ đều phải nằm trong tên món. Ví dụ
   `"ga uc"` vẫn khớp `"Ức gà luộc"`.

### Viết test (khuyến khích, giảng viên thường đánh giá cao)

Tạo `test/search_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vitalize/logic/search.dart';

void main() {
  test('foldVi drops the marks and the case', () {
    expect(foldVi('Bánh Mì Đặc Biệt'), 'banh mi dac biet');
    expect(foldVi('Phở bò tái'), 'pho bo tai');
  });

  test('matchesVi finds every word, in any order', () {
    expect(matchesVi('Ức gà luộc', 'uc ga'), isTrue);
    expect(matchesVi('Ức gà luộc', 'ga uc'), isTrue);
    expect(matchesVi('Ức gà luộc', 'bo'), isFalse);
    expect(matchesVi('Phở bò tái', '  '), isTrue);
  });
}
```

```bash
flutter test test/search_test.dart
```

Phải ra `All tests passed!`.

**Commit:**

```bash
git add lib/logic/search.dart test/search_test.dart
```

```bash
git commit -m "feat: tim kiem tieng Viet khong dau"
```

---

## Bước 4: Màn Thêm món (`lib/screens/food_pick_screen.dart`)

**Tạo file** `lib/screens/food_pick_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/haptics.dart';
import '../app/theme.dart';
import '../app/toast.dart';
import '../data/catalog.dart';
import '../data/models.dart';
import '../logic/format.dart';
import '../logic/meals.dart';
import '../logic/search.dart';
import '../state/log_store.dart';
import '../widgets/controls.dart';
import '../widgets/icons.dart';
import '../widgets/meal_editor.dart';
import '../widgets/pressable.dart';
import 'food/meal_parts.dart';

/// Add a meal by hand: search the common foods, tap to add, adjust the portions, pick the slot,
/// save. Saved meals have the source `manual`.
class FoodPickScreen extends StatefulWidget {
  const FoodPickScreen({super.key});

  @override
  State<FoodPickScreen> createState() => _FoodPickScreenState();
}

class _FoodPickScreenState extends State<FoodPickScreen> {
  final _query = TextEditingController();
  List<MealItem> _items = [];
  MealSlot _slot = slotForTime(DateTime.now());

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// A food tapped again gets half a serving more instead of a second row.
  void _add(FoodItem food) {
    final i = _items.indexWhere((it) => it.food.name == food.name);
    setState(() {
      _items = i < 0
          ? [..._items, MealItem(food: food)]
          : [
              for (final (j, it) in _items.indexed)
                j == i ? it.withServings(it.servings + 0.5) : it,
            ];
    });
    Haptics.tick();
  }

  void _save() {
    final log = context.read<LogStore>();
    final meal = log.addMeal(slot: _slot, items: _items, source: 'manual');
    Haptics.success();
    Toast.show(
      context,
      'Đã lưu ${mealSlotLabel[_slot]!.toLowerCase()}, ${formatNumber(mealTotals(meal).kcal)} kcal',
      actionLabel: 'Hoàn tác',
      onAction: () => log.removeMeal(meal.id),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim();
    final found = [
      for (final f in catalog.foods)
        if (query.isEmpty || matchesVi(f.name, query)) f,
    ];
    return MealScaffold(
      title: 'Thêm món',
      footer: _items.isEmpty
          ? null
          : PrimaryButton(label: 'Lưu vào ${mealSlotLabel[_slot]!.toLowerCase()}', onPressed: _save),
      children: [
        Text('Bạn đã ăn gì?', style: mealTitleStyle),
        const SizedBox(height: 16),
        _SearchBox(controller: _query, onChanged: () => setState(() {})),
        if (_items.isNotEmpty) ...[
          const SizedBox(height: 24),
          MealEditor(items: _items, onChanged: (items) => setState(() => _items = items)),
          const SizedBox(height: 22),
          SlotPicker(label: 'Lưu vào', value: _slot, onChanged: (s) => setState(() => _slot = s)),
        ],
        const SizedBox(height: 26),
        SectionTitle(query.isEmpty ? 'Món thường gặp' : 'Kết quả cho "$query"'),
        if (found.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text('Chưa có món này trong danh sách.', style: VT.ui(14.5, color: V.muted)),
          ),
        for (final f in found) _FoodOption(food: f, onTap: () => _add(f)),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final text = VT.ui(17, weight: FontWeight.w500, height: 1);
    OutlineInputBorder ring(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(V.rControl),
      borderSide: BorderSide(color: color, width: width),
      gapPadding: 0,
    );
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      textInputAction: TextInputAction.search,
      style: text,
      decoration: InputDecoration(
        hintText: 'Tìm món: phở, ức gà, chuối…',
        hintStyle: text.copyWith(color: V.faint),
        filled: true,
        fillColor: V.bg3,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18.5),
        enabledBorder: ring(V.lineStrong, 1),
        focusedBorder: ring(V.accent, 1.5),
      ),
    );
  }
}

/// One food in the list: name and portion, its energy, and a plus.
class _FoodOption extends StatelessWidget {
  const _FoodOption({required this.food, required this.onTap});

  final FoodItem food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Thêm ${food.name}',
    excludeSemantics: true,
    child: Pressable(
      onTap: onTap,
      builder: (pressed) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: pressed ? V.bg3 : const Color(0x00000000),
          border: const Border(bottom: BorderSide(color: V.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(food.name, style: VT.ui(16, weight: FontWeight.w500, height: 1.3)),
                  const SizedBox(height: 2),
                  Text(food.portion, style: VT.ui(13.5, color: V.muted)),
                ],
              ),
            ),
            Text('${formatNumber(food.kcal)} kcal', style: VT.mono(13.5, color: V.muted)),
            const SizedBox(width: 12),
            const VIcon(VIcons.plus, size: 20, color: V.accent),
          ],
        ),
      ),
    ),
  );
}
```

### Đọc hiểu: trạng thái của màn hình

| Biến | Kiểu | Giữ gì |
|---|---|---|
| `_query` | `TextEditingController` | chữ trong ô tìm |
| `_items` | `List<MealItem>` | các món đã chọn, kèm số phần |
| `_slot` | `MealSlot` | bữa sẽ lưu vào; mặc định đoán theo giờ (`slotForTime`) |

### Luồng dữ liệu

```
Gõ chữ ──▶ _SearchBox.onChanged ──▶ setState(() {}) ──▶ build chạy lại
           └─▶ found = catalog.foods lọc bằng matchesVi(tên, chữ gõ) ──▶ vẽ danh sách _FoodOption

Bấm món ──▶ _add(food)
           ├─ chưa có trong _items ──▶ thêm MealItem(food) (1 phần)
           └─ đã có ──▶ tăng thêm 0.5 phần (withServings)

MealEditor đổi phần / bỏ món ──▶ onChanged(items) ──▶ setState(_items = items)

Bấm "Lưu" ──▶ _save()
           ├─ LogStore.addMeal(slot, items, source: 'manual') ──▶ Firestore users/{uid}/meals
           ├─ Toast "Đã lưu bữa trưa, 645 kcal" + nút Hoàn tác (removeMeal)
           └─ pop() quay về tab Ăn uống (tab tự cập nhật vì nó watch LogStore)
```

### Những điểm cần hiểu

- **`setState(() {})` rỗng** ở ô tìm: dữ liệu (chữ gõ) đã nằm trong `_query`, chỉ cần báo "vẽ
  lại".
- **`[..._items, MealItem(food: food)]`**: tạo **list mới** thay vì `_items.add(...)`. Đây là
  cách chung của project (xem `LogStore`): không sửa list cũ, nên widget nhận ra có thay đổi.
- **`footer: _items.isEmpty ? null : PrimaryButton(...)`**: chưa chọn món thì không có nút Lưu.
- **`source: 'manual'`**: trường `source` của bữa ăn trước giờ là `'demo'` hoặc `'ai'`. Giá trị
  mới `'manual'` giúp phân biệt bữa nhập tay. Màn chi tiết bữa chỉ ghi *"kết quả mẫu"* khi
  `source == 'demo'`, nên không cần sửa gì thêm.
- `_SearchBox` và `_FoodOption` có dấu `_`: widget riêng của file này.

### Kiểm tra

`flutter analyze` → `No issues found!`.

**Commit:**

```bash
git add lib/screens/food_pick_screen.dart
```

```bash
git commit -m "feat: man Them mon de nhap bua an thu cong"
```

---

## Bước 5: Nút mở màn Thêm món (`lib/screens/food_screen.dart`)

Phần nút nằm trong widget riêng `_Capture` (cuối file). Phải sửa **4 chỗ**: import, truyền hàm,
khai báo tham số, vẽ nút.

**5.1 Import.** **Dòng 25** là `import 'food/meal_thumb.dart';`. Thêm **ngay dưới**:

```dart
import 'food_pick_screen.dart';
```

**5.2 Truyền hàm mở màn hình.** Khoảng **dòng 99–102**, trong `build` của `_FoodScreenState`:

```dart
              child: _Capture(
                onCamera: () => _capture(ImageSource.camera),
                onLibrary: () => _capture(ImageSource.gallery),
              ),
```

Thêm dòng `onManual`:

```dart
              child: _Capture(
                onCamera: () => _capture(ImageSource.camera),
                onLibrary: () => _capture(ImageSource.gallery),
                onManual: () => Navigator.of(context).push(vRoute(const FoodPickScreen())),
              ),
```

**5.3 Khai báo tham số.** Khoảng **dòng 344–348**:

```dart
class _Capture extends StatelessWidget {
  const _Capture({required this.onCamera, required this.onLibrary});

  final VoidCallback onCamera;
  final VoidCallback onLibrary;
```

Sửa thành:

```dart
class _Capture extends StatelessWidget {
  const _Capture({required this.onCamera, required this.onLibrary, required this.onManual});

  final VoidCallback onCamera;
  final VoidCallback onLibrary;
  final VoidCallback onManual;
```

**5.4 Vẽ nút.** Vẫn trong `_Capture`, tìm khối nút *Chọn ảnh có sẵn* (khoảng **dòng 362–371**):

```dart
        SizedBox(
          height: 50,
          child: GhostButton(
            label: 'Chọn ảnh có sẵn',
            icon: VIcons.image,
            expand: true,
            onPressed: onLibrary,
          ),
        ),
        const SizedBox(height: 14),
```

Chèn khối nút mới **giữa** `),` (đóng `SizedBox` của nút Chọn ảnh) và `const SizedBox(height: 14),`:

```dart
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: GhostButton(
            label: 'Nhập món thủ công',
            icon: VIcons.plus,
            expand: true,
            onPressed: onManual,
          ),
        ),
```

**Vì sao truyền hàm (`onManual`) mà không gọi `Navigator` ngay trong `_Capture`?** Project giữ
`_Capture` là widget "ngốc" (chỉ vẽ nút); việc **làm gì khi bấm** do màn cha quyết định. Hai nút có
sẵn (`onCamera`, `onLibrary`) cũng làm vậy, nên nút mới làm theo cho đồng nhất.

### Kiểm tra và commit

```bash
flutter analyze
```

```bash
flutter test
```

Ảnh golden của tab Ăn uống sẽ fail vì có thêm nút. Đó là thay đổi có chủ ý, nên:

```bash
flutter test --update-goldens
```

```bash
git add lib/screens/food_screen.dart test/goldens
```

```bash
git commit -m "feat: nut Nhap mon thu cong o tab An uong"
```

---

## Bước 6: Thử, push, PR

Vì có file mới trong `assets/`, phải **dừng hẳn** app (`q`) rồi:

```bash
flutter run
```

| # | Thao tác | Kết quả đúng |
|---|---|---|
| 1 | Tab Ăn uống | Có nút **Nhập món thủ công** dưới *Chọn ảnh có sẵn* |
| 2 | Bấm nút | Màn **Thêm món**, danh sách 22 món dưới tiêu đề *Món thường gặp* |
| 3 | Gõ `pho` | Chỉ còn *Phở bò tái*; tiêu đề *Kết quả cho "pho"* |
| 4 | Gõ `xyz` | *Chưa có món này trong danh sách.* |
| 5 | Xoá chữ, bấm *Cơm trắng* 2 lần, bấm *Ức gà luộc* 1 lần | Phía trên có 2 món: Cơm 1,5 phần, Ức gà 1 phần; tổng ≈ 458 kcal |
| 6 | Chọn bữa **Tối** → **Lưu vào bữa tối** | Toast *Đã lưu bữa tối, 458 kcal* + Hoàn tác; quay về tab Ăn uống, có nhóm Bữa tối |
| 7 | Bấm **Hoàn tác** trên toast | Bữa vừa lưu biến mất |
| 8 | Firebase Console → Firestore → `users/<UID>/meals` | Có document với `source: "manual"` |

```bash
git push -u origin feature/manual-food
```

Tạo Pull Request → merge → `git switch main` → `git pull`.

---

## Tự kiểm tra

1. Vì sao `foods` đọc được từ asset dù `read()` ưu tiên Firestore?
2. Nếu đổi `_add` thành `_items.add(MealItem(food: food)); setState(() {});` thì app có chạy không?
   Vì sao project lại chọn cách tạo list mới?
3. Muốn tìm bài tập theo tên ở màn Cơ thể, bạn dùng lại hàm nào? Đặt ô tìm ở đâu?
