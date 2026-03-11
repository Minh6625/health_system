# ⚡ Quick Start - Deploy Branch

## 🎯 Mục đích

Nhánh `deploy` chứa phiên bản ổn định với các tính năng cơ bản đã hoạt động.

## 📌 Lưu ý quan trọng

**Backend** → Deploy lên server (VPS, Cloud)  
**Frontend** → Build thành APK/IPA để cài trên điện thoại

---

## 🖥️ DEVELOPMENT (Test local)

### 1️⃣ Setup Database (1 lần duy nhất)

```bash
psql -U postgres -c "CREATE DATABASE hg_db;"
cd "SQL SCRIPTS"
# Chạy các file SQL từ 01 đến 09
```

### 2️⃣ Chạy Backend

```bash
cd backend
venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8080
```

### 3️⃣ Test Frontend

```bash
flutter pub get
flutter run
```

---

## 🚀 PRODUCTION (Deploy thật)

### Backend → Deploy lên Server

```bash
# 1. SSH vào server
ssh user@your-server-ip

# 2. Clone code
git clone https://github.com/your-repo/health_system.git
cd health_system/backend

# 3. Setup
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt gunicorn

# 4. Tạo .env với DATABASE_URL và SECRET_KEY

# 5. Chạy với systemd (xem DEPLOY.md)
```

### Frontend → Build App

```bash
# 1. Đổi API endpoint trong api_client.dart
# Từ: http://10.0.2.2:8080/api/v1
# Sang: https://your-domain.com/api/v1

# 2. Build APK
flutter build apk --release

# 3. File APK ở: build/app/outputs/flutter-apk/app-release.apk

# 4. Copy APK vào điện thoại và cài đặt
```

---

## ✅ Tính năng đã hoạt động

### Backend API

- ✅ POST `/api/v1/auth/register` - Đăng ký
- ✅ POST `/api/v1/auth/login` - Đăng nhập
- ✅ GET `/api/v1/health` - Health check

### Frontend Screens

- ✅ Login Screen
- ✅ Register Screen
- ✅ Home Screen
- ✅ Emergency (SOS) Screen
- ✅ Profile Screen

---

## 📖 Hướng dẫn chi tiết

Xem file `DEPLOY.md` để biết hướng dẫn đầy đủ về deploy backend lên server.
