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
| Quản lý trạng thái | provider | Nhật ký tập, ăn uống, hồ sơ |
| Lưu trữ cục bộ | shared_preferences | Lưu dữ liệu trên máy |
| Thông báo | flutter_local_notifications, timezone, flutter_timezone | Nhắc lịch tập hằng tuần |
| Quyền | permission_handler | Xin quyền thông báo, camera |
| Ảnh | image_picker | Chụp, chọn ảnh món ăn |
| Khác | wakelock_plus, url_launcher, path_drawing | Giữ màn hình sáng, mở nguồn tham khảo, vẽ hình |

## Chạy thử

```sh
flutter pub get
flutter run
```

`flutter test` chạy toàn bộ kiểm thử, kể cả ảnh mẫu giao diện trong `test/goldens/`.

Nội dung (bài tập, buổi tập, hình động) được xuất từ bản web trước đó bằng
`tool/export_data.ts`. Giấy phép của hình cơ thể và font: xem `THIRD_PARTY_NOTICES.md`.
