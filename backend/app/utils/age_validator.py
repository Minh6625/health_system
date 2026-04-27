"""Reusable age validation extracted from AuthService.

Both registration (`AuthService.register`) and profile updates
(`ProfileUpdateRequest`) need the same constraints; keeping the logic
in one place avoids the two callers drifting and producing different
error messages for the same input.
"""

from __future__ import annotations

from datetime import date
from typing import Optional


def validate_age(date_of_birth: Optional[date]) -> tuple[bool, str]:
    """Validate age from date of birth.

    Requirements:
    - Age >= 16
    - Age <= 150 (reasonable upper limit)
    - Not in the future

    Returns (is_valid, message).
    """
    if date_of_birth is None:
        return True, "OK"  # Optional field

    today = date.today()

    if date_of_birth > today:
        return False, "Ngày sinh không hợp lệ (trong tương lai)"

    days_old = (today - date_of_birth).days

    if days_old < 16 * 365:
        return False, "Bạn phải đủ 16 tuổi"

    if days_old > 150 * 365:
        return False, "Ngày sinh không hợp lệ (tuổi quá cao)"

    return True, "OK"
