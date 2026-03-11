# GitHub Actions Workflows

## 📋 Available Workflows

### 1. Backend CI/CD

**File:** `backend-ci.yml`  
**Badge:** ![Backend CI/CD](https://github.com/YOUR_USERNAME/health_system/workflows/Backend%20CI/CD/badge.svg)

**Triggers:**

- Push to `deploy` or `main` branches
- Pull requests to `deploy` or `main`

**Jobs:**

- Run tests with PostgreSQL
- Check code quality
- Deploy to Heroku (only on `deploy` branch)
- Health check after deployment

---

### 2. Backend Tests

**File:** `backend-test.yml`  
**Badge:** ![Backend Tests](https://github.com/YOUR_USERNAME/health_system/workflows/Backend%20Tests/badge.svg)

**Triggers:**

- Push to any branch with changes in `backend/`
- Pull requests with changes in `backend/`

**Jobs:**

- Run pytest with coverage
- Upload coverage to Codecov

---

### 3. Backend Linting

**File:** `backend-lint.yml`  
**Badge:** ![Backend Linting](https://github.com/YOUR_USERNAME/health_system/workflows/Backend%20Linting/badge.svg)

**Triggers:**

- Push to any branch with changes in `backend/`
- Pull requests with changes in `backend/`

**Jobs:**

- Black: Code formatting
- isort: Import sorting
- flake8: Code linting
- mypy: Type checking

---

## 🚀 Usage

### Automatic Deployment

Push to `deploy` branch to trigger automatic deployment:

```bash
git checkout deploy
git merge feat/your-feature
git push origin deploy
```

### Manual Workflow Trigger

You can also trigger workflows manually from GitHub Actions tab.

---

## 🔐 Required Secrets

Add these secrets in GitHub repository settings:

| Secret            | Description                             |
| ----------------- | --------------------------------------- |
| `HEROKU_API_KEY`  | Heroku API key from `heroku auth:token` |
| `HEROKU_APP_NAME` | Your Heroku app name                    |
| `HEROKU_EMAIL`    | Your Heroku account email               |

---

## 📊 Workflow Status

Check workflow status at:
`https://github.com/YOUR_USERNAME/health_system/actions`

---

## 🐛 Troubleshooting

If workflows fail:

1. Check logs in GitHub Actions tab
2. Verify secrets are set correctly
3. Ensure Heroku app exists
4. Check database connection

---

## 📝 Notes

- Tests run on every push/PR
- Deployment only happens on `deploy` branch
- All checks must pass before deployment
- Health check verifies deployment success
