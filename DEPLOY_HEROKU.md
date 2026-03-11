# 🚀 Deploy Backend lên Heroku

## 📌 Tổng quan

Hướng dẫn deploy backend FastAPI lên Heroku - đơn giản, nhanh chóng, miễn phí (hoặc giá rẻ).

## ✅ Ưu điểm Heroku

- ✅ Setup nhanh (< 10 phút)
- ✅ Tự động deploy khi push code
- ✅ PostgreSQL database miễn phí
- ✅ HTTPS tự động
- ✅ Không cần quản lý server

---

## 🛠️ Bước 1: Chuẩn bị

### 1.1. Tạo tài khoản Heroku

Truy cập: https://signup.heroku.com/

### 1.2. Cài đặt Heroku CLI

**Windows:**

```bash
# Download từ: https://devcenter.heroku.com/articles/heroku-cli
# Hoặc dùng chocolatey:
choco install heroku-cli
```

**Mac:**

```bash
brew tap heroku/brew && brew install heroku
```

**Linux:**

```bash
curl https://cli-assets.heroku.com/install.sh | sh
```

### 1.3. Login Heroku

```bash
heroku login
```

---

## 📦 Bước 2: Chuẩn bị Backend cho Heroku

### 2.1. Tạo file Procfile

Tạo file `backend/Procfile` (không có extension):

```
web: gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:$PORT
```

### 2.2. Tạo file runtime.txt

Tạo file `backend/runtime.txt`:

```
python-3.11.9
```

### 2.3. Cập nhật requirements.txt

Đảm bảo file `backend/requirements.txt` có gunicorn:

```
fastapi==0.116.1
uvicorn[standard]==0.35.0
pydantic==2.11.7
sqlalchemy==2.0.26
psycopg2-binary==2.9.9
python-dotenv==1.0.0
bcrypt==4.1.2
python-jose[cryptography]==3.3.0
gunicorn==21.2.0

# Testing
pytest==8.0.0
pytest-asyncio==0.23.5
httpx==0.27.0
```

### 2.4. Tạo file .gitignore (nếu chưa có)

Tạo file `backend/.gitignore`:

```
venv/
__pycache__/
*.pyc
.env
*.db
.pytest_cache/
```

---

## 🚀 Bước 3: Deploy lên Heroku

### 3.1. Di chuyển vào thư mục backend

```bash
cd backend
```

### 3.2. Khởi tạo Git (nếu chưa có)

```bash
git init
git add .
git commit -m "Initial commit for Heroku"
```

### 3.3. Tạo Heroku app

```bash
heroku create your-app-name
# Ví dụ: heroku create healthguard-api
```

Heroku sẽ tạo URL: `https://your-app-name.herokuapp.com`

### 3.4. Thêm PostgreSQL database

```bash
# Free tier (10,000 rows)
heroku addons:create heroku-postgresql:mini

# Hoặc Essential tier ($5/tháng, 10M rows)
# heroku addons:create heroku-postgresql:essential-0
```

### 3.5. Set environment variables

```bash
# Generate SECRET_KEY
python -c "import secrets; print(secrets.token_hex(32))"

# Set variables
heroku config:set SECRET_KEY=your-generated-secret-key
heroku config:set ALGORITHM=HS256
heroku config:set ACCESS_TOKEN_EXPIRE_MINUTES=30

# Xem tất cả config
heroku config
```

**Lưu ý:** DATABASE_URL được Heroku tự động set khi add PostgreSQL addon.

### 3.6. Deploy code

```bash
git push heroku main
# Hoặc nếu branch khác:
# git push heroku your-branch:main
```

### 3.7. Chạy SQL scripts để khởi tạo database

```bash
# Lấy DATABASE_URL
heroku config:get DATABASE_URL

# Connect vào database
heroku pg:psql

# Trong psql, copy-paste nội dung từng file SQL:
# 01_init_timescaledb.sql
# 02_create_tables_user_management.sql
# ... đến 09_create_policies.sql

# Hoặc chạy từ local:
heroku pg:psql < "../SQL SCRIPTS/01_init_timescaledb.sql"
heroku pg:psql < "../SQL SCRIPTS/02_create_tables_user_management.sql"
# ... tiếp tục với các file khác
```

### 3.8. Kiểm tra logs

```bash
heroku logs --tail
```

---

## 🧪 Bước 4: Test Backend trên Heroku

### 4.1. Mở app

```bash
heroku open
```

### 4.2. Test API endpoints

```bash
# Health check
curl https://your-app-name.herokuapp.com/api/v1/health

# API Docs
# Mở browser: https://your-app-name.herokuapp.com/docs

# Test register
curl -X POST https://your-app-name.herokuapp.com/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "full_name": "Test User",
    "date_of_birth": "1990-01-01",
    "gender": "male"
  }'

# Test login
curl -X POST https://your-app-name.herokuapp.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

---

## 📱 Bước 5: Cập nhật Frontend

### 5.1. Đổi API endpoint

Mở file `lib/core/network/api_client.dart`:

```dart
class ApiClient {
  // Đổi từ localhost sang Heroku URL
  static const String baseUrl = 'https://your-app-name.herokuapp.com/api/v1';

  // ... rest of code
}
```

### 5.2. Build APK

```bash
cd ..  # Quay về thư mục gốc
flutter clean
flutter pub get
flutter build apk --release
```

File APK: `build/app/outputs/flutter-apk/app-release.apk`

---

## 🔄 Bước 6: Update Code (sau này)

Khi có code mới:

```bash
cd backend
git add .
git commit -m "Update: your changes"
git push heroku main
```

Heroku sẽ tự động deploy lại!

---

## 🛠️ Các lệnh Heroku hữu ích

### Xem logs

```bash
heroku logs --tail
heroku logs --tail --source app
```

### Restart app

```bash
heroku restart
```

### Chạy commands

```bash
heroku run python
heroku run bash
```

### Database

```bash
# Connect database
heroku pg:psql

# Backup database
heroku pg:backups:capture
heroku pg:backups:download

# Xem database info
heroku pg:info
```

### Environment variables

```bash
# Xem tất cả
heroku config

# Set variable
heroku config:set KEY=VALUE

# Unset variable
heroku config:unset KEY
```

### Scaling

```bash
# Xem dynos
heroku ps

# Scale up
heroku ps:scale web=2

# Scale down
heroku ps:scale web=1
```

---

## 💰 Chi phí Heroku

### Free Tier (Eco Dynos - $5/tháng)

- 1000 dyno hours/tháng
- App sleep sau 30 phút không hoạt động
- PostgreSQL: 10,000 rows

### Hobby ($7/tháng)

- App không sleep
- PostgreSQL: 10M rows
- SSL certificate

### Professional ($25+/tháng)

- Horizontal scaling
- Metrics & monitoring
- Preboot (zero-downtime deploys)

**Khuyến nghị:** Bắt đầu với Eco ($5/tháng) cho testing, sau đó nâng cấp lên Hobby khi production.

---

## 🐛 Troubleshooting

### App không start

**Lỗi:** Application error

**Giải pháp:**

```bash
# Xem logs
heroku logs --tail

# Kiểm tra Procfile đúng chưa
cat Procfile

# Kiểm tra requirements.txt có gunicorn chưa
cat requirements.txt | grep gunicorn
```

### Database connection error

**Lỗi:** Could not connect to database

**Giải pháp:**

```bash
# Kiểm tra DATABASE_URL
heroku config:get DATABASE_URL

# Kiểm tra PostgreSQL addon
heroku addons

# Restart app
heroku restart
```

### SQL scripts không chạy được

**Lỗi:** Permission denied hoặc syntax error

**Giải pháp:**

```bash
# Chạy từng script một và kiểm tra lỗi
heroku pg:psql < "../SQL SCRIPTS/01_init_timescaledb.sql"

# Nếu lỗi TimescaleDB, có thể bỏ qua (Heroku PostgreSQL không support TimescaleDB)
# Chỉ cần chạy các script tạo tables
```

### App chạy chậm

**Nguyên nhân:** Free/Eco dyno sleep sau 30 phút

**Giải pháp:**

1. Nâng cấp lên Hobby ($7/tháng)
2. Hoặc dùng service ping app mỗi 25 phút (ví dụ: UptimeRobot)

---

## 🔐 Security Best Practices

### 1. Không commit .env file

```bash
# Đảm bảo .env trong .gitignore
echo ".env" >> .gitignore
```

### 2. Dùng strong SECRET_KEY

```bash
# Generate mới mỗi lần deploy
python -c "import secrets; print(secrets.token_hex(32))"
heroku config:set SECRET_KEY=new-generated-key
```

### 3. Enable HTTPS only

Heroku tự động redirect HTTP → HTTPS, nhưng nên check trong code:

```python
# app/main.py
from fastapi.middleware.httpsredirect import HTTPSRedirectMiddleware

if os.getenv("ENVIRONMENT") == "production":
    app.add_middleware(HTTPSRedirectMiddleware)
```

### 4. Rate limiting

Cài đặt slowapi để prevent abuse:

```bash
pip install slowapi
```

---

## 📊 Monitoring

### Heroku Dashboard

https://dashboard.heroku.com/apps/your-app-name

Xem:

- Dyno metrics
- Response time
- Throughput
- Memory usage

### Logs

```bash
# Real-time logs
heroku logs --tail

# Logs với filter
heroku logs --tail --source app
heroku logs --tail --ps web
```

---

## 🎯 Checklist Deploy Heroku

- [ ] Tạo tài khoản Heroku
- [ ] Cài đặt Heroku CLI
- [ ] Tạo file Procfile
- [ ] Tạo file runtime.txt
- [ ] Cập nhật requirements.txt (có gunicorn)
- [ ] Tạo Heroku app
- [ ] Add PostgreSQL addon
- [ ] Set environment variables (SECRET_KEY, etc.)
- [ ] Deploy code: `git push heroku main`
- [ ] Chạy SQL scripts
- [ ] Test API endpoints
- [ ] Cập nhật API endpoint trong Flutter app
- [ ] Build APK mới
- [ ] Test app với backend Heroku

---

## 🚀 Alternative: Deploy từ GitHub

### Setup GitHub Integration

1. Vào Heroku Dashboard: https://dashboard.heroku.com/apps/your-app-name
2. Tab "Deploy" → "Deployment method" → Chọn "GitHub"
3. Connect GitHub repository
4. Enable "Automatic deploys" từ branch `deploy`

Bây giờ mỗi khi push code lên GitHub branch `deploy`, Heroku sẽ tự động deploy!

---

**Deploy xong rồi thì test ngay bằng app Flutter nhé! 🎉**
