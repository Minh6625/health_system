-- =============================================================================
-- 20260519_seed_rules_config_thresholds.sql
-- =============================================================================
-- Seed clinical thresholds (rules_config v2.0.0) into system_settings as the
-- single source of truth for backend risk pipeline + mobile UI classifiers.
--
-- Two rows are upserted:
--   1. clinical_rules_thresholds   — nested rules_config shape served by
--                                    GET /api/v1/mobile/settings/thresholds
--   2. vitals_default_thresholds   — legacy flat shape consumed by
--                                    SettingsService.get_vitals_daytime_thresholds
--
-- These rows are upserted (ON CONFLICT DO UPDATE) so re-running this migration
-- after a manual edit via the admin website overrides the stale row.
--
-- Source: Iot_Simulator_clean/pre_model_trigger/health_rules/rules_config.json
-- Pinned version: 2.0.0
-- =============================================================================

-- Nested clinical-rules shape (canonical, mobile + sim consume).
INSERT INTO system_settings (
    setting_key,
    setting_group,
    setting_value,
    description,
    is_editable
) VALUES (
    'clinical_rules_thresholds',
    'clinical',
    '{
      "version": "2.0.0",
      "vitals": {
        "heart_rate": {"urgent_low": 40, "send_low": 50, "watch_high": 110, "send_high": 130, "urgent_high": 131},
        "spo2": {"urgent_low": 90, "send_low": 94, "watch_low": 95},
        "body_temp": {"urgent_low": 35.0, "send_low": 36.0, "watch_high": 37.5, "send_high": 39.0, "urgent_high": 39.1},
        "resp_rate": {"urgent_low": 8, "watch_high": 20, "send_high": 24, "urgent_high": 25},
        "sys_bp": {"urgent_low": 90, "send_low": 100, "watch_high": 139, "send_high": 140, "urgent_high": 180},
        "dia_bp": {"watch_high": 89, "send_high": 90, "urgent_high": 120}
      },
      "fall_confidence_threshold": 0.5,
      "model_thresholds": {
        "health": {"warning_at": 0.35, "high_risk_true_at": 0.5, "critical_at": 0.65},
        "fall": {"fall_true_at": 0.5, "warning_at": 0.6, "critical_at": 0.85},
        "sleep": {"critical_below": 50, "poor_below": 60, "fair_below": 75, "good_below": 85}
      }
    }'::jsonb,
    'Clinical rules config (rules_config v2.0.0). Single source of truth for vital thresholds + model bands. Edited via admin website /settings.',
    TRUE
)
ON CONFLICT (setting_key) DO UPDATE SET
    setting_group = EXCLUDED.setting_group,
    setting_value = EXCLUDED.setting_value,
    description = EXCLUDED.description,
    is_editable = EXCLUDED.is_editable,
    updated_at = NOW();

-- Legacy flat shape used by SettingsService.get_vitals_daytime_thresholds.
-- Values projected from clinical_rules_thresholds for back-compat with
-- risk_alert_service. Bumped to align with rules_config v2.0.0 (e.g.
-- hr_critical_min 50 -> 40, urgent path matches HR_VERY_LOW threshold).
INSERT INTO system_settings (
    setting_key,
    setting_group,
    setting_value,
    description,
    is_editable
) VALUES (
    'vitals_default_thresholds',
    'vitals',
    '{
      "hr_critical_min": 40,
      "hr_critical_max": 131,
      "hr_warning_min": 50,
      "hr_warning_max": 110,
      "spo2_critical": 90,
      "spo2_warning": 94,
      "rr_critical_min": 8,
      "rr_critical_max": 25,
      "bp_sys_critical": 180,
      "bp_dia_critical": 120,
      "bp_sys_warning": 140,
      "bp_dia_warning": 90
    }'::jsonb,
    'Daytime vitals thresholds (legacy flat shape projected from clinical_rules_thresholds v2.0.0). Used by risk_alert_service.',
    TRUE
)
ON CONFLICT (setting_key) DO UPDATE SET
    setting_group = EXCLUDED.setting_group,
    setting_value = EXCLUDED.setting_value,
    description = EXCLUDED.description,
    is_editable = EXCLUDED.is_editable,
    updated_at = NOW();

-- Sleep-context overrides (apnea / OSA gates). Mirrors rules_config sleep
-- context with the same shape as vitals_default_thresholds plus 3 sleep-only
-- keys (osa_alert_spo2_threshold, nocturnal_tachy_hr, apnea_rr_threshold).
INSERT INTO system_settings (
    setting_key,
    setting_group,
    setting_value,
    description,
    is_editable
) VALUES (
    'vitals_sleep_thresholds',
    'vitals',
    '{
      "hr_critical_min": 38,
      "hr_critical_max": 100,
      "hr_warning_min": 42,
      "hr_warning_max": 90,
      "spo2_critical": 85,
      "spo2_warning": 90,
      "rr_critical_min": 6,
      "rr_critical_max": 25,
      "bp_sys_critical": 180,
      "bp_dia_critical": 120,
      "bp_sys_warning": 160,
      "bp_dia_warning": 100,
      "osa_alert_spo2_threshold": 88,
      "nocturnal_tachy_hr": 120,
      "apnea_rr_threshold": 6
    }'::jsonb,
    'Sleep-context vitals thresholds (rules_config v2.0.0 + OSA/apnea gates). Used by SettingsService.get_vitals_sleep_thresholds.',
    TRUE
)
ON CONFLICT (setting_key) DO UPDATE SET
    setting_group = EXCLUDED.setting_group,
    setting_value = EXCLUDED.setting_value,
    description = EXCLUDED.description,
    is_editable = EXCLUDED.is_editable,
    updated_at = NOW();
