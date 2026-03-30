# ⚡ Quick Start - Deploy với Heroku

## 🎯 Mục đích

Nhánh `deploy` chứa phiên bản ổn định để deploy backend lên Heroku và build app Flutter.

## 📌 Quy trình

**Backend** → Deploy lên Heroku (miễn phí hoặc $5/tháng)  
**Frontend** → Build thành APK để cài trên điện thoại

---

## 🚀 Deploy Backend lên Heroku

### Cách 1: Tự động (Khuyến nghị)

```bash
cd scripts
deploy_heroku.bat
```

Script sẽ tự động:

- ✅ Tạo Heroku app
- ✅ Add PostgreSQL database
- ✅ Set environment variables
- ✅ Deploy code

### Cách 2: Manual

```bash
cd backend

# 1. Login Heroku
heroku login

# 2. Tạo app
heroku create your-app-name

# 3. Add PostgreSQL
heroku addons:create heroku-postgresql:mini

# 4. Set environment variables
python -c "import secrets; print(secrets.token_hex(32))"
heroku config:set SECRET_KEY=your-generated-key
heroku config:set ALGORITHM=HS256

# 5. Deploy
git init
git add .
git commit -m "Deploy to Heroku"
git push heroku main

# 6. Chạy SQL scripts
heroku pg:psql < "../SQL SCRIPTS/02_create_tables_user_management.sql"
heroku pg:psql < "../SQL SCRIPTS/03_create_tables_devices.sql"
# ... chạy các file SQL khác (02-09)
```

### Kiểm tra

```bash
# Xem logs
heroku logs --tail

# Test API
curl https://your-app-name.herokuapp.com/api/v1/health

# Mở API docs
heroku open /docs
```

---

## 📱 Build Frontend App

### 1. Cập nhật API endpoint

Mở file `lib/core/network/api_client.dart`:

```dart
class ApiClient {
  // Đổi từ localhost sang Heroku URL
  static const String baseUrl = 'https://your-app-name.herokuapp.com/api/v1';

  // ... rest of code
}
```

### 2. Build APK

```bash
flutter clean
flutter pub get
flutter build apk --release
```

### 3. Cài đặt

File APK ở: `build/app/outputs/flutter-apk/app-release.apk`

Copy vào điện thoại và cài đặt.

---

## ✅ Tính năng đã hoạt động

### Backend API

- ✅ POST `/api/v1/auth/register` - Đăng ký
- ✅ POST `/api/v1/auth/login` - Đăng nhập
- ✅ GET `/api/v1/health` - Health check

### Frontend App

- ✅ Login Screen
- ✅ Register Screen
- ✅ Home Screen
- ✅ Emergency (SOS) Screen
- ✅ Profile Screen
- ✅ Health Monitoring

---

## 🐛 Troubleshooting

### Backend không start

```bash
heroku logs --tail
heroku restart
```

### App không kết nối backend

- Kiểm tra API endpoint trong `api_client.dart` đúng chưa
- Test API: `curl https://your-app-name.herokuapp.com/api/v1/health`

---

## 📖 Hướng dẫn chi tiết

Xem file **DEPLOY_HEROKU.md** để biết hướng dẫn đầy đủ về:

- Setup Heroku CLI
- Cấu hình environment variables
- Chạy SQL scripts
- Monitoring và troubleshooting
- Chi phí và scaling

---

**Deploy xong thì test ngay bằng app Flutter nhé! 🎉**
