import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/analysis/domain/entities/risk_history_entity.dart';
import 'package:healthguard/features/analysis/domain/entities/risk_report_entity.dart';
import 'package:healthguard/features/analysis/providers/risk_history_provider.dart';
import 'package:healthguard/features/analysis/repositories/risk_analysis_repository.dart';

class _FakeRiskHistoryRepository extends RiskAnalysisRepository {
  _FakeRiskHistoryRepository(this.history);

  final RiskHistoryEntity history;

  @override
  Future<RiskHistoryEntity> fetchHistory({
    required String? profileId,
    String range = '7d',
    int page = 1,
    int limit = 20,
  }) async {
    return history;
  }
}

void main() {
  test('RiskHistoryProvider loads canonical history payload', () async {
    final provider = RiskHistoryProvider(
      repository: _FakeRiskHistoryRepository(
        RiskHistoryEntity(
          range: '7d',
          summary: RiskHistorySummary(
            averageScore: 44,
            highestScore: 61,
            lowestScore: 31,
            deltaVsPreviousPeriod: -6,
            trendPoints: const [61, 57, 54, 50, 48, 45, 44],
          ),
          items: [
            RiskHistoryItemEntity(
              reportId: 21,
              score: 44,
              level: RiskLevel.medium,
              analyzedAt: DateTime(2026, 4, 16, 9, 15),
              reasonPreview:
                  'Chi so suc khoe dang on dinh hon so voi ky truoc.',
            ),
          ],
          page: 1,
          limit: 20,
          hasMore: false,
        ),
      ),
    );

    await provider.fetchHistory(profileId: 'self', range: '7d', refresh: true);

    expect(provider.error, isNull);
    expect(provider.summary?.averageScore, 44);
    expect(provider.items.single.reportId, 21);
    expect(provider.items.single.level, RiskLevel.medium);
    expect(provider.hasMore, isFalse);
  });
}
