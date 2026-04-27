import 'package:flutter_test/flutter_test.dart';

import 'package:healthguard/core/notifications/fall_event_handler.dart';
import 'package:healthguard/features/fall/models/fall_event.dart';
import 'package:healthguard/features/fall/repositories/fall_event_repository.dart';

class _StubRepo implements FallEventRepository {
  _StubRepo({this.event, this.throwError = false});

  final FallEvent? event;
  final bool throwError;

  @override
  Future<FallEventList> listEvents({
    int limit = 20,
    int offset = 0,
    String? patientId,
  }) async {
    return FallEventList(items: const [], total: 0, limit: limit, offset: offset);
  }

  @override
  Future<FallEvent?> getEvent(int id, {String? patientId}) async {
    if (throwError) throw Exception('boom');
    return event;
  }

  @override
  Future<FallEvent?> dismiss(int id, {String? reason, String? patientId}) async {
    return null;
  }
}

void main() {
  group('parseFallEventFromPushData', () {
    test('happy path builds a FallEvent stub from the push envelope', () {
      final event = parseFallEventFromPushData({
        'type': 'fall_alert',
        'event_type': 'fall_detected',
        'fall_event_id': '42',
        'fall_event_uuid': '11111111-2222-3333-4444-555555555555',
        'confidence': '0.910',
        'title': 'Phát hiện ngã',
        'body': 'Bạn có ổn không?',
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      });
      expect(event, isNotNull);
      expect(event!.id, 42);
      expect(event.uuid, '11111111-2222-3333-4444-555555555555');
      expect(event.confidence, 0.91);
      expect(event.status, FallEventStatus.detected);
      // Fields the push doesn't carry must default to zero / now.
      expect(event.deviceId, 0);
      expect(event.detectedAt.isUtc, isFalse,
          reason: 'detectedAt should default to local DateTime.now()');
    });

    test('returns null when type is not fall_alert', () {
      final event = parseFallEventFromPushData({
        'type': 'sos_alert',
        'fall_event_id': '42',
        'fall_event_uuid': 'u',
      });
      expect(event, isNull);
    });

    test('returns null when fall_event_id is missing or unparseable', () {
      // Missing.
      expect(
        parseFallEventFromPushData({
          'type': 'fall_alert',
          'fall_event_uuid': 'u',
        }),
        isNull,
      );
      // Not a number.
      expect(
        parseFallEventFromPushData({
          'type': 'fall_alert',
          'fall_event_id': 'not-a-number',
          'fall_event_uuid': 'u',
        }),
        isNull,
      );
    });

    test('returns null when fall_event_uuid is missing / empty', () {
      expect(
        parseFallEventFromPushData({
          'type': 'fall_alert',
          'fall_event_id': '42',
          // No uuid.
        }),
        isNull,
      );
      expect(
        parseFallEventFromPushData({
          'type': 'fall_alert',
          'fall_event_id': '42',
          'fall_event_uuid': '',
        }),
        isNull,
      );
    });

    test('confidence is clamped to [0, 1] and unparseable falls back to 0', () {
      final clamped = parseFallEventFromPushData({
        'type': 'fall_alert',
        'fall_event_id': '1',
        'fall_event_uuid': 'u',
        'confidence': '1.5',  // out of range
      });
      expect(clamped!.confidence, 1.0);

      final negative = parseFallEventFromPushData({
        'type': 'fall_alert',
        'fall_event_id': '1',
        'fall_event_uuid': 'u',
        'confidence': '-0.3',
      });
      expect(negative!.confidence, 0.0);

      final unparseable = parseFallEventFromPushData({
        'type': 'fall_alert',
        'fall_event_id': '1',
        'fall_event_uuid': 'u',
        'confidence': 'high',
      });
      expect(unparseable!.confidence, 0.0);

      final missing = parseFallEventFromPushData({
        'type': 'fall_alert',
        'fall_event_id': '1',
        'fall_event_uuid': 'u',
      });
      expect(missing!.confidence, 0.0);
    });
  });

  group('hydrateFallEvent', () {
    final stub = FallEvent(
      id: 17,
      uuid: 'u',
      deviceId: 0,
      detectedAt: DateTime.now(),
      confidence: 0.5,
      status: FallEventStatus.detected,
    );

    test('returns the freshly-fetched event on success', () async {
      final fresh = FallEvent(
        id: 17,
        uuid: 'u',
        deviceId: 5,
        detectedAt: DateTime.now(),
        confidence: 0.9,
        status: FallEventStatus.detected,
        modelVersion: 'v1.0',
      );
      final repo = _StubRepo(event: fresh);

      final hydrated = await hydrateFallEvent(stub, repository: repo);

      expect(hydrated, isNotNull);
      expect(hydrated!.deviceId, 5);
      expect(hydrated.modelVersion, 'v1.0');
    });

    test('returns null when the row is gone (404)', () async {
      final repo = _StubRepo(event: null);
      final hydrated = await hydrateFallEvent(stub, repository: repo);
      expect(hydrated, isNull);
    });

    test('returns null on transport error rather than throwing', () async {
      final repo = _StubRepo(throwError: true);
      // Best-effort: a network failure must not propagate to the
      // caller — the alert screen continues with the synthetic stub.
      final hydrated = await hydrateFallEvent(stub, repository: repo);
      expect(hydrated, isNull);
    });
  });
}
