import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/emergency/models/sos_event_model.dart';

/// Regression tests pinning the parser to the canonical backend payload
/// produced by `EmergencyService.get_sos_detail` /
/// `backend/app/schemas/emergency.py`. The previous Flutter parser read
/// `time` / `description` keys that did not exist, which crashed the SOS
/// detail screen for every active fall-detection event (Phase 4b).
void main() {
  group('SOSEventModel.fromJson', () {
    Map<String, dynamic> activeFallPayload() => <String, dynamic>{
      'sos_id': 18,
      'patient': <String, dynamic>{
        'user_id': 4,
        'full_name': 'Tran Patient E2E',
        'avatar_url': null,
        'phone': null,
        'date_of_birth': null,
      },
      'trigger_type': 'fall_detected',
      'trigger_time': '2026-04-25T13:51:15.551501Z',
      'status': 'active',
      'location': null,
      'fall_detection_xai': <String, dynamic>{
        'confidence': 0.92,
        'timeline': <Map<String, dynamic>>[
          <String, dynamic>{
            'time_offset': 'T+0s',
            'event': 'Phát hiện sự kiện té ngã (độ tin cậy 92%)',
          },
          <String, dynamic>{
            'time_offset': 'T+0.3s',
            'event': 'Stillness detected',
          },
        ],
        'trigger_reason':
            'Độ tin cậy phát hiện 92% từ mô hình IMU; biến thể: forward_fall',
      },
      'resolution': null,
    };

    test('parses canonical backend payload for active fall SOS', () {
      final model = SOSEventModel.fromJson(activeFallPayload());

      expect(model.id, '18');
      expect(model.status, 'active');
      expect(model.isActive, isTrue);
      expect(model.isFallDetection, isTrue);
      expect(model.patient.id, '4');
      expect(model.patient.name, 'Tran Patient E2E');
      expect(model.patient.phone, '');

      final xai = model.fallDetectionXAI!;
      expect(xai.confidence, closeTo(0.92, 1e-9));
      expect(xai.triggerReason, contains('92%'));
      expect(xai.timeline, hasLength(2));
      expect(xai.timeline.first.time, 'T+0s');
      expect(xai.timeline.first.description, contains('té ngã'));
      expect(xai.timeline[1].time, 'T+0.3s');
      expect(xai.timeline[1].description, 'Stillness detected');
    });

    test('uses empty fallback location when payload omits coordinates', () {
      final model = SOSEventModel.fromJson(activeFallPayload());
      expect(model.location.latitude, isNull);
      expect(model.location.longitude, isNull);
      expect(model.location.address, isNull);
    });

    test('parses resolution fields from canonical resolved payload', () {
      final payload = activeFallPayload()
        ..['status'] = 'resolved'
        ..['fall_detection_xai'] = null
        ..['resolution'] = <String, dynamic>{
          'resolved_at': '2026-04-25T13:41:06.165556Z',
          'resolved_by_name': 'Nguyen Caregiver E2E',
          'resolution_status': 'safe',
          'notes': '[safe] Người chăm sóc xác nhận đã xử lý',
        };

      final model = SOSEventModel.fromJson(payload);
      expect(model.status, 'resolved');
      expect(model.resolution, isNotNull);
      expect(model.resolution!.resolutionStatus, 'safe');
      expect(model.resolution!.resolvedBy, 'Nguyen Caregiver E2E');
      expect(model.resolution!.notes, startsWith('[safe]'));
    });

    test('tolerates legacy timeline keys (time / description)', () {
      // Defensive fallback: if a mock or older client emits the legacy keys,
      // the parser should still succeed instead of crashing.
      final payload = activeFallPayload();
      payload['fall_detection_xai'] = <String, dynamic>{
        'confidence': 0.5,
        'timeline': <Map<String, dynamic>>[
          <String, dynamic>{
            'time': 'T+0s',
            'description': 'Legacy mock entry',
          },
        ],
        'trigger_reason': null,
      };

      final model = SOSEventModel.fromJson(payload);
      final xai = model.fallDetectionXAI!;
      expect(xai.timeline, hasLength(1));
      expect(xai.timeline.first.time, 'T+0s');
      expect(xai.timeline.first.description, 'Legacy mock entry');
      expect(xai.triggerReason, isNull);
    });
  });
}
