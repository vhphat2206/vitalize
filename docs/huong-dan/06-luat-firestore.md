# Phần 6: Siết luật bảo mật Firestore

> Phần này **không sửa code Dart**, chỉ sửa `firestore.rules`. Bản luật dưới đây **chưa được chạy
> thử**, nên hãy thử trong Rules Playground trước khi Publish (Bước 3).

## Vì sao cần

Mở `firestore.rules`, khối cuối hiện là:

```
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
```

Nghĩa là: người dùng đã đăng nhập được **đọc/ghi mọi thứ** trong `users/<uid của mình>/…`. Đúng là
không ai đọc được dữ liệu người khác. Nhưng một người biết chút kỹ thuật vẫn có thể ghi rác vào phần
của mình (trường lạ, chuỗi rất dài, ảnh hàng MB), làm tốn dung lượng và tiền Firebase của nhóm.

**Luật tốt hơn** là chỉ cho ghi **đúng các trường app thật sự ghi**, đúng kiểu dữ liệu.

## Lấy danh sách trường ở đâu

Mỗi loại dữ liệu có hàm `toJson()`. Đó chính là những gì app gửi lên Firestore:

| Collection | Hàm | File | Các trường |
|---|---|---|---|
| `users/{uid}` | `updateProfile` (`{'profile': …}`), `signIn` (`createdAt`) | `prefs_store.dart`, `cloud.dart` | `profile`, `createdAt` |
| `users/{uid}/sets` | `LoggedSet.toJson` | `log_store.dart` | `id`, `exerciseId`, `at`, `kg`?, `reps`?, `seconds`? |
| `users/{uid}/sessions` | `LoggedSession.toJson` | `log_store.dart` | `id`, `routineId`, `at`, `seconds` |
| `users/{uid}/meals` | `LoggedMeal.toJson` | `log_store.dart` | `id`, `at`, `slot`, `items`, `photo`?, `source` |

(`?` = có thể không có, ví dụ hiệp chống đẩy không có `kg`.)

> **Quan trọng:** sau này thêm trường mới vào `toJson()` thì **phải thêm vào luật**. Nếu không, app
> sẽ ghi lỗi `permission-denied`. Nhớ ghi điều này vào README.

---

## Bước 0: Tạo nhánh

```bash
git switch main
```

```bash
git pull
```

```bash
git switch -c chore/firestore-rules
```

## Bước 1: Sửa `firestore.rules`

Thay **khối cuối** (từ dòng comment `// Each user's profile…` đến hết `match /users/{uid}/{document=**} { … }`)
bằng:

```
    function isOwner(uid) {
      return request.auth != null && request.auth.uid == uid;
    }

    function onlyKeys(keys) {
      return request.resource.data.keys().hasOnly(keys);
    }

    // users/{uid}: the profile (a map) and when the user first appeared.
    match /users/{uid} {
      allow read, delete: if isOwner(uid);
      allow create, update: if isOwner(uid)
        && onlyKeys(['profile', 'createdAt'])
        && (!('profile' in request.resource.data) || request.resource.data.profile is map);
    }

    // LoggedSet.toJson
    match /users/{uid}/sets/{id} {
      allow read, delete: if isOwner(uid);
      allow create, update: if isOwner(uid)
        && onlyKeys(['id', 'exerciseId', 'at', 'kg', 'reps', 'seconds'])
        && request.resource.data.exerciseId is string
        && request.resource.data.at is timestamp;
    }

    // LoggedSession.toJson
    match /users/{uid}/sessions/{id} {
      allow read, delete: if isOwner(uid);
      allow create, update: if isOwner(uid)
        && onlyKeys(['id', 'routineId', 'at', 'seconds'])
        && request.resource.data.routineId is string
        && request.resource.data.seconds is int
        && request.resource.data.at is timestamp;
    }

    // LoggedMeal.toJson; the photo is a small base64 JPEG.
    match /users/{uid}/meals/{id} {
      allow read, delete: if isOwner(uid);
      allow create, update: if isOwner(uid)
        && onlyKeys(['id', 'at', 'slot', 'items', 'photo', 'source'])
        && request.resource.data.slot in ['breakfast', 'lunch', 'dinner', 'snack']
        && request.resource.data.items is list
        && request.resource.data.items.size() <= 30
        && (!('photo' in request.resource.data)
            || (request.resource.data.photo is string
                && request.resource.data.photo.size() < 200000))
        && request.resource.data.at is timestamp;
    }
```

Các khối `match /exercises/…`, `/muscles/…` phía trên giữ nguyên. Hai dấu `}` cuối file (đóng
`match /databases/…` và `service cloud.firestore`) cũng giữ nguyên.

### Đọc hiểu cú pháp luật

| Cú pháp | Nghĩa |
|---|---|
| `match /users/{uid}/sets/{id}` | áp cho mọi document trong `users/<bất kỳ>/sets/`; `{uid}` thành biến |
| `allow read, delete: if …` | cho đọc và xoá nếu điều kiện đúng |
| `allow create, update: if …` | cho tạo mới và sửa nếu điều kiện đúng |
| `request.auth.uid` | UID người đang gửi yêu cầu (đã đăng nhập) |
| `request.resource.data` | dữ liệu **sau khi ghi** (toàn bộ document) |
| `.keys().hasOnly([...])` | document chỉ được chứa các khoá trong danh sách (thiếu thì được, thừa thì không) |
| `x is string / int / map / list / timestamp` | kiểm tra kiểu |
| `'photo' in request.resource.data` | document có khoá `photo` không |
| `function isOwner(uid) { … }` | hàm tự viết để khỏi lặp lại |

Vì sao trường `at` là `timestamp`: `toJson()` ghi `Timestamp.fromDate(at)`. Vì sao `photo` dưới
200.000 ký tự: ảnh thumbnail app tạo khoảng 220 px, chất lượng 72, tức chỉ vài chục KB; giới hạn
này chặn ảnh to bất thường.

## Bước 2: Thử bằng Rules Playground (không ảnh hưởng dữ liệu thật)

1. Firebase Console → **Firestore Database** → tab **Rules**.
2. Dán toàn bộ nội dung `firestore.rules` mới vào ô soạn (**chưa bấm Publish**).
3. Bấm **Rules Playground** (nút ở cạnh trên trình soạn).
4. Thử từng trường hợp:

| Simulation type | Location | Authenticated | Dữ liệu (Build document) | Mong đợi |
|---|---|---|---|---|
| `create` | `/users/u1/sets/s1` | ✔, UID `u1` | `id`: string, `exerciseId`: string, `at`: timestamp, `reps`: integer | ✅ Allowed |
| `create` | `/users/u1/sets/s1` | ✔, UID `u2` | như trên | ❌ Denied (ghi vào phần người khác) |
| `create` | `/users/u1/sets/s1` | ✔, UID `u1` | như trên **+ `hack`: string** | ❌ Denied (trường lạ) |
| `create` | `/users/u1/meals/m1` | ✔, UID `u1` | `id`, `at`: timestamp, `slot`: `"lunch"`, `items`: array, `source`: `"manual"` | ✅ Allowed |
| `create` | `/users/u1/meals/m1` | ✔, UID `u1` | như trên nhưng `slot`: `"brunch"` | ❌ Denied |
| `get` | `/exercises/squat` | không | — | ✅ Allowed |

Kết quả nào khác bảng thì đọc dòng đỏ Playground chỉ ra để sửa.

## Bước 3: Publish và thử app thật

**Cách A (dễ):** ngay trong tab Rules → **Publish**.

**Cách B (dòng lệnh):** cần cài Node.js, rồi:

```bash
npm install -g firebase-tools
```

```bash
firebase login
```

```bash
firebase deploy --only firestore:rules
```

Sau đó mở app, thử **đủ** các thao tác ghi: sửa hồ sơ, ghi hiệp, xong một buổi tập ngắn, lưu bữa
(chụp ảnh **và** nhập tay), sửa khẩu phần một bữa, xoá bữa, xoá nhật ký trong Cài đặt. Theo dõi
terminal `flutter run`. Nếu thấy:

```
Saving to Firestore failed: [cloud_firestore/permission-denied] ...
```

thì luật đang chặn một trường app có ghi. Đối chiếu lại bảng ở đầu trang. Cần gấp thì vào tab
**Rules** → **History** → chọn bản cũ → **Restore**.

## Bước 4: Commit, push

```bash
git add firestore.rules
```

```bash
git commit -m "chore: chi cho ghi dung cac truong app dung vao Firestore"
```

```bash
git push -u origin chore/firestore-rules
```

Tạo Pull Request → merge.

---

## Tự kiểm tra

1. Vì sao luật cũ (`{document=**}`) vẫn an toàn về **quyền riêng tư** nhưng chưa an toàn về **dữ
   liệu rác**?
2. Ở Phần 3, nếu bạn thêm trường `note` cho bữa ăn, luật nào phải sửa?
3. `hasOnly` khác `hasAll` thế nào? Vì sao ở đây dùng `hasOnly`?
