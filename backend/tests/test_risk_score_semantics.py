from app.services.risk_inference_service import (
    canonicalize_risk_level,
    derive_health_level,
    derive_health_score,
    normalize_risk_score,
)


class TestRiskScoreSemantics:
    def test_canonicalize_maps_legacy_levels(self) -> None:
        assert canonicalize_risk_level("moderate") == "medium"
        assert canonicalize_risk_level("high") == "medium"
        assert canonicalize_risk_level("critical") == "critical"
        assert canonicalize_risk_level("low") == "low"

    def test_model_backends_use_label_confidence_bands(self) -> None:
        assert normalize_risk_score(level="low", confidence=0.90, backend="onnx") == 3.3
        assert normalize_risk_score(level="medium", confidence=0.50, backend="lightgbm") == 50.0
        assert normalize_risk_score(level="critical", confidence=0.80, backend="onnx") == 93.4

    def test_rule_based_scores_stay_within_canonical_band(self) -> None:
        assert normalize_risk_score(level="low", raw_score=18, backend="rule_based") == 18.0
        assert normalize_risk_score(level="medium", raw_score=80, backend="rule_based") == 66.0
        assert normalize_risk_score(level="critical", raw_score=40, backend="rule_based") == 67.0

    def test_health_fields_are_inverse_of_risk_score(self) -> None:
        assert derive_health_score(24.5) == 75.5
        assert derive_health_level("low") == "stable"
        assert derive_health_level("medium") == "watch"
        assert derive_health_level("critical") == "critical"
