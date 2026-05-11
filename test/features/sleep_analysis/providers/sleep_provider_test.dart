import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/sleep_analysis/models/sleep_session.dart';
import 'package:healthguard/features/sleep_analysis/providers/sleep_provider.dart';
import 'package:healthguard/features/sleep_analysis/repositories/sleep_repository.dart';

class _FakeSleepRepository implements SleepRepository {
  _FakeSleepRepository({
    this.latestSleep,
    this.history = const [],
    Map<DateTime, SleepSession?>? sessionsByDate,
    this.throwOnLatest,
    this.throwOnSessionByDate,
  }) : _sessionsByDate = sessionsByDate ?? {};

  final SleepSession? latestSleep;
  final List<SleepSession> history;
  final Map<DateTime, SleepSession?> _sessionsByDate;
  final Object? throwOnLatest;
  final Object? throwOnSessionByDate;
  final List<String?> latestCalls = [];
  final List<String?> historyCalls = [];
  final List<(DateTime, String?)> sessionByDateCalls = [];

  @override
  Future<SleepSession?> getLatestSleep({String? patientId}) async {
    latestCalls.add(patientId);
    if (throwOnLatest != null) {
      throw throwOnLatest!;
    }
    return latestSleep;
  }

  @override
  Future<List<SleepSession>> getSleepHistory({
    required DateTime from,
    required DateTime to,
    String? patientId,
  }) async {
    historyCalls.add(patientId);
    return history;
  }

  @override
  Future<SleepSession?> getSessionByDate(
    DateTime date, {
    String? patientId,
  }) async {
    final normalized = DateTime(date.year, date.month, date.day);
    sessionByDateCalls.add((normalized, patientId));
    if (throwOnSessionByDate != null) {
      throw throwOnSessionByDate!;
    }
    return _sessionsByDate[normalized];
  }
}

SleepSession _session({
  required String id,
  required DateTime sleepDate,
  int qualityScore = 78,
  String qualityLabel = 'GOOD',
  int sleepMinutes = 380,
}) {
  final normalizedDate = DateTime(
    sleepDate.year,
    sleepDate.month,
    sleepDate.day,
  );
  return SleepSession(
    sessionId: id,
    sleepDate: normalizedDate,
    startTime: normalizedDate.subtract(const Duration(hours: 1)),
    endTime: DateTime(
      normalizedDate.year,
      normalizedDate.month,
      normalizedDate.day,
      6,
      30,
    ),
    inBedMinutes: 420,
    sleepMinutes: sleepMinutes,
    awakeMinutes: 40,
    efficiencyRatio: 0.9,
    qualityScore: qualityScore,
    qualityLabel: qualityLabel,
    wakeCount: 1,
    phases: const SleepPhasesDTO(
      lightMinutes: 210,
      deepMinutes: 90,
      remMinutes: 80,
    ),
  );
}

void main() {
  group('SleepProvider', () {
    test(
      'loadAll success populates latest history and selected date',
      () async {
        final latest = _session(id: 'latest', sleepDate: DateTime(2026, 4, 17));
        final repository = _FakeSleepRepository(
          latestSleep: latest,
          history: [
            latest,
            _session(
              id: 'older',
              sleepDate: DateTime(2026, 4, 16),
              sleepMinutes: 360,
            ),
          ],
        );
        final provider = SleepProvider(
          repository: repository,
          now: () => DateTime(2026, 4, 17, 9),
        );

        await provider.loadAll(patientId: '42', forceRefresh: true);

        expect(provider.loadState, SleepLoadState.success);
        expect(provider.latestSession?.sessionId, 'latest');
        expect(provider.selectedSession?.sessionId, 'latest');
        expect(provider.selectedDate, DateTime(2026, 4, 17));
        expect(provider.historyList, hasLength(2));
        expect(repository.latestCalls.single, '42');
        expect(repository.historyCalls.single, '42');
      },
    );

    test(
      'loadAll empty keeps empty state when latest and history are absent',
      () async {
        final provider = SleepProvider(
          repository: _FakeSleepRepository(
            latestSleep: null,
            history: const [],
          ),
        );

        await provider.loadAll(forceRefresh: true);

        expect(provider.loadState, SleepLoadState.empty);
        expect(provider.latestSession, isNull);
        expect(provider.historyList, isEmpty);
      },
    );

    test('loadAll exposes friendly network error copy', () async {
      final provider = SleepProvider(
        repository: _FakeSleepRepository(
          throwOnLatest: Exception('Network error: SocketException'),
        ),
      );

      await provider.loadAll(forceRefresh: true);

      expect(provider.loadState, SleepLoadState.error);
      expect(
        provider.errorMessage,
        'Mất kết nối mạng. Vui lòng kiểm tra Wi-Fi/4G.',
      );
    });

    test(
      'selectDate marks current day before 6am as noDataYet without hitting repository',
      () async {
        final repository = _FakeSleepRepository();
        final provider = SleepProvider(
          repository: repository,
          now: () => DateTime(2026, 4, 17, 5, 30),
        );

        await provider.selectDate(DateTime(2026, 4, 17));

        expect(provider.loadState, SleepLoadState.noDataYet);
        expect(provider.selectedSession, isNull);
        expect(repository.sessionByDateCalls, isEmpty);
      },
    );

    test('setPatient invalidates cached state when profile changes', () async {
      final latest = _session(id: 'latest', sleepDate: DateTime(2026, 4, 17));
      final provider = SleepProvider(
        repository: _FakeSleepRepository(
          latestSleep: latest,
          history: [latest],
        ),
      );

      await provider.loadAll(patientId: '42', forceRefresh: true);
      provider.setPatient('77');

      expect(provider.patientId, '77');
      expect(provider.loadState, SleepLoadState.initial);
      expect(provider.latestSession, isNull);
      expect(provider.selectedSession, isNull);
      expect(provider.historyList, isEmpty);
      expect(provider.errorMessage, isNull);
    });

    test(
      'selectDate and selectHistorySession update canonical selected session',
      () async {
        final latest = _session(id: 'latest', sleepDate: DateTime(2026, 4, 17));
        final older = _session(
          id: 'older',
          sleepDate: DateTime(2026, 4, 16),
          sleepMinutes: 350,
        );
        final repository = _FakeSleepRepository(
          latestSleep: latest,
          history: [latest, older],
          sessionsByDate: {DateTime(2026, 4, 16): older},
        );
        final provider = SleepProvider(repository: repository);

        await provider.loadAll(forceRefresh: true);
        await provider.selectDate(DateTime(2026, 4, 16));

        expect(provider.selectedSession?.sessionId, 'older');
        expect(provider.selectedDate, DateTime(2026, 4, 16));

        provider.selectHistorySession(latest);

        expect(provider.selectedSession?.sessionId, 'latest');
        expect(provider.selectedDate, DateTime(2026, 4, 17));
      },
    );

    test('loadAll prefers an injected report date during bootstrap', () async {
      final latest = _session(id: 'latest', sleepDate: DateTime(2026, 4, 17));
      final older = _session(
        id: 'older',
        sleepDate: DateTime(2026, 4, 16),
        sleepMinutes: 350,
      );
      final repository = _FakeSleepRepository(
        latestSleep: latest,
        history: [latest, older],
      );
      final provider = SleepProvider(repository: repository);

      await provider.loadAll(
        forceRefresh: true,
        preferredDate: DateTime(2026, 4, 16, 22),
      );

      expect(provider.loadState, SleepLoadState.success);
      expect(provider.selectedSession?.sessionId, 'older');
      expect(provider.selectedDate, DateTime(2026, 4, 16));
      expect(repository.sessionByDateCalls, isEmpty);
    });

    test(
      'loadAll prefers noDataYet over stale fallback data for current day before 6am',
      () async {
        final latest = _session(id: 'latest', sleepDate: DateTime(2026, 4, 17));
        final provider = SleepProvider(
          repository: _FakeSleepRepository(
            latestSleep: latest,
            history: [latest],
          ),
          now: () => DateTime(2026, 4, 18, 5, 30),
        );

        await provider.loadAll(
          forceRefresh: true,
          preferredDate: DateTime(2026, 4, 18),
        );

        expect(provider.loadState, SleepLoadState.noDataYet);
        expect(provider.selectedSession, isNull);
        expect(provider.selectedDate, DateTime(2026, 4, 18));
      },
    );

    test(
      'selectDate failure preserves current session and exposes a date error banner message',
      () async {
        final latest = _session(id: 'latest', sleepDate: DateTime(2026, 4, 17));
        final provider = SleepProvider(
          repository: _FakeSleepRepository(
            latestSleep: latest,
            history: [latest],
            throwOnSessionByDate: Exception('Network error: SocketException'),
          ),
        );

        await provider.loadAll(forceRefresh: true);
        await provider.selectDate(DateTime(2026, 4, 16));

        expect(provider.loadState, SleepLoadState.success);
        expect(provider.selectedSession?.sessionId, 'latest');
        expect(provider.selectedDate, DateTime(2026, 4, 17));
        expect(
          provider.dateErrorMessage,
          'Mất kết nối mạng. Vui lòng kiểm tra Wi-Fi/4G.',
        );
      },
    );
  });
}
