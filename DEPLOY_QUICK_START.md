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

### Backend → Deploy lên Heroku

**Cách 1: Tự động (khuyến nghị)**

```bash
cd scripts
deploy_heroku.bat
# Script sẽ tự động setup và deploy
```

**Cách 2: Manual**

```bash
cd backend

# 1. Login Heroku
heroku login

# 2. Tạo app
heroku create your-app-name

# 3. Add PostgreSQL
heroku addons:create heroku-postgresql:mini

# 4. Set environment variables
heroku config:set SECRET_KEY=your-secret-key
heroku config:set ALGORITHM=HS256

# 5. Deploy
git init
git add .
git commit -m "Deploy to Heroku"
git push heroku main

# 6. Chạy SQL scripts
heroku pg:psql < "../SQL SCRIPTS/02_create_tables_user_management.sql"
# ... chạy các file SQL khác
```

**Xem hướng dẫn chi tiết:** `DEPLOY_HEROKU.md`

### Frontend → Build App

```bash
# 1. Đổi API endpoint trong api_client.dart
# Từ: http://10.0.2.2:8080/api/v1
# Sang: https://your-app-name.herokuapp.com/api/v1

# 2. Build APK
flutter build apk --release

# 3. File APK ở: build/app/outputs/flutter-apk/app-release.apk

# 4. Copy APK vào điện thoại và cài đặt
```

---

## 📚 Tài liệu chi tiết

- **DEPLOY_HEROKU.md** - Hướng dẫn deploy backend lên Heroku (khuyến nghị)
- **DEPLOY.md** - Hướng dẫn deploy lên VPS/Server khác

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
