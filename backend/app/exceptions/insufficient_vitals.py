"""ADR-018: ``InsufficientVitalsError`` — fail-closed gate for risk inference.

Raised by :func:`app.services.risk_alert_service._build_inference_payload`
when one or more *critical* vital fields (heart rate, SpO2, respiratory
rate, body temperature) are missing or NULL on the latest vitals row.

The risk endpoint translates this to a structured HTTP 422 response
with ``error.code == "INSUFFICIENT_VITALS"`` so the mobile app can show
an honest empty state instead of a fake "Sức khỏe ổn định" message.

Bug: HS-024.
ADR: ADR-018 (fail-closed critical + synthetic flag soft).
"""

from __future__ import annotations


class InsufficientVitalsError(Exception):
    """Raised when critical vital fields are missing for risk inference.

    Attributes
    ----------
    missing_fields:
        Ordered list of critical field names (in DB column naming) whose
        values were ``None`` or missing on the latest vitals row.
    """

    def __init__(self, missing_fields: list[str]):
        self.missing_fields = list(missing_fields)
        joined = ", ".join(self.missing_fields) if self.missing_fields else "(none)"
        super().__init__(
            f"Critical vital fields are missing: {joined}. "
            f"Risk inference requires non-null heart_rate, spo2, "
            f"respiratory_rate, and temperature."
        )
