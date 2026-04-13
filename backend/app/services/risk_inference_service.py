from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from functools import lru_cache
from math import exp
from pathlib import Path
from typing import Any, Mapping, Sequence, Literal
import os
import threading

try:
    import numpy as np
except ImportError:  # pragma: no cover - optional at runtime
    np = None  # type: ignore[assignment]

try:
    import joblib
except ImportError:  # pragma: no cover - optional at runtime
    joblib = None  # type: ignore[assignment]

try:
    import onnxruntime as ort
except ImportError:  # pragma: no cover - optional at runtime
    ort = None  # type: ignore[assignment]

try:
    import lightgbm as lgb
except ImportError:  # pragma: no cover - optional at runtime
    lgb = None  # type: ignore[assignment]

FEATURE_ORDER = (
    "heart_rate",
    "resp_rate",
    "body_temp",
    "spo2",
    "sys_bp",
    "dia_bp",
    "age",
    "gender",
    "weight",
    "height",
    "hrv",
    "pulse_pressure",
    "bmi",
    "map_val",
)

LABEL_MAP = {
    0: "low",
    1: "critical",
    2: "medium",
}

DEFAULT_HRV = 50.0
DEFAULT_AGE = 35.0
DEFAULT_WEIGHT_KG = 70.0
DEFAULT_HEIGHT_CM = 170.0
MODEL_DIR_ENV = "HEALTHGUARD_MODEL_DIR"
ONNX_MODEL_FILENAME = "healthguard.onnx"
LIGHTGBM_MODEL_FILENAME = "healthguard_lightgbm.pkl"
MODEL_BACKENDS = ("onnx", "lightgbm", "rule_based")


@dataclass(frozen=True)
class RiskInferenceInput:
    heart_rate: float
    resp_rate: float
    body_temp: float
    spo2: float
    sys_bp: float
    dia_bp: float
    age: float
    gender: float | int | str
    weight: float
    height: float
    hrv: float | None = None


@dataclass(frozen=True)
class RiskInferenceResult:
    label_id: int
    label: str
    score: float
    confidence: float
    backend: str
    feature_vector: tuple[float, ...]
    fallback_reason: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "label_id": self.label_id,
            "label": self.label,
            "score": self.score,
            "confidence": self.confidence,
            "backend": self.backend,
            "feature_vector": list(self.feature_vector),
            "fallback_reason": self.fallback_reason,
        }


@dataclass(frozen=True)
class ModelBundle:
    model_dir: Path
    onnx_session: Any | None
    lightgbm_model: Any | None
    onnx_error: str | None = None
    lightgbm_error: str | None = None

    @property
    def is_ready(self) -> bool:
        return self.onnx_session is not None or self.lightgbm_model is not None


_MODEL_LOCK = threading.Lock()


def _resolve_model_dir() -> Path:
    override = os.getenv(MODEL_DIR_ENV)
    if override:
        return Path(override).expanduser().resolve()

    return (Path(__file__).resolve().parents[4] / "healthguard-ai" / "models" / "healthguard").resolve()


def _as_float(value: Any, default: float | None = None) -> float:
    if value is None:
        if default is None:
            raise ValueError("missing numeric value")
        return float(default)

    if isinstance(value, bool):
        return float(int(value))

    try:
        return float(value)
    except (TypeError, ValueError) as error:
        if default is None:
            raise ValueError(f"invalid numeric value: {value!r}") from error
        return float(default)


def _normalize_gender(gender: float | int | str | None) -> float:
    if gender is None:
        return 0.0

    if isinstance(gender, (int, float)) and not isinstance(gender, bool):
        return 1.0 if float(gender) >= 1 else 0.0

    normalized = str(gender).strip().lower()
    if normalized in {"m", "male", "man", "1", "true"}:
        return 1.0
    if normalized in {"f", "female", "woman", "0", "false"}:
        return 0.0
    return 0.0


def _normalize_height_m(height: float) -> float:
    if height <= 0:
        raise ValueError("height must be positive")
    if height > 3.5:
        return height / 100.0
    return height


def _normalize_probability_vector(values: Sequence[float]) -> list[float]:
    if not values:
        return []

    numeric = [float(value) for value in values]
    if all(0.0 <= value <= 1.0 for value in numeric):
        total = sum(numeric)
        if total > 0.0 and abs(total - 1.0) <= 0.15:
            return [value / total for value in numeric]

    shifted = [value - max(numeric) for value in numeric]
    exps = [exp(value) for value in shifted]
    total = sum(exps)
    if total == 0.0:
        return [1.0 / len(numeric) for _ in numeric]
    return [value / total for value in exps]


def _coerce_date(value: Any) -> date | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    if isinstance(value, str):
        try:
            return date.fromisoformat(value[:10])
        except ValueError:
            return None
    return None


def _age_from_date_of_birth(value: Any) -> float | None:
    dob = _coerce_date(value)
    if dob is None:
        return None
    today = datetime.utcnow().date()
    years = today.year - dob.year
    if (today.month, today.day) < (dob.month, dob.day):
        years -= 1
    return float(max(0, years))


def coerce_risk_input(payload: Mapping[str, Any]) -> RiskInferenceInput:
    age = payload.get("age")
    if age is None:
        age = _age_from_date_of_birth(payload.get("date_of_birth"))

    weight = payload.get("weight")
    if weight is None:
        weight = payload.get("weight_kg")
    if weight is None:
        weight = DEFAULT_WEIGHT_KG

    height = payload.get("height")
    if height is None:
        height = payload.get("height_cm")
    if height is None:
        height = payload.get("height_m")
    if height is None:
        height = DEFAULT_HEIGHT_CM

    hrv = payload.get("hrv")

    return RiskInferenceInput(
        heart_rate=_as_float(payload.get("heart_rate")),
        resp_rate=_as_float(payload.get("resp_rate")),
        body_temp=_as_float(payload.get("body_temp")),
        spo2=_as_float(payload.get("spo2")),
        sys_bp=_as_float(payload.get("sys_bp")),
        dia_bp=_as_float(payload.get("dia_bp")),
        age=_as_float(age, default=DEFAULT_AGE),
        gender=payload.get("gender"),
        weight=_as_float(weight, default=DEFAULT_WEIGHT_KG),
        height=_as_float(height, default=DEFAULT_HEIGHT_CM),
        hrv=_as_float(hrv, default=DEFAULT_HRV) if hrv is not None else None,
    )


def build_feature_vector(data: RiskInferenceInput) -> tuple[float, ...]:
    height_m = _normalize_height_m(_as_float(data.height))
    weight_kg = _as_float(data.weight, default=DEFAULT_WEIGHT_KG)
    hrv = _as_float(data.hrv, default=DEFAULT_HRV) if data.hrv is not None else DEFAULT_HRV
    sys_bp = _as_float(data.sys_bp)
    dia_bp = _as_float(data.dia_bp)

    pulse_pressure = sys_bp - dia_bp
    bmi = weight_kg / (height_m * height_m)
    map_val = (sys_bp + 2.0 * dia_bp) / 3.0

    return (
        _as_float(data.heart_rate),
        _as_float(data.resp_rate),
        _as_float(data.body_temp),
        _as_float(data.spo2),
        sys_bp,
        dia_bp,
        _as_float(data.age, default=DEFAULT_AGE),
        _normalize_gender(data.gender),
        weight_kg,
        height_m,
        hrv,
        pulse_pressure,
        bmi,
        map_val,
    )


def _load_onnx_session(model_dir: Path) -> tuple[Any | None, str | None]:
    if ort is None:
        return None, "onnxruntime is not installed"

    model_path = model_dir / ONNX_MODEL_FILENAME
    if not model_path.exists():
        return None, f"missing model file: {model_path}"

    try:
        session = ort.InferenceSession(str(model_path), providers=["CPUExecutionProvider"])
        return session, None
    except Exception as error:  # pragma: no cover - runtime safety
        return None, f"failed to load ONNX model: {error}"


def _load_lightgbm_model(model_dir: Path) -> tuple[Any | None, str | None]:
    model_path = model_dir / LIGHTGBM_MODEL_FILENAME
    if not model_path.exists():
        return None, f"missing model file: {model_path}"

    if joblib is None or lgb is None:
        return None, "lightgbm/joblib is not installed"

    try:
        model = joblib.load(model_path)
        return model, None
    except Exception as error:  # pragma: no cover - runtime safety
        return None, f"failed to load LightGBM model: {error}"


@lru_cache(maxsize=1)
def load_model_bundle() -> ModelBundle:
    model_dir = _resolve_model_dir()
    with _MODEL_LOCK:
        onnx_session, onnx_error = _load_onnx_session(model_dir)
        lightgbm_model, lightgbm_error = _load_lightgbm_model(model_dir)
    return ModelBundle(
        model_dir=model_dir,
        onnx_session=onnx_session,
        lightgbm_model=lightgbm_model,
        onnx_error=onnx_error,
        lightgbm_error=lightgbm_error,
    )


def clear_model_cache() -> None:
    load_model_bundle.cache_clear()


def get_model_status() -> dict[str, Any]:
    bundle = load_model_bundle()
    return {
        "model_dir": str(bundle.model_dir),
        "onnx_ready": bundle.onnx_session is not None,
        "lightgbm_ready": bundle.lightgbm_model is not None,
        "onnx_error": bundle.onnx_error,
        "lightgbm_error": bundle.lightgbm_error,
    }


def _extract_label_and_confidence(outputs: Sequence[Any]) -> tuple[int, float]:
    if not outputs:
        return 2, 0.0

    first_output = outputs[0]

    if np is not None and isinstance(first_output, np.ndarray):
        array = first_output
        if array.ndim == 0:
            label_id = int(array.item())
            return label_id, 1.0

        if array.ndim == 1:
            probabilities = _normalize_probability_vector(array.tolist())
            label_id = int(max(range(len(probabilities)), key=probabilities.__getitem__))
            return label_id, float(probabilities[label_id])

        if array.ndim >= 2:
            row = array[0].tolist()
            probabilities = _normalize_probability_vector(row)
            label_id = int(max(range(len(probabilities)), key=probabilities.__getitem__))
            return label_id, float(probabilities[label_id])

    if isinstance(first_output, (list, tuple)):
        if first_output and isinstance(first_output[0], (list, tuple)):
            probabilities = _normalize_probability_vector([float(value) for value in first_output[0]])
            label_id = int(max(range(len(probabilities)), key=probabilities.__getitem__))
            return label_id, float(probabilities[label_id])

        numeric = [float(value) for value in first_output]
        if len(numeric) == 1:
            label_id = int(round(numeric[0]))
            return label_id, 1.0
        probabilities = _normalize_probability_vector(numeric)
        label_id = int(max(range(len(probabilities)), key=probabilities.__getitem__))
        return label_id, float(probabilities[label_id])

    try:
        label_id = int(first_output)
        return label_id, 1.0
    except (TypeError, ValueError):
        return 2, 0.0


def _predict_with_onnx(feature_vector: Sequence[float], bundle: ModelBundle) -> RiskInferenceResult | None:
    session = bundle.onnx_session
    if session is None:
        return None

    try:
        input_name = session.get_inputs()[0].name
        model_input: Any
        if np is not None:
            model_input = np.asarray([list(feature_vector)], dtype=np.float32)
        else:
            model_input = [list(feature_vector)]
        outputs = session.run(None, {input_name: model_input})
        label_id, confidence = _extract_label_and_confidence(outputs)
        label = LABEL_MAP.get(label_id, "medium")
        score = round(confidence * 100.0, 2)
        return RiskInferenceResult(
            label_id=label_id,
            label=label,
            score=score,
            confidence=round(confidence, 4),
            backend="onnx",
            feature_vector=tuple(float(value) for value in feature_vector),
        )
    except Exception as error:  # pragma: no cover - runtime safety
        return RiskInferenceResult(
            label_id=2,
            label=LABEL_MAP[2],
            score=0.0,
            confidence=0.0,
            backend="onnx",
            feature_vector=tuple(float(value) for value in feature_vector),
            fallback_reason=f"ONNX inference failed: {error}",
        )


def _predict_with_lightgbm(feature_vector: Sequence[float], bundle: ModelBundle) -> RiskInferenceResult | None:
    model = bundle.lightgbm_model
    if model is None:
        return None

    try:
        matrix: Any
        if np is not None:
            matrix = np.asarray([list(feature_vector)], dtype=float)
        else:
            matrix = [list(feature_vector)]

        if hasattr(model, "predict_proba"):
            raw = model.predict_proba(matrix)
            if np is not None and isinstance(raw, np.ndarray):
                row = raw[0].tolist() if raw.ndim > 1 else raw.tolist()
            elif isinstance(raw, (list, tuple)):
                row = raw[0] if raw and isinstance(raw[0], (list, tuple)) else raw
            else:
                row = [float(raw)]
            probabilities = _normalize_probability_vector([float(value) for value in row])
            label_id = int(max(range(len(probabilities)), key=probabilities.__getitem__))
            confidence = float(probabilities[label_id])
        else:
            raw = model.predict(matrix)
            if np is not None and isinstance(raw, np.ndarray):
                values = raw.flatten().tolist()
            elif isinstance(raw, (list, tuple)):
                values = list(raw)
            else:
                values = [raw]

            if len(values) == 1:
                label_id = int(round(float(values[0])))
                confidence = 1.0
            else:
                probabilities = _normalize_probability_vector([float(value) for value in values])
                label_id = int(max(range(len(probabilities)), key=probabilities.__getitem__))
                confidence = float(probabilities[label_id])

        label = LABEL_MAP.get(label_id, "medium")
        score = round(confidence * 100.0, 2)
        return RiskInferenceResult(
            label_id=label_id,
            label=label,
            score=score,
            confidence=round(confidence, 4),
            backend="lightgbm",
            feature_vector=tuple(float(value) for value in feature_vector),
        )
    except Exception as error:  # pragma: no cover - runtime safety
        return RiskInferenceResult(
            label_id=2,
            label=LABEL_MAP[2],
            score=0.0,
            confidence=0.0,
            backend="lightgbm",
            feature_vector=tuple(float(value) for value in feature_vector),
            fallback_reason=f"LightGBM inference failed: {error}",
        )


def _fallback_risk_result(feature_vector: Sequence[float], reason: str) -> RiskInferenceResult:
    (
        heart_rate,
        resp_rate,
        body_temp,
        spo2,
        sys_bp,
        dia_bp,
        _age,
        _gender,
        _weight,
        _height,
        hrv,
        pulse_pressure,
        bmi,
        map_val,
    ) = feature_vector

    emergency_flags = 0
    warning_flags = 0

    if heart_rate >= 130 or heart_rate <= 40:
        emergency_flags += 1
    elif heart_rate >= 100 or heart_rate <= 55:
        warning_flags += 1

    if resp_rate >= 30 or resp_rate <= 8:
        emergency_flags += 1
    elif resp_rate >= 24 or resp_rate <= 12:
        warning_flags += 1

    if body_temp >= 39.0 or body_temp <= 35.0:
        emergency_flags += 1
    elif body_temp >= 38.0 or body_temp <= 36.0:
        warning_flags += 1

    if spo2 < 90.0:
        emergency_flags += 1
    elif spo2 < 95.0:
        warning_flags += 1

    if sys_bp >= 180.0 or sys_bp <= 80.0:
        emergency_flags += 1
    elif sys_bp >= 140.0 or sys_bp <= 90.0:
        warning_flags += 1

    if dia_bp >= 120.0 or dia_bp <= 50.0:
        emergency_flags += 1
    elif dia_bp >= 95.0 or dia_bp <= 60.0:
        warning_flags += 1

    if map_val >= 130.0 or map_val <= 55.0:
        emergency_flags += 1
    elif map_val >= 110.0 or map_val <= 65.0:
        warning_flags += 1

    if pulse_pressure >= 100.0 or pulse_pressure <= 20.0:
        warning_flags += 1

    if bmi >= 40.0 or bmi <= 16.0:
        warning_flags += 1

    if hrv <= 20.0:
        warning_flags += 1

    if emergency_flags >= 2 or (spo2 < 92.0 and heart_rate >= 130.0):
        label_id = 1
        score = min(100.0, 70.0 + emergency_flags * 10.0)
        confidence = min(0.99, 0.75 + emergency_flags * 0.05)
    elif warning_flags >= 1:
        label_id = 2
        score = min(100.0, 40.0 + warning_flags * 8.0)
        confidence = min(0.90, 0.55 + warning_flags * 0.05)
    else:
        label_id = 0
        score = max(0.0, 18.0 - warning_flags * 2.0)
        confidence = 0.85

    return RiskInferenceResult(
        label_id=label_id,
        label=LABEL_MAP[label_id],
        score=round(score, 2),
        confidence=round(confidence, 4),
        backend="rule_based",
        feature_vector=tuple(float(value) for value in feature_vector),
        fallback_reason=reason,
    )


def infer_risk(
    data: RiskInferenceInput | Mapping[str, Any],
    backend: Literal["auto", "onnx", "lightgbm", "rule_based"] = "auto",
) -> RiskInferenceResult:
    if isinstance(data, Mapping):
        data = coerce_risk_input(data)

    feature_vector = build_feature_vector(data)
    bundle = load_model_bundle()

    if backend == "rule_based":
        return _fallback_risk_result(feature_vector, "rule_based backend requested")

    if backend in {"auto", "onnx"}:
        result = _predict_with_onnx(feature_vector, bundle)
        if result is not None and result.fallback_reason is None:
            return result
        if backend == "onnx" and result is not None:
            return result

    if backend in {"auto", "lightgbm"}:
        result = _predict_with_lightgbm(feature_vector, bundle)
        if result is not None and result.fallback_reason is None:
            return result
        if backend == "lightgbm" and result is not None:
            return result

    if backend == "onnx":
        reason = bundle.onnx_error or "ONNX backend unavailable"
        return _fallback_risk_result(feature_vector, reason)

    if backend == "lightgbm":
        reason = bundle.lightgbm_error or "LightGBM backend unavailable"
        return _fallback_risk_result(feature_vector, reason)

    reasons = [reason for reason in (bundle.onnx_error, bundle.lightgbm_error) if reason]
    reason = "; ".join(reasons) if reasons else "no model backend available"
    return _fallback_risk_result(feature_vector, reason)


def describe_feature_vector(data: RiskInferenceInput | Mapping[str, Any]) -> dict[str, float]:
    if isinstance(data, Mapping):
        data = coerce_risk_input(data)

    feature_vector = build_feature_vector(data)
    return {
        name: float(value)
        for name, value in zip(FEATURE_ORDER, feature_vector, strict=True)
    }


__all__ = [
    "FEATURE_ORDER",
    "LABEL_MAP",
    "MODEL_BACKENDS",
    "RiskInferenceInput",
    "RiskInferenceResult",
    "build_feature_vector",
    "clear_model_cache",
    "coerce_risk_input",
    "describe_feature_vector",
    "get_model_status",
    "infer_risk",
    "load_model_bundle",
]
