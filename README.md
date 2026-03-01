# health_system

Ứng dụng Flutter hỗ trợ theo dõi và giám sát sức khỏe cá nhân (Personal Health Monitoring System).

Hiện tại dự án đang ở giai đoạn xây dựng giao diện và cấu trúc nền tảng (UI + Architecture). Chức năng Login đang sử dụng dữ liệu giả lập (mock data), chưa kết nối database hoặc backend.

---

## 📌 Mục tiêu dự án

- Xây dựng hệ thống theo dõi sức khỏe từ thiết bị đeo (wearable/smartwatch)
- Cảnh báo nguy cơ tim mạch, đột quỵ
- Hỗ trợ người thân theo dõi từ xa
- Hướng tới tích hợp AI trong các giai đoạn sau

---

## 🏗 Cấu trúc thư mục hiện tại

lib/
│
├── main.dart
│
├── screens/ # Các màn hình giao diện (UI)
│ └── login_screen.dart
│
├── models/ # Chứa các model dữ liệu
│ └── user_model.dart
│
├── services/ # Xử lý logic nghiệp vụ (business logic)
│ └── auth_service.dart
│
├── widgets/ # Các widget tái sử dụng
│ └── custom_textfield.dart

---

## 🧩 Mô tả từng thành phần

### 1️⃣ screens/

Chứa các màn hình giao diện của ứng dụng.

Hiện có:

- `login_screen.dart`: Màn hình đăng nhập đã nâng cấp giao diện.

---

### 2️⃣ models/

Chứa các lớp dữ liệu (Data Model).

Hiện tại:

- `user_model.dart`: Model mô phỏng người dùng gồm:
  - email
  - password

⚠️ Lưu ý: Dữ liệu đang là giả lập (chưa có database).

---

### 3️⃣ services/

Chứa logic xử lý chính của ứng dụng.

Hiện tại:

- `auth_service.dart`:
  - Kiểm tra email và password
  - So sánh với dữ liệu mock
  - Trả về kết quả đăng nhập thành công hoặc thất bại

Hiện chưa:

- Kết nối Firebase
- Kết nối API
- Kết nối backend

---

### 4️⃣ widgets/

Chứa các widget dùng lại nhiều lần.

Hiện có:

- `custom_textfield.dart`: TextField tái sử dụng cho form login.

Mục tiêu:

- Tách UI ra khỏi màn hình chính
- Code sạch hơn
- Dễ mở rộng sau này

---

## 🚀 Trạng thái hiện tại

✔️ Hoàn thành:

- Cấu trúc project chuẩn
- Login UI đẹp hơn
- Mock login hoạt động

⏳ Chưa hoàn thành:

- Database
- Backend API
- Firebase Authentication
- Dashboard sau login
- Kết nối thiết bị IoT

---

## 🔮 Hướng phát triển tiếp theo

1. Kết nối Firebase Authentication
2. Xây dựng Dashboard sau login
3. Thiết kế hệ thống nhận dữ liệu từ smartwatch
4. Tích hợp AI dự đoán nguy cơ sức khỏe
5. Xây dựng hệ thống cảnh báo khẩn cấp

---

## 🛠 Cách chạy project

```bash
flutter pub get
flutter run

📚 Tài nguyên tham khảo

Flutter Documentation

Firebase for Flutter

Dart Language

👨‍💻 Nhóm phát triển

Thành viên nhóm sẽ cập nhật tại đây

📌 Lưu ý quan trọng

Hiện tại chức năng login chỉ dùng mock data để test giao diện và luồng xử lý.

Không sử dụng cho production.
```
