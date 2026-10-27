# Phần 2: Đăng ký, đăng nhập, đăng xuất, quên mật khẩu

> Gặp cú pháp lạ thì tra [00-kien-thuc-nen.md](00-kien-thuc-nen.md).

## Làm xong phần này, app sẽ có

- Cài đặt có thêm dòng **Tài khoản**. Đang là khách thì dòng đó ghi *"Đang dùng tài khoản khách"*.
- Màn **Tài khoản** gồm:
  - hai chế độ **Tạo tài khoản / Đăng nhập**, ô email và ô mật khẩu;
  - nút **Tiếp tục với Google** và link **Quên mật khẩu?**;
  - khi đã đăng nhập: hiện email và nút **Đăng xuất**.
- Tạo tài khoản khi đang là khách thì **giữ nguyên** nhật ký đã ghi.
- Đăng nhập trên máy khác vẫn thấy đúng nhật ký của mình.

## Bản đồ việc cần làm

| Bước | Việc | File | Commit sau bước |
|---|---|---|---|
| 0 | Dọn nhánh Git, cập nhật `main` | — | — |
| 1 | Bật Email/Password và Google trong Firebase Console | Console, `firebase.json` | ✔ |
| 2 | Thêm SHA cho đăng nhập Google | Console, `android/app/google-services.json` | ✔ |
| 3 | Tạo "người phụ trách tài khoản" | `lib/state/account_store.dart` (mới) | ✔ |
| 4 | "Người canh cửa" báo đổi người dùng | `lib/state/cloud.dart` | |
| 5 | Store nhật ký chuyển theo người dùng | `lib/state/log_store.dart` | |
| 6 | Store hồ sơ chuyển theo người dùng | `lib/state/prefs_store.dart` | ✔ (gộp 4–6) |
| 7 | Nối dây trong `main` | `lib/main.dart` | ✔ |
| 8 | Màn hình Tài khoản | `lib/screens/account_screen.dart` (mới) | ✔ |
| 9 | Đường vào từ Cài đặt | `lib/screens/settings_screen.dart` | ✔ |
| 10 | Thử toàn bộ, push, tạo Pull Request | — | — |

Sau **mỗi commit** app vẫn build được, nên bạn có thể dừng giữa chừng.

---

## Bước 0: Dọn nhánh Git trước khi làm

Tình trạng hiện tại trên máy bạn (đã kiểm tra bằng `git log --all`):

```
origin/main ── 089e999 fix: settings no longer say the log stays on the phone   ← Phát đã sửa đúng Phần 1
            └─ 5e23b6f docs: meal thumbnails ...
main (máy bạn) ── 972a717   (cũ hơn origin/main 2 commit)
fix/android-build ── f590557, 76b3f76   (76b3f76 chưa push)
fix/settings-text ── 0d5690c   (làm trùng việc Phát đã làm)
```

Phát đã đưa phần sửa chữ Cài đặt lên `main`, nên nhánh `fix/settings-text` của bạn **không cần
nữa**. Nếu vẫn merge sẽ bị xung đột (conflict) ở chính những dòng đó. Làm như sau.

**0.1** Đẩy commit còn thiếu của nhánh build Android:

```bash
git switch fix/android-build
```

```bash
git push
```

Lên GitHub → repo `vhphat2206/vitalize` → **Pull requests** → **New pull request** →
base: `main`, compare: `fix/android-build` → **Create pull request** → nhờ Phát duyệt và
**Merge**.

**0.2** Cập nhật `main` trên máy:

```bash
git switch main
```

```bash
git pull
```

**0.3** Bỏ nhánh làm trùng (cả trên máy và trên GitHub):

```bash
git branch -D fix/settings-text
```

```bash
git push origin --delete fix/settings-text
```

**0.4** Kiểm tra lại test trên `main` mới:

```bash
flutter test
```

Nếu chỉ các **test ảnh golden** fail (dòng báo `Pixel test failed, x% diff`) thì đó là do Phát tạo
ảnh trên máy khác với máy bạn. Cả nhóm thống nhất một máy tạo ảnh golden. Nếu nhóm chọn máy bạn,
chạy `flutter test --update-goldens` rồi commit `test/goldens` riêng.

**0.5** Tạo nhánh cho Phần 2:

```bash
git switch -c feature/account
```

> Nếu PR `fix/android-build` chưa được merge thì khi build trên máy bạn có thể gặp lại lỗi Kotlin
> hoặc hết RAM. Lúc đó chạy `git merge fix/android-build` trong nhánh `feature/account`.

---

## Bước 1: Bật Email/Password và Google trong Firebase

**Mục tiêu:** Firebase mặc định chỉ cho đăng nhập kiểu khách. Phải bật thêm thì code mới gọi được.

**1.1 Kiểm tra quyền của bạn:** [console.firebase.google.com](https://console.firebase.google.com)
→ chọn project **vitalize-gym** → ⚙ (cạnh *Project Overview*) → **Users and permissions**. Tìm
email của bạn: cột *Role* phải là **Owner** hoặc **Editor**. Nếu là *Viewer* thì nhờ Phát nâng
quyền.

**1.2 Bật Email/Password:** menu trái → **Build** → **Authentication** → tab **Sign-in method** →
**Add new provider** → **Email/Password** → bật công tắc đầu tiên *Email/Password* (để **tắt**
dòng *Email link (passwordless sign-in)*) → **Save**.

**1.3 Bật Google:** vẫn tab **Sign-in method** → **Add new provider** → **Google** → bật
**Enable** → *Project support email*: chọn email của nhóm → **Save**.

Xong bước này, danh sách *Sign-in providers* có 3 dòng **Enabled**: Anonymous, Email/Password,
Google.

**1.4 Ghi lại vào `firebase.json`:** file này nói cho lệnh `firebase deploy` biết cần bật những
gì. Ghi vào đây để sau này deploy không vô tình tắt mất Email/Password.

Mở `firebase.json`, tìm:

```json
  "auth": {
    "providers": {
      "anonymous": true
    }
  },
```

Sửa thành:

```json
  "auth": {
    "providers": {
      "anonymous": true,
      "emailPassword": true
    }
  },
```

Chú ý dấu phẩy sau `true` ở dòng `anonymous`. JSON sai một dấu phẩy là lỗi cả file.

**Commit:**

```bash
git add firebase.json
```

```bash
git commit -m "chore: bat dang nhap email/mat khau trong firebase.json"
```

---

## Bước 2: Thêm SHA để đăng nhập Google chạy trên Android

**Mục tiêu:** Google chỉ cho app đăng nhập nếu Firebase biết "chữ ký" (SHA) của bản app đang chạy.
Mỗi máy tính build app có một chữ ký debug riêng. **Bạn nào build trên máy mình thì thêm SHA của
máy đó.** Bỏ qua bước này thì email/mật khẩu vẫn chạy, chỉ nút Google không chạy.

**2.1 Lấy SHA:** trong terminal PowerShell của VS Code:

```bash
cd android
```

```bash
.\gradlew signingReport
```

Lệnh chạy khá lâu ở lần đầu. Kéo lên tìm khối có `Variant: debug`:

```
Variant: debug
Config: debug
Store: C:\Users\<tên bạn>\.android\debug.keystore
Alias: AndroidDebugKey
MD5: ...
SHA1: 5A:3C:....:9F          ← copy dòng này
SHA-256: 1B:77:....:E0       ← và dòng này
```

Quay về thư mục project:

```bash
cd ..
```

**2.2 Thêm vào Firebase:** ⚙ → **Project settings** → tab **General** → kéo xuống *Your apps* → app
Android `app.vitalize.vitalize` → **Add fingerprint** → dán SHA1 → **Save**. Bấm **Add
fingerprint** lần nữa → dán SHA-256 → **Save**.

**2.3 Tải lại cấu hình:** vẫn ở đó, bấm **google-services.json** để tải về → chép đè vào
`android/app/google-services.json`.

**2.4 Kiểm tra:** chạy `git diff android/app/google-services.json`.

- **Có dòng thay đổi** (thường là khối `"oauth_client"` có `certificate_hash`) → commit:

  ```bash
  git add android/app/google-services.json
  ```

  ```bash
  git commit -m "chore: cap nhat google-services.json sau khi them SHA"
  ```

- **Không có dòng nào**, `"oauth_client": []` vẫn rỗng: **vẫn ổn**, không cần commit. Ở project
  đã nâng cấp *Identity Platform* (tiêu đề trang Authentication ghi như vậy), file tải về có thể
  không có khối này. Code ở Bước 3 truyền **Web client ID trực tiếp** cho `google_sign_in`
  (`googleWebClientId`, mục 3.1), nên không cần đọc `oauth_client` trong file. Chỉ cần **Google
  đã Enabled**, **SHA-1 đã thêm**, và Google Cloud có **Android client** (mục 3.1 d). Nếu
  `git status` vẫn báo file bị sửa chỉ vì kiểu xuống dòng, trả về bản trên Git:

  ```bash
  git restore android/app/google-services.json
  ```

Nút Google có chạy thật hay không sẽ biết ở bảng thử **Bước 10, dòng 10**.

---

## Bước 3: Tạo `lib/state/account_store.dart`

**Mục tiêu:** gom **mọi lệnh gọi Firebase Auth** vào một chỗ. Màn hình chỉ cần gọi
`account.register(email, mk)`, không phải biết Firebase hoạt động ra sao.

**Tạo file:** trong VS Code, chuột phải thư mục `lib/state` → **New File** → gõ
`account_store.dart`. Dán toàn bộ:

```dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// The Firebase project's Web client ID: Firebase Console → Authentication → Sign-in method →
/// Google → Web SDK configuration. Google sign-in on Android needs it; it is not a secret.
const googleWebClientId = '455512342228-REPLACE_ME.apps.googleusercontent.com';

/// A failure with a message that can be shown as is.
class AccountError implements Exception {
  const AccountError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Firebase's error codes, in words for the user.
String authMessage(String code) => switch (code) {
  'invalid-email' => 'Email không hợp lệ.',
  'email-already-in-use' ||
  'credential-already-in-use' => 'Email này đã có tài khoản. Chọn "Đăng nhập" để vào tài khoản đó.',
  'weak-password' => 'Mật khẩu cần ít nhất 6 ký tự.',
  'invalid-credential' || 'wrong-password' || 'user-not-found' => 'Email hoặc mật khẩu không đúng.',
  'user-disabled' => 'Tài khoản này đã bị khoá.',
  'too-many-requests' => 'Thử quá nhiều lần, đợi một lát rồi thử lại.',
  'network-request-failed' => 'Không có mạng. Kiểm tra kết nối rồi thử lại.',
  'operation-not-allowed' => 'Cách đăng nhập này chưa được bật trong Firebase Console.',
  'web-context-canceled' || 'canceled' => 'Đã huỷ đăng nhập.',
  'provider-already-linked' => 'Tài khoản đã được liên kết rồi.',
  _ => 'Không thực hiện được, thử lại nhé.',
};

/// The Firebase account behind the log.
///
/// The app starts as a guest (anonymous, see signIn in cloud.dart). "Tạo tài khoản" links an
/// email and password, or Google, to that same user: the uid stays, so does the log. "Đăng nhập"
/// switches to an account made earlier (on another phone, say), and the stores follow it (see
/// watchUserSwitch). "Đăng xuất" goes back to a fresh guest.
class AccountStore extends ChangeNotifier {
  AccountStore(this._auth) : _user = _auth.currentUser {
    // userChanges, not authStateChanges: linking an email keeps the same user, and only
    // userChanges reports it.
    _subscription = _auth.userChanges().listen((u) {
      _user = u;
      notifyListeners();
    });
  }

  final FirebaseAuth _auth;
  late final StreamSubscription<User?> _subscription;
  User? _user;

  /// GoogleSignIn.initialize may be called only once per app run.
  bool _googleReady = false;

  /// A guest until an email or Google is linked; also while signing in for the first time.
  bool get isGuest => _user?.isAnonymous ?? true;

  String? get email => _user?.email;

  /// Guest → account with email and password, keeping the guest's log.
  Future<void> register(String email, String password) => _run(() async {
    final user = _auth.currentUser;
    if (user != null && user.isAnonymous) {
      await user.linkWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } else {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
    }
  });

  /// An account made earlier. The guest's log on this phone stays with the guest.
  Future<void> signIn(String email, String password) =>
      _run(() => _auth.signInWithEmailAndPassword(email: email, password: password));

  /// Google: the phone's own account picker, then links that account to the guest, or signs in
  /// to the Vitalize account it already belongs to.
  Future<void> continueWithGoogle() async {
    final credential = GoogleAuthProvider.credential(idToken: await _googleIdToken());
    await _run(() async {
      final user = _auth.currentUser;
      if (user != null && user.isAnonymous) {
        try {
          await user.linkWithCredential(credential);
          return;
        } on FirebaseAuthException catch (e) {
          if (e.code != 'credential-already-in-use') rethrow;
          // This Google account already has a Vitalize account: sign in to it instead.
        }
      }
      await _auth.signInWithCredential(credential);
    });
  }

  /// Picks a Google account on the phone (Credential Manager) and returns its ID token.
  Future<String?> _googleIdToken() async {
    final google = GoogleSignIn.instance;
    try {
      if (!_googleReady) {
        await google.initialize(serverClientId: googleWebClientId);
        _googleReady = true;
      }
      final account = await google.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      debugPrint('Google: ${e.code} ${e.description}');
      throw AccountError(
        e.code == GoogleSignInExceptionCode.canceled
            ? 'Đã huỷ đăng nhập Google.'
            : 'Không đăng nhập Google được, thử lại nhé.',
      );
    }
  }

  Future<void> resetPassword(String email) =>
      _run(() => _auth.sendPasswordResetEmail(email: email));

  /// Signs out of Google too, so the next "Tiếp tục với Google" asks which account.
  Future<void> signOut() => _run(() async {
    if (_googleReady) await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  });

  Future<void> _run(Future<void> Function() work) async {
    try {
      await work();
    } on FirebaseAuthException catch (e) {
      debugPrint('Account: ${e.code} ${e.message}');
      throw AccountError(authMessage(e.code));
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
```

### Đọc hiểu từng khối

**`AccountError`**: một loại lỗi "của mình", chỉ chứa câu tiếng Việt để hiện lên màn hình. Màn hình
chỉ cần `catch` loại này, không phải biết lỗi gốc của Firebase.

**`authMessage(code)`**: Firebase báo lỗi bằng mã tiếng Anh (`e.code`). Hàm này dịch mã sang câu dễ
hiểu. Các mã hay gặp:

| Mã | Khi nào |
|---|---|
| `email-already-in-use` | tạo tài khoản bằng email đã có người dùng |
| `weak-password` | mật khẩu dưới 6 ký tự |
| `invalid-credential` | sai email hoặc mật khẩu. Firebase mới gộp chung để kẻ xấu không dò được email nào tồn tại |
| `operation-not-allowed` | quên làm Bước 1 |
| `network-request-failed` | mất mạng |

**Constructor `AccountStore(this._auth) : _user = _auth.currentUser { ... }`**:
- `this._auth`: gán tham số vào field `_auth`.
- `: _user = _auth.currentUser`: lấy user hiện tại ngay lúc tạo.
- Trong `{ }`: `listen` stream `userChanges()`. Mỗi khi user đổi (đăng nhập, đăng xuất, **hoặc vừa
  gắn email**) thì cập nhật `_user` và `notifyListeners()`, để màn Cài đặt / Tài khoản vẽ lại.
- Dùng `userChanges()` chứ không dùng `authStateChanges()`: khi gắn email vào tài khoản khách, UID
  không đổi nên `authStateChanges()` **không** báo, chỉ `userChanges()` báo.

**`isGuest`**: `_user?.isAnonymous ?? true`. Không có user (đang đăng nhập lần đầu) thì coi như khách.

**`register`**: đang là khách thì `linkWithCredential`, gắn email vào **chính user khách**, nên UID
giữ nguyên và nhật ký còn nguyên. Không phải khách (hiếm, phòng hờ) thì tạo user mới.

**`signIn`**: đăng nhập tài khoản có sẵn. UID sẽ đổi; Bước 4–7 lo phần chuyển dữ liệu.

**`continueWithGoogle`** (dùng package `google_sign_in`, xem mục 3.1 ngay dưới):
1. `_googleIdToken()` mở **bảng chọn tài khoản Google của chính điện thoại** (Credential Manager
   của Android), rồi lấy **ID token**: một "giấy chứng nhận" do Google ký, nói rằng người này là
   chủ email đó.
2. `GoogleAuthProvider.credential(idToken: ...)` biến token đó thành credential của Firebase.
3. Đang là khách thì `linkWithCredential`, gắn Google vào user khách, UID giữ nguyên.
4. Nếu Google đó **đã có** tài khoản Vitalize (mã `credential-already-in-use`), hoặc không phải
   khách, thì `signInWithCredential`: đăng nhập vào tài khoản đó.
5. `GoogleSignIn.initialize(...)` chỉ được gọi **một lần** mỗi lần chạy app, nên có biến
   `_googleReady`.

> Bản đầu tiên của hướng dẫn dùng `signInWithProvider` (đăng nhập qua trang web trong trình
> duyệt). Trên nhiều điện thoại và máy ảo Android, cách đó báo lỗi *"Unable to process request due
> to missing initial state"*, vì trình duyệt chặn bộ nhớ phiên (sessionStorage). Cách
> `google_sign_in` dùng bảng chọn tài khoản có sẵn của Android nên không bị lỗi này.

**`_run(work)`**: chạy `work`; nếu Firebase ném `FirebaseAuthException` thì:
- in ra terminal dòng `Account: <mã> <chi tiết>` (rất hữu ích khi gỡ lỗi);
- ném lại thành `AccountError` với câu tiếng Việt.

**`dispose`**: huỷ `listen` khi store bị bỏ.

### 3.1 Thêm package `google_sign_in` và điền Web client ID

**a) Thêm package** (lệnh này tự sửa `pubspec.yaml` và `pubspec.lock`):

```bash
flutter pub add google_sign_in
```

Bản đã thử là `google_sign_in: ^7.2.0`.

**b) Lấy Web client ID:** Firebase Console → **Authentication** → **Sign-in method** → bấm vào
dòng **Google** → mở mục **Web SDK configuration** → copy dòng **Web client ID**. Nó có dạng
`455512342228-xxxxxxxx.apps.googleusercontent.com`.

**c) Dán vào code:** trong `lib/state/account_store.dart`, thay giá trị
`'455512342228-REPLACE_ME.apps.googleusercontent.com'` của `googleWebClientId` bằng Web client ID
vừa copy. Đây **không phải bí mật**: nó chỉ cho Google biết token được cấp cho project nào, nên để
trong code và commit lên Git được.

**d) Kiểm tra Android client trên Google Cloud:** bảng chọn tài khoản Google của Android chỉ chạy
khi Google Cloud có một **OAuth client loại Android** khớp *package name* và *SHA-1*.
1. Mở [console.cloud.google.com/apis/credentials](https://console.cloud.google.com/apis/credentials),
   chọn project **vitalize-gym** ở thanh trên cùng.
2. Mục **OAuth 2.0 Client IDs** phải có một dòng **Type: Android** (thường tên là *Android client
   for app.vitalize.vitalize (auto created by Google Service)*). Bấm vào để xem: *Package name* là
   `app.vitalize.vitalize`, *SHA-1* trùng với SHA1 máy bạn.
3. **Không có** dòng Android nào → **+ Create credentials** → **OAuth client ID** → Application
   type **Android** → Package name `app.vitalize.vitalize` → SHA-1 của máy bạn → **Create**. Mỗi
   máy build cần SHA-1 của máy đó.
4. Cùng trang đó cũng có dòng **Type: Web application** (*Web client (auto created by Google
   Service)*). Client ID của dòng này chính là Web client ID ở bước b.

### Kiểm tra

```bash
flutter analyze
```

Phải ra `No issues found!`. File này chưa được dùng ở đâu, nên app chạy y như cũ.

**Lỗi hay gặp:**
- `Target of URI doesn't exist: 'package:firebase_auth/...'`: chạy `flutter pub get`
  (`firebase_auth` đã có sẵn trong `pubspec.yaml`).
- Báo lỗi ở dòng `'a' || 'b' =>`: bạn dán thiếu, hoặc dùng Dart cũ. Kiểm tra `flutter --version`
  (cần Dart 3.13+).

**Commit:**

```bash
git add lib/state/account_store.dart pubspec.yaml pubspec.lock
```

```bash
git commit -m "feat: AccountStore goi Firebase Auth va dich ma loi sang tieng Viet"
```

---

## Bước 4: "Người canh cửa" trong `lib/state/cloud.dart`

**Mục tiêu:** khi UID **đổi** (đăng nhập tài khoản khác, hoặc đăng xuất) thì báo cho các store
biết để chuyển dữ liệu.

**Mở** `lib/state/cloud.dart`. File hiện có 37 dòng, kết thúc bằng dấu `}` của hàm `signIn`.
Đặt con trỏ **sau dấu `}` cuối cùng**, Enter một dòng trống, rồi dán:

```dart

/// Calls [onSwitch] with the next user's document whenever a different user signs in (an
/// account made on another phone, say), and with a fresh guest after signing out. The first
/// user of a launch, and linking an email to the guest, keep the same document: no call.
StreamSubscription<User?> watchUserSwitch(
  FirebaseAuth auth,
  FirebaseFirestore db,
  void Function(Future<UserDoc> user) onSwitch,
) {
  var uid = auth.currentUser?.uid;
  return auth.authStateChanges().listen((user) {
    if (user == null) {
      // Signed out: carry on as a new guest.
      if (uid != null) onSwitch(signIn(auth, db));
    } else if (uid != null && user.uid != uid) {
      onSwitch(Future.value(db.collection('users').doc(user.uid)));
    }
    uid = user?.uid;
  });
}
```

### Đọc hiểu

- `var uid = ...`: nhớ UID **hiện tại**.
- Mỗi lần `authStateChanges()` phát ra có ba trường hợp:

| Tình huống | `user` | `uid` (cũ) | Làm gì |
|---|---|---|---|
| Mở app, Firebase khôi phục user cũ | `abc` | `null` | không báo (chưa có ai để "đổi") |
| Đăng nhập tài khoản khác | `def` | `abc` | **báo** `onSwitch(users/def)` |
| Gắn email vào khách | không phát ra (UID không đổi) | — | — |
| Đăng xuất | `null` | `def` | **báo** `onSwitch(signIn(...))`: tạo khách mới |
| Khách mới vừa tạo xong | `xyz` | `null` | không báo (đã báo ở dòng trên) |

- `onSwitch` là một **hàm được truyền vào** (callback). `main.dart` (Bước 7) sẽ truyền hàm gọi
  `switchUser` của hai store.
- `Future.value(x)`: bọc giá trị có sẵn thành `Future`, để cùng kiểu với `signIn(...)`.
- Không cần thêm import: `cloud.dart` đã import `dart:async`, `cloud_firestore`, `firebase_auth`.

### Kiểm tra

`flutter analyze` → `No issues found!`. Chưa commit, làm tiếp Bước 5–6 rồi commit chung.

---

## Bước 5: `LogStore` chuyển theo người dùng (`lib/state/log_store.dart`)

**Mục tiêu:** khi được báo đổi người, store nhật ký phải: ngừng nghe dữ liệu người cũ → xoá dữ liệu
đang hiện → nghe dữ liệu người mới.

**5.1** Mở `lib/state/log_store.dart`, đến **dòng 164–170**:

```dart
  LogStore(this._user) {
    _user.then(_listen);
  }

  static const _photoDays = 30;

  final Future<UserDoc> _user;
```

Sửa **hai chỗ**:

```dart
  LogStore(this._user) {
    _follow(_user);
  }

  static const _photoDays = 30;

  Future<UserDoc> _user;
```

- `_user.then(_listen)` → `_follow(_user)` (hàm `_follow` sẽ viết ở 5.2).
- Bỏ chữ `final` trước `Future<UserDoc> _user;`, vì giờ `_user` phải **gán lại** được khi đổi người.

**5.2** Tìm dòng `void _listen(UserDoc user) {` (khoảng **dòng 183**). Đặt con trỏ ở **đầu** dòng
đó, Enter tạo dòng trống phía trên, rồi dán:

```dart
  /// Another user signed in, or out (see watchUserSwitch): drop this log and follow theirs.
  void switchUser(Future<UserDoc> user) {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    _sets = [];
    _sessions = [];
    _meals = [];
    notifyListeners();
    _user = user;
    _follow(user);
  }

  /// Listens to [user] once signed in, unless another user has taken over by then.
  void _follow(Future<UserDoc> user) => user.then((u) {
    if (identical(user, _user)) _listen(u);
  });

```

### Đọc hiểu

- `_subscriptions` là danh sách 3 "đường nghe" (`sets`, `sessions`, `meals`) mà `_listen` tạo.
  `cancel()` hết để không nhận dữ liệu người cũ nữa.
- Gán `[]` cho 3 list và `notifyListeners()`: màn hình trống ngay, không hiện lẫn dữ liệu.
- `_user = user`: từ giờ các hàm ghi (`_write`, dùng `_user.then(...)`) tự ghi vào tài khoản mới.
- **`_follow`**: chờ `user` xong rồi mới `_listen`. Điều kiện `identical(user, _user)` nghĩa là
  "`user` vẫn là người hiện tại chứ?". Nếu người dùng đổi tài khoản 2 lần liên tiếp, lần cũ xong
  muộn sẽ bị bỏ qua, không ghi đè lần mới. `identical` so sánh **cùng một đối tượng**, không phải
  so giá trị.

### Kiểm tra

`flutter analyze` → `No issues found!`. Nếu báo `The final variable '_user' can only be set once`
thì bạn quên bỏ chữ `final` ở 5.1.

---

## Bước 6: `PrefsStore` chuyển theo người dùng (`lib/state/prefs_store.dart`)

Giống Bước 5, nhưng cho **hồ sơ** (chiều cao, cân nặng…). **Cài đặt** (rung, giữ màn hình,
nhắc lịch) là của **điện thoại**, lưu trong SharedPreferences, nên giữ nguyên.

**6.1** Mở `lib/state/prefs_store.dart`:
- **Dòng 179**: đổi `_user.then(_listen);` thành `_follow(_user);`
- **Dòng 184**: đổi `final Future<UserDoc> _user;` thành `Future<UserDoc> _user;`

**6.2** Tìm `void _listen(UserDoc user) {` (khoảng **dòng 194**), dán **phía trên** nó:

```dart
  /// Another user signed in, or out (see watchUserSwitch): their profile from now on. The
  /// settings belong to the phone and stay.
  void switchUser(Future<UserDoc> user) {
    _subscription?.cancel();
    _subscription = null;
    _profile = const Profile();
    notifyListeners();
    _user = user;
    _follow(user);
  }

  /// Listens to [user] once signed in, unless another user has taken over by then.
  void _follow(Future<UserDoc> user) => user.then((u) {
    if (identical(user, _user)) _listen(u);
  });

```

`PrefsStore` chỉ có **một** đường nghe (`_subscription`, kiểu nullable), nên dùng `?.cancel()`.
`const Profile()` là hồ sơ trống mặc định.

### Kiểm tra và commit (gộp Bước 4–6)

```bash
flutter analyze
```

```bash
flutter test
```

Cả hai phải sạch. Các store chạy y như cũ vì chưa ai gọi `switchUser`.

```bash
git add lib/state/cloud.dart lib/state/log_store.dart lib/state/prefs_store.dart
```

```bash
git commit -m "feat: ho so va nhat ky chuyen theo khi doi nguoi dung"
```

---

## Bước 7: Nối dây trong `lib/main.dart`

**Mục tiêu:** (1) tạo `AccountStore` để màn hình dùng được; (2) bật "người canh cửa" và chỉ cho nó
gọi `switchUser` của hai store.

**7.1** Thêm import. **Dòng 17** đang là `import 'state/cloud.dart';`. Thêm **phía trên** nó (giữ
thứ tự chữ cái):

```dart
import 'state/account_store.dart';
```

**7.2** Tìm đoạn từ **dòng 26** (`final db = FirebaseFirestore.instance;`) đến hết dòng
`ChangeNotifierProvider(create: (_) => TabNav()),`. Đoạn cũ trông như sau:

```dart
  final db = FirebaseFirestore.instance;
  // Not awaited: the app opens straight away, and the stores wait for the user to save.
  final user = signIn(FirebaseAuth.instance, db);
  final results = await Future.wait([Catalog.load(db: db), SharedPreferences.getInstance()]);
  final prefs = results[1] as SharedPreferences;
  final prefsStore = PrefsStore(prefs, user);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => prefsStore),
        ChangeNotifierProvider(create: (_) => LogStore(user)),
        ChangeNotifierProvider(create: (_) => TabNav()),
```

Thay **cả đoạn** bằng:

```dart
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  // Not awaited: the app opens straight away, and the stores wait for the user to save.
  final user = signIn(auth, db);
  final results = await Future.wait([Catalog.load(db: db), SharedPreferences.getInstance()]);
  final prefs = results[1] as SharedPreferences;
  final prefsStore = PrefsStore(prefs, user);
  final logStore = LogStore(user);
  // Signed in to another account, or signed out: the profile and the log follow.
  watchUserSwitch(auth, db, (next) {
    prefsStore.switchUser(next);
    logStore.switchUser(next);
  });
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => prefsStore),
        ChangeNotifierProvider(create: (_) => logStore),
        ChangeNotifierProvider(create: (_) => AccountStore(auth)),
        ChangeNotifierProvider(create: (_) => TabNav()),
```

Các dòng sau đó (`],`, `child: const VitalizeApp(),`, phần nhắc lịch…) **giữ nguyên**.

### Đọc hiểu: những gì thay đổi

| Trước | Sau | Vì sao |
|---|---|---|
| `LogStore(user)` tạo **bên trong** provider | `final logStore = LogStore(user);` tạo trước | cần biến `logStore` để gọi `logStore.switchUser(...)` |
| — | `watchUserSwitch(auth, db, (next) { ... })` | bật người canh cửa; `(next) {...}` chính là `onSwitch` ở Bước 4 |
| — | `ChangeNotifierProvider(create: (_) => AccountStore(auth))` | để `context.watch<AccountStore>()` dùng được ở màn hình |
| `FirebaseAuth.instance` viết 1 lần | `final auth = FirebaseAuth.instance;` | dùng 3 lần nên đặt tên cho gọn |

### Kiểm tra

```bash
flutter analyze
```

Nếu app đang chạy, nhấn **`R`** (hot restart, chữ hoa) trong terminal `flutter run`. Sửa `main.dart`
thì `r` không đủ. App phải mở bình thường, mọi thứ như cũ.

**Commit:**

```bash
git add lib/main.dart
```

```bash
git commit -m "feat: noi AccountStore va theo doi doi nguoi dung trong main"
```

---

## Bước 8: Màn hình Tài khoản (`lib/screens/account_screen.dart`)

**Tạo file:** chuột phải `lib/screens` → **New File** → `account_screen.dart`. Dán:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../app/toast.dart';
import '../state/account_store.dart';
import '../widgets/back_bar.dart';
import '../widgets/controls.dart';

enum _Mode { register, signIn }

bool _emailOk(String email) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

/// Tài khoản, pushed from settings. A guest makes an account (the log stays) or signs in to one
/// made before; someone signed in sees their email and can sign out.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  _Mode _mode = _Mode.register;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Runs [work]; on success says [done] and, unless [stay], goes back to settings.
  Future<void> _go(
    Future<void> Function(AccountStore account) work,
    String done, {
    bool stay = false,
  }) async {
    if (_busy) return;
    final account = context.read<AccountStore>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work(account);
      if (!mounted) return;
      Toast.show(context, done);
      if (!stay) Navigator.of(context).pop();
    } on AccountError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    final email = _email.text.trim();
    final password = _password.text;
    final problem = !_emailOk(email)
        ? 'Email không hợp lệ.'
        : password.length < 6
        ? 'Mật khẩu cần ít nhất 6 ký tự.'
        : null;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    if (_mode == _Mode.register) {
      _go((a) => a.register(email, password), 'Đã tạo tài khoản $email');
    } else {
      _go((a) => a.signIn(email, password), 'Đã đăng nhập $email');
    }
  }

  void _forgot() {
    final email = _email.text.trim();
    if (!_emailOk(email)) {
      setState(() => _error = 'Nhập email ở trên rồi bấm lại "Quên mật khẩu".');
      return;
    }
    _go((a) => a.resetPassword(email), 'Đã gửi email đặt lại mật khẩu tới $email', stay: true);
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountStore>();
    final insets = MediaQuery.paddingOf(context);
    return ScrolledPast(
      threshold: 40,
      builder: (context, scrolled, controller) => Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              controller: controller,
              padding: EdgeInsets.fromLTRB(V.pad, insets.top + 64, V.pad, insets.bottom + 32),
              child: account.isGuest ? _guest() : _signedIn(account),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BackBar(title: 'Tài khoản', solid: scrolled),
          ),
        ],
      ),
    );
  }

  Widget _guest() {
    final register = _mode == _Mode.register;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Bạn đang dùng tài khoản khách', style: VT.display(26, height: 1.2)),
        const SizedBox(height: 10),
        Text(
          register
              ? 'Tạo tài khoản để giữ nhật ký khi đổi máy hoặc cài lại app. Những gì bạn đã ghi '
                    'được giữ nguyên.'
              : 'Vào tài khoản đã tạo trước đó. Nhật ký của tài khoản khách trên máy này không '
                    'chuyển sang tài khoản đó.',
          style: VT.ui(15, color: V.muted),
        ),
        const SizedBox(height: 22),
        Segmented<_Mode>(
          options: const [(_Mode.register, 'Tạo tài khoản'), (_Mode.signIn, 'Đăng nhập')],
          value: _mode,
          onChanged: (m) => setState(() {
            _mode = m;
            _error = null;
          }),
        ),
        const SizedBox(height: 18),
        _Field(
          controller: _email,
          hint: 'Email',
          keyboard: TextInputType.emailAddress,
          autofill: AutofillHints.email,
        ),
        const SizedBox(height: 10),
        _Field(
          controller: _password,
          hint: register ? 'Mật khẩu (ít nhất 6 ký tự)' : 'Mật khẩu',
          obscure: true,
          autofill: register ? AutofillHints.newPassword : AutofillHints.password,
          onSubmitted: _submit,
        ),
        if (_error case final error?) ...[
          const SizedBox(height: 12),
          Text(error, style: VT.ui(14, color: V.danger)),
        ],
        const SizedBox(height: 18),
        PrimaryButton(
          label: _busy ? 'Đang xử lý…' : (register ? 'Tạo tài khoản' : 'Đăng nhập'),
          onPressed: _busy ? null : _submit,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: GhostButton(
            label: 'Tiếp tục với Google',
            expand: true,
            onPressed: _busy
                ? null
                : () => _go((a) => a.continueWithGoogle(), 'Đã đăng nhập bằng Google'),
          ),
        ),
        if (!register) ...[
          const SizedBox(height: 6),
          Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _busy ? null : _forgot,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Quên mật khẩu?', style: VT.ui(14, color: V.muted)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _signedIn(AccountStore account) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Đã đăng nhập', style: VT.display(26, height: 1.2)),
      const SizedBox(height: 10),
      Text(account.email ?? '', style: VT.ui(16)),
      const SizedBox(height: 10),
      Text(
        'Hồ sơ và nhật ký được lưu theo tài khoản này: đăng nhập trên máy khác vẫn thấy.',
        style: VT.ui(15, color: V.muted),
      ),
      if (_error case final error?) ...[
        const SizedBox(height: 12),
        Text(error, style: VT.ui(14, color: V.danger)),
      ],
      const SizedBox(height: 22),
      SizedBox(
        height: 50,
        child: GhostButton(
          label: 'Đăng xuất',
          danger: true,
          expand: true,
          onPressed: _busy ? null : () => _go((a) => a.signOut(), 'Đã đăng xuất'),
        ),
      ),
    ],
  );
}

/// One text box, styled like the name editor on the profile.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.keyboard,
    this.autofill,
    this.obscure = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;
  final String? autofill;
  final bool obscure;
  final VoidCallback? onSubmitted;

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
      keyboardType: keyboard,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: !obscure,
      autofillHints: [?autofill],
      textInputAction: onSubmitted == null ? TextInputAction.next : TextInputAction.done,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      style: text,
      decoration: InputDecoration(
        hintText: hint,
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
```

### Đọc hiểu: cấu trúc màn hình

```
AccountScreen (StatefulWidget)
└─ _AccountScreenState
   ├─ trạng thái: _email, _password (ô nhập) · _mode (tạo / đăng nhập) · _busy · _error
   ├─ _go(work, done)   ← khuôn chung cho MỌI nút: khoá nút → gọi store → toast / hiện lỗi
   ├─ _submit()         ← kiểm tra email + mật khẩu trên máy trước, rồi gọi register / signIn
   ├─ _forgot()         ← gửi email đặt lại mật khẩu
   └─ build()
      ├─ account.isGuest ? _guest() : _signedIn(account)
      └─ BackBar 'Tài khoản' (nút quay lại, giống các màn khác)
_Field                  ← ô nhập, chép kiểu dáng từ ô đổi tên ở profile_screen.dart
```

Những điểm cần hiểu:

1. **`context.watch<AccountStore>()` trong `build`**: khi gắn email xong, `AccountStore` gọi
   `notifyListeners()`. Màn hình tự vẽ lại, `isGuest` thành `false`, nên chuyển sang `_signedIn`.
2. **`_go(...)` có 4 việc** theo thứ tự:
   1. `_busy = true` để khoá nút, tránh bấm 2 lần;
   2. `await work(account)` gọi store;
   3. thành công: toast + `pop()` quay về Cài đặt; lỗi: lưu `_error` để hiện chữ đỏ;
   4. `finally`: luôn mở khoá nút.
3. **Lấy `context.read` *trước* `await`**: sau `await` màn hình có thể đã bị đóng, dùng `context`
   lúc đó là lỗi. Vì vậy sau `await` có `if (!mounted) return;`.
4. **Kiểm tra trên máy trước khi gọi Firebase** (`_emailOk`, độ dài mật khẩu): báo lỗi ngay, không
   tốn một lần gọi mạng.
5. **`_Mode`** là `enum` riêng của file (dấu `_`). `Segmented` (trong `controls.dart`) là thanh
   chọn 2 nút, cùng loại với thanh chọn bữa Sáng/Trưa/Tối.
6. **`if (_error case final error?) ...[ ... ]`**: chỉ vẽ chữ lỗi khi `_error` khác null. Dấu
   `...[ ]` "trải" nhiều widget vào danh sách `children`.

### Kiểm tra

`flutter analyze` → `No issues found!`. Màn hình chưa có đường vào (Bước 9 mới thêm), nên app
chưa thay đổi gì.

**Commit:**

```bash
git add lib/screens/account_screen.dart
```

```bash
git commit -m "feat: man hinh Tai khoan (tao tai khoan, dang nhap, Google, quen mat khau, dang xuat)"
```

---

## Bước 9: Đường vào từ Cài đặt (`lib/screens/settings_screen.dart`)

**9.1 Import.** Ở đầu file:
- Dưới dòng `import '../logic/reminders.dart';` (dòng 8), thêm:

  ```dart
  import '../state/account_store.dart';
  ```

- Trên dòng `import 'profile/entrance.dart';` (khoảng dòng 16–17), thêm:

  ```dart
  import 'account_screen.dart';
  ```

**9.2 Lấy store.** Tìm dòng `final refused = _refused;` (khoảng dòng 216, trong `build`). Thêm
**ngay dưới**:

```dart
    // Null in widget tests that give the screen no account.
    final account = context.watch<AccountStore?>();
```

Vì sao có dấu `?`: các test sẵn có (`test/settings_screen_test.dart`) dựng màn Cài đặt **không có**
`AccountStore`. Với `AccountStore?`, Provider trả `null` thay vì báo lỗi `Could not find the correct
Provider`. Nhờ vậy test cũ vẫn chạy, còn nhóm Tài khoản chỉ hiện khi có store (tức là trong app
thật).

**9.3 Thêm nhóm "Tài khoản".** Tìm `title: 'Dữ liệu của bạn',` (khoảng dòng 305). Đoạn quanh đó
trông như sau:

```dart
                    const SizedBox(height: 30),
                    Group(
                      title: 'Dữ liệu của bạn',
```

Đặt con trỏ ở đầu dòng `Group(` **này** và dán **phía trên** nó:

```dart
                    if (account != null) ...[
                      Group(
                        title: 'Tài khoản',
                        children: [
                          ValueRow(
                            label: account.isGuest ? 'Tạo tài khoản hoặc đăng nhập' : 'Tài khoản',
                            hint: account.isGuest ? 'Đang dùng tài khoản khách' : account.email,
                            onTap: () =>
                                Navigator.of(context).push(vRoute(const AccountScreen())),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
```

Kết quả, thứ tự nhóm trong Cài đặt: **Khi tập → Nhắc lịch tập → Tài khoản → Dữ liệu của bạn →
Thông tin**.

**9.4 Sửa câu ghi chú.** Bản trên `main` (của Phát) đang ghi *"Nhật ký lưu trên Firebase, gắn với
máy này…"*. Giờ dữ liệu gắn với **tài khoản**, không còn gắn với máy. Tìm:

```dart
                        const _Note(
                          'Nhật ký lưu trên Firebase, gắn với máy này. Mất mạng vẫn ghi được, có mạng lại tự '
                          'đồng bộ.',
                        ),
```

Thay bằng:

```dart
                        const _Note(
                          'Nhật ký lưu trên Firebase theo tài khoản của bạn. Mất mạng vẫn ghi '
                          'được, có mạng lại tự đồng bộ.',
                        ),
```

(Nếu câu trong file của bạn hơi khác, cứ tìm `_Note(` ngay dưới nút **Xoá nhật ký ăn uống**.)

### Kiểm tra

```bash
flutter analyze
```

```bash
flutter test
```

Nếu `flutter test` chỉ fail ở **ảnh golden `settings_*.png`** (do 9.4 đổi câu chữ) thì chạy:

```bash
flutter test --update-goldens
```

**Commit:**

```bash
git add lib/screens/settings_screen.dart test/goldens
```

```bash
git commit -m "feat: them muc Tai khoan trong Cai dat"
```

---

## Bước 10: Thử toàn bộ, push, tạo Pull Request

### 10.1 Chạy app

```bash
flutter run
```

### 10.2 Kịch bản thử (vừa thử vừa chụp ảnh cho báo cáo)

Mở song song Firebase Console → **Authentication** → **Users** để đối chiếu.

| # | Thao tác | Kết quả đúng | Xem trên Console |
|---|---|---|---|
| 1 | Hồ sơ → ⚙ → Cài đặt | Có nhóm **Tài khoản**, dòng *Đang dùng tài khoản khách* | Có 1 user, cột Identifier *(anonymous)*. **Ghi lại UID** |
| 2 | Vào một bài tập, ghi 2 hiệp | Tab Tuần này có 2 hiệp | — |
| 3 | Tài khoản → **Tạo tài khoản**, nhập email thật + mật khẩu 6+ ký tự | Toast *Đã tạo tài khoản…*, quay về Cài đặt, dòng Tài khoản hiện email | Cùng UID ở bước 1, giờ có email và biểu tượng ✉ |
| 4 | Tab Tuần này | **Vẫn còn 2 hiệp** | — |
| 5 | Tài khoản → **Đăng xuất** | Toast *Đã đăng xuất*; tab Tuần này **trống** | Xuất hiện thêm 1 user ẩn danh mới |
| 6 | Tài khoản → **Đăng nhập**, nhập email bước 3 | Toast *Đã đăng nhập…*; **2 hiệp hiện lại**; Hồ sơ hiện lại thông tin cũ | — |
| 7 | Đăng xuất, rồi Đăng nhập với **mật khẩu sai** | Chữ đỏ *Email hoặc mật khẩu không đúng.* | — |
| 8 | Tạo tài khoản với `abc` / mật khẩu `123` | Chữ đỏ *Email không hợp lệ.* (kiểm tra ngay trên máy) | — |
| 9 | Chế độ Đăng nhập → nhập email → **Quên mật khẩu?** | Toast *Đã gửi email…*; hộp thư (xem cả **Spam**) có thư từ Firebase | — |
| 10 | **Tiếp tục với Google** (đã làm Bước 2) | Mở trang chọn tài khoản Google → toast *Đã đăng nhập bằng Google* | Có user với biểu tượng **G** |

### 10.3 Gỡ lỗi khi một bước không đúng

Khi có lỗi, `AccountStore` in ra terminal `flutter run` một dòng `Account: <mã> <chi tiết>`. Đọc
mã đó trước.

| Hiện tượng | Nguyên nhân thường gặp | Cách sửa |
|---|---|---|
| *Cách đăng nhập này chưa được bật…* | `operation-not-allowed` | Làm lại Bước 1.2 / 1.3 |
| Trang web *"Unable to process request due to missing initial state"* | Đang dùng bản cũ `signInWithProvider` | Đổi sang `google_sign_in` như Bước 3 và 3.1 |
| Chọn tài khoản Google xong lại báo *Đã huỷ đăng nhập Google.*, log `Google: GoogleSignInExceptionCode.canceled` | Thường là **cấu hình sai**, không phải bạn bấm huỷ: thiếu Android client / sai SHA-1 / sai `googleWebClientId` | Làm lại 3.1 b–d; đợi 5 phút sau khi tạo client |
| Log `clientConfigurationError` hoặc `serverClientId must be provided` | `googleWebClientId` còn `REPLACE_ME` hoặc dán sai | Làm lại 3.1 b–c |
| Bấm Google trên máy ảo không mở gì | Máy ảo không có trình duyệt / Google Play | Thử trên điện thoại thật, hoặc tạo máy ảo loại có biểu tượng Play Store |
| Đăng nhập xong nhưng nhật ký không đổi | Quên Bước 7 (`watchUserSwitch`) hoặc chưa hot restart | Kiểm tra `main.dart`, nhấn `R` |
| `Could not find the correct Provider<AccountStore>` | Chưa thêm provider ở Bước 7, hoặc dùng `watch<AccountStore>()` (thiếu `?`) ở Cài đặt | Xem lại 7.2 và 9.2 |
| Không nhận được email quên mật khẩu | Thư vào Spam; hoặc email đó chưa từng đăng ký (Firebase vẫn báo thành công để không lộ thông tin) | Kiểm tra Spam, dùng đúng email ở bước 3 |
| `permission-denied` khi lưu hiệp sau khi đăng nhập | Bạn đã làm Phần 6 (luật Firestore) mà sai tên trường | Xem lại Phần 6 |

### 10.4 Push và Pull Request

```bash
git log --oneline -8
```

Phải thấy khoảng 6–7 commit của Phần 2. Đẩy lên:

```bash
git push -u origin feature/account
```

GitHub → **Compare & pull request** → tiêu đề *"Đăng ký, đăng nhập, đăng xuất"* → mô tả ngắn: đã
làm gì, đã thử những bước nào ở 10.2, đính kèm vài ảnh chụp → **Create pull request** → nhờ một bạn
xem → **Merge**. Sau đó:

```bash
git switch main
```

```bash
git pull
```

---

## Tự kiểm tra xem đã hiểu chưa

1. Vì sao **Tạo tài khoản** không làm mất nhật ký, còn **Đăng nhập** thì phải gọi `switchUser`?
   *(Gợi ý: UID có đổi không?)*
2. Nếu bỏ dòng `_subscriptions.clear();` trong `switchUser` thì chuyện gì xảy ra sau 2 lần đổi tài
   khoản? *(Gợi ý: list giữ các subscription đã cancel và cứ dài thêm.)*
3. Vì sao `AccountStore` nghe `userChanges()` còn `watchUserSwitch` nghe `authStateChanges()`?
4. Vì sao trong `_go` phải `context.read<AccountStore>()` **trước** `await`?
