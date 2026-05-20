import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/family/models/recent_alert_item.dart';
import 'package:healthguard/features/family/providers/person_alerts_provider.dart';
import 'package:healthguard/features/family/repositories/family_repository.dart';

class _StubRepository extends FamilyRepository {
  _StubRepository();

  RecentAlertsResponse? successResponse;
  Object? errorToThrow;
  int callCount = 0;
  int? lastPatientId;
  int? lastDays;
  int? lastLimit;

  @override
  Future<RecentAlertsResponse> fetchRecentAlerts(
    int patientUserId, {
    int days = 7,
    int limit = 10,
  }) async {
    callCount++;
    lastPatientId = patientUserId;
    lastDays = days;
    lastLimit = limit;
    if (errorToThrow != null) throw errorToThrow!;
    return successResponse ??
        RecentAlertsResponse(
          items: const <RecentAlertItem>[],
          windowDays: days,
          totalInWindow: 0,
        );
  }
}

RecentAlertItem _alert({String uuid = 'u1'}) {
  return RecentAlertItem(
    id: 1,
    uuid: uuid,
    alertType: RecentAlertType.fallDetected,
    rawAlertType: 'fall_detected',
    severity: RecentAlertSeverity.critical,
    rawSeverity: 'critical',
    title: 'Phát hiện té ngã',
    occurredAt: DateTime.utc(2026, 5, 20, 9, 30),
  );
}

void main() {
  group('PersonAlertsProvider', () {
    test('starts in initial status', () {
      final provider = PersonAlertsProvider(repository: _StubRepository());
      expect(provider.status, PersonAlertsStatus.initial);
      expect(provider.items, isEmpty);
      expect(provider.isLoading, isFalse);
    });

    test('rejects non-numeric profileId without hitting repository', () async {
      final repo = _StubRepository();
      final provider = PersonAlertsProvider(repository: repo);

      await provider.load('not-a-number');

      expect(provider.status, PersonAlertsStatus.error);
      expect(repo.callCount, 0);
      expect(provider.errorMessage, isNotNull);
    });

    test('granted: empty list keeps status granted (not error)', () async {
      final repo = _StubRepository()
        ..successResponse = RecentAlertsResponse(
          items: const <RecentAlertItem>[],
          windowDays: 7,
          totalInWindow: 0,
        );
      final provider = PersonAlertsProvider(repository: repo);

      await provider.load('42');

      expect(provider.status, PersonAlertsStatus.granted);
      expect(provider.items, isEmpty);
      expect(provider.windowDays, 7);
      expect(repo.lastPatientId, 42);
      expect(repo.lastDays, 7);
      expect(repo.lastLimit, 10);
    });

    test('granted: populated list propagates items', () async {
      final repo = _StubRepository()
        ..successResponse = RecentAlertsResponse(
          items: <RecentAlertItem>[_alert(uuid: 'u1'), _alert(uuid: 'u2')],
          windowDays: 7,
          totalInWindow: 2,
        );
      final provider = PersonAlertsProvider(repository: repo);

      await provider.load('42');

      expect(provider.status, PersonAlertsStatus.granted);
      expect(provider.items.length, 2);
      expect(provider.isReady, isTrue);
    });

    test('permission denied maps to permissionDenied status', () async {
      final repo = _StubRepository()
        ..errorToThrow = const RecentAlertsPermissionDeniedException(
          'You do not have permission',
        );
      final provider = PersonAlertsProvider(repository: repo);

      await provider.load('42');

      expect(provider.status, PersonAlertsStatus.permissionDenied);
      expect(provider.items, isEmpty);
      expect(provider.isPermissionDenied, isTrue);
    });

    test('generic exception lands in error state with message', () async {
      final repo = _StubRepository()
        ..errorToThrow = Exception('boom');
      final provider = PersonAlertsProvider(repository: repo);

      await provider.load('42');

      expect(provider.status, PersonAlertsStatus.error);
      expect(provider.hasError, isTrue);
      expect(provider.errorMessage, contains('boom'));
    });

    test('reload preserves the windowDays from the previous response',
        () async {
      final repo = _StubRepository()
        ..successResponse = RecentAlertsResponse(
          items: const <RecentAlertItem>[],
          windowDays: 14,
          totalInWindow: 0,
        );
      final provider = PersonAlertsProvider(repository: repo);

      await provider.load('42', days: 14);
      expect(provider.windowDays, 14);

      await provider.reload('42');

      expect(repo.callCount, 2);
      expect(repo.lastDays, 14);
    });
  });
}
