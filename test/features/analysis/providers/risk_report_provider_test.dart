import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/analysis/domain/entities/risk_report_detail_entity.dart';
import 'package:healthguard/features/analysis/domain/entities/risk_report_entity.dart';
import 'package:healthguard/features/analysis/providers/risk_report_provider.dart';
import 'package:healthguard/features/analysis/repositories/risk_analysis_repository.dart';

class _FakeRiskAnalysisRepository extends RiskAnalysisRepository {
  _FakeRiskAnalysisRepository({
    this.report,
    this.detail,
    this.latestError,
  });

  final RiskReportEntity? report;
  final RiskReportDetailEntity? detail;
  final Object? latestError;

  @override
  Future<RiskReportEntity> fetchLatestReport(String? profileId) async {
    if (latestError != null) {
      throw latestError!;
    }
    return report!;
  }

  @override
  Future<RiskReportDetailEntity> fetchReportDetail(
    int reportId,
    String? profileId,
  ) async {
    return detail!;
  }
}

void main() {
  group('RiskReportProvider', () {
    test(
      'loads latest report and detail with canonical fields from repository',
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
            isStale: true,
          ),
          detail: RiskReportDetailEntity(
            reportId: 12,
            profileId: 'self',
            score: 41,
            healthScore: 59.0,
            level: RiskLevel.medium,
            displayStatus: 'Can theo doi',
            summary: 'Mot vai chi so can theo doi them trong ngay hom nay.',
            analyzedAt: DateTime(2026, 4, 16, 8, 30),
            previousScore: 38,
            trend7d: const [52, 49, 48, 45, 44, 43, 41],
            breakdown: [
              FactorBreakdown(
                key: 'heart_rate',
                label: 'Nhip tim',
                contributionScore: 0.62,
                impactLevel: 'high',
                value: '101',
                unit: 'bpm',
                routeTarget: 'vital_hr',
              ),
            ],
            xaiExplanation: 'Chi so tim mach can theo doi them.',
            recommendations: const ['Nghi ngoi va do lai.'],
            recommendationPreview: const ['Nghi ngoi va do lai.'],
            topFactors: [TopFactor(key: 'heart_rate', label: 'Nhip tim')],
            snapshot: SnapshotMetrics(
              heartRate: 101,
              spO2: 96,
              sysBp: 136,
              diaBp: 84,
              bodyTemp: 36.8,
              hrv: 29,
              mapVal: 101,
            ),
            confidence: 0.84,
            isStale: true,
          ),
        );
        final provider = RiskReportProvider(repository: repository);

        await provider.fetchLatestReport('self');
        await provider.fetchReportDetail(12, 'self');

        expect(provider.error, isNull);
        expect(provider.report?.reportId, 12);
        expect(provider.report?.level, RiskLevel.medium);
        expect(provider.reportDetail?.snapshot.heartRate, 101);
        expect(provider.reportDetail?.healthScore, 59.0);
        expect(
          provider.reportDetail?.breakdown.single.contributionScore,
          closeTo(0.62, 0.0001),
        );
        expect(provider.hasStaleContent, isTrue);
      },
    );

    test(
      'maps no-data latest response into empty state instead of error',
      () async {
        final provider = RiskReportProvider(
          repository: _FakeRiskAnalysisRepository(
            latestError: Exception('Chưa có dữ liệu đánh giá'),
          ),
        );

        await provider.fetchLatestReport('self');

        expect(provider.report, isNull);
        expect(provider.error, isNull);
        expect(provider.isEmpty, isTrue);
        expect(
          provider.emptyMessage,
          'Chưa có báo cáo rủi ro. Hãy đeo thiết bị thêm vài giờ để hệ thống tạo báo cáo đầu tiên.',
        );
      },
    );

    test('exposes forbidden error for linked profile failures', () async {
      final provider = RiskReportProvider(
        repository: _FakeRiskAnalysisRepository(
          latestError: Exception(
            'Không có quyền xem dữ liệu của người dùng này',
          ),
        ),
      );

      await provider.fetchLatestReport('42');

      expect(provider.error, isNotNull);
      expect(provider.isForbidden, isTrue);
      expect(provider.isEmpty, isFalse);
    });
  });
}
