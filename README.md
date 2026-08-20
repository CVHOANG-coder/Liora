# VideoGen

Codebase Flutter tối giản, được tách riêng từ định hướng kiến trúc và giao diện của WaifuAI.

## Màn hình

- Home: lời chào, thẻ giới thiệu, thao tác nhanh và danh sách dự án gần đây.
- Profile: thông tin cá nhân, thống kê, gói Pro và menu tài khoản.
- Bottom tab: Home và Profile, nút tạo mới nằm giữa.
- Create sheet: mở từ nút `+`, cho phép chọn Video, Hình ảnh hoặc Mẫu.

## Cấu trúc

```text
lib/
├── core/constants/
├── presentation/screens/
│   ├── home/
│   ├── main/
│   └── profile/
├── presentation/widgets/
├── shared/themes/
└── main.dart
```

## Chạy project

```bash
flutter pub get
flutter run
```

## Kiểm tra

```bash
flutter analyze
flutter test
```
