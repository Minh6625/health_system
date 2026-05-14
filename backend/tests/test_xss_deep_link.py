"""Regression test for HS-018 — XSS in deep_link_redirect.

The handler interpolates user-controlled query params (action, code, email)
into an HTML/JS response. Without escaping, an attacker can inject markup or
JavaScript via crafted email links.

Verifies post-fix:
1. Malicious script payload is encoded in the response (no raw tag).
2. Quote-breakout attempts are escaped.
3. Standard happy-path values still render correctly.
"""

from __future__ import annotations

from app.api.routes.auth import deep_link_redirect


def _call(action: str, code: str, email: str) -> str:
    response = deep_link_redirect(action=action, code=code, email=email)
    return response.body.decode("utf-8")


def test_malicious_payload_escaped():
    """Script tag payload must not appear raw in the JS string literal portion."""
    body = _call(
        action="<script>x=1</script>",
        code="abc",
        email="x@example.com",
    )
    # Extract the JS string literal where user input lands.
    js_section = body.split("var targetUrl = ")[1].split(";", 1)[0]
    # User-injected raw markup must be escaped (URL-encoded) in this critical region.
    assert "<script>x=1</script>" not in js_section
    assert "<script>" not in js_section
    # URL-encoded form should be present instead.
    assert "%3Cscript%3E" in js_section


def test_quote_breakout_escaped_in_js_string():
    """Double-quote injection must not break out of the JS string literal."""
    body = _call(
        action="verify",
        code='" + x + "',
        email="x@example.com",
    )
    assert '" + x + "' not in body


def test_happy_path_renders_safely():
    """Standard verification link still produces a valid HTML response."""
    body = _call(
        action="verify-email",
        code="123456",
        email="user@example.com",
    )
    assert "Health Guard" in body
    assert "verify-email" in body
    assert "123456" in body
    # Email is URL-encoded (@ -> %40).
    assert "user%40example.com" in body
