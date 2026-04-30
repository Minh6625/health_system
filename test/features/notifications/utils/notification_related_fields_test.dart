import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/notifications/utils/notification_vital_insight.dart';

/// F-13 (M-3) regression tests for `buildNotificationRelatedFields`.
///
/// Tester screenshot for `NotificationDetailScreen` showed the
/// "Chỉ số và thông tin liên quan" card rendering English snake_case
/// labels ("Device id", "Risk level", "Risk score id", "Escalation
/// stage", "Auto escalate after seconds") and untranslated enum
/// values ("medium", "initial"). Worse, `risk_score_id` — an internal
/// DB foreign key — leaked into the UI as "Risk score id: 9".
///
/// These tests pin the new contract:
///   1. Risk-alert specific keys render with Vietnamese labels +
///      localised enum values.
///   2. Internal DB FKs (`risk_score_id` and friends) are filtered
///      out entirely.
///   3. The well-known vitals / fall-event paths still work
///      (regression coverage for the existing behaviour).
void main() {
  group('buildNotificationRelatedFields — F-13 (M-3)', () {
    test(
        'risk-alert payload renders Vietnamese labels for risk_level, '
        'risk_score, escalation_stage, auto_escalate_after_seconds, '
        'device_id — and HIDES risk_score_id (internal FK)', () {
      final item = <String, dynamic>{
        'data': <String, dynamic>{
          'device_id': 1,
          'risk_level': 'medium',
          'risk_score': 32.67,
          'risk_score_id': 9, // internal FK — must NOT appear
          'escalation_stage': 'initial',
          'auto_escalate_after_seconds': 60,
        },
      };

      final fields = buildNotificationRelatedFields(item);
      final byLabel = {for (final e in fields) e.key: e.value};

      // Localised labels + values.
      expect(byLabel['Thiết bị'], '#1');
      expect(byLabel['Mức nguy cơ'], 'Trung bình',
          reason:
              '`medium` must localise to "Trung bình"; "Risk level: '
              'medium" was the exact tester complaint.');
      expect(byLabel['Điểm nguy cơ'], '32.67',
          reason:
              'Numeric risk score keeps 2 decimals when fractional, '
              '0 when integer (avoids "32.0" eyesore).');
      expect(byLabel['Giai đoạn'], 'Mới phát sinh',
          reason: '`initial` enum must localise to Vietnamese.');
      expect(byLabel['Tự leo thang sau'], '60 giây',
          reason:
              'Hides the awkward "Auto escalate after seconds: 60" '
              'snake_case fallback by giving the field its own row.');

      // Internal FK suppression.
      expect(byLabel.containsKey('Risk score id'), isFalse,
          reason:
              '`risk_score_id` is a DB FK with no meaning to end '
              'users — must be filtered out before the prettifier '
              'fallback can leak it.');
      expect(
        fields.any((e) => e.value == '9'),
        isFalse,
        reason:
            'The integer FK 9 must not appear under any label since '
            'we hide the field outright.',
      );
    });

    test(
        'risk_level localiser handles every backend bucket (low / '
        'medium / moderate / high / critical) with sensible Vietnamese '
        'words', () {
      const cases = <String, String>{
        'low': 'Nhẹ',
        'medium': 'Trung bình',
        'moderate': 'Trung bình',
        'high': 'Cao',
        'critical': 'Nguy hiểm',
      };

      cases.forEach((raw, expected) {
        final fields = buildNotificationRelatedFields(<String, dynamic>{
          'data': <String, dynamic>{'risk_level': raw},
        });
        final value = fields.firstWhere((e) => e.key == 'Mức nguy cơ').value;
        expect(value, expected, reason: 'risk_level=$raw should map to "$expected"');
      });
    });

    test(
        'escalation_stage localiser covers backend buckets including '
        'aliases (pending → initial bucket, in_progress → escalating '
        'bucket, closed → resolved bucket)', () {
      const cases = <String, String>{
        'initial': 'Mới phát sinh',
        'pending': 'Mới phát sinh',
        'escalating': 'Đang leo thang',
        'in_progress': 'Đang leo thang',
        'resolved': 'Đã xử lý',
        'closed': 'Đã xử lý',
        'cancelled': 'Đã hủy',
        'canceled': 'Đã hủy',
      };

      cases.forEach((raw, expected) {
        final fields = buildNotificationRelatedFields(<String, dynamic>{
          'data': <String, dynamic>{'escalation_stage': raw},
        });
        final value = fields.firstWhere((e) => e.key == 'Giai đoạn').value;
        expect(value, expected, reason: 'escalation_stage=$raw should map to "$expected"');
      });
    });

    test(
        'unknown risk_level / escalation_stage value falls through to '
        'the raw string (defensive — better to show the raw token than '
        'crash or display blank when the backend ships a new bucket)',
        () {
      final fields = buildNotificationRelatedFields(<String, dynamic>{
        'data': <String, dynamic>{
          'risk_level': 'extreme', // not in our switch
          'escalation_stage': 'reopened', // not in our switch
        },
      });
      final byLabel = {for (final e in fields) e.key: e.value};

      expect(byLabel['Mức nguy cơ'], 'extreme');
      expect(byLabel['Giai đoạn'], 'reopened');
    });

    test(
        'all hidden FK keys are filtered (risk_score_id, alert_id, '
        'profile_id, user_id, event_id, notification_id, created_by, '
        'updated_by) — protects against future notification payloads '
        'leaking new FK columns', () {
      final item = <String, dynamic>{
        'data': <String, dynamic>{
          'risk_score_id': 9,
          'alert_id': 12,
          'profile_id': 3,
          'user_id': 42,
          'event_id': 99,
          'notification_id': 5,
          'created_by': 7,
          'updated_by': 11,
          // One legit field so the function returns SOMETHING; if all
          // input is hidden the result is empty and we cannot tell
          // from the assertions whether hiding actually worked.
          'heart_rate': 88,
        },
      };

      final fields = buildNotificationRelatedFields(item);

      expect(fields, hasLength(1),
          reason:
              'Only the heart_rate field should survive — every FK '
              'in the payload is in the hidden set.');
      expect(fields.first.key, 'Nhịp tim');
    });

    test(
        'existing well-known vital fields still render correctly — '
        'regression guard so the M-3 patch does not break the original '
        '"Diễn biến chỉ số" / vital-detail flow', () {
      final item = <String, dynamic>{
        'data': <String, dynamic>{
          'heart_rate': 88,
          'spo2': 96,
          'temperature': 37.2,
          'blood_pressure_sys': 120,
          'blood_pressure_dia': 80,
        },
      };

      final fields = buildNotificationRelatedFields(item);
      final byLabel = {for (final e in fields) e.key: e.value};

      expect(byLabel['Nhịp tim'], '88 BPM');
      expect(byLabel['SpO2'], '96%');
      expect(byLabel['Nhiệt độ'], '37.2°C');
      expect(byLabel['Huyết áp'], '120/80 mmHg');
    });

    test(
        'empty data block returns empty list — guards against null '
        'deref in the screen when a notification has no `data` field',
        () {
      expect(
        buildNotificationRelatedFields(<String, dynamic>{}),
        isEmpty,
      );
      expect(
        buildNotificationRelatedFields(<String, dynamic>{
          'data': <String, dynamic>{},
        }),
        isEmpty,
      );
    });
  });
}
