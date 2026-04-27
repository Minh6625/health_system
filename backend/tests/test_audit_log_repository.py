"""Unit tests for `_coerce_ip` in AuditLogRepository.

The Postgres `audit_logs.ip_address` column has type `inet`. Empty strings
or non-IP placeholders (e.g. "", "unknown") raise
`psycopg2.errors.InvalidTextRepresentation` and crash any HTTP route that
emits an audit log. The coercion helper converts such values to None so
they are stored as NULL.

Regression: bug surfaced as PUT /profile -> 500 "Internal Server Error"
when `request.client` was falsy and the route passed "" downstream.
"""

import pytest

from app.repositories.audit_log_repository import _coerce_ip


@pytest.mark.parametrize(
    "value",
    [None, "", "   ", "\t\n", "unknown", "?", "192.168.1", "999.999.999.999", "abc"],
)
def test_coerce_ip_invalid_returns_none(value):
    assert _coerce_ip(value) is None


@pytest.mark.parametrize(
    "value",
    [
        "127.0.0.1",
        "192.168.1.50",
        "10.0.0.1",
        "::1",
        "fe80::1",
        "2001:db8::1",
    ],
)
def test_coerce_ip_valid_returned_unchanged(value):
    assert _coerce_ip(value) == value


def test_coerce_ip_strips_whitespace():
    assert _coerce_ip("  127.0.0.1  ") == "127.0.0.1"
