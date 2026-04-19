import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/analysis/domain/entities/risk_history_entity.dart';
import 'package:healthguard/features/analysis/domain/entities/risk_report_entity.dart';
import 'package:healthguard/features/analysis/providers/risk_history_provider.dart';
import 'package:healthguard/features/analysis/repositories/risk_analysis_repository.dart';

class _FakeRiskHistoryRepository extends RiskAnalysisRepository {
  _FakeRiskHistoryRepository(this._handler);

  final Future<RiskHistoryEntity> Function({
    required String? profileId,
    required String range,
    required int page,
    required int limit,
  })
  _handler;

  @override
  Future<RiskHistoryEntity> fetchHistory({
    required String? profileId,
    String range = '7d',
    int page = 1,
    int limit = 20,
  }) async {
    return _handler(
      profileId: profileId,
      range: range,
      page: page,
      limit: limit,
    );
  }
}

RiskHistoryEntity _historyPage({
  required String range,
  required int page,
  required bool hasMore,
  List<RiskHistoryItemEntity>? items,
}) {
  return RiskHistoryEntity(
    range: range,
    summary: RiskHistorySummary(
      averageScore: 44.5,
      highestScore: 61.0,
      lowestScore: 31.0,
      deltaVsPreviousPeriod: -6.5,
      trendPoints: const [61, 57, 54, 50, 48, 45, 44],
    ),
    items:
        items ??
        [
          RiskHistoryItemEntity(
            reportId: 21,
            score: 44,
            healthScore: 56.0,
            level: RiskLevel.medium,
            displayStatus: 'Can theo doi',
            analyzedAt: DateTime(2026, 4, 16, 9, 15),
            reasonPreview: 'Chi so suc khoe dang on dinh hon so voi ky truoc.',
            isStale: false,
          ),
        ],
    page: page,
    limit: 20,
    hasMore: hasMore,
  );
}

void main() {
  group('RiskHistoryProvider', () {
    test('loads canonical history payload', () async {
      final provider = RiskHistoryProvider(
        repository: _FakeRiskHistoryRepository(({
          required profileId,
          required range,
          required page,
          required limit,
        }) async {
          return _historyPage(range: range, page: page, hasMore: false);
        }),
      );

      await provider.fetchHistory(
        profileId: 'self',
        range: '7d',
        refresh: true,
      );

      expect(provider.error, isNull);
      expect(provider.summary?.averageScore, 44.5);
      expect(provider.items.single.reportId, 21);
      expect(provider.items.single.level, RiskLevel.medium);
      expect(provider.items.single.displayStatus, 'Can theo doi');
      expect(provider.hasMore, isFalse);
      expect(provider.hasSummary, isTrue);
    });

    test(
      'surfaces load-more failures without clearing existing items',
      () async {
        final provider = RiskHistoryProvider(
          repository: _FakeRiskHistoryRepository(({
            required profileId,
            required range,
            required page,
            required limit,
          }) async {
            if (page == 1) {
              return _historyPage(range: range, page: page, hasMore: true);
            }
            throw Exception('backend timeout');
          }),
        );

        await provider.fetchHistory(
          profileId: 'self',
          range: '7d',
          refresh: true,
        );
        provider.loadMore('self');
        await Future<void>.delayed(Duration.zero);

        expect(provider.items, hasLength(1));
        expect(provider.error, isNull);
        expect(provider.paginationError, contains('backend timeout'));
        expect(provider.hasMore, isTrue);
      },
    );

    test(
      'ignores stale range response after user switches range quickly',
      () async {
        final firstRange = Completer<RiskHistoryEntity>();
        final provider = RiskHistoryProvider(
          repository: _FakeRiskHistoryRepository(({
            required profileId,
            required range,
            required page,
            required limit,
          }) async {
            if (range == '7d') {
              return firstRange.future;
            }
            return _historyPage(
              range: range,
              page: page,
              hasMore: false,
              items: [
                RiskHistoryItemEntity(
                  reportId: 88,
                  score: 31,
                  healthScore: 69.0,
                  level: RiskLevel.low,
                  displayStatus: 'On dinh',
                  analyzedAt: DateTime(2026, 4, 10, 8, 0),
                  reasonPreview: 'Da on dinh tro lai.',
                  isStale: false,
                ),
              ],
            );
          }),
        );

        final pendingFirstLoad = provider.fetchHistory(
          profileId: 'self',
          range: '7d',
          refresh: true,
        );
        await Future<void>.delayed(Duration.zero);

        final switchedRangeLoad = provider.changeRange('self', '30d');
        await switchedRangeLoad;

        firstRange.complete(_historyPage(range: '7d', page: 1, hasMore: false));
        await pendingFirstLoad;
        await Future<void>.delayed(Duration.zero);

        expect(provider.currentRange, '30d');
        expect(provider.items.single.reportId, 88);
        expect(provider.items.single.displayStatus, 'On dinh');
        expect(provider.error, isNull);
        expect(provider.paginationError, isNull);
      },
    );
  });
}
