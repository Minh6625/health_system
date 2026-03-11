# 🚀 Nhánh Deploy - Health System

## 📌 Giới thiệu

Đây là nhánh **deploy** chứa phiên bản ổn định của Health System với các tính năng cơ bản đã hoạt động.

## 🎯 Cách deploy

### Backend (FastAPI)

Deploy lên server (VPS, AWS, Heroku, etc.) để chạy API 24/7.

### Frontend (Flutter)

Build thành file APK (Android) hoặc IPA (iOS) để cài trên điện thoại.

## ✅ Tính năng đã hoạt động

### Backend API

- ✅ Authentication (Login/Register)
- ✅ User management
- ✅ JWT token authentication
- ✅ PostgreSQL database
- ✅ Password hashing với bcrypt

### Frontend App

- ✅ Login/Register screens
- ✅ Home dashboard
- ✅ Emergency (SOS) feature
- ✅ Profile management
- ✅ Health monitoring

## 📚 Tài liệu

- **DEPLOY_QUICK_START.md** - Hướng dẫn nhanh (5 phút)
- **DEPLOY_HEROKU.md** - Deploy backend lên Heroku (khuyến nghị)
- **DEPLOY.md** - Deploy backend lên VPS/Server
- **DEPLOY_CHECKLIST.md** - Checklist kiểm tra trước khi deploy

## 🛠️ Scripts tự động

- `scripts/setup_database.bat` - Tự động setup database
- `scripts/start_backend.bat` - Tự động chạy backend
- `scripts/start_frontend.bat` - Tự động chạy frontend

## 🚀 Quick Start

### Development (Test local)

```bash
# 1. Setup database
cd scripts
setup_database.bat

# 2. Start backend
start_backend.bat

# 3. Start frontend (terminal khác)
start_frontend.bat
```

### Production (Deploy thật)

```bash
# Backend: Deploy lên server
# Xem DEPLOY.md phần "PHẦN 1: DEPLOY BACKEND LÊN SERVER"

# Frontend: Build APK
flutter build apk --release
# File APK: build/app/outputs/flutter-apk/app-release.apk
```

## 🔧 Cấu hình quan trọng

### Backend (.env)

```env
DATABASE_URL=postgresql://postgres:password@localhost:5432/hg_db
SECRET_KEY=your-secret-key
```

### Frontend (api_client.dart)

```dart
// Development
static const String baseUrl = 'http://10.0.2.2:8080/api/v1';

// Production
static const String baseUrl = 'https://your-domain.com/api/v1';
```

## 📊 Kiến trúc

```
┌─────────────────┐
│  Flutter App    │  ← Build thành APK/IPA
│  (Mobile)       │
└────────┬────────┘
         │ HTTPS/REST
         │
┌────────▼────────┐
│  FastAPI        │  ← Deploy lên Server
│  (Backend)      │
└────────┬────────┘
         │
┌────────▼────────┐
│  PostgreSQL     │  ← Trên Server
│  (Database)     │
└─────────────────┘
```

## 🧪 Test

### Test Backend

```bash
curl http://localhost:8080/api/v1/health
```

### Test Frontend

```bash
flutter run
# Hoặc cài APK lên điện thoại
```

## 📞 Hỗ trợ

Nếu gặp vấn đề:

1. Đọc file DEPLOY.md phần Troubleshooting
2. Kiểm tra logs backend: `sudo journalctl -u healthguard -f`
3. Kiểm tra logs frontend: `flutter run --verbose`

---

**Bắt đầu với DEPLOY_QUICK_START.md để deploy nhanh! 🚀**
