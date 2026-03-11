# ✅ Deploy Checklist - Health System

## 📋 Pre-deployment Checklist

### 🗄️ Database

- [ ] PostgreSQL 17+ đã cài đặt
- [ ] Database `hg_db` đã được tạo
- [ ] Script 01: TimescaleDB extension đã chạy
- [ ] Script 02: User management tables đã tạo
- [ ] Script 03: Device tables đã tạo
- [ ] Script 04: Timeseries tables đã tạo
- [ ] Script 05: Events & alerts tables đã tạo
- [ ] Script 06: AI analytics tables đã tạo
- [ ] Script 07: System tables đã tạo
- [ ] Script 08: Indexes đã tạo
- [ ] Script 09: Policies đã tạo
- [ ] Kiểm tra: `\dt` hiển thị tất cả tables

### 🔧 Backend

- [ ] Python 3.11+ đã cài đặt
- [ ] Virtual environment đã tạo
- [ ] Dependencies từ requirements.txt đã cài
- [ ] File `.env` đã tạo và cấu hình đúng
  - [ ] DATABASE_URL đúng
  - [ ] SECRET_KEY đã đổi (không dùng default)
  - [ ] ALGORITHM = HS256
  - [ ] ACCESS_TOKEN_EXPIRE_MINUTES đã set
- [ ] Backend chạy thành công tại port 8080
- [ ] Truy cập http://localhost:8080/docs thành công
- [ ] Health check endpoint trả về `{"status": "ok"}`

### 📱 Frontend

- [ ] Flutter SDK 3.11.0+ đã cài đặt
- [ ] Dependencies đã cài: `flutter pub get`
- [ ] API endpoint trong `api_client.dart` đã cấu hình đúng
  - [ ] Android Emulator: `http://10.0.2.2:8080/api/v1`
  - [ ] iOS Simulator: `http://localhost:8080/api/v1`
  - [ ] Thiết bị thật: `http://[YOUR_IP]:8080/api/v1`
- [ ] App build thành công: `flutter run`
- [ ] Không có lỗi compile

---

## 🧪 Functional Testing Checklist

### 1. Authentication Flow

#### Register

- [ ] Mở app, nhấn "Đăng ký"
- [ ] Nhập thông tin hợp lệ:
  - Email: test@example.com
  - Password: password123
  - Họ tên: Nguyễn Văn A
  - Ngày sinh: 01/01/1990
  - Giới tính: Nam
- [ ] Nhấn "Đăng ký"
- [ ] Hiển thị thông báo "Đăng ký thành công"
- [ ] Kiểm tra database:
  ```sql
  SELECT * FROM users WHERE email = 'test@example.com';
  ```
- [ ] User đã được tạo trong database
- [ ] Password đã được hash (không lưu plain text)

#### Login

- [ ] Nhập email và password vừa đăng ký
- [ ] Nhấn "Đăng nhập"
- [ ] Chuyển sang màn hình Home thành công
- [ ] Token được lưu trong secure storage
- [ ] User info hiển thị đúng

#### Validation

- [ ] Email không hợp lệ → Hiển thị lỗi
- [ ] Password quá ngắn → Hiển thị lỗi
- [ ] Email đã tồn tại → Hiển thị lỗi "Email đã được sử dụng"
- [ ] Sai password → Hiển thị lỗi "Sai email hoặc password"

### 2. Home Screen

- [ ] Màn hình Home hiển thị đúng
- [ ] Hiển thị tên user
- [ ] Hiển thị avatar/profile picture
- [ ] Navigation bar hoạt động
- [ ] Các card/widget hiển thị đúng:
  - [ ] Health monitoring card
  - [ ] Emergency card
  - [ ] Device status card
  - [ ] Quick actions

### 3. Emergency (SOS) Feature

- [ ] Nhấn vào Emergency từ Home
- [ ] SOS card hiển thị đúng
- [ ] Nút "Call Emergency" hoạt động
- [ ] Danh sách emergency contacts hiển thị
- [ ] Có thể thêm emergency contact mới
- [ ] Có thể xóa emergency contact
- [ ] Có thể gọi điện từ danh sách
- [ ] Có thể gửi SMS khẩn cấp

### 4. Profile Screen

- [ ] Nhấn vào Profile từ navigation
- [ ] Hiển thị thông tin user:
  - [ ] Họ tên
  - [ ] Email
  - [ ] Ngày sinh
  - [ ] Giới tính
- [ ] Có thể chỉnh sửa thông tin
- [ ] Nút "Đăng xuất" hoạt động
- [ ] Sau khi đăng xuất, quay về màn hình Login

### 5. Health Monitoring

- [ ] Màn hình Health Monitoring hiển thị
- [ ] Các metrics hiển thị (nếu có data):
  - [ ] Heart rate
  - [ ] Blood pressure
  - [ ] Sleep data
  - [ ] Activity data
- [ ] Charts/graphs render đúng
- [ ] Có thể xem lịch sử dữ liệu

---

## 🔐 Security Checklist

- [ ] Passwords được hash với bcrypt
- [ ] JWT tokens được sử dụng cho authentication
- [ ] Tokens được lưu trong secure storage (không lưu plain text)
- [ ] API endpoints yêu cầu authentication (trừ login/register)
- [ ] SECRET_KEY đã được thay đổi (không dùng default)
- [ ] File `.env` không được commit lên Git
- [ ] CORS được cấu hình đúng
- [ ] SQL injection được prevent (dùng ORM)
- [ ] Input validation được thực hiện ở cả frontend và backend

---

## 🚀 Performance Checklist

- [ ] App khởi động trong < 3 giây
- [ ] Login response time < 1 giây
- [ ] API calls có timeout (5 giây)
- [ ] Loading indicators hiển thị khi đang fetch data
- [ ] Error handling đúng cách (không crash app)
- [ ] Database queries có indexes
- [ ] Images được cache (nếu có)

---

## 📱 Device Testing Checklist

### Android

- [ ] Test trên Android Emulator
- [ ] Test trên thiết bị Android thật
- [ ] API endpoint dùng đúng IP (10.0.2.2 cho emulator)
- [ ] Permissions được request đúng cách
- [ ] App không crash khi rotate màn hình

### iOS (nếu có)

- [ ] Test trên iOS Simulator
- [ ] Test trên thiết bị iOS thật
- [ ] API endpoint dùng localhost cho simulator
- [ ] Permissions được request đúng cách

---

## 🐛 Error Handling Checklist

### Backend Errors

- [ ] 400 Bad Request → Hiển thị lỗi validation
- [ ] 401 Unauthorized → Redirect về Login
- [ ] 404 Not Found → Hiển thị "Không tìm thấy"
- [ ] 500 Server Error → Hiển thị "Lỗi server"
- [ ] Network timeout → Hiển thị "Không thể kết nối"

### Frontend Errors

- [ ] No internet → Hiển thị thông báo
- [ ] Backend offline → Hiển thị thông báo
- [ ] Invalid input → Hiển thị validation errors
- [ ] Crash recovery → App không bị crash hoàn toàn

---

## 📊 Database Integrity Checklist

- [ ] Foreign keys hoạt động đúng
- [ ] Cascade delete được cấu hình đúng
- [ ] Timestamps (created_at, updated_at) tự động update
- [ ] Unique constraints hoạt động (email unique)
- [ ] Check constraints hoạt động (age > 0)
- [ ] Indexes được tạo cho các columns thường query

---

## 📝 Documentation Checklist

- [ ] README.md có hướng dẫn cơ bản
- [ ] DEPLOY.md có hướng dẫn chi tiết
- [ ] DEPLOY_QUICK_START.md có hướng dẫn nhanh
- [ ] API endpoints được document trong /docs
- [ ] Code có comments đầy đủ
- [ ] Database schema được document

---

## 🎯 Final Deployment Checklist

### Pre-Production

- [ ] Tất cả tests đã pass
- [ ] Code đã được review
- [ ] Security vulnerabilities đã được fix
- [ ] Performance đã được optimize
- [ ] Documentation đã hoàn thiện

### Production

- [ ] Environment variables đã được set đúng
- [ ] Database backup đã được setup
- [ ] Monitoring/logging đã được setup
- [ ] SSL/HTTPS đã được cấu hình
- [ ] Domain name đã được cấu hình
- [ ] Firewall rules đã được set
- [ ] Rate limiting đã được enable

### Post-Deployment

- [ ] Smoke tests đã pass
- [ ] Monitoring dashboard hoạt động
- [ ] Logs được ghi đúng
- [ ] Backup tự động hoạt động
- [ ] Rollback plan đã sẵn sàng

---

## ✅ Sign-off

**Tested by:** ********\_\_\_********  
**Date:** ********\_\_\_********  
**Environment:** [ ] Development [ ] Staging [ ] Production  
**Status:** [ ] Pass [ ] Fail

**Notes:**

---

---

---

---

**Khi tất cả checklist đã hoàn thành, bạn có thể tự tin deploy! 🚀**
