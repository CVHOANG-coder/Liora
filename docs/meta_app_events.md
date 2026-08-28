# Meta App Events — Nostalia

Ứng dụng dùng [facebook_app_events](https://pub.dev/packages/facebook_app_events)
`^0.30.5` (Flutter wrapper cho Meta SDK Android/iOS) để đo lường cài đặt và
lượt mở app từ quảng cáo. Không thêm Facebook Login hoặc Audience Network.

## Cấu hình đã tích hợp

| Mục | Giá trị |
| --- | --- |
| Facebook App ID | `2116175409267246` |
| Android package | `com.nostalia.ai.videogenerator` |
| Android activity | `com.nostalia.ai.videogenerator.MainActivity` |
| iOS Bundle ID | `com.nostalia.ai.videogenerator` |
| iOS URL scheme | `fb2116175409267246` |

App ID và Client Token nằm trong `android/app/src/main/res/values/facebook.xml`
và `ios/Runner/Info.plist`. Client Token là cấu hình mobile client, **không phải
App Secret**. Không đưa Facebook App Secret/access token quản trị vào app.

`MetaAppEventsService` khởi tạo trong `main()` và kích hoạt đo lường app events.
SDK native quản lý lifecycle; không gửi thêm sự kiện activation trên mỗi lần
resume và không gửi thủ công purchase để tránh đếm trùng với auto logging.
Không truyền tên, email, mã hồ sơ hoặc user ID riêng vào Meta.

## Tracking trên iOS

- IDFA mặc định tắt trong Info.plist. Chỉ bật khi ATT trả về `granted`.
- Ở lần cài mới, hoãn activation/install ping đến sau quyết định ATT đầu tiên
  để áp dụng quyền trước khi SDK gửi install ping (chỉ gửi một lần).
- Yêu cầu ATT sau khi splash hiển thị, trước khi chuyển tới Home để không trùng
  với hộp thoại quyền thông báo. Từ chối/restricted không chặn sử dụng app.
- Nếu không có quyền ATT, giữ giới hạn sử dụng dữ liệu cho analytics/conversions
  và để native SDK áp dụng giới hạn của hệ điều hành; không dùng ID thay thế.
- Khi quay lại app từ Settings, đọc lại ATT và cập nhật quyền thu thập IDFA.
- Đồng bộ thêm cờ advertiser tracking cho iOS 15/16. Trên iOS 17+, Meta SDK
  tự đọc ATT và bỏ qua setter cũ; app không ghi đè lựa chọn của người dùng.
- Dùng `permission_handler` có sẵn. SwiftPM đọc
  `NSUserTrackingUsageDescription`; CocoaPods có macro ATT trong Podfile.
  Với build trực tiếp từ Xcode, nếu permission_handler báo không tìm thấy
  Info.plist, làm theo hướng dẫn package để đặt `PERMISSION_HANDLER_INFO_PLIST`
  trỏ đến file `ios/Runner/Info.plist` của checkout và resolve lại Swift packages.

ATT không thay thế toàn bộ yêu cầu đồng ý xử lý dữ liệu theo khu vực. Trước khi
phát hành, rà soát privacy policy, App Store App Privacy và Google Play Data
Safety/Advertising ID tương ứng với Meta SDK và các SDK hiện có. Android hiện
bật thu thập Advertising ID trong bước khởi tạo; nếu thị trường yêu cầu consent
riêng, cần nối trạng thái consent vào bước này trước khi cho phép thu thập.

## Cần hoàn tất trên Meta trước khi chạy quảng cáo

1. Mở đúng app trong Meta for Developers, kiểm tra nền tảng Android/iOS dùng
   package/bundle ID ở trên. Điền thông tin Google Play/App Store; iOS App Store
   ID phải lấy từ app thực tế, không dùng Facebook App ID thay thế.
2. Liên kết app/data source với business và tài khoản quảng cáo sẽ sử dụng.
   Hoàn tất các yêu cầu trạng thái app/quyền truy cập mà dashboard hiển thị.
3. Bật/kiểm tra app event logging trong cài đặt Meta; mở Events Manager và chọn
   data source của app để kiểm tra Test Events/Diagnostics.
4. Cài **bản build mới** trên điện thoại thật, mở app và kiểm tra app activation
   (`fb_mobile_activate_app`) xuất hiện. Thử cài mới để kiểm tra install. Sự kiện
   có thể được gửi theo batch; không kết luận ngay chỉ từ log local.
5. Trên iOS thử cả Allow và Ask App Not to Track, sau đó thay đổi quyền trong
   Settings và mở lại app. Trên Android kiểm tra thêm bản release từ Play.
6. Chỉ chọn app để chạy chiến dịch App promotion sau khi xác nhận Meta nhận
   events. Nếu tối ưu Purchase/Subscribe/StartTrial, kiểm tra sự kiện giao dịch
   sandbox thực tế trước; không mặc định auto logging đã đủ cho mọi flow IAP.

Chưa có quyền truy cập dashboard trong lần tích hợp này nên chưa thể xác nhận
event đã đến Meta, liên kết tài khoản quảng cáo hoặc tạo chiến dịch.

## Build và chẩn đoán

Thay đổi này có native SDK nên hot reload/hot restart không đủ:

```sh
flutter pub get
flutter run
```

Khi cần log SDK trên thiết bị thử nghiệm:

```sh
flutter run --dart-define=META_DEBUG_LOGGING=true
```

Log chi tiết chỉ được bật ở debug mode. Không chia sẻ log chứa dữ liệu thiết bị.

```sh
flutter analyze
flutter test test/meta_app_events_service_test.dart
flutter test
flutter build apk --debug
flutter build ios --simulator --debug
```

Tham khảo: [package](https://pub.dev/packages/facebook_app_events),
[Meta Android App Events](https://developers.facebook.com/docs/app-events/getting-started-app-events-android/),
[Meta iOS App Events](https://developers.facebook.com/docs/app-events/getting-started-app-events-ios/),
[Apple privacy and tracking](https://developer.apple.com/app-store/user-privacy-and-data-use/).
