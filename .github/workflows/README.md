# GitHub Actions Workflows

## 📋 Available Workflows

### Backend CI

**File:** `backend-ci.yml`  
**Badge:** ![Backend CI](https://github.com/YOUR_USERNAME/health_system/workflows/Backend%20CI/badge.svg)

**Triggers:**

- Push to any branch with changes in `backend/`
- Pull requests to `deploy` or `main`

**Jobs:**

- Run tests with PostgreSQL
- Check code style with flake8
- Generate test summary

**Note:** This workflow only runs CI (Continuous Integration). Deploy to Heroku manually using the script or Heroku CLI.

---

## 🚀 Usage

### Automatic Testing

Tests run automatically when you push code:

```bash
git add .
git commit -m "feat: add new feature"
git push origin your-branch
```

### Manual Deployment

Deploy to Heroku manually:

```bash
# Option 1: Use script
cd scripts
deploy_heroku.bat

# Option 2: Manual
cd backend
git push heroku deploy:main
```

---

## 📊 Workflow Status

Check workflow status at:
`https://github.com/YOUR_USERNAME/health_system/actions`

---

## 🐛 Troubleshooting

If workflows fail:

1. Check logs in GitHub Actions tab
2. Run tests locally: `pytest tests/ -v`
3. Check code style: `flake8 app/`

---

## 📝 Notes

- Tests run on every push/PR
- Code style checks are non-blocking
- Deploy to Heroku manually when ready
- All checks must pass before merging PR
