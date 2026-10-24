# Vitalize

Ứng dụng tập gym trên điện thoại, viết bằng Flutter.

- **Cơ thể**: chạm vào nhóm cơ trên bản đồ cơ thể (mặt trước, mặt sau) để xem các bài tập
  cho cơ đó, lọc theo dụng cụ.
- **Bài tập**: 73 bài, mỗi bài có hình động minh hoạ, các bước, lỗi hay gặp, cơ chính và cơ
  phụ, nguồn tham khảo (ACE, NASM, NSCA, Mayo Clinic, …) và ghi từng hiệp.
- **Buổi tập ngắn**: 6 buổi khởi động, giãn cơ, core, toàn thân, cardio; đồng hồ đếm từng động
  tác, rung báo, giữ màn hình sáng.
- **Ăn uống**: chụp hoặc chọn ảnh món ăn để ước tính calo (hiện đang ở chế độ thử, trả kết quả
  mẫu), so với mục tiêu mỗi ngày tính từ hồ sơ.
- **Tuần này**: số hiệp đã tập theo từng nhóm cơ trong tuần.
- **Hồ sơ và cài đặt**: thông tin cơ thể, mục tiêu, nhắc lịch tập bằng thông báo.

## Công nghệ

| Thành phần | Công nghệ / thư viện | Mục đích |
| --- | --- | --- |
| Ứng dụng | Flutter, Dart | Giao diện và logic |
| Cơ sở dữ liệu | Firebase Cloud Firestore (cloud_firestore) | Danh mục bài tập; nhật ký tập, bữa ăn, hồ sơ của từng người |
| Xác thực | Firebase Authentication (firebase_auth), đăng nhập ẩn danh | Mỗi máy một tài khoản riêng, không cần đăng ký |
| Quản lý trạng thái | provider | Nhật ký tập, ăn uống, hồ sơ |
| Lưu trữ cục bộ | shared_preferences | Cài đặt riêng của máy (rung, màn hình, nhắc lịch) |
| Thông báo | flutter_local_notifications, timezone, flutter_timezone | Nhắc lịch tập hằng tuần |
| Quyền | permission_handler | Xin quyền thông báo, camera |
| Ảnh | image_picker | Chụp, chọn ảnh món ăn |
| Khác | wakelock_plus, url_launcher, path_drawing | Giữ màn hình sáng, mở nguồn tham khảo, vẽ hình |

## Chạy thử

Cần Flutter bản stable mới nhất (Dart 3.13 trở lên). Trên Windows: cài Git, Flutter và Android
Studio, rồi chạy trên điện thoại Android (bật gỡ lỗi USB) hoặc máy ảo Android. Bản iPhone chỉ
build được trên máy Mac.

```sh
git clone https://github.com/vhphat2206/vitalize.git
cd vitalize
flutter pub get
flutter run
```

Không cần đăng nhập Firebase: cấu hình kết nối (`lib/firebase_options.dart`,
`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`) đã nằm trong repo.
Các khoá trong đó không phải bí mật; dữ liệu được bảo vệ bằng luật trong `firestore.rules`.

`flutter test` chạy toàn bộ kiểm thử, kể cả ảnh mẫu giao diện trong `test/goldens/`; phần lưu trữ
được thử trên Firestore giả lập trong bộ nhớ (fake_cloud_firestore), không đụng dữ liệu thật.

## Dữ liệu trên Firebase

Mở app lần đầu, app tự đăng nhập ẩn danh: mỗi máy có một mã người dùng (uid) riêng, thấy trong
Firebase Console → Authentication.

| Đường dẫn trong Firestore | Nội dung | Ai được đọc / ghi |
| --- | --- | --- |
| `exercises`, `muscles`, `routines`, `moves`, `meta` | Danh mục: 73 bài tập, nhóm cơ, buổi tập ngắn, động tác, nhãn dụng cụ | Ai cũng đọc được; app không ghi |
| `users/{uid}` | Hồ sơ (trường `profile`) | Chỉ chính người đó |
| `users/{uid}/sets`, `…/sessions`, `…/meals` | Các hiệp đã ghi, buổi tập đã xong, bữa ăn | Chỉ chính người đó |

Firestore giữ một bản sao trên máy nên app vẫn dùng được khi mất mạng; có mạng lại thì tự đồng
bộ. Danh mục bài tập đọc từ Firestore mỗi lần mở app; lần đầu mà chưa có mạng thì dùng bản JSON đi
kèm app (`assets/data`). Hình cơ thể, hình động và kết quả mẫu của đo calo luôn nằm trong app.

Dành cho người quản lý dự án Firebase (cần `firebase login` bằng tài khoản chủ dự án):

```sh
dart run tool/seed_firestore.dart                 # đưa danh mục từ assets/data lên Firestore
firebase deploy --only firestore:rules,auth       # luật bảo vệ dữ liệu + bật đăng nhập ẩn danh
```

Nội dung (bài tập, buổi tập, hình động) được xuất từ bản web trước đó bằng
`tool/export_data.ts`. Giấy phép của hình cơ thể và font: xem `THIRD_PARTY_NOTICES.md`.
