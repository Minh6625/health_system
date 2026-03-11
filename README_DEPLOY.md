# 🚀 Nhánh Deploy - Health System

## 📌 Giới thiệu

Đây là nhánh **deploy** chứa phiên bản ổn định của Health System để deploy lên Heroku.

## 🎯 Quy trình Deploy

### Backend (FastAPI)

Deploy lên **Heroku** - đơn giản, nhanh chóng, có free tier.

### Frontend (Flutter)

Build thành file **APK** (Android) hoặc **IPA** (iOS) để cài trên điện thoại.

---

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

---

## 📚 Tài liệu

- **DEPLOY_QUICK_START.md** - Hướng dẫn nhanh (5 phút)
- **DEPLOY_HEROKU.md** - Hướng dẫn chi tiết deploy lên Heroku

---

## 🛠️ Scripts tự động

- **scripts/deploy_heroku.bat** - Tự động deploy backend lên Heroku

---

## 🚀 Quick Start

### 1. Deploy Backend lên Heroku

```bash
cd scripts
deploy_heroku.bat
```

Hoặc manual:

```bash
cd backend
heroku login
heroku create your-app-name
heroku addons:create heroku-postgresql:mini
heroku config:set SECRET_KEY=your-secret-key
git push heroku main
```

### 2. Build Frontend App

```bash
# Đổi API endpoint trong lib/core/network/api_client.dart
# Sang: https://your-app-name.herokuapp.com/api/v1

flutter build apk --release
# File APK: build/app/outputs/flutter-apk/app-release.apk
```

---

## 📊 Kiến trúc

```
┌─────────────────┐
│  Flutter App    │  ← Build thành APK/IPA
│  (Mobile)       │
└────────┬────────┘
         │ HTTPS/REST
         │
┌────────▼────────┐
│  Heroku         │  ← Deploy Backend
│  (FastAPI)      │
└────────┬────────┘
         │
┌────────▼────────┐
│  PostgreSQL     │  ← Heroku Postgres Addon
│  (Database)     │
└─────────────────┘
```

---

## 🧪 Test

### Test Backend

```bash
curl https://your-app-name.herokuapp.com/api/v1/health
```

### Test Frontend

Cài APK lên điện thoại và test các tính năng.

---

## 💰 Chi phí Heroku

- **Eco Dynos**: $5/tháng (app sleep sau 30 phút không dùng)
- **Hobby**: $7/tháng (app không sleep)
- **PostgreSQL Mini**: Free (10,000 rows)

---

## 📞 Hỗ trợ

Nếu gặp vấn đề:

1. Xem logs: `heroku logs --tail`
2. Đọc file DEPLOY_HEROKU.md phần Troubleshooting
3. Test API bằng curl hoặc Postman

---

**Bắt đầu với DEPLOY_QUICK_START.md để deploy nhanh! 🚀**
