# health_system

Health System gồm Frontend (Flutter) + Backend (FastAPI) kết nối PostgreSQL.

## Cấu trúc chính

```text
lib/                  # Flutter app (feature-first architecture)
backend/              # FastAPI backend (API + Database)
  app/
    main.py           # Entry point
    api/              # REST API routes
    models/           # SQLAlchemy ORM models
    repositories/     # Database layer
    services/         # Business logic
    schemas/          # Request/response schemas
    db/               # Database config & connection
SQL SCRIPTS/          # PostgreSQL initialization scripts
```

## Chạy Frontend (Flutter)

```bash
flutter pub get
flutter run
```

Backend sẽ chạy ở `http://localhost:8000` (configure ở `lib/core/network/api_client.dart`).

## Chạy Backend (FastAPI)

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

Create `.env` file:

```env
DATABASE_URL=postgresql://postgres:123456@localhost:5433/health_system
SECRET_KEY=your-secret-key-change-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
```

Run:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Database Setup

1. **PostgreSQL 17+** running on `localhost:5433`
   - User: `postgres`
   - Password: `123456`

2. Create database: `health_system`

3. Run SQL scripts in order:

   ```bash
   psql -h localhost -p 5433 -U postgres -d health_system -f "SQL SCRIPTS/01_init_timescaledb.sql"
   psql -h localhost -p 5433 -U postgres -d health_system -f "SQL SCRIPTS/02_create_tables_user_management.sql"
   # ... continue 03-09
   ```

4. Tables created:
   - `users` - Người dùng (patient, caregiver, admin)
   - `user_relationships` - Quan hệ bệnh nhân ↔ người giám sát
   - `emergency_contacts` - Danh bạ khẩn cấp
   - Các bảng khác cho thiết bị, time-series, alerts, v.v.

## API Endpoints

Base URL: `http://localhost:8000/api/v1`

### Health Check

```
GET /health
```

Response:

```json
{ "status": "ok" }
```

### Auth - Register

```
POST /auth/register
```

Request:

```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

Response:

```json
{
  "success": true,
  "message": "Đăng ký thành công"
}
```

### Auth - Login

```
POST /auth/login
```

Same format as register.

## Architecture Notes

- **Frontend**: Feature-first architecture with Provider state management
- **Backend**: FastAPI + SQLAlchemy ORM
- **Database**: PostgreSQL 17+ with TimescaleDB for time-series data
- **Auth**: Bcrypt password hashing (no JWT yet - add in next phase)
- **Status**: ✅ Register/Login fully integrated | ⏳ JWT tokens, refresh tokens (next)

## Development Flow

1. Start backend: `cd backend && uvicorn app.main:app --reload`
2. Start frontend: `flutter run` (automatically connects to `http://localhost:8000`)
3. Test login/register with PostgreSQL backend
