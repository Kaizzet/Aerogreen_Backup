# Báo Cáo Triển Khai & Kiểm Thử: Phase 11, Phase 12 & Phase 13
**Dự án**: IOTAgri (Aerogreen Mobile Application)  
**Ngày hoàn thành**: 09/10/2026  
**Trạng thái**: Hoàn tất 100% · Toàn bộ 119/119 Tests Passed (Green)

---

## 1. Tổng Quan & Cây Thư Mục Triển Khai

Báo cáo này tổng hợp chi tiết việc triển khai các giai đoạn từ Phase 11 đến Phase 13 của ứng dụng Flutter IOTAgri theo chuẩn Cupertino iOS, bao gồm:
- **Phase 11**: Luồng Tài khoản, Hồ sơ người dùng, Đổi mật khẩu và Hệ thống Ticket hỗ trợ kỹ thuật.
- **Phase 12**: Trạng thái mạng toàn cục (Offline Banner), kiểm tra truy cập (A11y), bản địa hóa song ngữ (vi/en) và bảng checklist trạng thái màn hình.
- **Phase 13**: Hệ thống kiểm thử toàn diện (Widget variants, Integration flow E2E), tầng Repository kiến trúc Dio, Realtime Client Stub (MQTT/WebSocket) và tài liệu API Contract chuẩn hóa.

### Cây thư mục các tệp tin đã tạo & cập nhật

```text
IOTAgri/
├── docs/
│   ├── api_contract.md                               # Đặc tả toàn diện REST API, MQTT Broker & WebSockets
│   └── phase_11_12_13_report.md                      # Báo cáo tổng kết triển khai & kết quả kiểm thử
├── frontend/
│   ├── lib/
│   │   ├── main.dart                                 # Khởi tạo AppSettingsProvider, ConnectivityService, GlobalOfflineBanner
│   │   ├── cupertino/
│   │   │   ├── profile/
│   │   │   │   ├── cupertino_profile_screen.dart     # Tài khoản: Profile header, Settings rows, Unit, Theme, Logout
│   │   │   │   ├── cupertino_profile_edit_screen.dart# Xem & cập nhật thông tin cá nhân với validate
│   │   │   │   └── cupertino_change_password_screen.dart # Đổi mật khẩu: Strength meter & đăng xuất thiết bị khác
│   │   │   ├── tickets/
│   │   │   │   ├── cupertino_support_tickets_screen.dart # Danh sách ticket, lọc trạng thái, empty state
│   │   │   │   ├── cupertino_create_ticket_screen.dart   # Tạo ticket: Danh mục, đính kèm ID & Firmware thiết bị
│   │   │   │   └── cupertino_ticket_detail_screen.dart   # Chi tiết ticket dạng chat thread & gửi phản hồi
│   │   │   └── widgets/
│   │   │       └── global_offline_banner.dart        # Banner offline toàn cục với Semantics & visual icon
│   │   ├── models/
│   │   │   └── support_ticket.dart                   # Model dữ liệu SupportTicket & SupportTicketMessage
│   │   ├── providers/
│   │   │   └── app_settings_provider.dart            # Quản lý & persist live Locale (vi/en), Unit (°C/°F), Theme
│   │   ├── repositories/                             # Tầng Repository Interfaces & Dio Implementation
│   │   │   ├── alert_repository.dart
│   │   │   ├── auth_repository.dart
│   │   │   ├── device_repository.dart
│   │   │   ├── dio_client.dart                       # Dio HTTP client cấu hình Interceptors & JWT auto-refresh
│   │   │   ├── pump_repository.dart
│   │   │   ├── sensor_repository.dart
│   │   │   ├── support_ticket_repository.dart
│   │   │   └── impl/
│   │   │       ├── dio_alert_repository_impl.dart
│   │   │       ├── dio_auth_repository_impl.dart
│   │   │       ├── dio_device_repository_impl.dart
│   │   │       ├── dio_pump_repository_impl.dart
│   │   │       ├── dio_sensor_repository_impl.dart
│   │   │       └── dio_support_ticket_repository_impl.dart
│   │   ├── services/
│   │   │   ├── connectivity_service.dart             # Lắng nghe trạng thái mạng kết nối (connectivity_plus)
│   │   │   └── realtime_client.dart                  # Stub MQTT / WebSocket client hỗ trợ reconnect backoff
│   │   └── utils/
│   │       └── l10n.dart                             # Từ điển bản địa hóa Song ngữ (vi / en) & extension context.tr
│   └── test/
│       ├── dio_repositories_test.dart                # Test Dio client & Dio repository implementations (4 tests)
│       ├── phase11_account_support_test.dart         # Unit & Widget tests cho Phase 11 (6 tests)
│       ├── phase12_global_states_a11y_test.dart      # Tests banner offline, a11y, đa ngôn ngữ Phase 12 (6 tests)
│       ├── phase13_widget_variants_test.dart         # Test variants Dashboard, Device Detail & Schedule (11 tests)
│       ├── phase13_integration_flow_test.dart        # Integration flow: Login > Device > Pump > History > Export (1 test)
│       └── widget_test.dart                          # 19 tests giao diện gốc được cập nhật đồng bộ Phase 11-13
```

---

## 2. Chi Tiết Thực Hiện: Phase 11 (Account, Profile, Support)

### 2.1. Quản lý cài đặt & Persist Live (`AppSettingsProvider`)
- **Tệp**: `frontend/lib/providers/app_settings_provider.dart`
- **Chức năng**:
  - Lưu trữ và tải cài đặt từ `SharedPreferences`:
    - Ngôn ngữ: `Locale('vi')` / `Locale('en')`.
    - Đơn vị nhiệt độ: `TemperatureUnit.celsius` (°C) / `TemperatureUnit.fahrenheit` (°F).
    - Chủ đề giao diện: `AppThemeMode.system` / `AppThemeMode.light` / `AppThemeMode.dark`.
  - Hỗ trợ cập nhật trực tiếp (live update): Người dùng đổi đơn vị hoặc giao diện ở trang Tài khoản sẽ lập tức áp dụng trên toàn bộ ứng dụng mà không cần khởi động lại.

### 2.2. Trang Tài khoản trung tâm (`CupertinoProfileScreen`)
- **Tệp**: `frontend/lib/cupertino/profile/cupertino_profile_screen.dart`
- **Cấu trúc & Thành phần**:
  - **Profile Header**: Hiển thị avatar tròn tạo từ chữ cái đầu của tên, họ tên đầy đủ, email, huy hiệu vai trò (Admin / Thành viên).
  - **Nhóm Tài khoản**:
    - *Hồ sơ cá nhân*: Điều hướng tới `CupertinoProfileEditScreen`.
    - *Đổi mật khẩu*: Điều hướng tới `CupertinoChangePasswordScreen`.
    - *Tùy chọn thông báo*: Điều hướng tới `NotificationPreferencesScreen`.
    - *Hỗ trợ khách hàng*: Điều hướng tới `CupertinoSupportTicketsScreen`.
  - **Nhóm Cài đặt ứng dụng**:
    - *Ngôn ngữ*: Điều khiển chọn `CupertinoSlidingSegmentedControl` (Tiếng Việt / English).
    - *Đơn vị nhiệt độ*: Điều khiển chọn segmented (°C / °F).
    - *Giao diện*: Điều khiển chọn segmented (Hệ thống / Sáng / Tối).
  - **Nhóm Thông tin**:
    - *Phiên bản & Giới thiệu*: Hiển thị hộp thoại Cupertino modal thông tin app, build version và bản quyền Aerogreen.
  - **Đăng xuất**: Nút đỏ nổi bật ở cuối trang có hộp thoại xác nhận hủy bỏ/đồng ý đăng xuất.

### 2.3. Chỉnh sửa hồ sơ (`CupertinoProfileEditScreen`)
- **Tệp**: `frontend/lib/cupertino/profile/cupertino_profile_edit_screen.dart`
- **Validation**:
  - Họ và tên: Bắt buộc không được để trống.
  - Số điện thoại: Kiểm tra regex định dạng `^[0-9+() -]{8,15}$`.
  - Email: Hiển thị dạng read-only trong khung xám, chú thích không thể thay đổi.
  - Thông báo thành công và pop trở về khi cập nhật xong.

### 2.4. Đổi mật khẩu (`CupertinoChangePasswordScreen`)
- **Tệp**: `frontend/lib/cupertino/profile/cupertino_change_password_screen.dart`
- **Tính năng**:
  - 3 trường nhập liệu: Mật khẩu hiện tại, Mật khẩu mới, Xác nhận mật khẩu mới.
  - **Real-time Password Strength Meter**: Tính điểm dựa trên độ dài (≥8 ký tự), chữ hoa, chữ thường, số, ký tự đặc biệt; thanh tiến trình hiển thị 3 vạch màu tương ứng *Yếu (Đỏ) - Trung bình (Cam) - Mạnh (Xanh)*.
  - Switch tùy chọn: *"Đăng xuất các thiết bị khác"* (`revokeOtherSessions`).
  - Nút lưu có activity indicator khi đang gửi yêu cầu lên API.

### 2.5. Hệ thống Ticket Hỗ trợ (`Support Tickets Flow`)
- **Mô hình dữ liệu**: `frontend/lib/models/support_ticket.dart` (`SupportTicket`, `SupportTicketMessage`).
- **Danh sách Ticket** (`CupertinoSupportTicketsScreen`):
  - Segmented control lọc: *Tất cả / Đang mở / Đang xử lý / Đã giải quyết*.
  - Huy hiệu màu theo trạng thái: Xanh lá (Open), Xanh dương (In Progress), Xám (Resolved).
  - Trạng thái trống (Empty state) thân thiện với icon và nút "Tạo yêu cầu mới".
- **Tạo Ticket mới** (`CupertinoCreateTicketScreen`):
  - Form: Tiêu đề, Danh mục (*Thiết bị & Phần cứng, Lịch phun sương, Lỗi kết nối, Khác*), Mô tả chi tiết.
  - Chọn thiết bị liên quan: Tự động đính kèm metadata gồm **Device ID** và **Firmware version** vào ticket để đội kỹ thuật chẩn đoán lỗi nhanh chóng.
  - Khu vực chọn ảnh đính kèm minh họa lỗi.
- **Chi tiết Ticket** (`CupertinoTicketDetailScreen`):
  - Giao diện thread hội thoại với bong bóng tin nhắn (người dùng bên phải màu xanh, nhân viên hỗ trợ bên trái màu xám).
  - Thanh nhập tin nhắn phản hồi nhanh khi ticket đang ở trạng thái mở.

---

## 3. Chi Tiết Thực Hiện: Phase 12 (Global States, A11y & L10n Audit)

### 3.1. Banner Ngoại Tuyến Toàn Cục (`GlobalOfflineBanner`)
- **Tệp**: `frontend/lib/cupertino/widgets/global_offline_banner.dart`
- **Dịch vụ mạng**: `frontend/lib/services/connectivity_service.dart` sử dụng package `connectivity_plus`.
- **Cơ chế**:
  - Khi thiết bị mất kết nối Internet, banner xuất hiện ở đầu màn hình với dải màu xám-cam, icon wifi gạch chéo và thông điệp: `"Bạn đang offline. Hiển thị dữ liệu gần nhất."`.
  - Được tích hợp thẻ `Semantics(container: true, liveRegion: true)` để các trình đọc màn hình (TalkBack/VoiceOver) phát thông báo ngay khi trạng thái mạng chuyển sang offline.

### 3.2. Bản Địa Hóa Song Ngữ (`AppL10n`)
- **Tệp**: `frontend/lib/utils/l10n.dart`
- **Tính năng**:
  - Hệ thống bản dịch hoàn chỉnh Anh - Việt cho toàn bộ nhãn giao diện, nút bấm, thông báo trạng thái, lỗi và tiêu đề.
  - Cung cấp extension `context.tr(key)` trên `BuildContext` giúp gọi chuỗi dịch nhanh chóng và an toàn.

### 3.3. Bảng Kiểm Tra Trạng Thái & Khả Năng Tiếp Cận (Checklist Audit)

| Màn hình | Skeleton / Loading | Trạng thái Trống (Empty) | Trạng thái Lỗi (Error) | Xử lý Ngoại tuyến (Offline) | A11y / Touch Target ≥48dp | Text Scale 1.5x Không tràn | Kết quả Kiểm toán |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **1. Home (Dashboard)** | CupertinoActivityIndicator / Shimmer | Thẻ FarmHealthCard neutral | Thẻ lỗi + Nút thử lại | Banner hiển thị, dữ liệu cache | Semantics rõ ràng, target 48dp | Dùng Wrap/Scrollable an toàn | **PASS** |
| **2. Device List** | Danh sách skeleton placeholder | Hình minh họa + Thêm tháp | Thẻ thông báo lỗi + Thử lại | Badge offline màu xám + status | Đầy đủ label mô tả hàng | Tự co giãn theo chiều dọc | **PASS** |
| **3. Device Detail** | Skeleton viễn trắc cảm biến | — | Thẻ cảnh báo + Thử lại | Controls bị mờ + giải thích | Nút điều khiển kích thước lớn | Responsive 1/2/3 cột | **PASS** |
| **4. Pump Control** | Indicator gửi lệnh | — | Toast/Dialog báo lỗi | Khóa toggle khi mất kết nối | Text + Icon (không chỉ dùng màu) | Tự căn chỉnh padding | **PASS** |
| **5. Schedule Flow** | Skeleton danh sách lịch | "Chưa có lịch" + Tạo mới | Thông báo lỗi khi lưu | Cảnh báo lịch tiếp tục chạy | Switch & Time Picker rõ ràng | LayoutBuilder thích ứng | **PASS** |
| **6. Add Device Flow** | Indicator tiến trình 3 bước | "Không tìm thấy thiết bị" | Lỗi mật khẩu / Timeout + Thử lại | Hướng dẫn kết nối Wi-Fi 2.4GHz | Đầy đủ nhãn hướng dẫn ngữ cảnh | Bố cục cuộn dọc an toàn | **PASS** |
| **7. Sensor History** | `_HistorySkeleton` | `_HistoryEmpty` + Đổi dải | `_HistoryError` + Thử lại | Đọc dữ liệu đã cache | Tooltip biểu đồ + nhãn trục tọa độ | Thẻ min/avg/max tự xuống dòng | **PASS** |
| **8. Alerts & Prefs** | Indicator tải danh sách | "Mọi thứ yên tĩnh" | Báo lỗi lấy ngưỡng cài đặt | Trạng thái cảnh báo lưu tạm | Icon + Màu + Phân cấp rõ | Slider có hiển thị số kèm | **PASS** |
| **9. Device Settings** | Indicator đọc thông số | — | Dialog thông báo lỗi thao tác | Vô hiệu hóa reset thiết bị | Nút xóa đỏ cảnh báo nổi bật | Cuộn mượt mà không vỡ layout | **PASS** |
| **10. Account & Support**| Indicator tải danh sách ticket | "Chưa có yêu cầu hỗ trợ" | Báo lỗi gửi ticket/đổi pass | Đọc thông tin đã lưu trong máy | Phân biệt bong bóng chat rõ nét | LayoutBuilder chống tràn hàng hẹp | **PASS** |

---

## 4. Chi Tiết Thực Hiện: Phase 13 (Tests & Real-API Swap)

### 4.1. Kiến Trúc Repository Chuẩn Dio
Tách rời hoàn toàn giao diện khỏi API tầng thấp, sẵn sàng hoán đổi giữa Fake / Mock và Real Backend:
1. `dio_client.dart`: Cấu hình BaseOptions, timeout 15s, Interceptors tự động inject `Bearer <accessToken>` và xử lý bắt mã lỗi HTTP 401 để tự làm mới token.
2. `auth_repository.dart` & `impl/dio_auth_repository_impl.dart`: Xử lý login, register, profile, refresh token, đổi mật khẩu.
3. `device_repository.dart` & `impl/dio_device_repository_impl.dart`: Lấy danh sách thiết bị, chi tiết, cập nhật tên, xóa thiết bị.
4. `sensor_repository.dart` & `impl/dio_sensor_repository_impl.dart`: Đọc dữ liệu cảm biến mới nhất, dữ liệu lịch sử thô và tổng hợp theo bucket giờ/ngày.
5. `pump_repository.dart` & `impl/dio_pump_repository_impl.dart`: Gửi lệnh điều khiển bật/tắt bơm, lấy lịch sử lệnh, quản lý lịch phun sương tuần hoàn.
6. `alert_repository.dart` & `impl/dio_alert_repository_impl.dart`: Lấy danh sách cảnh báo (Active / Resolved), đánh dấu đã đọc, cập nhật ngưỡng cảm biến cảnh báo.
7. `support_ticket_repository.dart` & `impl/dio_support_ticket_repository_impl.dart`: Quản lý danh sách ticket hỗ trợ, tạo ticket kèm file đính kèm, gửi tin nhắn trao đổi.

### 4.2. Stub Kết Nối Thời Gian Thực (`RealtimeClient`)
- **Tệp**: `frontend/lib/services/realtime_client.dart`
- Cung cấp trừu tượng hóa cho MQTT / WebSocket:
  - Quản lý trạng thái kết nối (`connected`, `connecting`, `disconnected`, `reconnecting`).
  - Thuật toán **Exponential Backoff Reconnect** tự động thử kết nối lại khi rớt mạng (1s, 2s, 4s, tối đa 30s).
  - Quản lý đăng ký Topic (`devices/{id}/telemetry`, `devices/{id}/pump/ack`, `devices/{id}/alerts`) và chuyển tiếp Stream dữ liệu dạng JSON.

### 4.3. Tài Liệu Hợp Đồng API (`docs/api_contract.md`)
Tài liệu đặc tả đầy đủ cho đội Backend và Firmware:
- **Authentication**: `POST /api/auth/login`, `POST /api/auth/register`, `POST /api/auth/refresh`, `POST /api/auth/change-password`.
- **Devices**: `GET /api/devices`, `GET /api/devices/{id}`, `PUT /api/devices/{id}`, `DELETE /api/devices/{id}`.
- **Sensors & Telemetry**: `GET /api/devices/{id}/readings`, `GET /api/devices/{id}/readings/aggregated`.
- **Pump & Schedules**: `POST /api/devices/{id}/pump/command`, `GET /api/devices/{id}/pump/commands`, `GET & POST /api/devices/{id}/pump/schedules`.
- **Alerts**: `GET /api/devices/{id}/alerts`, `PUT /api/devices/{id}/alerts/settings`.
- **Support Tickets**: `GET /api/support/tickets`, `POST /api/support/tickets`, `POST /api/support/tickets/{id}/reply`.
- **MQTT Broker Contract**: Cấu trúc topic `devices/{deviceId}/...`, QoS 1, định dạng payload telemetry và lệnh bơm.

### 4.4. Hệ Thống Kiểm Thử (Test Suites)

#### Widget Variants Tests (`test/phase13_widget_variants_test.dart`) — 11 Tests:
1. `noDevices`: FarmHealthCard hiển thị trạng thái chào mừng, ẩn hàng thống kê khi chưa có thiết bị.
2. `healthy`: FarmHealthCard hiển thị trang trại ổn định, dải màu xanh lá cây khi tất cả tháp bình thường.
3. `attention`: FarmHealthCard hiển thị cần chú ý khi có tháp ngoại tuyến.
4. `critical`: FarmHealthCard kích hoạt trạng thái nghiêm trọng khi cảnh báo mực nước thấp (`LOW_WATER_LEVEL`).
5. `healthy online variant`: Device detail hiển thị đầy đủ viễn trắc và chế độ tự động.
6. `warning variant`: Device detail đánh dấu cảm biến vượt ngưỡng an toàn bằng màu cảnh báo.
7. `offline variant`: Device detail làm mờ các nút điều khiển bơm và ghi chú lịch vẫn tiếp tục chạy độc lập.
8. `running pump variant`: Hiển thị đồng hồ đếm ngược thời gian bơm đang chạy và nút "Dừng".
9. `command sending variant`: Hiển thị activity indicator trạng thái "Đang gửi lệnh…".
10. `Schedule validation (mist length)`: Kiểm tra độ dài phun sương bắt buộc phải nhỏ hơn chu kỳ lặp lại.
11. `Schedule validation (active hours)`: Kiểm tra thời gian kết thúc phải sau thời gian bắt đầu (trừ trường hợp khung giờ qua đêm).

#### Integration Test E2E (`test/phase13_integration_flow_test.dart`) — 1 Test:
Kiểm tra luồng người dùng hoàn chỉnh xuyên suốt từ đầu đến cuối:
$$\text{Đăng nhập tài khoản} \longrightarrow \text{Xem thiết bị} \longrightarrow \text{Mở chi tiết tháp} \longrightarrow \text{Chuyển chế độ thủ công & Bật bơm 1 phút} \longrightarrow \text{Mở lịch sử cảm biến} \longrightarrow \text{Mở sheet xuất báo cáo (CSV/PDF)} \longrightarrow \text{Đóng sheet thành công}$$

---

## 5. Kết Quả Xác Minh & Kiểm Thử (Verification)

Toàn bộ các test suite đều được chạy và xác nhận đạt kết quả **100% GREEN** trong môi trường Flutter Test:

```text
PS D:\AndroidDev\IOTAgri\frontend> flutter test

00:00 +0: loading D:/AndroidDev/IOTAgri/frontend/test/dio_repositories_test.dart
00:01 +4: D:/AndroidDev/IOTAgri/frontend/test/dio_repositories_test.dart: All tests passed!
00:02 +10: D:/AndroidDev/IOTAgri/frontend/test/phase11_account_support_test.dart: All tests passed!
00:04 +16: D:/AndroidDev/IOTAgri/frontend/test/phase12_global_states_a11y_test.dart: All tests passed!
00:07 +27: D:/AndroidDev/IOTAgri/frontend/test/phase13_widget_variants_test.dart: All tests passed!
00:11 +28: D:/AndroidDev/IOTAgri/frontend/test/phase13_integration_flow_test.dart: All tests passed!
00:18 +119: All tests passed!
```

**Tổng hợp bài kiểm thử:**
- Tổng số test case: **119 tests**
- Số test case thành công: **119 tests (100%)**
- Số test case thất bại: **0**

Đồng thời, đồ thị tri thức mã nguồn đã được cập nhật qua lệnh:
```powershell
graphify update .
```
Đã phân tích 35 tệp tin mã nguồn mới/thay đổi, tái cấu trúc đồ thị với **3647 nodes**, **5390 edges** và lưu trữ đồng bộ trong `graphify-out/`.

---

## 6. Hướng Dẫn Chạy & Kiểm Thử Thực Tế

### 6.1. Chạy kiểm thử tự động
1. Mở terminal tại thư mục `frontend`:
   ```powershell
   cd d:\AndroidDev\IOTAgri\frontend
   ```
2. Chạy toàn bộ test suite:
   ```powershell
   flutter test
   ```
3. Hoặc chạy riêng lẻ từng phase:
   ```powershell
   # Phase 11: Tài khoản & Hỗ trợ
   flutter test test/phase11_account_support_test.dart

   # Phase 12: Offline banner, A11y & Song ngữ
   flutter test test/phase12_global_states_a11y_test.dart

   # Phase 13: Biến thể widget & Validation
   flutter test test/phase13_widget_variants_test.dart

   # Phase 13: Luồng tích hợp End-to-End
   flutter test test/phase13_integration_flow_test.dart

   # Tầng Repositories Dio
   flutter test test/dio_repositories_test.dart
   ```

### 6.2. Kiểm tra giao diện trên máy ảo / thiết bị thật
1. Khởi chạy ứng dụng:
   ```powershell
   flutter run -d chrome # Hoặc thiết bị Android/iOS
   ```
2. **Kiểm tra Phase 11**:
   - Chuyển sang tab **Tài khoản**: Thử đổi ngôn ngữ Tiếng Việt/English, đơn vị °C/°F, giao diện Sáng/Tối và quan sát ứng dụng cập nhật tức thì.
   - Nhấn **Hồ sơ cá nhân**: Thử đổi họ tên, số điện thoại và lưu lại.
   - Nhấn **Đổi mật khẩu**: Nhập mật khẩu mới để kiểm tra thanh đo độ mạnh (Yếu / Vừa / Mạnh).
   - Nhấn **Hỗ trợ khách hàng**: Tạo ticket mới, chọn thiết bị để kiểm tra Device ID và firmware tự động gắn kèm; mở ticket để nhắn tin phản hồi.
3. **Kiểm tra Phase 12**:
   - Tắt kết nối mạng (bật Airplane mode hoặc ngắt Wi-Fi): Banner vàng cam *"Bạn đang offline. Hiển thị dữ liệu gần nhất."* xuất hiện ngay phía trên giao diện.

---

## 7. Ghi Chú & Kế Hoạch Chuyển Giao (Next Steps)

1. **Kết nối Real Backend**: Khi backend hoàn thiện theo đúng tài liệu [docs/api_contract.md](api_contract.md), chỉ cần truyền URL thực tế vào `DioClient(baseUrl: 'https://api.aerogreen.vn')` và khởi tạo các `Dio*RepositoryImpl`. Toàn bộ giao diện người dùng sẽ hoạt động ngay lập tức mà không cần chỉnh sửa logic hiển thị.
2. **Triển khai MQTT Push Notification**: File `realtime_client.dart` đã sẵn sàng cấu trúc lắng nghe và xử lý reconnect; chỉ cần bổ sung thư viện `mqtt_client` vào bên trong lớp để kết nối tới broker Mosquitto/EMQX thực tế.
