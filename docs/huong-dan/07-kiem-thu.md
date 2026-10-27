# Kiểm thử Vitalize sau khi `git clone`

Trang này dành cho **mọi thành viên** vừa clone repo về và muốn kiểm tra app chạy đúng. Gồm 4
lớp kiểm thử, từ nhanh đến kỹ:

| Lớp | Kiểm gì | Mất bao lâu | Cần gì |
|---|---|---|---|
| A. Phân tích tĩnh | Lỗi cú pháp, kiểu dữ liệu, import thiếu | ~10 giây | Flutter |
| B. Test tự động | 149 test: logic, màn hình, ảnh golden, lưu trữ trên Firestore giả | ~1 phút | Flutter |
| C. Luật Firestore | Ai được ghi gì vào database | ~1 phút | Node.js, Java, Firebase CLI, Git Bash |
| D. Kiểm thử tay | Từng chức năng trên điện thoại/máy ảo, có kết quả mong đợi | ~30 phút | Máy ảo hoặc điện thoại Android |

Kết quả các lớp này dùng được luôn cho mục **2.2 Minh họa chức năng** và **3. Kết luận** của báo
cáo.

---

## 0. Chuẩn bị sau khi clone

```bash
git clone https://github.com/vhphat2206/vitalize.git
```

```bash
cd vitalize
```

```bash
flutter pub get
```

Kiểm tra phiên bản. Cả nhóm nên dùng **cùng một** bản Flutter để `pubspec.lock` và ảnh golden
không lệch nhau:

```bash
flutter --version
```

Những thứ **đã có sẵn trong repo**, không cần làm lại:

- Cấu hình Firebase (`lib/firebase_options.dart`, `android/app/google-services.json`).
- Sửa lỗi build Windows trong `android/gradle.properties` (Kotlin cache khi project ở ổ khác pub
  cache, giới hạn RAM cho Gradle).
- Web client ID cho đăng nhập Google (`googleWebClientId` trong `lib/state/account_store.dart`).
- Luật Firestore đã deploy lên project `vitalize-gym`.

Những thứ **mỗi máy phải tự làm** (chỉ cần cho nút *Tiếp tục với Google*):

- Thêm **SHA-1 và SHA-256 của máy mình** vào Firebase (xem [02-dang-nhap.md](02-dang-nhap.md),
  Bước 2). Không làm thì email/mật khẩu vẫn chạy, chỉ riêng Google báo lỗi.

---

## A. Phân tích tĩnh

```bash
flutter analyze
```

**Đạt:** `No issues found!`

Không đạt thì đọc từng dòng `error -` / `warning -`, mỗi dòng ghi rõ file và số dòng. Thường gặp:
`Target of URI doesn't exist`, nghĩa là quên `flutter pub get`.

---

## B. Test tự động

```bash
flutter test
```

**Đạt:** dòng cuối là `+149: All tests passed!` (con số tăng lên khi nhóm thêm test).

### Bộ test kiểm những gì

| File trong `test/` | Kiểm |
|---|---|
| `body_screen_test.dart`, `body_figure_test.dart` | Bản đồ cơ, chạm cơ mở danh sách bài, lọc dụng cụ, xoay trước/sau |
| `exercise_screen_test.dart` | Chi tiết bài tập, ghi hiệp, hoàn tác |
| `routines_test.dart` | Buổi tập ngắn, đồng hồ từng động tác |
| `food_screen_test.dart`, `meal_screens_test.dart`, `meal_analyzer_test.dart` | Tab Ăn uống, chụp ảnh (chế độ demo), sửa và xoá bữa |
| `week_screen_test.dart`, `food_week_tabs_test.dart` | Tab Tuần này |
| `profile_screen_test.dart`, `settings_screen_test.dart`, `reminders_test.dart` | Hồ sơ, Cài đặt, nhắc lịch |
| `firestore_stores_test.dart`, `catalog_firestore_test.dart` | Đọc/ghi Firestore, dùng **Firestore giả trong bộ nhớ** (`fake_cloud_firestore`), không đụng dữ liệu thật |
| `search_test.dart` | Tìm kiếm không dấu |
| `jpeg_encoder_test.dart`, `demo_test.dart`, `demo_golden_test.dart` | Nén ảnh món ăn, hình động bài tập |

### Chạy riêng một file hoặc một test

```bash
flutter test test/search_test.dart
```

```bash
flutter test test/exercise_screen_test.dart --plain-name "logging a set"
```

### Khi test ảnh golden fail

Dòng lỗi có dạng `Golden "goldens/xxx.png": Pixel test failed, 2.40%, ... diff detected.`

1. Mở thư mục `test/failures/` (Git bỏ qua thư mục này). Mỗi ảnh fail có 4 file:
   - `_masterImage`: ảnh mẫu;
   - `_testImage`: ảnh vừa chụp;
   - `_isolatedDiff`, `_maskedDiff`: chỗ khác nhau.
2. Nếu khác vì **font hơi lệch** (thường 1–4%, do máy khác hệ điều hành với máy tạo ảnh mẫu): bình
   thường. Hỏi nhóm xem máy nào là máy tạo ảnh chuẩn.
3. Nếu khác vì **bạn vừa cố ý đổi giao diện**: tạo lại ảnh mẫu, mở vài ảnh trong `test/goldens/`
   xem đúng ý chưa, rồi commit:

```bash
flutter test --update-goldens
```

4. Nếu khác ở chỗ **không ai đụng tới**: có thể là lỗi thật. Báo nhóm, đừng `--update-goldens` để
   che đi.

> **Đã biết:** test `exercise_screen_test.dart: logging a set…` thỉnh thoảng fail khi chạy cả bộ
> (ảnh `exercise_logged.png` lệch ~0,3%), chạy riêng thì qua. Nguyên nhân và cách sửa ở **mục E**
> cuối trang.

---

## C. Kiểm thử luật Firestore bằng emulator

Luật trong `firestore.rules` quyết định ai được đọc/ghi gì. Script `tool/test_rules.sh` chạy luật
trên **Firestore emulator** (bản Firestore chạy trên máy, dùng project giả `demo-vitalize`, không
đụng dữ liệu thật) rồi thử ghi 10 kiểu dữ liệu, xem kết quả có đúng mong đợi không.

### C.1 Cài công cụ (một lần)

1. **Node.js** bản LTS từ [nodejs.org](https://nodejs.org).
2. **Java** 11 trở lên (đã có nếu cài Android Studio; kiểm tra bằng `java -version`).
3. **Firebase CLI:**

```bash
npm install -g firebase-tools
```

4. **Git Bash** (đi kèm Git for Windows). Script viết cho bash, **không chạy được trong
   PowerShell**: chữ `bash` trong PowerShell trỏ tới WSL. Trong VS Code: bảng Terminal → mũi tên
   cạnh dấu **+** → chọn **Git Bash**.

### C.2 Tạo script `tool/test_rules.sh` (một lần, rồi commit)

Thư mục `tool/` đã có các script khác của project (`seed_firestore.dart`, `export_data.ts`). Tạo
file `tool/test_rules.sh`:

```bash
#!/usr/bin/env bash
# Checks firestore.rules against the Firestore emulator: each write below must be allowed or
# denied as stated. Run it through the emulator, which sets FIRESTORE_EMULATOR_HOST:
#
#   firebase emulators:exec --only firestore --project demo-vitalize "bash tool/test_rules.sh"
#
# The demo- project never touches the real Firebase project.

host=${FIRESTORE_EMULATOR_HOST:-127.0.0.1:8080}
base="http://$host/v1/projects/demo-vitalize/databases/(default)/documents"
failed=0

b64() { printf '%s' "$1" | base64 | tr -d '\n=' | tr '+/' '-_'; }

# An unsigned ID token for user $1; the emulator accepts these.
token() {
  local now
  now=$(date +%s)
  printf '%s.%s.' "$(b64 '{"alg":"none","typ":"JWT"}')" \
    "$(b64 "{\"sub\":\"$1\",\"user_id\":\"$1\",\"iat\":$now,\"exp\":$((now + 3600)),\"aud\":\"demo-vitalize\",\"iss\":\"https://securetoken.google.com/demo-vitalize\",\"firebase\":{\"sign_in_provider\":\"anonymous\"}}")"
}

# expect <allowed|denied> <what> <uid> <document path> <fields as Firestore REST JSON>
expect() {
  local code got
  code=$(curl -s -o /dev/null -w '%{http_code}' -X PATCH "$base/$4" \
    -H "Authorization: Bearer $(token "$3")" -H 'Content-Type: application/json' \
    -d "{\"fields\":$5}")
  if [ "$code" = 200 ]; then got=allowed; else got=denied; fi
  if [ "$got" = "$1" ]; then
    echo "  ok    $2: $got"
  else
    echo "  FAIL  $2: expected $1, got $got (HTTP $code)"
    failed=$((failed + 1))
  fi
}

at='{"timestampValue":"2026-10-27T05:00:00Z"}'
set="{\"id\":{\"stringValue\":\"s1\"},\"exerciseId\":{\"stringValue\":\"squat\"},\"at\":$at,\"reps\":{\"integerValue\":\"10\"}}"
meal="\"id\":{\"stringValue\":\"m1\"},\"at\":$at,\"items\":{\"arrayValue\":{}},\"source\":{\"stringValue\":\"manual\"}"

echo "firestore.rules on $host"
expect allowed 'set, by its owner' u1 users/u1/sets/s1 "$set"
expect denied 'set, by another user' u2 users/u1/sets/s2 "$set"
expect denied 'set, with a field the app never writes' u1 users/u1/sets/s3 \
  "{\"id\":{\"stringValue\":\"s3\"},\"exerciseId\":{\"stringValue\":\"squat\"},\"at\":$at,\"hack\":{\"stringValue\":\"x\"}}"
expect denied 'set, time as text' u1 users/u1/sets/s4 \
  "{\"id\":{\"stringValue\":\"s4\"},\"exerciseId\":{\"stringValue\":\"squat\"},\"at\":{\"stringValue\":\"now\"}}"
expect allowed 'session' u1 users/u1/sessions/x1 \
  "{\"id\":{\"stringValue\":\"x1\"},\"routineId\":{\"stringValue\":\"core\"},\"at\":$at,\"seconds\":{\"integerValue\":\"300\"}}"
expect allowed 'meal, lunch' u1 users/u1/meals/m1 "{$meal,\"slot\":{\"stringValue\":\"lunch\"}}"
expect denied 'meal, unknown slot' u1 users/u1/meals/m2 "{$meal,\"slot\":{\"stringValue\":\"brunch\"}}"
expect allowed 'profile' u1 users/u1 '{"profile":{"mapValue":{"fields":{"name":{"stringValue":"A"}}}}}'
expect denied 'profile, another user' u2 users/u1 '{"profile":{"mapValue":{}}}'
expect denied 'exercise catalog, written by the app' u1 exercises/squat '{"name":{"stringValue":"x"}}'

if [ "$failed" -gt 0 ]; then
  echo "$failed check(s) failed"
  exit 1
fi
echo 'All rule checks passed'
```

Đọc hiểu nhanh:
- `firebase emulators:exec` bật emulator, chạy script, rồi tự tắt emulator. Nó cũng đặt biến
  `FIRESTORE_EMULATOR_HOST` để script biết emulator ở cổng nào.
- `token u1` tạo một "vé đăng nhập" giả cho user `u1`. Emulator chấp nhận vé không ký, Firebase
  thật thì không.
- `expect allowed|denied ...` gửi một lệnh ghi qua REST API của Firestore. Mã HTTP `200` nghĩa là
  luật cho phép, `403` là bị chặn. Sau đó so với mong đợi.
- Script trả mã lỗi `1` nếu có ca sai, nên sau này gắn được vào CI (GitHub Actions).

### C.3 Chạy

Trong terminal **Git Bash**, ở thư mục `vitalize`:

```bash
firebase emulators:exec --only firestore --project demo-vitalize "bash tool/test_rules.sh"
```

**Đạt** (đã chạy thử với `firestore.rules` hiện tại):

```
firestore.rules on 127.0.0.1:8080
  ok    set, by its owner: allowed
  ok    set, by another user: denied
  ok    set, with a field the app never writes: denied
  ok    set, time as text: denied
  ok    session: allowed
  ok    meal, lunch: allowed
  ok    meal, unknown slot: denied
  ok    profile: allowed
  ok    profile, another user: denied
  ok    exercise catalog, written by the app: denied
All rule checks passed
```

Lần đầu chạy, Firebase CLI tải emulator về (khoảng 60 MB), nên hơi lâu. `--project demo-vitalize`
**không cần** `firebase login`.

**Khi nào chạy lại:** mỗi khi sửa `firestore.rules`, hoặc thêm trường mới vào một hàm `toJson()`
(thêm luôn một dòng `expect` cho trường đó).

### C.4 Thử nhanh trên Rules Playground (không cần cài gì)

Firebase Console → Firestore Database → Rules → **Rules Playground**. Lưu ý:
- Với `create`/`update`, **phải bấm Build document** và thêm từng trường bằng **Add field**. Để
  trống sẽ báo *"Property data is undefined"*.
- Thêm trường ở **cấp ngoài cùng**, không lồng vào một trường tên `data`.
- Chưa chắc thì tin kết quả của emulator (C.3) hơn.

---

## D. Kiểm thử tay trên app

```bash
flutter run
```

Chọn máy ảo hoặc điện thoại khi được hỏi. Muốn thử **Google** trên máy ảo: tạo máy ảo loại có
biểu tượng **Play Store** và đăng nhập một tài khoản Google trong máy ảo.

Mở song song **Firebase Console** → *Authentication → Users* và *Firestore Database → Data* để đối
chiếu dữ liệu. Mỗi ca có mã (ví dụ `TK-01`) để ghi vào bảng kết quả ở mục F và vào báo cáo.

### D.1 Tài khoản (Cài đặt → Tài khoản)

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| TK-01 | Mở app lần đầu → Hồ sơ → ⚙ | Nhóm **Tài khoản** ghi *Đang dùng tài khoản khách*; Console có user ẩn danh mới |
| TK-02 | Ghi 2 hiệp → Tài khoản → **Tạo tài khoản** (email thật, mật khẩu ≥ 6 ký tự) | Toast *Đã tạo tài khoản…*; Console: **cùng UID** giờ có email; 2 hiệp **vẫn còn** |
| TK-03 | Tạo tài khoản với email `abc` | Chữ đỏ *Email không hợp lệ.* |
| TK-04 | Tạo tài khoản với mật khẩu `123` | Chữ đỏ *Mật khẩu cần ít nhất 6 ký tự.* |
| TK-05 | Tạo tài khoản bằng email đã dùng ở TK-02 (trên máy/khách khác) | *Email này đã có tài khoản…* |
| TK-06 | **Đăng xuất** | Toast *Đã đăng xuất*; tab Tuần này **trống**; Console có thêm 1 user ẩn danh |
| TK-07 | **Đăng nhập** bằng email TK-02 | 2 hiệp và hồ sơ cũ **hiện lại** |
| TK-08 | Đăng nhập sai mật khẩu | *Email hoặc mật khẩu không đúng.* |
| TK-09 | Chế độ Đăng nhập → nhập email → **Quên mật khẩu?** | Toast *Đã gửi email…*; hộp thư (kể cả Spam) có thư đặt lại mật khẩu |
| TK-10 | **Tiếp tục với Google** khi là khách | Bảng chọn tài khoản Google của Android → toast *Đã đăng nhập bằng Google*; Console: user có biểu tượng **G** |
| TK-11 | Đăng xuất rồi **Tiếp tục với Google** lại | Hỏi chọn tài khoản lại; vào đúng tài khoản cũ, dữ liệu cũ hiện lại |
| TK-12 | Tắt mạng → Đăng nhập | *Không có mạng. Kiểm tra kết nối rồi thử lại.* |

### D.2 Hồ sơ

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| HS-01 | Tab Hồ sơ khi chưa nhập gì | Mục lượng ăn mỗi ngày nhắc nhập giới tính, năm sinh, chiều cao, cân nặng |
| HS-02 | Nhập tên, giới tính Nam, năm sinh 2003, cao 170, nặng 65, mục tiêu Tăng cơ, 4 buổi/tuần | Hiện năng lượng và đạm/tinh bột/béo mỗi ngày; đổi mục tiêu thì con số đổi theo |
| HS-03 | Thoát app hẳn, mở lại | Hồ sơ vẫn còn (đọc từ Firestore `users/<UID>.profile`) |

### D.3 Cơ thể và Bài tập

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| CT-01 | Tab Cơ thể → chạm vào ngực | Mở danh sách *Bài tập cho …* |
| CT-02 | **Lọc theo dụng cụ** → chọn một dụng cụ | Danh sách chỉ còn bài dùng dụng cụ đó |
| CT-03 | Xoay sang mặt sau | Hình đổi sang mặt sau, chạm được cơ lưng, mông… |
| BT-01 | Mở một bài | Có hình động, ô Hiệp / Số lần / **Nghỉ**, các bước, lỗi hay gặp, tài liệu tham khảo |
| BT-02 | **Ghi một hiệp** → chỉnh mức tạ, số lần → **Lưu hiệp** | Toast *Đã ghi…* + Hoàn tác; dòng *Hôm nay* hiện hiệp vừa ghi |
| BT-03 | Bấm **Hoàn tác** trên toast | Hiệp biến mất |
| BT-04 | Ghi hiệp ở bài có thời gian nghỉ | Dòng **Nghỉ 1:30** (tuỳ bài) đếm ngược; **+15 giây** tăng thời gian; **Bỏ qua** tắt; hết giờ thì rung (nếu bật) và biến mất |

### D.4 Buổi tập ngắn

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| BN-01 | Tab Bài tập | 6 buổi, mỗi buổi ghi số động tác và số vòng |
| BN-02 | Mở một buổi → **Bắt đầu** | Đồng hồ *Chuẩn bị* rồi từng động tác; màn hình không tắt (nếu bật *Giữ màn hình sáng*) |
| BN-03 | **Tạm dừng / Tiếp tục**, **Bỏ qua động tác**, **Động tác trước** | Đồng hồ dừng / chạy / chuyển đúng |
| BN-04 | Để chạy hết | Màn hoàn thành *Buổi này đã được ghi vào tuần của bạn.*; tab Tuần này có buổi đó |

### D.5 Ăn uống

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| AU-01 | **Chụp món ăn** lần đầu | Hỏi quyền camera; từ chối thì có hướng dẫn mở Cài đặt |
| AU-02 | Chụp/chọn ảnh | *Đang xem ảnh…* → kết quả **mẫu**, ghi rõ *Chế độ thử* (AI chưa kết nối) |
| AU-03 | Chỉnh ½ phần, chọn bữa → **Lưu** | Bữa hiện ở tab Ăn uống kèm ảnh nhỏ; thanh năng lượng tăng |
| AU-04 | **Nhập món thủ công** → gõ `pho` | Ra *Phở bò tái* (tìm không dấu) |
| AU-05 | Bấm *Cơm trắng* 2 lần + *Ức gà luộc* → bữa Tối → **Lưu** | Toast *Đã lưu bữa tối, 458 kcal*; Console: document có `source: "manual"` |
| AU-06 | Mở một bữa đã lưu → sửa khẩu phần / **Xoá bữa ăn này** → Hoàn tác | Cập nhật / xoá / khôi phục đúng |
| AU-07 | Ăn vượt mục tiêu ngày | Câu *Đã vượt … kcal* |

### D.6 Tuần này

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| TN-01 | Sau khi ghi vài hiệp | Ngày có tập được đánh dấu; cơ đã tập đỏ dần trên hình theo số hiệp (1–5, 6–11, 12+) |
| TN-02 | Bấm **‹** | Tiêu đề *Tuần trước*, ngày lùi 7 ngày; có nút **›** |
| TN-03 | Bấm **›** về tuần này | Nút › biến mất |
| TN-04 | Xoá một hiệp trong danh sách → Hoàn tác | Xoá / khôi phục đúng |

### D.7 Cài đặt và nhắc lịch

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| CD-01 | Bật **Nhắc tôi đi tập** | Hỏi quyền thông báo; cho phép thì hiện *Sẽ nhắc lúc … vào …* |
| CD-02 | Chọn ngày hôm nay, giờ nhắc = 2 phút nữa → chờ | Có thông báo nhắc tập (kể cả khi đã thoát app) |
| CD-03 | Từ chối quyền thông báo | Công tắc tự tắt, có hướng dẫn **Mở Cài đặt** |
| CD-04 | Tắt **Rung khi đếm giờ** → chạy buổi tập / đồng hồ nghỉ | Không rung |
| CD-05 | **Xoá nhật ký tập** → xác nhận | Tab Tuần này trống; Console: `sets`, `sessions` trống |

### D.8 Mất mạng

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| MM-01 | Bật chế độ máy bay → ghi 1 hiệp, lưu 1 bữa | App hiện ngay như bình thường |
| MM-02 | Xem Firestore Console lúc đó | **Chưa** có dữ liệu mới |
| MM-03 | Tắt chế độ máy bay, đợi vài giây | Console có hiệp và bữa vừa ghi (tự đồng bộ) |

---

## E. Sửa test đồng hồ nghỉ thỉnh thoảng fail (nên làm)

**Hiện tượng:** chạy `flutter test` cả bộ, thỉnh thoảng fail
`exercise_screen_test.dart: logging a set: weight and reps, then undo from the toast`, vì ảnh
`goldens/exercise_logged.png` lệch ~0,3%. Chạy riêng file đó thì qua.

**Nguyên nhân:** `RestTimer` (Phần 5) tính thời gian còn lại bằng `DateTime.now()`, tức **giờ thật
của máy**. Trong test, Flutter dùng **giờ giả** (`tester.pump` cho thời gian trôi tức thì), nhưng
`DateTime.now()` không theo giờ giả. Máy chạy chậm (khi chạy cả 149 test) thì số giây trên đồng hồ
lúc chụp ảnh lệch đi 1 giây, và ảnh khác ảnh mẫu.

**Cách sửa:** dùng package `clock`. `clock.now()` bình thường trả giờ thật, còn trong test nó tự theo
giờ giả. Đã thử: sau khi sửa, chạy cả bộ 3 lần liên tiếp đều qua 149/149.

```bash
git switch main
```

```bash
git pull
```

```bash
git switch -c fix/rest-timer-clock
```

```bash
flutter pub add clock
```

**`lib/widgets/rest_timer.dart`:** thêm import dưới `import 'dart:async';` (để một dòng trống ở
giữa như các import khác):

```dart
import 'package:clock/clock.dart' as time;
```

và sửa hàm `_remaining`:

```dart
  int _remaining() => (widget.until.difference(time.clock.now()).inMilliseconds / 1000).ceil();
```

**`lib/screens/exercise_screen.dart`:** thêm import dưới `import 'dart:math' as math;` (dòng trống ở
giữa):

```dart
import 'package:clock/clock.dart' as time;
```

và trong `_logSet` đổi `DateTime.now()` của dòng `_restUntil`:

```dart
            setState(() => _restUntil = time.clock.now().add(Duration(seconds: ex.dose.rest)));
```

**Vì sao `as time`:** project đã có hàm `clock(...)` trong `lib/logic/format.dart` (đổi `90` thành
`1:30`). Không đặt tiền tố thì Dart báo `ambiguous_import` vì có hai thứ cùng tên `clock`.

Kiểm tra và commit:

```bash
flutter analyze
```

```bash
flutter test
```

```bash
git add pubspec.yaml pubspec.lock lib/widgets/rest_timer.dart lib/screens/exercise_screen.dart
```

```bash
git commit -m "fix: dong ho nghi theo gio gia trong test, het fail luc co luc khong"
```

```bash
git push -u origin fix/rest-timer-clock
```

---

## F. Mẫu bảng ghi kết quả (cho báo cáo)

| Mã | Chức năng | Kết quả | Ghi chú / ảnh |
|---|---|---|---|
| — | `flutter analyze` | Đạt | No issues found |
| — | `flutter test` | Đạt 149/149 | |
| — | `tool/test_rules.sh` | Đạt 10/10 | |
| TK-01 | Tài khoản khách | Đạt | hinh-tk-01.png |
| TK-02 | Tạo tài khoản giữ dữ liệu | | |
| … | … | | |
| AU-02 | AI phân tích ảnh | **Chưa hoàn thiện** | Chế độ demo, trả kết quả mẫu |

Nhớ ghi trung thực: ca nào chưa chạy được thì ghi *Chưa đạt* kèm lý do, đúng như file yêu cầu báo
cáo đề nghị.

---

## G. Lỗi hay gặp khi chạy lần đầu

| Lỗi | Nguyên nhân | Cách xử lý |
|---|---|---|
| `Could not close incremental caches` | Project và pub cache ở hai ổ đĩa khác nhau | Đã sửa trong `android/gradle.properties`; nếu vẫn gặp, chạy `flutter clean` rồi chạy lại |
| `Gradle build daemon disappeared` / `insufficient memory` | Hết RAM | Đóng bớt chương trình; chạy `cd android` → `.\gradlew --stop` → `cd ..` |
| `compileSdk ... requires 36/37` | `android/app/build.gradle.kts` bị sửa `compileSdk` | Giữ `compileSdk = 37`; cài Android SDK 37 trong Android Studio → SDK Manager |
| Google: *Đã huỷ đăng nhập Google.* dù không huỷ | Chưa thêm SHA máy mình / thiếu Android client | [02-dang-nhap.md](02-dang-nhap.md) Bước 2 và 3.1 d |
| *Cách đăng nhập này chưa được bật…* | Provider tắt trong Firebase | Authentication → Sign-in method |
| `permission-denied` khi lưu | Thêm trường mới vào `toJson()` mà chưa thêm vào luật | Sửa `firestore.rules`, chạy lại mục C, deploy |
| Hot reload không thấy thay đổi | Sửa `main.dart`, asset, file Android | `R`, hoặc `q` rồi `flutter run` lại |
