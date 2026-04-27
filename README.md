# HealthGuard — Hệ thống Giám sát Sức khỏe Thông minh

![Backend CI](https://github.com/Minh6625/health_system/workflows/Backend%20CI/badge.svg)

**HealthGuard** là hệ sinh thái giám sát sức khỏe toàn diện gồm **ứng dụng di động Flutter** + **Backend FastAPI** + **AI Risk Model API**, phục vụ bệnh nhân đeo smartwatch, người giám hộ (caregiver) và nhân viên y tế (clinician).

---

## 1. Tổng Quan Kiến Trúc

```mermaid
flowchart LR
    A["IoT Simulator\n(port 8090)"] -->|POST /telemetry/ingest| B["FastAPI Backend\n(port 8000)"]
    C["Flutter Mobile App"] <-->|REST + JWT| B
    B -->|HTTP POST| D["Model API\nhealthguard-model-api\n(port 8001)"]
    B <--> E["PostgreSQL + TimescaleDB"]
    B -->|Firebase FCM| F["Push Notifications"]
```

| Service | URL mặc định |
|---|---|
| FastAPI Backend | `http://localhost:8000` |
| AI Model API | `http://localhost:8001` |
| IoT Simulator | `http://localhost:8090` |

---

## 2. Tính Năng Chính

### Mobile App (Flutter)
- **Đánh giá rủi ro sức khỏe** — điểm risk 0–100, phân loại Low / Medium / Critical, SHAP breakdown giải thích yếu tố đóng góp
- **Nút Đánh giá lại** — buộc tính lại ngay từ chỉ số hiện tại, bỏ qua cache 6 tiếng
- **Lịch sử rủi ro** — biểu đồ trend 7 ngày, lọc theo loại (general / sleep / fall)
- **Giám sát té ngã** — nhận alert khi phát hiện ngã, xem lịch sử sự kiện, đếm ngược xác nhận SOS
- **Phân tích giấc ngủ** — điểm ngủ, hiệu suất, phân bố pha (NREM/REM)
- **Emergency SOS** — màn hình cấp cứu, bản đồ vị trí, timeline xử lý
- **Linked Profiles** — giám sát người thân, chuyển đổi hồ sơ không cần logout
- **Chế độ Clinician** — xem SHAP waterfall chi tiết + model request ID truy vết

### Backend (FastAPI)
- **Telemetry Ingest** — nhận batch vitals từ IoT Simulator, lưu TimescaleDB
- **Risk Calculation** — tự động tính risk sau mỗi lần ingest, circuit breaker khi model API lỗi, fallback rule-based
- **Vitals averaging** — lấy trung bình 5 mẫu gần nhất (~5s) để giảm nhiễu sensor
- **Audience gating** — response shape khác nhau cho patient / clinician
- **Firebase Push Notifications** — gửi alert khi risk tăng cao hoặc phát hiện té ngã

---

## 3. Cấu Trúc Project

```text
health_system/
├── backend/                    # FastAPI backend
│   ├── app/
│   │   ├── api/routes/         # REST endpoints
│   │   ├── services/           # Business logic (risk, alert, sleep, fall)
│   │   ├── adapters/           # Model API adapter, persistence adapters
│   │   ├── models/             # SQLAlchemy ORM models
│   │   ├── schemas/            # Pydantic request/response schemas
│   │   ├── core/               # Config, auth, dependencies
│   │   └── db/                 # Database connection
│   ├── migrations/             # SQL migration scripts
│   ├── tests/                  # Unit + contract + eval tests
│   └── requirements.txt
├── lib/                        # Flutter app (feature-first)
│   ├── core/                   # Network, routing, services
│   └── features/
│       ├── analysis/           # Risk report, history, SHAP
│       ├── auth/               # Login, register, session
│       ├── device/             # Device management
│       ├── emergency/          # SOS, emergency contacts
│       ├── fall/               # Fall detection, history
│       ├── health_monitoring/  # Vitals dashboard
│       ├── notifications/      # Push notification center
│       ├── profile/            # User profile, clinician toggle
│       └── sleep_analysis/     # Sleep score, phases
├── SQL SCRIPTS/                # PostgreSQL init scripts (01→09)
└── docs/                       # Architecture & contract docs
```

---

## 4. Hướng Dẫn Khởi Động

### Bước 0 — Cấu hình môi trường

Tạo file `backend/.env` (không commit):

```env
# --- Bắt buộc ---
DATABASE_URL=postgresql://postgres:password@localhost:5433/health_system
SECRET_KEY=<sinh bằng: openssl rand -hex 32>

# --- JWT ---
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_DAYS=30

# --- AI Model API ---
HEALTHGUARD_MODEL_API_URL=http://localhost:8001
# HEALTHGUARD_MODEL_API_DISABLED=1   # uncomment để tắt model, dùng rule-based fallback

# --- Email (tuỳ chọn — dùng cho verify email / reset password) ---
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SENDER_EMAIL=
SENDER_PASSWORD=

# --- Deep link ---
BACKEND_URL=http://localhost:8000
FRONTEND_URL=http://localhost:3000
MOBILE_DEEP_LINK_SCHEME=healthguard

# --- Tuning ---
RISK_COOLDOWN_SECONDS=60
FALL_CONFIDENCE_THRESHOLD=0.7
```

### Bước 1 — Khởi động Database

```powershell
# PostgreSQL 17+ phải đang chạy trên port 5433
# Chạy migration scripts theo thứ tự:
psql -h localhost -p 5433 -U postgres -d health_system -f "SQL SCRIPTS/01_init_timescaledb.sql"
psql -h localhost -p 5433 -U postgres -d health_system -f "SQL SCRIPTS/02_create_tables_user_management.sql"
# ... tiếp tục 03 → 09
```

### Bước 2 — Khởi động Backend

```powershell
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Bước 3 — Khởi động AI Model API

```powershell
# Repo riêng: healthguard-model-api
cd ..\healthguard-model-api
uvicorn app.main:app --port 8001
```

### Bước 4 — Chạy Flutter App

```powershell
flutter pub get
flutter run
# Backend URL được đọc từ .env hoặc mặc định http://10.0.2.2:8000/api/v1/mobile
```

---

## 5. API Highlights

Base URL: `http://localhost:8000/api/v1/mobile`

| Method | Endpoint | Mô tả |
|---|---|---|
| `POST` | `/auth/login` | Đăng nhập, nhận JWT |
| `POST` | `/auth/register` | Đăng ký tài khoản |
| `POST` | `/telemetry/ingest` | Nhận batch vitals từ IoT Simulator |
| `POST` | `/risk/calculate` | Tính risk (có cache 6h) |
| `POST` | `/risk/recalculate` | Tính risk ngay, bypass cache |
| `GET` | `/analysis/risk-reports` | Danh sách báo cáo risk |
| `GET` | `/analysis/risk-reports/{id}` | Chi tiết + SHAP (clinician: thêm waterfall) |
| `GET` | `/analysis/risk-history` | Lịch sử risk có filter theo type |
| `POST` | `/telemetry/imu-window` | Nhận IMU window từ thiết bị (fall detection) |
| `GET` | `/health` | Health check |

---

## 6. Changelog

### 2026-04-28 — Risk Recalculate + Noise Fix
- **`POST /risk/recalculate`** — endpoint mới cho phép mobile bypass cache 6h, tự tìm device theo user
- **Vitals averaging** — `_fetch_latest_vitals` lấy trung bình 5 mẫu (~5s) thay vì 1 mẫu đơn để giảm nhiễu sensor
- **Mobile** — nút "Đánh giá lại" (xanh lá) trong khối action button, spinner khi in-flight, SnackBar thành công màu xanh

### 2026-04-27 — Phase 8: SHAP Detail Screen + Clinician Toggle
- **SHAP Waterfall Screen** — màn hình chi tiết đóng góp từng feature (clinician mode)
- **Clinician Audience Toggle** — người dùng có role clinician có thể bật/tắt chế độ xem chi tiết kỹ thuật
- **Audience-aware cache** — DTO cache lazy write-through theo audience type (Phase 7)
- **Circuit Breaker** — tự ngắt khi model API lỗi liên tục, tự phục hồi sau cooldown (Phase 7)
- **Fall Feature Module** — màn hình lịch sử té ngã, push primitives, confusion-matrix eval harness (Phase 4B)
- **Sleep Risk Filter** — lọc lịch sử risk theo type: general / sleep / fall (Phase 4A)
- **model_request_id** — truy vết từng lần gọi model API (Phase 2)
