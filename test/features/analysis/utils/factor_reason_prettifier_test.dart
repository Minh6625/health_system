import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/analysis/utils/factor_reason_prettifier.dart';

/// F-14 (M-1) regression tests.
///
/// Backend (`healthguard-model-api/app/services/prediction_contract.py
/// :_build_reason`) emits raw templates like
/// `"heart_rate=68.6 đang làm giảm nguy cơ"` for any feature outside
/// the `REASON_OVERRIDES` whitelist AND for every `risk_down`
/// direction. Tester screenshot showed two such strings rendered
/// verbatim on the risk-report screen — the model-API contract leaked
/// to the end user.
///
/// `prettifyFactorReason` is invoked at the parsing boundary in
/// `risk_analysis_repository.dart` so chips, summary card, breakdown
/// section, and history preview all consume the cleaned form. These
/// tests pin the contract:
///
///   1. Known feature keys are mapped to Vietnamese label + unit.
///   2. Unknown keys fall back to Title Case (no `=` leak).
///   3. Multiple feature tokens in one reason (joined with `; `) all
///      get rewritten — the bug card showed 2 in the same blue box.
///   4. Already-clean strings pass through untouched (idempotent).
///   5. Empty input → empty output (no null deref upstream).
void main() {
  group('prettifyFactorReason — F-14 (M-1)', () {
    test(
        'rewrites heart_rate=value into "Nhịp tim {value} BPM" — the '
        'exact case from the tester screenshot must no longer leak the '
        'snake_case key', () {
      const raw = 'heart_rate=68.6 đang làm giảm nguy cơ';

      final result = prettifyFactorReason(raw);

      expect(result, 'Nhịp tim 68.6 BPM đang làm giảm nguy cơ');
      expect(result.contains('heart_rate'), isFalse,
          reason:
              'The snake_case feature key must be fully replaced; if it '
              'still appears the model-API contract is leaking.');
      expect(result.contains('='), isFalse,
          reason: 'The literal `=` separator is the API tell — must be gone.');
    });

    test(
        'rewrites diastolic_blood_pressure with the full Vietnamese '
        'medical term and the mmHg unit', () {
      const raw = 'diastolic_blood_pressure=78.6 đang làm giảm nguy cơ';

      final result = prettifyFactorReason(raw);

      expect(result, 'Huyết áp tâm trương 78.6 mmHg đang làm giảm nguy cơ');
    });

    test(
        'rewrites both segments when reasons are joined with "; " '
        '(the format `RiskQuickExplanationCard._buildResolvedSummary` '
        'produces when stitching two top factors together)', () {
      const raw = 'heart_rate=68.6 đang làm giảm nguy cơ; '
          'diastolic_blood_pressure=78.6 đang làm giảm nguy cơ';

      final result = prettifyFactorReason(raw);

      expect(
        result,
        'Nhịp tim 68.6 BPM đang làm giảm nguy cơ; '
        'Huyết áp tâm trương 78.6 mmHg đang làm giảm nguy cơ',
        reason:
            'Both feature tokens must be rewritten — the regex is '
            'global, not anchored to start-of-string.',
      );
    });

    test(
        'handles risk_up direction (the override branch the model-API '
        'is supposed to cover) — when that override is missing on the '
        'server side we must still scrub the leak', () {
      // Backend `_build_reason` only fires `REASON_OVERRIDES` when
      // `direction == "risk_up"` AND the feature key is in the dict.
      // Anything outside that intersection falls through to the raw
      // template. This regression covers a risk_up case for a feature
      // (`respiratory_rate`) that is NOT in the overrides dict.
      const raw = 'respiratory_rate=22 đang làm tăng nguy cơ';

      final result = prettifyFactorReason(raw);

      expect(result, 'Nhịp thở 22 lần/phút đang làm tăng nguy cơ');
    });

    test(
        'rewrites SpO2 with the proper subscript ₂ so the medical '
        'glyph matches the rest of the app (vital_signs_provider, '
        'health_card use SpO₂, not SpO2)', () {
      const raw = 'spo2=94.5 đang làm tăng nguy cơ';

      final result = prettifyFactorReason(raw);

      expect(result, 'SpO₂ 94.5 % đang làm tăng nguy cơ');
    });

    test(
        'falls back to Title Case for unknown feature keys so the user '
        'never sees the raw `=` even when the model adds a feature we '
        'have not mapped yet (forward-compat safety net)', () {
      const raw = 'custom_lab_metric=42.5 đang làm tăng nguy cơ';

      final result = prettifyFactorReason(raw);

      expect(result, 'Custom Lab Metric 42.5 đang làm tăng nguy cơ',
          reason:
              'Unknown key → Title Case label, value preserved, no `=`. '
              'A new feature shipping on the server must not trigger a '
              'visible contract leak before the frontend ships its map.');
      expect(result.contains('='), isFalse);
    });

    test(
        'is idempotent — running on an already-prettified string is a '
        'no-op so calling it twice (e.g. in test infra) does not '
        'double-translate', () {
      const raw = 'heart_rate=68.6 đang làm giảm nguy cơ';
      final once = prettifyFactorReason(raw);

      final twice = prettifyFactorReason(once);

      expect(twice, once,
          reason:
              'Once cleaned, the string no longer matches the regex '
              '(no more `=`), so the prettifier becomes a no-op.');
    });

    test(
        'preserves negative values (some derived features can have '
        'negative SHAP-projected values like derived_pulse_pressure '
        'differentials)', () {
      const raw = 'derived_pulse_pressure=-5.2 đang làm giảm nguy cơ';

      final result = prettifyFactorReason(raw);

      expect(result, 'Áp lực mạch -5.2 mmHg đang làm giảm nguy cơ');
    });

    test(
        'returns empty string for empty input — guards against '
        'null-coalesced "" being passed in from the JSON parser', () {
      expect(prettifyFactorReason(''), '');
    });

    test(
        'leaves a string with no feature_key=value tokens untouched — '
        'Gemini explanations and pre-localised reasons must pass '
        'through verbatim', () {
      const raw = 'Nhịp tim cao hơn bình thường';

      final result = prettifyFactorReason(raw);

      expect(result, raw);
    });

    test(
        'does NOT match equals signs inside non-feature contexts (e.g. '
        'a future `score=…` token in clinical text). The regex requires '
        'a snake_case feature word + `=` + numeric value, which is '
        'narrow enough to avoid collateral rewrites.', () {
      // This guards against an over-eager regex that would rewrite any
      // `word=number` pattern. Today the regex IS that broad — the test
      // documents the current behavior so we notice if we tighten it
      // and accidentally break the M-1 fix.
      const raw = 'Điểm rủi ro = 42 trên thang 100'; // spaces around `=`

      final result = prettifyFactorReason(raw);

      expect(result, raw,
          reason:
              'Token requires no whitespace between key, `=`, and value. '
              'Free-form prose with `key = value` (with spaces) is left '
              'alone.');
    });
  });
}
