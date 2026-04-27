import 'package:flutter_test/flutter_test.dart';

import 'package:healthguard/features/fall/models/fall_event.dart';

void main() {
  group('FallEventStatus.fromJson', () {
    test('parses each canonical value', () {
      expect(FallEventStatus.fromJson('detected'), FallEventStatus.detected);
      expect(FallEventStatus.fromJson('dismissed'), FallEventStatus.dismissed);
      expect(FallEventStatus.fromJson('confirmed'), FallEventStatus.confirmed);
      expect(FallEventStatus.fromJson('escalated'), FallEventStatus.escalated);
    });

    test('falls back to unknown for null / unrecognised input', () {
      expect(FallEventStatus.fromJson(null), FallEventStatus.unknown);
      expect(FallEventStatus.fromJson(''), FallEventStatus.unknown);
      // Forward-compat: server adds new status in v2 → mobile binary
      // built against v1 must not crash, just classify as unknown.
      expect(FallEventStatus.fromJson('snoozed'), FallEventStatus.unknown);
    });

    test('isActive is true for detected + unknown only', () {
      expect(FallEventStatus.detected.isActive, isTrue);
      expect(FallEventStatus.unknown.isActive, isTrue);
      expect(FallEventStatus.dismissed.isActive, isFalse);
      expect(FallEventStatus.confirmed.isActive, isFalse);
      expect(FallEventStatus.escalated.isActive, isFalse);
    });

    test('hasEscalated is true for confirmed + escalated only', () {
      expect(FallEventStatus.confirmed.hasEscalated, isTrue);
      expect(FallEventStatus.escalated.hasEscalated, isTrue);
      expect(FallEventStatus.detected.hasEscalated, isFalse);
      expect(FallEventStatus.dismissed.hasEscalated, isFalse);
    });
  });

  group('FallEvent.fromJson', () {
    final completeJson = <String, dynamic>{
      'id': 17,
      'uuid': '11111111-2222-3333-4444-555555555555',
      'device_id': 5,
      'detected_at': '2026-04-27T10:00:00+00:00',
      'confidence': 0.91,
      'model_version': 'v1.0',
      'latitude': 21.0,
      'longitude': 105.8,
      'address': 'Hà Nội',
      'user_notified_at': '2026-04-27T10:00:05+00:00',
      'user_responded_at': null,
      'user_cancelled': false,
      'cancel_reason': null,
      'sos_triggered': false,
      'status': 'detected',
      'features': {'meta': {'request_id': 'rq-abc'}},
    };

    test('happy path: every field round-trips', () {
      final event = FallEvent.fromJson(Map<String, dynamic>.from(completeJson));
      expect(event.id, 17);
      expect(event.uuid, '11111111-2222-3333-4444-555555555555');
      expect(event.deviceId, 5);
      expect(event.confidence, 0.91);
      expect(event.modelVersion, 'v1.0');
      expect(event.latitude, 21.0);
      expect(event.longitude, 105.8);
      expect(event.address, 'Hà Nội');
      expect(event.userCancelled, isFalse);
      expect(event.cancelReason, isNull);
      expect(event.status, FallEventStatus.detected);
      expect(event.features, isA<Map<String, dynamic>>());
    });

    test('missing optional fields default to null / false', () {
      final minimal = <String, dynamic>{
        'id': 1,
        'uuid': '00000000-0000-0000-0000-000000000000',
        'device_id': 9,
        'detected_at': '2026-04-27T10:00:00+00:00',
        'confidence': 0.7,
        'status': 'detected',
      };
      final event = FallEvent.fromJson(minimal);
      expect(event.modelVersion, isNull);
      expect(event.latitude, isNull);
      expect(event.longitude, isNull);
      expect(event.address, isNull);
      expect(event.userNotifiedAt, isNull);
      expect(event.userRespondedAt, isNull);
      expect(event.userCancelled, isFalse);
      expect(event.sosTriggered, isFalse);
      expect(event.features, isNull);
    });

    test('non-map features value is dropped instead of crashing', () {
      final json = Map<String, dynamic>.from(completeJson)
        ..['features'] = 'not a map';
      final event = FallEvent.fromJson(json);
      expect(event.features, isNull);
    });
  });

  group('FallEvent.copyWith', () {
    test('updates only the supplied fields', () {
      final original = FallEvent.fromJson(<String, dynamic>{
        'id': 17,
        'uuid': 'u',
        'device_id': 5,
        'detected_at': '2026-04-27T10:00:00+00:00',
        'confidence': 0.9,
        'status': 'detected',
      });
      final updated = original.copyWith(
        userCancelled: true,
        cancelReason: 'Tôi ổn',
        status: FallEventStatus.dismissed,
      );
      expect(updated.id, original.id);
      expect(updated.confidence, original.confidence);
      expect(updated.userCancelled, isTrue);
      expect(updated.cancelReason, 'Tôi ổn');
      expect(updated.status, FallEventStatus.dismissed);
    });
  });

  group('FallEventList.fromJson', () {
    test('parses items + pagination metadata', () {
      final list = FallEventList.fromJson({
        'items': [
          {
            'id': 1,
            'uuid': 'a',
            'device_id': 1,
            'detected_at': '2026-04-27T10:00:00+00:00',
            'confidence': 0.9,
            'status': 'detected',
          },
          {
            'id': 2,
            'uuid': 'b',
            'device_id': 1,
            'detected_at': '2026-04-27T11:00:00+00:00',
            'confidence': 0.85,
            'status': 'dismissed',
          },
        ],
        'total': 5,
        'limit': 20,
        'offset': 0,
      });
      expect(list.items, hasLength(2));
      expect(list.total, 5);
      expect(list.limit, 20);
      expect(list.offset, 0);
      expect(list.items[0].id, 1);
      expect(list.items[1].status, FallEventStatus.dismissed);
    });

    test('skips non-map items in the array (defensive)', () {
      final list = FallEventList.fromJson({
        'items': [
          {
            'id': 1,
            'uuid': 'a',
            'device_id': 1,
            'detected_at': '2026-04-27T10:00:00+00:00',
            'confidence': 0.9,
            'status': 'detected',
          },
          'this should be skipped',
          null,
        ],
        'total': 1,
        'limit': 20,
        'offset': 0,
      });
      expect(list.items, hasLength(1));
    });

    test('empty + missing metadata yields empty list with defaults', () {
      final list = FallEventList.fromJson({});
      expect(list.isEmpty, isTrue);
      expect(list.total, 0);
    });
  });
}
