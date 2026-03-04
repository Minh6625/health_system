# 🧪 Testing Guide - HealthGuard Mobile Backend

> **Last Updated**: 2026-03-04  
> **Framework**: pytest 8.0.0  
> **Coverage**: Auth Service (15 tests)

---

## 📋 Table of Contents

- [Quick Start](#-quick-start)
- [Running Tests](#-running-tests)
- [Test Structure](#-test-structure)
- [Writing Tests](#-writing-tests)
- [Best Practices](#-best-practices)
- [Coverage Reports](#-coverage-reports)
- [Troubleshooting](#-troubleshooting)

---

## 🚀 Quick Start

### 1. Install Dependencies

```powershell
cd backend
python -m pip install -r requirements.txt
```

**Required packages:**

- `pytest==8.0.0` - Testing framework
- `pytest-asyncio==0.23.5` - Async test support
- `httpx==0.27.0` - HTTP client for API testing

### 2. Run All Tests

```powershell
python -m pytest tests/ -v
```

### 3. Run Specific Test File

```powershell
python -m pytest tests/test_auth_service.py -v
```

---

## 🏃 Running Tests

### Basic Commands

```powershell
# Run all tests
python -m pytest tests/

# Run with verbose output
python -m pytest tests/ -v

# Run with short output (only show errors)
python -m pytest tests/ -q

# Run and stop at first failure
python -m pytest tests/ -x

# Run specific test file
python -m pytest tests/test_auth_service.py

# Run specific test class
python -m pytest tests/test_auth_service.py::TestAuthService

# Run specific test method
python -m pytest tests/test_auth_service.py::TestAuthService::test_login_valid_credentials
```

### Advanced Options

```powershell
# Run tests matching pattern
python -m pytest tests/ -k "login"

# Run tests with markers
python -m pytest tests/ -m "slow"

# Show local variables on failure
python -m pytest tests/ -l

# Show print statements
python -m pytest tests/ -s

# Parallel execution (requires pytest-xdist)
python -m pytest tests/ -n auto
```

---

## 📁 Test Structure

```
backend/tests/
├── README.md                    # This file
├── __init__.py                  # Package marker
├── conftest.py                  # Shared fixtures (future)
├── test_auth_service.py         # Auth service unit tests (15 tests)
├── test_user_repository.py      # User repository tests (future)
├── test_api_auth.py             # Auth API integration tests (future)
└── test_api_vitals.py           # Vitals API tests (future)
```

### Current Test Coverage

| Module                    | Tests | Status     | Coverage            |
| ------------------------- | ----- | ---------- | ------------------- |
| `test_auth_service.py`    | 15    | ✅ Passing | Auth business logic |
| `test_user_repository.py` | -     | ⬜ TODO    | Data access layer   |
| `test_api_auth.py`        | -     | ⬜ TODO    | Auth API endpoints  |

---

## 📝 Writing Tests

### Test File Naming Convention

- Test files must start with `test_` prefix: `test_*.py`
- Test classes must start with `Test` prefix: `class TestAuthService`
- Test methods must start with `test_` prefix: `def test_login_valid_credentials`

### Test Template

```python
"""
Unit tests for [Module Name]

Run with: pytest backend/tests/test_[module].py
"""
import pytest
from unittest.mock import Mock, patch

from app.services.your_service import YourService
from app.models.your_model import YourModel


class TestYourService:
    """Test cases for YourService class."""

    @pytest.fixture
    def mock_db(self):
        """Mock database session."""
        return Mock()

    @pytest.fixture
    def mock_model(self):
        """Mock model object."""
        model = Mock(spec=YourModel)
        model.id = 1
        model.name = "Test"
        return model

    def test_your_function_success(self, mock_db, mock_model):
        """Test successful case."""
        # Arrange: Setup mocks
        with patch('app.services.your_service.YourRepository') as mock_repo:
            mock_repo.get_by_id.return_value = mock_model

            # Act: Execute function
            result = YourService.your_function(mock_db, 1)

            # Assert: Verify results
            assert result is not None
            assert result.id == 1
            mock_repo.get_by_id.assert_called_once_with(mock_db, 1)

    def test_your_function_failure(self, mock_db):
        """Test failure case."""
        # Arrange
        with patch('app.services.your_service.YourRepository') as mock_repo:
            mock_repo.get_by_id.return_value = None

            # Act
            result = YourService.your_function(mock_db, 999)

            # Assert
            assert result is None
```

### Fixtures (Reusable Test Data)

```python
# In conftest.py (shared across all tests)
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

@pytest.fixture(scope="function")
def db_session():
    """Create a test database session."""
    engine = create_engine("sqlite:///:memory:")
    SessionLocal = sessionmaker(bind=engine)
    session = SessionLocal()

    yield session

    session.close()
```

### Mocking External Dependencies

```python
# Mock database calls
with patch('app.services.auth_service.UserRepository') as mock_repo:
    mock_repo.get_by_email.return_value = mock_user

# Mock utility functions (imported inside function)
with patch('app.utils.password.verify_password') as mock_verify:
    mock_verify.return_value = True

# Mock email service
with patch('app.services.auth_service.EmailService') as mock_email:
    mock_email.send_verification_email.return_value = True

# Mock JWT functions
with patch('app.services.auth_service.create_access_token') as mock_jwt:
    mock_jwt.return_value = "fake_token_123"
```

---

## ✅ Best Practices

### 1. Test Organization (AAA Pattern)

```python
def test_example(self):
    """Test description."""
    # Arrange: Setup test data and mocks
    user = Mock(id=1, email="test@example.com")

    # Act: Execute the function being tested
    result = AuthService.some_function(user)

    # Assert: Verify the result
    assert result is True
```

### 2. Test Naming

- ✅ **Good**: `test_login_with_valid_credentials`
- ✅ **Good**: `test_register_with_invalid_email`
- ❌ **Bad**: `test_1`, `test_function`

### 3. One Assertion Per Test (when possible)

```python
# ✅ Good: Focused test
def test_login_returns_success(self):
    result = AuthService.login(...)
    assert result[0] is True  # success flag

def test_login_returns_token(self):
    result = AuthService.login(...)
    assert result[2] is not None  # token_data

# ⚠️ Acceptable: Multiple related assertions
def test_login_response_structure(self):
    success, message, token_data = AuthService.login(...)
    assert success is True
    assert message == "Đăng nhập thành công"
    assert "access_token" in token_data
    assert "refresh_token" in token_data
```

### 4. Independent Tests

- Each test should be **independent** and **isolated**
- Tests should not rely on execution order
- Use fixtures to setup/teardown test data

### 5. Mock External Dependencies

```python
# ✅ Good: Mock external calls
with patch('app.services.auth_service.EmailService') as mock_email:
    mock_email.send_verification_email.return_value = True
    # Test code here

# ❌ Bad: Real email sending in tests
# This will fail in CI/CD or when offline
AuthService.register(...)  # Sends real email!
```

### 6. Test Edge Cases

```python
# Valid input
def test_login_with_valid_credentials(self):
    ...

# Invalid input
def test_login_with_invalid_email(self):
    ...

def test_login_with_empty_password(self):
    ...

def test_login_with_null_email(self):
    ...

# Boundary values
def test_register_with_6_char_password(self):  # Min length
    ...

def test_register_with_5_char_password(self):  # Below min
    ...
```

### 7. Descriptive Assertions

```python
# ✅ Good: Clear assertion message
assert len(results) > 0, "Should return at least one result"

# ✅ Good: Use pytest helpers
from pytest import approx
assert result == approx(3.14, rel=0.01)
```

---

## 📊 Coverage Reports

### Install Coverage Tool

```powershell
python -m pip install pytest-cov
```

### Generate Coverage Report

```powershell
# Terminal output
python -m pytest tests/ --cov=app --cov-report=term-missing

# HTML report
python -m pytest tests/ --cov=app --cov-report=html

# XML report (for CI/CD)
python -m pytest tests/ --cov=app --cov-report=xml
```

### View HTML Report

```powershell
# After generating HTML report
start htmlcov/index.html  # Windows
```

### Coverage Output Example

```
----------- coverage: platform win32, python 3.11.14 -----------
Name                                Stmts   Miss  Cover   Missing
-----------------------------------------------------------------
app/services/auth_service.py          245     12    95%   102-105, 350-355
app/repositories/user_repository.py    87      8    91%   45-47, 78-82
-----------------------------------------------------------------
TOTAL                                 332     20    94%
```

### Coverage Goals

| Level             | Target | Priority |
| ----------------- | ------ | -------- |
| Unit Tests        | ≥ 80%  | HIGH     |
| Integration Tests | ≥ 70%  | MEDIUM   |
| Overall           | ≥ 75%  | HIGH     |

---

## 🐛 Troubleshooting

### Issue 1: `pytest` command not found

**Error:**

```
pytest: The term 'pytest' is not recognized...
```

**Solution:**

```powershell
# Use python -m instead
python -m pytest tests/
```

### Issue 2: Module import errors

**Error:**

```
ModuleNotFoundError: No module named 'app'
```

**Solutions:**

1. **Check current directory:**

   ```powershell
   # Should be in backend/ folder
   cd c:\Dev\health_system\backend
   python -m pytest tests/
   ```

2. **Add backend to PYTHONPATH:**

   ```powershell
   $env:PYTHONPATH="$PWD"
   python -m pytest tests/
   ```

3. **Install package in editable mode:**
   ```powershell
   pip install -e .
   ```

### Issue 3: Mock attribute errors

**Error:**

```
AttributeError: <module 'app.services.auth_service'> does not have the attribute 'verify_password'
```

**Solution:**
Check where the function is **actually imported from**:

```python
# In auth_service.py
from app.utils.password import verify_password  # Import location

# In test file - patch at import location, not usage location
with patch('app.utils.password.verify_password') as mock_verify:  # ✅ Correct
    ...

# NOT:
with patch('app.services.auth_service.verify_password') as mock_verify:  # ❌ Wrong
    ...
```

**Rule**: Patch where the object is **imported from**, not where it's **used**.

### Issue 4: Database connection in tests

**Error:**

```
sqlalchemy.exc.OperationalError: could not connect to server
```

**Solution:**
Use mocks instead of real database:

```python
@pytest.fixture
def mock_db(self):
    """Mock database session - no real connection."""
    return Mock()
```

### Issue 5: Tests fail with async functions

**Error:**

```
RuntimeError: no running event loop
```

**Solution:**
Mark async tests with `@pytest.mark.asyncio`:

```python
import pytest

@pytest.mark.asyncio
async def test_async_function(self):
    result = await some_async_function()
    assert result is not None
```

---

## 📚 Resources

### Pytest Documentation

- Official docs: https://docs.pytest.org/
- Fixtures guide: https://docs.pytest.org/en/stable/fixture.html
- Parametrize: https://docs.pytest.org/en/stable/parametrize.html

### Mocking

- unittest.mock: https://docs.python.org/3/library/unittest.mock.html
- pytest-mock: https://pytest-mock.readthedocs.io/

### Best Practices

- Test Driven Development (TDD)
- Behavior Driven Development (BDD) with pytest-bdd
- Continuous Integration (CI/CD) with GitHub Actions

---

## 🎯 Quick Reference Commands

```powershell
# Install dependencies
python -m pip install -r requirements.txt

# Run all tests
python -m pytest tests/ -v

# Run specific file
python -m pytest tests/test_auth_service.py

# Run with coverage
python -m pytest tests/ --cov=app --cov-report=term-missing

# Run matching pattern
python -m pytest tests/ -k "login"

# Stop at first failure
python -m pytest tests/ -x

# Show print statements
python -m pytest tests/ -s

# Generate HTML coverage report
python -m pytest tests/ --cov=app --cov-report=html
```

---

## 📝 TODO: Future Tests

### High Priority

- [ ] `test_api_auth.py` - Integration tests for auth endpoints
- [ ] `test_user_repository.py` - Unit tests for user data access
- [ ] `test_vitals_service.py` - Unit tests for vitals business logic

### Medium Priority

- [ ] `test_jwt.py` - JWT token generation/validation tests
- [ ] `test_rate_limiter.py` - Rate limiting logic tests
- [ ] `test_password.py` - Password hashing/validation tests

### Low Priority

- [ ] Performance tests (load testing)
- [ ] Security tests (OWASP checks)
- [ ] End-to-end tests with real database

---

**Maintained by**: Backend Development Team  
**Questions?**: Contact project lead or check project documentation

**Current Status**:

- ✅ Auth Service: 15/15 tests passing (100%)
- ⬜ Other modules: TBD

**Last Test Run**: 2026-03-04 ✅ All tests passing
