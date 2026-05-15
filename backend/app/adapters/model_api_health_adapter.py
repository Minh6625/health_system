"""Adapter for the external healthguard-model-api (health domain).

Responsibilities (Phase 3b — see plan section E.3):

* ``to_record`` — translate the ``risk_inference_service`` payload into
  the model-api ``VitalSignsRecord`` shape (computes derived HRV /
  pulse-pressure / BMI / MAP fields).
* ``from_response`` — accept the canonical 6-layer model-api response and
  produce a uniform :class:`NormalizedExplanation` ready for the
  persistence adapter.
* ``from_local_inference`` — same end shape, but built from the local
  rule-based / ONNX / LightGBM result so the persistence layer never
  has to branch on the source.

The helpers that used to live as private functions in
:mod:`app.services.risk_alert_service` (``_build_model_api_record``,
``_normalize_model_api_top_features``, ``_normalize_model_api_shap``,
``_alias_feature_name``, ``_feature_importance_from_top_features``,
``_map_model_api_risk_level``, ``_default_recommendations``,
``_build_explanation_text``, ``_build_feature_importance``,
``_build_ai_explanation_payload``) are gathered here as private
``@staticmethod`` so they remain testable in isolation.
"""

from __future__ import annotations

from typing import Any

from app.adapters.normalized_explanation import NormalizedExplanation
from app.services.risk_inference_service import (
    RiskInferenceResult,
    canonicalize_risk_level,
    normalize_risk_score,
)

# Mapping from model-api feature names (HealthGuard schema) to backend / UI canonical keys.
_MODEL_API_FEATURE_ALIASES: dict[str, str] = {
    "respiratory_rate": "resp_rate",
    "body_temperature": "body_temp",
    "systolic_blood_pressure": "sys_bp",
    "diastolic_blood_pressure": "dia_bp",
    "derived_hrv": "hrv",
    "derived_pulse_pressure": "pulse_pressure",
    "derived_bmi": "bmi",
    "derived_map": "map_val",
}

# Mapping model-api ``risk_level`` (normal|warning|critical) to backend canonical (low|medium|critical).
_MODEL_API_RISK_LEVEL_MAP: dict[str, str] = {
    "normal": "low",
    "warning": "medium",
    "high": "medium",
    "moderate": "medium",
    "medium": "medium",
    "critical": "critical",
    "low": "low",
}


class ModelApiHealthAdapter:
    """Boundary class between the inference layer and the persistence layer."""

    # ------------------------------------------------------------------
    # to_record — outbound: backend payload -> model-api request body
    # ------------------------------------------------------------------

    @staticmethod
    def to_record(payload: dict[str, Any]) -> dict[str, Any]:
        """Map the ``risk_inference_service`` payload to a ``VitalSignsRecord``.

        Computes the four derived features (HRV / pulse-pressure / BMI /
        MAP) so that ``health_service.prepare_inference_frame`` accepts the
        record without falling back to its ``ValueError("Missing required
        keys")`` path.

        XR-003 step 2: tracks which fields were default-filled via
        ``is_synthetic_default`` + ``defaults_applied`` list. When any
        primary vital (heart_rate, spo2, body_temp) is missing, flag is set.
        """
        defaults_applied: list[str] = []

        def _get_or_default(key: str, payload_key: str, default: float) -> float:
            val = payload.get(payload_key)
            if val is None or val == "":
                defaults_applied.append(key)
                return default
            return float(val)

        heart_rate = _get_or_default("heart_rate", "heart_rate", 75.0)
        resp_rate = _get_or_default("respiratory_rate", "resp_rate", 16.0)
        body_temp = _get_or_default("body_temperature", "body_temp", 36.6)
        spo2 = _get_or_default("spo2", "spo2", 98.0)
        sys_bp = _get_or_default("systolic_blood_pressure", "sys_bp", 120.0)
        dia_bp = _get_or_default("diastolic_blood_pressure", "dia_bp", 80.0)

        # ADR-018: soft fields — track defaults so the model-api response
        # surfaces a complete ``defaults_applied`` list. HRV default aligned
        # to 40.0 to match :func:`risk_alert_service._build_inference_payload`
        # (drift between the two layers was a HS-024 symptom).
        height_cm_raw = payload.get("height_cm")
        if height_cm_raw is None or height_cm_raw == "":
            defaults_applied.append("height_cm")
            height_cm = 165.0
        else:
            height_cm = float(height_cm_raw)
        height_m = height_cm / 100.0 if height_cm > 3.5 else height_cm
        if height_m <= 0:
            height_m = 1.65

        weight_kg_raw = payload.get("weight_kg")
        if weight_kg_raw is None or weight_kg_raw == "":
            defaults_applied.append("weight_kg")
            weight_kg = 65.0
        else:
            weight_kg = float(weight_kg_raw)

        hrv_raw = payload.get("hrv")
        if hrv_raw is None or hrv_raw == "":
            defaults_applied.append("hrv")
            hrv = 40.0
        else:
            hrv = float(hrv_raw)

        gender_norm = str(payload.get("gender") or "").strip().lower()
        gender_int = 1 if gender_norm in {"m", "male", "man", "nam", "1", "true"} else 0

        is_synthetic = len(defaults_applied) > 0

        return {
            "heart_rate": heart_rate,
            "respiratory_rate": resp_rate,
            "body_temperature": body_temp,
            "spo2": spo2,
            "systolic_blood_pressure": sys_bp,
            "diastolic_blood_pressure": dia_bp,
            "age": int(round(float(payload.get("age") or 35.0))),
            "gender": gender_int,
            "weight_kg": weight_kg,
            "height_m": round(height_m, 4),
            "derived_hrv": hrv,
            "derived_pulse_pressure": round(sys_bp - dia_bp, 4),
            "derived_bmi": round(weight_kg / (height_m * height_m), 4),
            "derived_map": round((sys_bp + 2.0 * dia_bp) / 3.0, 4),
            "is_synthetic_default": is_synthetic,
            "defaults_applied": defaults_applied,
        }

    # ------------------------------------------------------------------
    # from_response — inbound: model-api response -> NormalizedExplanation
    # ------------------------------------------------------------------

    @staticmethod
    def from_response(
        response: dict[str, Any],
        *,
        defaults_applied: list[str],
        feature_snapshot: dict[str, Any],
    ) -> NormalizedExplanation:
        """Translate a model-api 6-layer response to NormalizedExplanation."""

        backend_label = "model_api_health"
        meta = response.get("meta") if isinstance(response.get("meta"), dict) else {}
        # ``model_version`` column is varchar(20). Prefer ``meta.model_version``
        # (e.g. "v_current") which fits; otherwise short-form "model_api_v1".
        model_version_label = str(meta.get("model_version") or "model_api_v1")[:20]

        raw_level = response.get("risk_level") or (
            response.get("prediction") or {}
        ).get("prediction_band")
        risk_level = ModelApiHealthAdapter._map_risk_level(raw_level) or "medium"

        try:
            probability = float(
                response.get("predicted_health_risk_probability")
                or (response.get("prediction") or {}).get("prediction_score")
                or 0.0
            )
        except (TypeError, ValueError):
            probability = 0.0
        confidence_value = max(0.0, min(1.0, probability))

        risk_score = normalize_risk_score(
            level=risk_level,
            confidence=confidence_value,
            raw_score=None,
            backend=backend_label,
        )
        prediction_label = str(
            (response.get("prediction") or {}).get("prediction_label")
            or response.get("predicted_health_risk_label")
            or risk_level
        )

        top_features = ModelApiHealthAdapter._normalize_top_features(
            response.get("top_features")
        )
        shap_details = ModelApiHealthAdapter._normalize_shap(response.get("shap"))
        ai_explanation = response.get("explanation") or {}
        if not isinstance(ai_explanation, dict):
            ai_explanation = {}

        feature_importance = ModelApiHealthAdapter._feature_importance_from_top_features(
            top_features
        )
        if not feature_importance:
            feature_importance = ModelApiHealthAdapter._feature_importance_from_snapshot(
                feature_snapshot
            )

        recommendations_raw = ai_explanation.get("recommended_actions") or []
        recommendations = [
            str(item).strip() for item in recommendations_raw if str(item).strip()
        ] or ModelApiHealthAdapter._default_recommendations(risk_level)

        explanation_text = (
            str(ai_explanation.get("short_text") or "").strip()
            or ModelApiHealthAdapter._build_explanation_text(
                risk_level=risk_level,
                backend=backend_label,
                defaults_applied=defaults_applied,
                fallback_reason=None,
            )
        )
        ai_explanation_payload = {
            "short_text": explanation_text,
            "clinical_note": str(ai_explanation.get("clinical_note") or "").strip(),
            "recommended_actions": recommendations,
        }
        xai_method = (
            "shap"
            if isinstance(shap_details, dict) and shap_details.get("available")
            else "rule_based"
        )
        artifact_path = (
            (response.get("meta") or {}).get("artifact_path")
            if isinstance(response.get("meta"), dict)
            else None
        )
        # Phase 2: pull the upstream model-api ``meta.request_id`` so the
        # persistence adapter can write it onto the row for end-to-end log
        # correlation. The column is varchar(36) (UUID-shaped) but we
        # ``str()`` defensively in case the upstream sent a number.
        raw_request_id = meta.get("request_id") if isinstance(meta, dict) else None
        model_request_id: str | None = None
        if raw_request_id is not None:
            candidate = str(raw_request_id).strip()
            model_request_id = candidate[:36] if candidate else None

        return NormalizedExplanation(
            risk_level=risk_level,
            risk_score=risk_score,
            confidence_value=confidence_value,
            prediction_label=prediction_label,
            label_id=None,
            backend_label=backend_label,
            model_version_label=model_version_label,
            explanation_text=explanation_text,
            recommendations=recommendations,
            feature_importance=feature_importance,
            top_features=top_features,
            ai_explanation_payload=ai_explanation_payload,
            shap_details=shap_details if isinstance(shap_details, dict) else None,
            xai_method=xai_method,
            artifact_path=artifact_path,
            fallback_reason=None,
            model_request_id=model_request_id,
        )

    # ------------------------------------------------------------------
    # from_local_inference — fallback path: infer_risk() -> NormalizedExplanation
    # ------------------------------------------------------------------

    @staticmethod
    def from_local_inference(
        inference_result: RiskInferenceResult,
        *,
        defaults_applied: list[str],
        feature_snapshot: dict[str, Any],
    ) -> NormalizedExplanation:
        """Translate a local ``infer_risk`` result to NormalizedExplanation.

        Used when the external model-api is unavailable / errored.
        """
        risk_level = canonicalize_risk_level(inference_result.label) or "medium"
        confidence_value = float(inference_result.confidence)
        risk_score = normalize_risk_score(
            level=risk_level,
            confidence=inference_result.confidence,
            raw_score=inference_result.score,
            backend=inference_result.backend,
        )
        backend_label = inference_result.backend
        feature_importance = ModelApiHealthAdapter._feature_importance_from_snapshot(
            feature_snapshot
        )
        explanation_text = ModelApiHealthAdapter._build_explanation_text(
            risk_level=risk_level,
            backend=backend_label,
            defaults_applied=defaults_applied,
            fallback_reason=inference_result.fallback_reason,
        )
        recommendations = ModelApiHealthAdapter._default_recommendations(risk_level)
        ai_explanation_payload = ModelApiHealthAdapter._build_ai_explanation_payload(
            explanation_text=explanation_text,
            risk_level=risk_level,
            recommendations=recommendations,
        )
        # ``model_version`` column is varchar(20); local labels keep "-v1.0" suffix.
        model_version_label = f"{backend_label}-v1.0"[:20]

        return NormalizedExplanation(
            risk_level=risk_level,
            risk_score=risk_score,
            confidence_value=confidence_value,
            prediction_label=inference_result.label,
            label_id=inference_result.label_id,
            backend_label=backend_label,
            model_version_label=model_version_label,
            explanation_text=explanation_text,
            recommendations=recommendations,
            feature_importance=feature_importance,
            top_features=[],
            ai_explanation_payload=ai_explanation_payload,
            shap_details=None,
            xai_method="rule_based",
            artifact_path=None,
            fallback_reason=inference_result.fallback_reason,
        )

    # ------------------------------------------------------------------
    # Private helpers — extracted from risk_alert_service module-level
    # ------------------------------------------------------------------

    @staticmethod
    def _map_risk_level(raw_level: str | None) -> str | None:
        if not raw_level:
            return None
        return _MODEL_API_RISK_LEVEL_MAP.get(str(raw_level).strip().lower())

    @staticmethod
    def _alias_feature_name(feature_name: str) -> str:
        return _MODEL_API_FEATURE_ALIASES.get(feature_name, feature_name)

    @staticmethod
    def _normalize_top_features(
        top_features: list[dict[str, Any]] | None,
    ) -> list[dict[str, Any]]:
        """Rewrite ``feature`` keys to backend/UI canonical names; drop invalid entries.

        Verbatim port of the pre-Phase-3b helper.
        """
        if not top_features:
            return []
        normalized: list[dict[str, Any]] = []
        for entry in top_features:
            if not isinstance(entry, dict):
                continue
            feature_name = str(entry.get("feature") or "").strip()
            if not feature_name:
                continue
            item = dict(entry)
            item["feature"] = ModelApiHealthAdapter._alias_feature_name(feature_name)
            normalized.append(item)
        return normalized

    @staticmethod
    def _normalize_shap(
        shap_payload: dict[str, Any] | None,
    ) -> dict[str, Any] | None:
        """Alias feature names inside ``shap.values`` so UI can match them to vitals.

        Verbatim port of the pre-Phase-3b helper.
        """
        if not isinstance(shap_payload, dict):
            return None
        values = shap_payload.get("values")
        if not isinstance(values, list):
            return shap_payload
        aliased_values: list[dict[str, Any]] = []
        for entry in values:
            if not isinstance(entry, dict):
                continue
            feature_name = str(entry.get("feature") or "").strip()
            if not feature_name:
                continue
            new_entry = dict(entry)
            new_entry["feature"] = ModelApiHealthAdapter._alias_feature_name(feature_name)
            aliased_values.append(new_entry)
        return {**shap_payload, "values": aliased_values}

    @staticmethod
    def _feature_importance_from_top_features(
        top_features: list[dict[str, Any]] | None,
    ) -> dict[str, float]:
        """Build legacy ``feature_importance`` dict (key -> impact) from SHAP top_features.

        Verbatim port of the pre-Phase-3b helper: a missing or ``None``
        ``impact`` defaults to ``0.0`` rather than being skipped, and the
        resulting value is rounded to 4 decimals.
        """
        if not top_features:
            return {}
        out: dict[str, float] = {}
        for entry in top_features:
            if not isinstance(entry, dict):
                continue
            key = str(entry.get("feature") or "").strip()
            if not key:
                continue
            try:
                out[key] = round(float(entry.get("impact") or 0.0), 4)
            except (TypeError, ValueError):
                continue
        return out

    @staticmethod
    def _feature_importance_from_snapshot(
        feature_snapshot: dict[str, Any],
    ) -> dict[str, float]:
        """Verbatim port of the pre-Phase-3b ``_build_feature_importance``.

        The original takes the absolute value of each feature and rounds to
        4 decimal places; preserve both transformations so existing tests
        and downstream consumers see identical numbers.
        """
        importance: dict[str, float] = {}
        for key in (
            "heart_rate",
            "spo2",
            "sys_bp",
            "dia_bp",
            "resp_rate",
            "body_temp",
            "hrv",
        ):
            value = feature_snapshot.get(key)
            if value is None:
                continue
            importance[key] = round(abs(float(value)), 4)
        return importance

    @staticmethod
    def _default_recommendations(risk_level: str) -> list[str]:
        """Risk-level aware recommendations used when model-api explanation is unavailable.

        Verbatim port of the pre-Phase-3b helper. The exact strings + counts
        (3 for critical, 2 for medium, 2 for low) are pinned by
        ``test_shap_explanation_contract.TestDefaultRecommendations``;
        do not change copy without updating those tests.
        """
        normalized = (risk_level or "").strip().lower()
        if normalized == "critical":
            return [
                "Đo lại chỉ số để xác nhận",
                "Đối chiếu triệu chứng hiện tại",
                "Liên hệ nhân viên y tế nếu cần",
            ]
        if normalized in {"medium", "moderate", "high", "warning"}:
            return [
                "Đo lại chỉ số sau 30-60 phút",
                "Theo dõi triệu chứng bất thường",
            ]
        return [
            "Tiếp tục theo dõi định kỳ",
            "Duy trì lịch đo đều đặn",
        ]

    @staticmethod
    def _build_explanation_text(
        *,
        risk_level: str,
        backend: str,
        defaults_applied: list[str],
        fallback_reason: str | None,
    ) -> str:
        """Compose the deterministic explanation text persisted as fallback.

        Verbatim port of the pre-Phase-3b helper; the English copy with the
        backticked backend label is what the existing ``risk_explanations``
        rows already contain on disk, so don't change it without a
        backfill plan.
        """
        notes: list[str] = [
            f"Risk inference backend `{backend}` predicted {risk_level.lower()} risk."
        ]
        if defaults_applied:
            notes.append(
                "Default inputs were used for: "
                + ", ".join(defaults_applied)
                + "."
            )
        if fallback_reason:
            notes.append(f"Fallback reason: {fallback_reason}.")
        return " ".join(notes)

    @staticmethod
    def _build_ai_explanation_payload(
        *,
        explanation_text: str,
        risk_level: str,
        recommendations: list[str] | None,
    ) -> dict[str, Any]:
        """Build the minimal AI-explanation payload consumed by Flutter.

        Verbatim port of the pre-Phase-3b helper. ``recommendations`` is
        accepted as ``None`` (the original used ``recommendations or []``)
        so callers from the rule-based path can pass through whatever
        ``_default_recommendations`` returned without an extra ``or []``.
        """
        return {
            "short_text": explanation_text,
            "clinical_note": "",
            "recommended_actions": list(recommendations or []),
        }

    @staticmethod
    def _safe_float(value: Any, default: float = 0.0) -> float:
        if value is None:
            return default
        try:
            return float(value)
        except (TypeError, ValueError):
            return default
