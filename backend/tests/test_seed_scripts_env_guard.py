"""Regression test for HS-023 — seed scripts env guards.

Verifies:
1. Production env (ENV=production) -> seed scripts raise RuntimeError before touching DB.
2. Missing env vars -> seed scripts raise RuntimeError with helpful message.

These tests do NOT touch the DB; they unit-test the guard helpers directly.
"""
from __future__ import annotations

import importlib
import sys

import pytest

DUMMY_VALUE = "x"


def _reload(module_name: str):
    """Drop a previously imported module so env changes take effect on re-import."""
    if module_name in sys.modules:
        del sys.modules[module_name]
    return importlib.import_module(module_name)


# ---------- create_caregiver_user.py ----------


def test_create_caregiver_refuses_in_production(monkeypatch):
    monkeypatch.setenv("ENV", "production")
    monkeypatch.setenv("SEED_CAREGIVER_EMAIL", "x@example.com")
    monkeypatch.setenv("SEED_CAREGIVER_PASSWORD", DUMMY_VALUE)

    mod = _reload("app.scripts.create_caregiver_user")
    with pytest.raises(RuntimeError, match="production"):
        mod.create_caregiver()


def test_create_caregiver_requires_email_env(monkeypatch):
    monkeypatch.setenv("ENV", "development")
    monkeypatch.delenv("SEED_CAREGIVER_EMAIL", raising=False)
    monkeypatch.setenv("SEED_CAREGIVER_PASSWORD", DUMMY_VALUE)

    mod = _reload("app.scripts.create_caregiver_user")
    with pytest.raises(RuntimeError, match="SEED_CAREGIVER_EMAIL"):
        mod.create_caregiver()


def test_create_caregiver_requires_password_env(monkeypatch):
    monkeypatch.setenv("ENV", "development")
    monkeypatch.setenv("SEED_CAREGIVER_EMAIL", "x@example.com")
    monkeypatch.delenv("SEED_CAREGIVER_PASSWORD", raising=False)

    mod = _reload("app.scripts.create_caregiver_user")
    with pytest.raises(RuntimeError, match="SEED_CAREGIVER_PASSWORD"):
        mod.create_caregiver()


# ---------- seed_home_dashboard_e2e.py ----------


def test_seed_home_dashboard_refuses_in_production(monkeypatch):
    monkeypatch.setenv("ENV", "production")

    sys.path.insert(0, str(__import__("pathlib").Path(__file__).resolve().parents[1]))
    mod = _reload("scripts.seed_home_dashboard_e2e")
    with pytest.raises(RuntimeError, match="production"):
        mod.main()


def test_seed_home_dashboard_requires_patient_email(monkeypatch):
    monkeypatch.setenv("ENV", "development")
    for var in (
        "SEED_E2E_PATIENT_EMAIL",
        "SEED_E2E_PATIENT_PASSWORD",
        "SEED_E2E_CAREGIVER_EMAIL",
        "SEED_E2E_CAREGIVER_PASSWORD",
        "SEED_E2E_EMPTY_SLEEP_EMAIL",
        "SEED_E2E_EMPTY_SLEEP_PASSWORD",
    ):
        monkeypatch.delenv(var, raising=False)

    sys.path.insert(0, str(__import__("pathlib").Path(__file__).resolve().parents[1]))
    mod = _reload("scripts.seed_home_dashboard_e2e")
    with pytest.raises(RuntimeError, match="SEED_E2E_PATIENT_EMAIL"):
        mod.main()
