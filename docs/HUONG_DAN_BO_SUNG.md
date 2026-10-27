# Hướng dẫn bổ sung chức năng cho Vitalize

Tài liệu này hướng dẫn **tự tay** sửa và thêm chức năng cho app, theo đúng cấu trúc project.
Mỗi phần gồm: vì sao cần làm → file nào, đặt ở đâu → code → cách chạy thử → lệnh Git (tạo nhánh,
commit, push).

Toàn bộ code dưới đây đã được chạy thử trên một bản sao của project (Flutter hiện tại trên máy
này): `flutter analyze` không báo lỗi và đủ 147/147 test qua sau khi tạo lại ảnh golden. Những gì
**chưa** kiểm được: đăng nhập thật với Firebase (cần bật trong Console), đăng nhập Google trên
điện thoại thật, và luật Firestore ở Phần 6.

---

## Mục lục

| Phần | Nội dung | Nhánh Git | Độ khó |
|---|---|---|---|
| 0 | Commit phần sửa lỗi build Android | `fix/android-build` | Dễ |
| 1 | Sửa chữ sai trong Cài đặt, tạo lại ảnh golden | `fix/settings-text` | Dễ |
| 2 | Đăng ký / đăng nhập (email, Google), đăng xuất, quên mật khẩu | `feature/account` | Khó |
| 3 | Nhập món ăn thủ công, có tìm kiếm không dấu | `feature/manual-food` | Vừa |
| 4 | Xem lại các tuần trước | `feature/week-history` | Dễ |
| 5 | Đồng hồ nghỉ giữa hiệp | `feature/rest-timer` | Vừa |
| 6 | Siết luật bảo mật Firestore | `chore/firestore-rules` | Vừa |
| 7 | Cập nhật bảng chức năng cho báo cáo | — | — |

Làm **lần lượt từng phần**. Xong phần nào thì đưa nhánh đó vào `main` rồi mới làm phần sau: Phần 1
và Phần 2 cùng sửa `settings_screen.dart`, làm song song dễ bị xung đột (conflict).

---

## Trước khi bắt đầu

### Cấu trúc thư mục `lib/` (để biết đặt file ở đâu)

```
lib/
├── main.dart            Khởi động Firebase, tạo các store (Provider), chạy app
├── app/                 Khung app: theme (màu V, chữ VT), thanh tab, toast, rung (haptics)
├── data/                Mô hình dữ liệu (models.dart) và danh mục nội dung (catalog.dart)
├── logic/               Hàm thuần, không có giao diện: tính calo, định dạng số, tuần…
├── state/               Store (ChangeNotifier) đọc/ghi Firestore: hồ sơ, nhật ký, tài khoản
├── screens/             Mỗi màn hình một file; thư mục con chứa phần riêng của màn đó
├── widgets/             Widget dùng chung: nút, hàng cài đặt, bottom sheet, icon…
└── demo/                Hình động minh hoạ bài tập
```

Quy ước của project, nên theo khi viết code mới:

- **Màu và chữ**: dùng `V.xxx` (màu, khoảng cách) và `VT.ui(...)`, `VT.display(...)`, `VT.mono(...)`
  trong `lib/app/theme.dart`, không tự đặt `Color(...)` hay `TextStyle(...)`.
- **Nút**: `PrimaryButton` (nút chính màu xanh), `GhostButton` (nút viền), `IconBtn` trong
  `lib/widgets/controls.dart`.
- **Mở màn hình mới**: `Navigator.of(context).push(vRoute(const TenManHinh()))` (`vRoute` nằm ở
  `lib/widgets/back_bar.dart`).
- **Thông báo ngắn**: `Toast.show(context, 'Nội dung', actionLabel: 'Hoàn tác', onAction: ...)`.
- **Đọc store**: trong `build` dùng `context.watch<LogStore>()` (vẽ lại khi dữ liệu đổi); trong hàm
  xử lý sự kiện dùng `context.read<LogStore>()`.

### Quy trình Git dùng cho mọi phần

```bash
git switch main
```

```bash
git pull
```

```bash
git switch -c ten-nhanh
```

Sửa code theo hướng dẫn, rồi kiểm tra:

```bash
flutter analyze
```

```bash
flutter test
```

Cuối cùng commit và push (mỗi phần có lệnh cụ thể ở cuối):

```bash
git add duong/dan/file1 duong/dan/file2
```

```bash
git commit -m "noi dung commit"
```

```bash
git push -u origin ten-nhanh
```

Sau khi push, lên GitHub mở repo → bấm **Compare & pull request** → **Create pull request** → nhờ
một bạn trong nhóm xem → **Merge**. Xong mới quay lại `git switch main` và `git pull` để làm phần
sau.

Lưu ý:

- **Quyền push**: repo `vhphat2206/vitalize` thuộc tài khoản của bạn Phát. Bạn cần được thêm làm
  **Collaborator** (Settings → Collaborators trên GitHub), nếu không `git push` sẽ báo
  `Permission denied`.
- **Chỉ `git add` đúng file** được ghi trong từng phần, đừng dùng `git add .`. Như vậy commit gọn
  và không lẫn file rác (thư mục `build/`, file log…).
- **Ảnh golden**: test so ảnh chụp màn hình với ảnh mẫu trong `test/goldens/`. Khi bạn cố ý đổi
  giao diện, test của màn đó sẽ fail vì ảnh khác. Hãy chạy `flutter test --update-goldens`, mở vài
  ảnh trong `test/goldens/` xem có đúng ý không, rồi commit luôn các ảnh đó. Font hiển thị khác
  nhau giữa Windows và macOS, nên **cả nhóm nên thống nhất chỉ tạo ảnh golden trên một loại máy**.

---

## Phần 0: Commit phần sửa lỗi build Android

**Vì sao:** các lỗi `flutter run` lúc trước đã được sửa trong `android/gradle.properties` nhưng
chưa commit. Nếu không commit, bạn khác clone về sẽ gặp lại đúng các lỗi đó.

Những gì đã đổi trong `android/gradle.properties`:

```properties
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=1G -XX:ReservedCodeCacheSize=256m -XX:+HeapDumpOnOutOfMemoryError
...
# The pub cache lives on C: while the project is on D:, which breaks Kotlin
# incremental compilation of plugins (firebase_core etc.) on Windows.
kotlin.incremental=false
kotlin.daemon.jvmargs=-Xmx2G
```

- `kotlin.incremental=false`: sửa lỗi `Could not close incremental caches`, xảy ra khi project ở
  ổ D: còn pub cache ở ổ C:.
- `-Xmx4G`, `kotlin.daemon.jvmargs=-Xmx2G`: sửa lỗi JVM crash vì hết RAM khi build cùng lúc với
  emulator.
- `compileSdk` trong `android/app/build.gradle.kts` đã trả lại **37** như bản trên Git, nên nội
  dung file đó không còn khác gì. `git status` vẫn báo `M` chỉ vì khác kiểu xuống dòng (LF/CRLF),
  nên trả nó về đúng bản trên Git:

```bash
git restore android/app/build.gradle.kts
```

Lệnh Git:

```bash
git switch -c fix/android-build
```

```bash
git add android/gradle.properties
```

```bash
git commit -m "fix(android): build tren Windows khi pub cache va project o hai o dia khac nhau"
```

```bash
git push -u origin fix/android-build
```

`pubspec.lock` cũng đang thay đổi, do `flutter pub get` trên bản Flutter mới hơn. Cả nhóm nên
thống nhất **một** phiên bản Flutter (`flutter --version`). Khi đã thống nhất, commit file này riêng:

```bash
git add pubspec.lock
```

```bash
git commit -m "chore: cap nhat pubspec.lock"
```

---

## Phần 1: Sửa chữ sai trong Cài đặt và tạo lại ảnh golden

> **Cập nhật:** bạn Phát đã làm đúng phần này và đưa lên `main` (commit `089e999`, *fix: settings
> no longer say the log stays on the phone*). Nhánh `fix/settings-text` của bạn không cần merge
> nữa. Cách dọn nhánh nằm ở **Bước 0** của [huong-dan/02-dang-nhap.md](huong-dan/02-dang-nhap.md).
> Phần dưới đây giữ lại để tham khảo.

**Vì sao:** từ khi chuyển sang Firestore, nhật ký đã được lưu trên mây, nhưng màn Cài đặt vẫn ghi
*"Nhật ký chỉ lưu trên điện thoại này, chưa đồng bộ lên tài khoản"*. Giảng viên đọc sẽ thấy mâu
thuẫn với phần công nghệ trong báo cáo. Ngoài ra 49 test đang fail trên Windows chỉ vì ảnh golden
được tạo trên máy khác.

### 1.1 Sửa `lib/screens/settings_screen.dart`

**a) Trong hàm `_confirmClear`**, tìm:

```dart
    final what = meals
        ? 'Xoá hết ${log.meals.length} bữa ăn đã lưu trên máy này.'
        : 'Xoá hết ${log.sets.length + log.sessions.length} mục đã ghi (hiệp tập và buổi tập '
              'ngắn) trên máy này.';
```

Thay bằng:

```dart
    final what = meals
        ? 'Xoá hết ${log.meals.length} bữa ăn đã lưu.'
        : 'Xoá hết ${log.sets.length + log.sessions.length} mục đã ghi (hiệp tập và buổi tập '
              'ngắn).';
```

**b) Trong `build`**, tìm `title: 'Dữ liệu trên máy này',` và đổi thành:

```dart
                      title: 'Dữ liệu của bạn',
```

**c) Cũng trong nhóm đó**, tìm:

```dart
                        const _Note(
                          'Nhật ký chỉ lưu trên điện thoại này, chưa đồng bộ lên tài khoản.',
                        ),
```

Thay bằng:

```dart
                        const _Note(
                          'Nhật ký lưu trên Firebase theo tài khoản của bạn, mất mạng vẫn ghi '
                          'được và tự đồng bộ khi có mạng lại.',
                        ),
```

### 1.2 Sửa test tương ứng: `test/settings_screen_test.dart`

Test tìm đúng câu chữ cũ, nên phải sửa theo. Có **hai chỗ, ở hai test khác nhau**. Mỗi chỗ chỉ
xoá cụm ` trên máy này`, còn lại giữ nguyên (đừng thay câu của test này bằng câu của test kia).

**a) Test `clearing the training log asks first`** (khoảng dòng 266). Tìm:

```dart
        'Xoá hết 3 mục đã ghi (hiệp tập và buổi tập ngắn) trên máy này. Không khôi phục lại được.',
```

Thay bằng:

```dart
        'Xoá hết 3 mục đã ghi (hiệp tập và buổi tập ngắn). Không khôi phục lại được.',
```

**b) Test `clearing meals`** (khoảng dòng 299). Tìm:

```dart
      find.text('Xoá hết 1 bữa ăn đã lưu trên máy này. Không khôi phục lại được.'),
```

Thay bằng:

```dart
      find.text('Xoá hết 1 bữa ăn đã lưu. Không khôi phục lại được.'),
```

Muốn chạy riêng test của màn Cài đặt cho nhanh:

```bash
flutter test test/settings_screen_test.dart
```

### 1.3 Tạo lại ảnh golden

```bash
flutter test --update-goldens
```

```bash
flutter test
```

Lần chạy thứ hai phải ra `All tests passed!`.

### 1.4 Git

```bash
git switch -c fix/settings-text
```

```bash
git add lib/screens/settings_screen.dart test/settings_screen_test.dart test/goldens
```

```bash
git commit -m "fix: chu trong Cai dat dung voi viec luu tren Firestore; tao lai anh golden"
```

```bash
git push -u origin fix/settings-text
```

---

## Phần 2 → 6: hướng dẫn chi tiết nằm ở các file riêng

Mỗi phần có một file riêng, đi từng bước nhỏ: mở file nào, dòng khoảng bao nhiêu, dán code gì,
giải thích từng khối, cách kiểm tra sau mỗi bước, lỗi hay gặp, và commit sau mỗi bước để lúc nào app
cũng build được.

| Phần | File hướng dẫn |
|---|---|
| Kiến thức nền (đọc trước) | [huong-dan/00-kien-thuc-nen.md](huong-dan/00-kien-thuc-nen.md) |
| 2. Đăng ký / đăng nhập | [huong-dan/02-dang-nhap.md](huong-dan/02-dang-nhap.md) (có **Bước 0: dọn nhánh Git**, làm trước tiên) |
| 3. Nhập món thủ công | [huong-dan/03-nhap-mon-thu-cong.md](huong-dan/03-nhap-mon-thu-cong.md) |
| 4. Xem tuần trước | [huong-dan/04-xem-tuan-truoc.md](huong-dan/04-xem-tuan-truoc.md) |
| 5. Đồng hồ nghỉ | [huong-dan/05-dong-ho-nghi.md](huong-dan/05-dong-ho-nghi.md) |
| 6. Luật Firestore | [huong-dan/06-luat-firestore.md](huong-dan/06-luat-firestore.md) |
| **Kiểm thử sau khi clone** (cho cả nhóm) | [huong-dan/07-kiem-thu.md](huong-dan/07-kiem-thu.md): analyze, test tự động, script thử luật Firestore, 40+ ca thử tay có mã, mẫu bảng kết quả cho báo cáo |

---

## Phần 7: Cập nhật bảng chức năng cho báo cáo (mục 2.1b)

Sau khi làm xong các phần trên, bảng chức năng sẽ thành:

| STT | Module | Chức năng | Trạng thái |
|---|---|---|---|
| 1 | Tài khoản | Tự đăng nhập tài khoản khách (ẩn danh) | Hoàn thành |
| 2 | Tài khoản | Tạo tài khoản bằng email, giữ dữ liệu đã có | Hoàn thành |
| 3 | Tài khoản | Đăng nhập email / Google, đăng xuất, quên mật khẩu | Hoàn thành |
| 4 | Hồ sơ | Thông tin cơ thể, mục tiêu, trình độ, số buổi/tuần | Hoàn thành |
| 5 | Hồ sơ | Tính calo và macro mỗi ngày (Mifflin–St Jeor) | Hoàn thành |
| 6 | Cơ thể | Bản đồ cơ trước/sau, lọc bài theo dụng cụ | Hoàn thành |
| 7 | Bài tập | Chi tiết 73 bài: hình động, các bước, lỗi hay gặp, tài liệu | Hoàn thành |
| 8 | Bài tập | Ghi hiệp (kg, số lần, giây), hoàn tác | Hoàn thành |
| 9 | Bài tập | Đồng hồ nghỉ giữa hiệp | Hoàn thành |
| 10 | Buổi tập ngắn | 6 buổi tập theo đồng hồ, tạm dừng, bỏ qua, rung, giữ màn hình sáng | Hoàn thành |
| 11 | Ăn uống | Nhập món thủ công, tìm kiếm không dấu | Hoàn thành |
| 12 | Ăn uống | Chụp/chọn ảnh món ăn | Hoàn thành |
| 13 | Ăn uống | AI nhận diện món từ ảnh | **Chưa hoàn thiện** (chế độ demo) |
| 14 | Ăn uống | Chỉnh khẩu phần, chọn bữa, tổng lượng ăn so với mục tiêu | Hoàn thành |
| 15 | Tuần này | Số hiệp theo nhóm cơ, ngày có tập, xem lại các tuần trước | Hoàn thành |
| 16 | Cài đặt | Nhắc lịch tập (thông báo), rung, giữ màn hình sáng, xoá nhật ký | Hoàn thành |

Bảng công nghệ (mục 2.1a): ghi **Backend: Firebase (Cloud Firestore + Firebase Authentication),
không có REST API riêng**, và **không dùng Dio**. Chỉ ghi những gì app thật sự dùng.

---

## Phụ lục: các việc lớn còn lại (gợi ý hướng làm)

- **AI phân tích ảnh thật:** `lib/logic/meal_analyzer.dart` đã sẵn chỗ gọi API qua
  `--dart-define=MEAL_API_URL=...`. Cần một backend nhỏ (ví dụ Firebase Cloud Functions) nhận ảnh,
  gọi model AI có khả năng đọc ảnh, rồi trả JSON đúng dạng `FoodItem`. **Không đặt API key trong
  app**, vì app Android rất dễ bị giải nén để lấy key.
- **Biểu đồ tiến độ:** thêm nhật ký cân nặng (collection `users/{uid}/weights`) và biểu đồ (package
  `fl_chart`); kỷ lục cá nhân (PR) cho từng bài tính từ `LogStore.sets`.
- **Dùng "Trình độ" để gợi ý:** `profile.level` đang thu thập nhưng chưa dùng. Có thể lọc hoặc
  sắp xếp bài tập theo `ex.level <= profile.level` ở màn Cơ thể.
- **Mục tiêu tuần:** so số buổi đã tập trong tuần với `profile.daysPerWeek` và hiện ở tab Tuần này
  ("Đã tập 2/3 buổi").
