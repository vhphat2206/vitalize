# Kiến thức nền dùng trong Phần 2 → 6

Đọc lướt trang này trước. Khi gặp một cú pháp lạ trong các phần sau, quay lại đây tra. Mọi ví dụ
đều lấy từ chính code Vitalize.

---

## 1. `Future`, `async` / `await`: việc làm "chờ kết quả"

Gọi Firebase cần thời gian (mạng). Dart không bắt app đứng chờ, mà trả về một **`Future<T>`**:
"lời hứa" sẽ có giá trị kiểu `T` **sau này**.

```dart
// lib/state/cloud.dart
Future<UserDoc> signIn(FirebaseAuth auth, FirebaseFirestore db) async { ... }
```

Hai cách lấy giá trị ra:

```dart
// Cách 1: await, chỉ dùng được trong hàm có chữ async
final user = await signIn(auth, db);   // dừng ở đây đến khi có kết quả

// Cách 2: then, đăng ký "khi nào xong thì làm việc này", không dừng
signIn(auth, db).then((user) => print(user.id));
```

Trong `main.dart`, app **không** `await signIn(...)`, vì muốn mở app ngay. Biến `user` là một
`Future<UserDoc>` được đưa cho `LogStore` và `PrefsStore`; hai store tự `.then(...)` khi đăng nhập
xong.

**Lỗi khi `await` thất bại** được bắt bằng `try / catch`:

```dart
try {
  await user.linkWithCredential(cred);
} on FirebaseAuthException catch (e) {   // chỉ bắt đúng loại lỗi của Firebase Auth
  print(e.code);                          // ví dụ: 'weak-password'
}
```

---

## 2. `Stream` và `listen`: dữ liệu đến **nhiều lần**

`Future` cho **một** giá trị, còn `Stream` cho **nhiều** giá trị theo thời gian.

| Stream trong app | Phát ra khi nào |
|---|---|
| `auth.authStateChanges()` | đăng nhập, đăng xuất (đổi người dùng) |
| `auth.userChanges()` | như trên, **và** khi thông tin user đổi (ví dụ vừa gắn email) |
| `collection('sets').snapshots()` | mỗi lần dữ liệu trên Firestore đổi |

```dart
final sub = auth.authStateChanges().listen((user) {
  // chạy mỗi lần có người đăng nhập / đăng xuất
});
...
sub.cancel();   // ngừng nghe, nếu không nó nghe mãi kể cả khi không cần nữa
```

`listen` trả về một **`StreamSubscription`**. Giữ nó lại để `cancel()` khi không cần nữa (trong
`dispose`, hoặc khi đổi sang người dùng khác).

---

## 3. `ChangeNotifier` + `notifyListeners()`: "store" của app

Các class trong `lib/state/` (`LogStore`, `PrefsStore`, và `AccountStore` sắp viết) đều
`extends ChangeNotifier`. Đây là chỗ giữ dữ liệu dùng chung cho nhiều màn hình.

```dart
class LogStore extends ChangeNotifier {
  List<LoggedSet> _sets = [];                 // dữ liệu riêng (dấu _ = private trong file)
  List<LoggedSet> get sets => ...;            // cho màn hình đọc

  void restoreSet(LoggedSet set) {
    _sets = [..._sets, set];
    notifyListeners();                        // "dữ liệu đổi rồi, ai đang xem thì vẽ lại"
    ...
  }
}
```

**Quy tắc:** đổi dữ liệu xong thì gọi `notifyListeners()`. Quên gọi thì màn hình không cập nhật.

---

## 4. Provider: đưa store tới màn hình

Trong `lib/main.dart`, các store được "treo" lên đầu cây widget:

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => prefsStore),
    ChangeNotifierProvider(create: (_) => logStore),
    ...
  ],
  child: const VitalizeApp(),
)
```

Bất kỳ màn hình nào bên dưới cũng lấy được store đó:

| Cách gọi | Dùng ở đâu | Ý nghĩa |
|---|---|---|
| `context.watch<LogStore>()` | trong `build` | lấy store **và** tự vẽ lại khi store gọi `notifyListeners()` |
| `context.read<LogStore>()` | trong hàm xử lý bấm nút, `initState` | chỉ lấy store, không theo dõi |
| `context.watch<AccountStore?>()` | có dấu `?` | không tìm thấy provider thì trả `null` thay vì báo lỗi |

Lỗi hay gặp: **`Could not find the correct Provider<X>`**. Nghĩa là bạn dùng
`context.watch<X>()` nhưng chưa thêm `ChangeNotifierProvider` cho `X` trong `main.dart`, hoặc
đã thêm mà chưa **hot restart** (xem mục 9).

---

## 5. `StatelessWidget` và `StatefulWidget`

- **`StatelessWidget`**: chỉ vẽ theo tham số truyền vào, không tự nhớ gì.
- **`StatefulWidget`**: có một class `State` đi kèm để **nhớ** giá trị (ô đang nhập, đang bận,
  lỗi…). Đổi giá trị bằng `setState`:

```dart
class _AccountScreenState extends State<AccountScreen> {
  bool _busy = false;

  void _start() {
    setState(() => _busy = true);   // đổi giá trị + yêu cầu vẽ lại
  }
}
```

Vòng đời cần biết:

| Hàm | Khi nào chạy | Thường làm gì |
|---|---|---|
| `initState()` | widget vừa được tạo | tạo `Timer`, bắt đầu `listen` |
| `build()` | mỗi lần cần vẽ | trả về giao diện |
| `didUpdateWidget(old)` | widget cha truyền tham số mới | so sánh `old.x` với `widget.x` |
| `dispose()` | widget bị bỏ (thoát màn hình) | `cancel()` timer/stream, `dispose()` controller |

**`mounted`**: sau một `await`, người dùng có thể đã thoát màn hình. Luôn kiểm tra
`if (!mounted) return;` trước khi dùng `context` hoặc `setState` sau `await`.

**`TextEditingController`**: giữ chữ trong ô nhập (`_email.text`). Nhớ `dispose()` nó trong
`dispose()`.

---

## 6. Null safety: dấu `?`, `!`, `??`

| Cú pháp | Nghĩa | Ví dụ |
|---|---|---|
| `String?` | có thể là `null` | `String? _error;` |
| `x?.y` | nếu `x` null thì cả biểu thức là null | `_user?.email` |
| `a ?? b` | nếu `a` null thì dùng `b` | `_user?.isAnonymous ?? true` |
| `x!` | "tôi chắc chắn x không null" (sai là crash) | `mealSlotLabel[_slot]!` |
| `if (x case final y?)` | nếu `x` khác null thì đặt tên `y` (kiểu không null) | `if (_error case final error?) Text(error)` |
| `[?x]` | chỉ thêm `x` vào list nếu khác null | `autofillHints: [?autofill]` |
| `'kg': ?kg` | chỉ thêm khoá vào map nếu khác null | `LoggedSet.toJson` |

---

## 7. `switch` biểu thức và pattern

```dart
String authMessage(String code) => switch (code) {
  'invalid-email' => 'Email không hợp lệ.',
  'invalid-credential' || 'wrong-password' => 'Email hoặc mật khẩu không đúng.',  // nhiều giá trị
  _ => 'Không thực hiện được, thử lại nhé.',                                       // còn lại
};
```

`_` là "mọi trường hợp khác". Dấu `||` trong pattern nghĩa là "hoặc".

---

## 8. Record và vòng lặp có chỉ số

```dart
final List<(MealSlot, String)> slotOptions = [(MealSlot.breakfast, 'Sáng'), ...];  // record 2 phần tử

for (final (i, item) in items.indexed) { ... }   // i = vị trí, item = phần tử
```

`for` và `if` viết **bên trong** list:

```dart
final found = [
  for (final f in catalog.foods)
    if (matchesVi(f.name, query)) f,
];
```

---

## 9. Hot reload, hot restart, chạy lại

Trong terminal đang chạy `flutter run`:

| Phím / lệnh | Dùng khi |
|---|---|
| `r` (hot reload) | sửa giao diện, sửa trong `build` |
| `R` (hot restart) | sửa `main.dart`, thêm provider, đổi biến `static`/global |
| `q` rồi `flutter run` lại | thêm file trong `assets/`, sửa `pubspec.yaml`, sửa file Android (`google-services.json`, Gradle) |

Sửa mà không thấy thay đổi thì thử bậc cao hơn trong bảng.

---

## 10. Firebase Authentication: các khái niệm

| Khái niệm | Nghĩa |
|---|---|
| **User** | một tài khoản trong Firebase Auth |
| **UID** | mã định danh duy nhất của user, ví dụ `Xy7…`. Dữ liệu Firestore nằm ở `users/{UID}` |
| **Anonymous** (ẩn danh / khách) | user không có email; `user.isAnonymous == true` |
| **Provider** | cách đăng nhập: `anonymous`, `password` (email), `google.com` |
| **Credential** | "bằng chứng" đăng nhập, ví dụ cặp email + mật khẩu |
| **Link** (liên kết) | gắn thêm một provider vào **user đang có**, UID giữ nguyên |
| **Sign in** (đăng nhập) | chuyển sang user ứng với credential đó; UID có thể khác |

Xem danh sách user: Firebase Console → **Authentication** → tab **Users**. Có các cột *Identifier*
(email, hoặc trống nếu là khách), *Providers* (biểu tượng cách đăng nhập) và *User UID*.
