# 🔄 CI Setup - GitHub Actions

## 📌 Tổng quan

CI pipeline tự động chạy tests khi push code. Deploy lên Heroku thực hiện manual.

---

## 🛠️ Workflow đã tạo

### Backend CI (`backend-ci.yml`)

**Trigger:** Push/PR vào bất kỳ nhánh nào có thay đổi trong `backend/`

**Jobs:**

- **Test:** Chạy pytest với PostgreSQL
- **Code Style:** Kiểm tra với flake8 (non-blocking)

---

## 🚀 Cách sử dụng

### CI tự động chạy khi push

```bash
git add .
git commit -m "feat: add new feature"
git push origin your-branch
```

GitHub Actions sẽ tự động chạy tests.

### Deploy manual lên Heroku

```bash
# Cách 1: Dùng script
cd scripts
deploy_heroku.bat

# Cách 2: Manual
cd backend
git push heroku deploy:main
```

---

## 📊 Workflow Flow

```
┌─────────────────┐
│  Push code      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Run Tests      │
│  - pytest       │
│  - PostgreSQL   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Code Style     │
│  - flake8       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  ✅ Done        │
└─────────────────┘
```

---

## 🧪 Test CI locally

### Chạy tests như CI

```bash
cd backend

# Setup test database
docker run -d \
  --name test-postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=test_db \
  -p 5432:5432 \
  postgres:17

# Run tests
export DATABASE_URL=postgresql://postgres:postgres@localhost:5432/test_db
export SECRET_KEY=test-secret-key
pytest tests/ -v

# Cleanup
docker stop test-postgres
docker rm test-postgres
```

### Chạy code style check

```bash
cd backend
pip install flake8
flake8 app/ --max-line-length=100 --ignore=E203,W503
```

---

## 🔧 Cấu hình Files

### `.github/workflows/backend-ci.yml`

CI workflow - chạy tests và code style checks

### `backend/pyproject.toml`

Cấu hình cho pytest

### `backend/.flake8`

Cấu hình cho flake8 linter

---

## 📝 Best Practices

### 1. Branch Strategy

```
main (production)
  ↑
deploy (staging)
  ↑
feat/* (features)
fix/* (bugfixes)
```

**Workflow:**

1. Tạo feature branch: `git checkout -b feat/new-feature`
2. Commit và push: `git push origin feat/new-feature`
3. Tạo PR vào `deploy` → CI chạy tests
4. Merge vào `deploy` sau khi tests pass
5. Deploy manual lên Heroku: `cd scripts && deploy_heroku.bat`
6. Test trên Heroku staging
7. Merge `deploy` vào `main` khi stable

### 2. Commit Messages

Dùng conventional commits:

```
feat: add new feature
fix: fix bug
docs: update documentation
test: add tests
refactor: refactor code
chore: update dependencies
```

### 3. Pull Requests

- Luôn tạo PR thay vì push trực tiếp
- Đợi CI pass trước khi merge
- Review code trước khi merge

---

## 🐛 Troubleshooting

### CI fails với "Database connection error"

**Nguyên nhân:** PostgreSQL service chưa ready

**Giải pháp:** Workflow đã có health check, nếu vẫn lỗi tăng retries trong workflow

### Tests fail locally nhưng pass trên CI

**Nguyên nhân:** Environment khác nhau

**Giải pháp:**

- Kiểm tra DATABASE_URL
- Kiểm tra Python version (phải 3.11)
- Chạy trong virtual environment

### Code style checks fail

**Giải pháp:**

```bash
# Check issues
flake8 app/ --show-source

# Fix automatically (nếu có)
autopep8 --in-place --aggressive app/**/*.py
```

---

## 📊 Monitoring

### GitHub Actions Dashboard

Xem tại: `https://github.com/your-username/health_system/actions`

### Logs

```bash
# GitHub Actions logs
# Xem trên web UI

# Local test logs
pytest tests/ -v --tb=long
```

---

## 🎯 Checklist Setup CI

- [ ] Push code lên GitHub
- [ ] Kiểm tra GitHub Actions chạy thành công
- [ ] Verify tests pass
- [ ] Deploy manual lên Heroku khi cần
- [ ] Test API endpoints
- [ ] Setup branch protection rules (optional)

---

## 🔒 Security Notes

1. **Không commit secrets vào code**
   - File `.env` trong `.gitignore`

2. **Protect branches**
   - Settings → Branches → Add rule
   - Require PR reviews
   - Require status checks to pass

---

## 📚 Resources

- GitHub Actions: https://docs.github.com/en/actions
- pytest: https://docs.pytest.org/
- flake8: https://flake8.pycqa.org/

---

**CI đã sẵn sàng! Push code và tests sẽ chạy tự động! ✨**

## 📌 Tổng quan

CI/CD pipeline tự động:

- ✅ Chạy tests khi push code
- ✅ Kiểm tra code quality (linting)
- ✅ Tự động deploy lên Heroku khi push vào nhánh `deploy`

---

## 🛠️ Workflows đã tạo

### 1. Backend CI/CD (`backend-ci.yml`)

**Trigger:** Push/PR vào nhánh `deploy` hoặc `main`

**Jobs:**

- **Test:** Chạy pytest với PostgreSQL
- **Deploy:** Tự động deploy lên Heroku (chỉ khi push vào nhánh `deploy`)

### 2. Backend Tests (`backend-test.yml`)

**Trigger:** Push/PR vào bất kỳ nhánh nào có thay đổi trong `backend/`

**Jobs:**

- Chạy tests với coverage
- Upload coverage reports lên Codecov

### 3. Backend Linting (`backend-lint.yml`)

**Trigger:** Push/PR vào bất kỳ nhánh nào có thay đổi trong `backend/`

**Jobs:**

- Black: Code formatting
- isort: Import sorting
- flake8: Code linting
- mypy: Type checking

---

## 🔐 Setup GitHub Secrets

Để CI/CD hoạt động, cần thêm secrets vào GitHub repository:

### Bước 1: Lấy Heroku API Key

```bash
# Login Heroku
heroku login

# Lấy API key
heroku auth:token
```

### Bước 2: Thêm Secrets vào GitHub

1. Vào GitHub repository
2. Settings → Secrets and variables → Actions
3. Thêm các secrets sau:

| Secret Name       | Value                    | Mô tả                                     |
| ----------------- | ------------------------ | ----------------------------------------- |
| `HEROKU_API_KEY`  | `your-heroku-api-key`    | API key từ `heroku auth:token`            |
| `HEROKU_APP_NAME` | `your-app-name`          | Tên app Heroku (ví dụ: `healthguard-api`) |
| `HEROKU_EMAIL`    | `your-email@example.com` | Email đăng ký Heroku                      |

### Bước 3: Verify Secrets

Sau khi thêm, secrets sẽ hiển thị như:

```
✅ HEROKU_API_KEY
✅ HEROKU_APP_NAME
✅ HEROKU_EMAIL
```

---

## 🚀 Cách sử dụng

### Tự động deploy khi push code

```bash
# 1. Commit code
git add .
git commit -m "feat: add new feature"

# 2. Push vào nhánh deploy
git push origin deploy
```

GitHub Actions sẽ tự động:

1. ✅ Chạy tests
2. ✅ Kiểm tra code quality
3. ✅ Deploy lên Heroku (nếu tests pass)
4. ✅ Health check API

### Xem kết quả CI/CD

1. Vào GitHub repository
2. Tab "Actions"
3. Xem workflow runs

---

## 📊 Workflow Flow

```
┌─────────────────┐
│  Push to deploy │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Run Tests      │
│  - pytest       │
│  - PostgreSQL   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Code Quality   │
│  - black        │
│  - flake8       │
└────────┬────────┘
         │
         ▼ (if pass)
┌─────────────────┐
│  Deploy Heroku  │
│  - Build        │
│  - Release      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Health Check   │
│  - Test API     │
└─────────────────┘
```

---

## 🧪 Test CI/CD locally

### Chạy tests như CI

```bash
cd backend

# Setup test database
docker run -d \
  --name test-postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=test_db \
  -p 5432:5432 \
  postgres:17

# Run tests
export DATABASE_URL=postgresql://postgres:postgres@localhost:5432/test_db
export SECRET_KEY=test-secret-key
pytest tests/ -v

# Cleanup
docker stop test-postgres
docker rm test-postgres
```

### Chạy linting như CI

```bash
cd backend

# Install tools
pip install black flake8 isort mypy

# Run checks
black --check app/
flake8 app/
isort --check-only app/
mypy app/ --ignore-missing-imports
```

---

## 🔧 Cấu hình Files

### `.github/workflows/backend-ci.yml`

Main CI/CD workflow - test và deploy

### `.github/workflows/backend-test.yml`

Chạy tests với coverage

### `.github/workflows/backend-lint.yml`

Kiểm tra code quality

### `backend/pyproject.toml`

Cấu hình cho black, isort, pytest, mypy

### `backend/.flake8`

Cấu hình cho flake8 linter

---

## 📝 Best Practices

### 1. Branch Strategy

```
main (production)
  ↑
deploy (staging)
  ↑
feat/* (features)
fix/* (bugfixes)
```

**Workflow:**

1. Tạo feature branch: `git checkout -b feat/new-feature`
2. Commit và push: `git push origin feat/new-feature`
3. Tạo PR vào `deploy` → CI chạy tests
4. Merge vào `deploy` → Tự động deploy lên Heroku
5. Test trên Heroku staging
6. Merge `deploy` vào `main` khi stable

### 2. Commit Messages

Dùng conventional commits:

```
feat: add new feature
fix: fix bug
docs: update documentation
test: add tests
refactor: refactor code
chore: update dependencies
```

### 3. Pull Requests

- Luôn tạo PR thay vì push trực tiếp
- Đợi CI pass trước khi merge
- Review code trước khi merge

---

## 🐛 Troubleshooting

### CI fails với "Heroku API key invalid"

**Giải pháp:**

```bash
# Lấy API key mới
heroku auth:token

# Update secret trên GitHub
# Settings → Secrets → HEROKU_API_KEY
```

### Tests fail với "Database connection error"

**Nguyên nhân:** PostgreSQL service chưa ready

**Giải pháp:** Workflow đã có health check, nếu vẫn lỗi:

```yaml
options: >-
  --health-cmd pg_isready
  --health-interval 10s
  --health-timeout 5s
  --health-retries 10  # Tăng retries
```

### Deploy fails với "No such app"

**Giải pháp:**

- Kiểm tra `HEROKU_APP_NAME` secret đúng chưa
- Kiểm tra app tồn tại: `heroku apps:info -a your-app-name`

### Code quality checks fail

**Giải pháp:**

```bash
# Format code
black app/
isort app/

# Fix linting issues
flake8 app/ --show-source

# Commit và push lại
git add .
git commit -m "style: fix code formatting"
git push
```

---

## 📊 Monitoring

### GitHub Actions Dashboard

Xem tại: `https://github.com/your-username/health_system/actions`

### Heroku Dashboard

Xem tại: `https://dashboard.heroku.com/apps/your-app-name`

### Logs

```bash
# GitHub Actions logs
# Xem trên web UI

# Heroku logs
heroku logs --tail -a your-app-name
```

---

## 🎯 Checklist Setup CI/CD

- [ ] Tạo Heroku app: `heroku create your-app-name`
- [ ] Add PostgreSQL: `heroku addons:create heroku-postgresql:mini`
- [ ] Lấy Heroku API key: `heroku auth:token`
- [ ] Thêm GitHub Secrets:
  - [ ] HEROKU_API_KEY
  - [ ] HEROKU_APP_NAME
  - [ ] HEROKU_EMAIL
- [ ] Push code vào nhánh `deploy`
- [ ] Kiểm tra GitHub Actions chạy thành công
- [ ] Verify deployment: `curl https://your-app-name.herokuapp.com/api/v1/health`
- [ ] Test API endpoints
- [ ] Setup branch protection rules (optional)

---

## 🔒 Security Notes

1. **Không commit secrets vào code**
   - Dùng GitHub Secrets
   - File `.env` trong `.gitignore`

2. **Protect branches**
   - Settings → Branches → Add rule
   - Require PR reviews
   - Require status checks to pass

3. **Rotate API keys định kỳ**
   ```bash
   heroku authorizations:create -d "CI/CD"
   # Update GitHub Secret
   ```

---

## 📚 Resources

- GitHub Actions: https://docs.github.com/en/actions
- Heroku CI/CD: https://devcenter.heroku.com/articles/github-integration
- pytest: https://docs.pytest.org/
- black: https://black.readthedocs.io/

---

**CI/CD đã sẵn sàng! Push code và xem magic happen! ✨**
