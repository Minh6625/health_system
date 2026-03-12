# GitHub Secrets Configuration

## Required Secrets for CI/CD

These secrets must be configured in GitHub repository settings:
**Settings → Secrets and variables → Actions → New repository secret**

### CI Test Environment Secrets

| Secret Name                      | Value                                                   | Description                                             |
| -------------------------------- | ------------------------------------------------------- | ------------------------------------------------------- |
| `CI_DATABASE_URL`                | `postgresql://postgres:postgres@localhost:5432/test_db` | Test database URL (temporary, auto-deleted after tests) |
| `CI_SECRET_KEY`                  | `test-secret-key-for-ci`                                | JWT secret key for test environment                     |
| `CI_ALGORITHM`                   | `HS256`                                                 | JWT algorithm                                           |
| `CI_ACCESS_TOKEN_EXPIRE_MINUTES` | `30`                                                    | Token expiration time in minutes                        |

## Important Notes

- ⚠️ **These are TEST-ONLY values** - safe to commit to repository
- **DO NOT use production values** for CI secrets
- These values are used only for automated testing in GitHub Actions
- Production secrets are stored separately on Heroku Config Vars
- CI database is temporary and destroyed after each test run
- If you need to update secrets, go to GitHub Settings → Secrets → Actions

## Production Secrets (Heroku)

Production secrets are managed separately on Heroku:

- Go to Heroku Dashboard → App → Settings → Config Vars
- Never commit production secrets to repository
- See `DEPLOY_HEROKU.md` for production deployment guide
