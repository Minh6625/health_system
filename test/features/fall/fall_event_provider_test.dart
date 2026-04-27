import 'package:flutter_test/flutter_test.dart';

import 'package:healthguard/features/fall/models/fall_event.dart';
import 'package:healthguard/features/fall/providers/fall_event_provider.dart';
import 'package:healthguard/features/fall/repositories/fall_event_repository.dart';

class _FakeRepository implements FallEventRepository {
  _FakeRepository({
    this.listFn,
    this.getFn,
    this.dismissFn,
  });

  Future<FallEventList> Function({int limit, int offset, String? patientId})?
      listFn;
  Future<FallEvent?> Function(int id, {String? patientId})? getFn;
  Future<FallEvent?> Function(int id, {String? reason, String? patientId})?
      dismissFn;

  int listCalls = 0;
  int dismissCalls = 0;

  @override
  Future<FallEventList> listEvents({
    int limit = 20,
    int offset = 0,
    String? patientId,
  }) {
    listCalls++;
    final fn = listFn;
    if (fn != null) {
      return fn(limit: limit, offset: offset, patientId: patientId);
    }
    return Future.value(
      FallEventList(items: const [], total: 0, limit: limit, offset: offset),
    );
  }

  @override
  Future<FallEvent?> getEvent(int id, {String? patientId}) {
    final fn = getFn;
    if (fn != null) return fn(id, patientId: patientId);
    return Future.value(null);
  }

  @override
  Future<FallEvent?> dismiss(int id, {String? reason, String? patientId}) {
    dismissCalls++;
    final fn = dismissFn;
    if (fn != null) return fn(id, reason: reason, patientId: patientId);
    return Future.value(null);
  }
}

FallEvent _stub({
  int id = 17,
  FallEventStatus status = FallEventStatus.detected,
  bool userCancelled = false,
  String? cancelReason,
}) {
  return FallEvent(
    id: id,
    uuid: 'u-$id',
    deviceId: 5,
    detectedAt: DateTime(2026, 4, 27, 10),
    confidence: 0.9,
    status: status,
    userCancelled: userCancelled,
    cancelReason: cancelReason,
  );
}

void main() {
  group('FallEventProvider.refresh', () {
    test('initial → loading → success populates events + totalCount', () async {
      final repo = _FakeRepository(
        listFn: ({limit = 20, offset = 0, patientId}) async {
          return FallEventList(
            items: [_stub(id: 1), _stub(id: 2)],
            total: 5,
            limit: limit,
            offset: offset,
          );
        },
      );
      final provider = FallEventProvider(repository: repo);
      expect(provider.listState, FallEventLoadState.initial);

      await provider.refresh();

      expect(provider.listState, FallEventLoadState.success);
      expect(provider.events, hasLength(2));
      expect(provider.totalCount, 5);
      expect(provider.listErrorMessage, isNull);
    });

    test('empty result transitions to empty state, not success', () async {
      final repo = _FakeRepository(
        listFn: ({limit = 20, offset = 0, patientId}) async {
          return FallEventList(
            items: const [], total: 0, limit: limit, offset: offset,
          );
        },
      );
      final provider = FallEventProvider(repository: repo);

      await provider.refresh();

      expect(provider.listState, FallEventLoadState.empty);
      expect(provider.events, isEmpty);
    });

    test('exception → error state with message; existing events untouched',
        () async {
      // Seed the provider with one event via the test hook.
      final repo = _FakeRepository(
        listFn: ({limit = 20, offset = 0, patientId}) async {
          throw Exception('connection refused');
        },
      );
      final provider = FallEventProvider(repository: repo);
      provider.debugSetEvents([_stub(id: 99)]);
      expect(provider.events, hasLength(1));

      await provider.refresh();

      expect(provider.listState, FallEventLoadState.error);
      expect(provider.listErrorMessage, contains('connection refused'));
      // UX contract: a transient failure must NOT wipe the cached
      // events — the user keeps seeing what we last loaded.
      expect(provider.events, hasLength(1));
      expect(provider.events.first.id, 99);
    });
  });

  group('FallEventProvider.dismiss', () {
    test('returns true and updates the event in place on success',
        () async {
      final repo = _FakeRepository(
        dismissFn: (id, {reason, patientId}) async {
          return _stub(
            id: id,
            status: FallEventStatus.dismissed,
            userCancelled: true,
            cancelReason: reason,
          );
        },
      );
      final provider = FallEventProvider(repository: repo)
        ..debugSetEvents([_stub(id: 17), _stub(id: 18)]);

      final ok = await provider.dismiss(17, reason: 'Tôi ổn');

      expect(ok, isTrue);
      expect(repo.dismissCalls, 1);
      expect(provider.isDismissing, isFalse);
      // Event 17 is updated, 18 untouched.
      final updated = provider.events.firstWhere((e) => e.id == 17);
      expect(updated.status, FallEventStatus.dismissed);
      expect(updated.userCancelled, isTrue);
      expect(updated.cancelReason, 'Tôi ổn');
    });

    test('returns false on 404 (server returns null)', () async {
      final repo = _FakeRepository(
        dismissFn: (id, {reason, patientId}) async => null,
      );
      final provider = FallEventProvider(repository: repo);

      final ok = await provider.dismiss(9999);

      expect(ok, isFalse);
    });

    test('exception sets dismissErrorMessage and returns false', () async {
      final repo = _FakeRepository(
        dismissFn: (id, {reason, patientId}) async {
          throw Exception('500 server error');
        },
      );
      final provider = FallEventProvider(repository: repo);

      final ok = await provider.dismiss(17);

      expect(ok, isFalse);
      expect(provider.dismissErrorMessage, contains('500 server error'));
      expect(provider.isDismissing, isFalse);
    });

    test('isDismissing is true while in flight, false after', () async {
      // Manual completer to control the in-flight window.
      final repo = _FakeRepository(
        dismissFn: (id, {reason, patientId}) async {
          await Future<void>.delayed(const Duration(milliseconds: 1));
          return _stub(id: id, status: FallEventStatus.dismissed);
        },
      );
      final provider = FallEventProvider(repository: repo)
        ..debugSetEvents([_stub(id: 17)]);

      final future = provider.dismiss(17);
      expect(provider.isDismissing, isTrue);

      await future;
      expect(provider.isDismissing, isFalse);
    });
  });

  group('FallEventProvider.latestActiveEvent', () {
    test('returns the first active event in the list', () {
      final provider = FallEventProvider(repository: _FakeRepository())
        ..debugSetEvents([
          _stub(id: 1, status: FallEventStatus.dismissed),
          _stub(id: 2, status: FallEventStatus.detected),  // <- this one
          _stub(id: 3, status: FallEventStatus.detected),
        ]);

      final active = provider.latestActiveEvent;

      expect(active, isNotNull);
      expect(active!.id, 2);
    });

    test('returns null when no active event exists', () {
      final provider = FallEventProvider(repository: _FakeRepository())
        ..debugSetEvents([
          _stub(id: 1, status: FallEventStatus.dismissed),
          _stub(id: 2, status: FallEventStatus.escalated),
        ]);
      expect(provider.latestActiveEvent, isNull);
    });
  });
}
