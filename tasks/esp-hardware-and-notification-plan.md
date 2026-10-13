# Kế Hoạch Chuẩn Hóa Code, Điều Khiển ESP32 Thật & Hệ Thống Thông Báo Thời Gian Thực

> **Dự án**: IOTAgri (Aeroponics IoT System)  
> **Tài liệu**: Kế hoạch kỹ thuật chi tiết (Technical Implementation Plan)  
> **Trạng thái**: Chờ duyệt trước khi triển khai mã nguồn  

---

## 1. Mục Tiêu & Phạm Vi

1. **Clean Code**: Xóa bỏ hoàn toàn mã giả/mã rác (Dead code) và chuẩn hóa chú thích trong Frontend.
2. **ESP32 Hardware Control**: Nâng cấp firmware ESP32 để tiếp nhận lệnh bật/tắt bơm từ ứng dụng/lịch trình, điều khiển Relay vật lý và phản hồi trạng thái (ACK) qua MQTT hai chiều.
3. **Real Notifications**: Thiết lập cơ chế thông báo thực tế tới hệ điều hành người dùng (Web & Mobile) khi có sự cố cảm biến hoặc thay đổi trạng thái tưới.
4. **Realtime Sync**: Đồng bộ hóa tức thời giữa Phần cứng ESP32 $\leftrightarrow$ MQTT Broker $\leftrightarrow$ Backend $\leftrightarrow$ Frontend Flutter (không trễ 20 giây do polling).

---

## 2. Chi Tiết Các Giai Đoạn Triển Khai

```mermaid
graph TD
    UI[Frontend Flutter] -->|1. REST API Command / Schedule| API[Backend ASP.NET Core 9]
    API -->|2. MQTT Command: devices/{key}/commands/pump| Broker[Mosquitto Broker :1883]
    Broker -->|3. Receive Command| ESP[ESP32 Hardware]
    ESP -->|4. Trigger GPIO Relay| Relay[Relay Máy Bơm]
    ESP -->|5. MQTT ACK: devices/{key}/pump-status| Broker
    Broker -->|6. Ingestion & DB Update| API
    Broker -->|7. Realtime Push :9001 WS| UI
    API -->|8. Alert / Notification Push| Notif[Hệ điều hành / Push Service]
```

---

### Giai Đoạn 1: Dọn Dẹp Mã Nguồn (Clean Code)

* **Mục tiêu**: Loại bỏ code thừa, tránh nhầm lẫn trong bảo trì và vận hành.
* **Các bước thực hiện**:
  1. **Xóa file rác mồ côi**: Xóa file `frontend/lib/services/mock_admin_service.dart`.
     * *Lý do*: Toàn bộ 8 màn hình Admin Panel đã chuyển sang dùng `ApiService` gọi trực tiếp Backend REST API thật. File này không còn bất kỳ import nào.
  2. **Dọn chú thích gây hiểu nhầm**:
     * `frontend/lib/cupertino/admin/tickets/cupertino_tickets_screen.dart`: Cập nhật comment tại dòng 51 từ `// Load tickets từ mock service` thành `// Load tickets từ ApiService`.
     * `frontend/lib/cupertino/admin/tickets/cupertino_ticket_detail_screen.dart`: Cập nhật comment tại dòng 55 từ `// Load tin nhắn (mock)` thành `// Load tin nhắn từ ApiService`.
  3. **Kiểm thử hồi quy**: Chạy `flutter test` đảm bảo 119/119 unit/widget tests tiếp tục xanh.

---

### Giai Đoạn 2: Firmware ESP32 - Điều Khiển Relay Thật & Phản Hồi Trạng Thái (2-Way MQTT)

* **File mục tiêu**: `firmware/ESP32DeviceSetup/ESP32DeviceSetup.ino`
* **Vấn đề hiện tại**: ESP32 chỉ gửi telemetry 1 chiều lên `devices/{deviceKey}/readings`, chưa đăng ký nhận lệnh điều khiển bơm và chưa có chân Relay.

#### Bước 2.1: Cấu hình phần cứng Relay
* Định nghĩa chân điều khiển máy bơm:
  ```cpp
  constexpr uint8_t PUMP_RELAY_PIN = 23; // Chân GPIO kết nối Relay máy bơm
  constexpr uint8_t RELAY_ACTIVE_LEVEL = HIGH; // HIGH hoặc LOW tùy module relay
  ```
* Khởi tạo trong `setup()`:
  ```cpp
  pinMode(PUMP_RELAY_PIN, OUTPUT);
  digitalWrite(PUMP_RELAY_PIN, !RELAY_ACTIVE_LEVEL); // Đảm bảo luôn TẮT khi khởi động
  ```

#### Bước 2.2: Đăng ký nhận lệnh MQTT (Subscribe)
* Khi kết nối MQTT thành công trong `connectMqtt()`:
  ```cpp
  String cmdTopic = "devices/" + deviceKey + "/commands/pump";
  mqtt.subscribe(cmdTopic.c_str());
  ```

#### Bước 2.3: Xử lý gói tin lệnh (MQTT Callback Handler)
* Gán callback `mqtt.setCallback(onMqttMessage);`.
* Khi nhận tin từ `devices/{deviceKey}/commands/pump`:
  * Backend gửi định dạng JSON:
    ```json
    {"id": "uuid-command-id", "isOn": true, "durationSeconds": 30}
    ```
  * Firmware bóc tách các trường: `id`, `isOn`, `durationSeconds`.
  * Điều khiển phần cứng:
    ```cpp
    digitalWrite(PUMP_RELAY_PIN, isOn ? RELAY_ACTIVE_LEVEL : !RELAY_ACTIVE_LEVEL);
    isPumpRunning = isOn;
    ```
  * **Cơ chế an toàn cục bộ (Hardware-safe Auto Shutoff)**:
    * Nếu `isOn == true` và `durationSeconds > 0`: Lưu `pumpStartedAt = millis()` và `pumpDurationMs = durationSeconds * 1000`.
    * Trong `loop()`: Kiểm tra nếu `millis() - pumpStartedAt >= pumpDurationMs` thì tự động ngắt relay, bảo vệ phần cứng kể cả khi mất kết nối mạng.

#### Bước 2.4: Phản hồi trạng thái (ACK) về Backend
* Ngay sau khi thực thi lệnh (hoặc khi tự động ngắt do hết giờ):
  * Publish gói tin lên topic `devices/{deviceKey}/pump-status`:
    ```json
    {
      "commandId": "uuid-command-id",
      "isOn": true,
      "wasSuccessful": true,
      "failureReason": null
    }
    ```
  * Backend `MqttIngestionService.cs` sẽ nhận tin này, cập nhật trạng thái lệnh sang `Acknowledged` và cập nhật `device.IsPumpOn` trong cơ sở dữ liệu.

---

### Giai Đoạn 3: Hệ Thống Thông Báo Thật (Real Notifications)

Hiện tại Backend chỉ ghi bản ghi vào bảng `DeviceAlerts`, Frontend đang dùng `FakeNotificationService` (in-memory stream).

#### Phương Án 3A: Thông báo hệ điều hành nội bộ qua WebSocket / SignalR (Khuyên dùng triển khai ngay)
* **Ưu điểm**: Hoạt động ngay trên mạng LAN/Dev, không cần tài khoản Google Play Developer hay chứng chỉ Apple.
* **Backend**:
  * Khi `DeviceAlertRules.IsUnsafe` phát hiện cảm biến vượt ngưỡng (nhiệt độ cao, cạn nước) trong `MqttIngestionService.cs`:
  * Publish sự kiện lên topic MQTT thông báo: `devices/{deviceKey}/alerts` hoặc gửi qua SignalR Hub.
* **Frontend Flutter**:
  * Tích hợp `flutter_local_notifications` (đối với Android) và Web Notifications API (đối với trình duyệt Chrome/Edge).
  * Khi nhận được sự kiện cảnh báo từ stream:
    * Gọi `showNotification(...)` bật popup thông báo của hệ điều hành kèm âm thanh/rung.
    * Người dùng nhấn vào thông báo $\rightarrow$ chuyển thẳng đến màn hình chi tiết thiết bị bị lỗi.

#### Phương Án 3B: Thông báo đẩy Firebase Cloud Messaging (FCM)
* **Trường hợp áp dụng**: Khi ứng dụng đã đóng hoàn toàn (killed background) trên điện thoại Android/iOS.
* **Các bước**:
  1. Cấu hình Firebase Project, tải `google-services.json` vào thư mục `android/app/`.
  2. Backend (.NET 9): Tích hợp SDK `FirebaseAdmin`, lưu FCM Device Token của người dùng.
  3. Khi có bản ghi `DeviceAlert` mới được thêm vào database: Backend gửi Push Message qua FCM HTTP v1 API.
  4. Frontend: Thay thế `FakeNotificationService` bằng `FcmNotificationService`.

---

### Giai Đoạn 4: Đồng Bộ Trạng Thái Thời Gian Thực (Realtime Sync)

* **Mục tiêu**: Loại bỏ độ trễ của cơ chế Polling (20 giây). Khi ấn nút bật bơm hoặc ESP32 phát hiện thay đổi, màn hình lập tức cập nhật.
* **Các bước thực hiện**:
  1. **Cấu hình Mosquitto WebSocket**:
     * Mở cổng `9001` (WebSocket) trong `mosquitto/config/mosquitto.conf` và `compose.yaml`:
       ```conf
       listener 1883
       allow_anonymous true

       listener 9001
       protocol websockets
       allow_anonymous true
       ```
  2. **Kích hoạt RealtimeClient trên Frontend**:
     * Hoàn thiện kết nối WebSocket thật trong `frontend/lib/services/realtime_client.dart` sử dụng package `mqtt_client`.
     * Đăng ký lắng nghe:
       * `devices/{deviceId}/readings`: Cập nhật thông số nhiệt độ/độ ẩm tức thì.
       * `devices/{deviceId}/pump-status`: Cập nhật nút bấm bơm (Xanh/Xám) ngay khi ESP32 đóng/ngắt relay.

---

## 3. Kế Hoạch Kiểm Thử & Tiêu Chí Nghiệm Thu (Acceptance Checklist)

| STT | Hạng mục kiểm thử | Kết quả mong đợi |
| :---: | :--- | :--- |
| 1 | **Clean Code** | Không còn `mock_admin_service.dart`; 119 tests Flutter pass 100%. |
| 2 | **ESP32 Boot** | ESP32 khởi động, Relay ở trạng thái TẮT an toàn, kết nối Wi-Fi & MQTT thành công. |
| 3 | **Gửi Telemetry** | ESP32 gửi dữ liệu cảm biến lên topic `readings`, Backend lưu vào PostgreSQL và hiển thị lên App. |
| 4 | **Điều khiển Bơm Thủ công** | Bấm "Bật bơm" trên App $\rightarrow$ Relay ESP32 kích hoạt ngay lập tức $\rightarrow$ ESP32 gửi ACK $\rightarrow$ App hiển thị "Bơm đang chạy". |
| 5 | **Hẹn giờ tưới an toàn** | Bật bơm với thời gian 30s $\rightarrow$ Đúng 30s sau Relay tự ngắt, ESP32 gửi ACK `isOn: false` về hệ thống. |
| 6 | **Thông báo khẩn cấp** | Khi cảm biến nước đo cạn (< ngưỡng) $\rightarrow$ Hệ điều hành phát âm thanh & hiển thị popup thông báo cảnh báo. |
