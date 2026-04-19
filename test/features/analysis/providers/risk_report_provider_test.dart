import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/analysis/domain/entities/risk_report_detail_entity.dart';
import 'package:healthguard/features/analysis/domain/entities/risk_report_entity.dart';
import 'package:healthguard/features/analysis/providers/risk_report_provider.dart';
import 'package:healthguard/features/analysis/repositories/risk_analysis_repository.dart';

class _FakeRiskAnalysisRepository extends RiskAnalysisRepository {
  _FakeRiskAnalysisRepository({required this.report, required this.detail});

  final RiskReportEntity report;
  final RiskReportDetailEntity detail;

  @override
  Future<RiskReportEntity> fetchLatestReport(String? profileId) async => report;

  @override
  Future<RiskReportDetailEntity> fetchReportDetail(
    int reportId,
    String? profileId,
  ) async => detail;
}

void main() {
  test(
    'RiskReportProvider loads latest report and detail from repository',
    () async {
      final repository = _FakeRiskAnalysisRepository(
        report: RiskReportEntity(
          reportId: 12,
          profileId: 'self',
          score: 41,
          level: RiskLevel.medium,
          displayStatus: 'Can theo doi',
          summary: 'Mot vai chi so can theo doi them trong ngay hom nay.',
          analyzedAt: DateTime(2026, 4, 16, 8, 30),
          previousScore: 38,
          trend7d: const [52, 49, 48, 45, 44, 43, 41],
          topFactors: [TopFactor(key: 'heart_rate', label: 'Nhip tim')],
          recommendationPreview: const ['Nghi ngoi va do lai.'],
          confidence: 0.84,
          isStale: false,
        ),
        detail: RiskReportDetailEntity(
          reportId: 12,
          profileId: 'self',
          score: 41,
          level: RiskLevel.medium,
          summary: 'Mot vai chi so can theo doi them trong ngay hom nay.',
          analyzedAt: DateTime(2026, 4, 16, 8, 30),
          breakdown: [
            FactorBreakdown(
              key: 'heart_rate',
              label: 'Nhip tim',
              contributionScore: 1,
              impactLevel: 'medium',
              value: '101',
              unit: 'bpm',
              routeTarget: 'vital_hr',
            ),
          ],
          xaiExplanation: 'Chi so tim mach can theo doi them.',
          recommendations: const ['Nghi ngoi va do lai.'],
          snapshot: SnapshotMetrics(
            heartRate: 101,
            spO2: 96,
            sysBp: 136,
            diaBp: 84,
            bodyTemp: 36.8,
            hrv: 29,
            mapVal: 101,
          ),
        ),
      );
      final provider = RiskReportProvider(repository: repository);

      await provider.fetchLatestReport('self');
      await provider.fetchReportDetail(12, 'self');

      expect(provider.error, isNull);
      expect(provider.report?.reportId, 12);
      expect(provider.report?.level, RiskLevel.medium);
      expect(provider.reportDetail?.snapshot.heartRate, 101);
    },
  );
}
