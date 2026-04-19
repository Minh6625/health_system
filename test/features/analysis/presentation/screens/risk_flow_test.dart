import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/analysis/domain/entities/risk_history_entity.dart';
import 'package:healthguard/features/analysis/domain/entities/risk_report_detail_entity.dart';
import 'package:healthguard/features/analysis/domain/entities/risk_report_entity.dart';
import 'package:healthguard/features/analysis/presentation/screens/risk_history_screen.dart';
import 'package:healthguard/features/analysis/presentation/screens/risk_report_detail_screen.dart';
import 'package:healthguard/features/analysis/presentation/screens/risk_report_screen.dart';
import 'package:healthguard/features/analysis/providers/risk_history_provider.dart';
import 'package:healthguard/features/analysis/providers/risk_report_provider.dart';
import 'package:healthguard/features/analysis/repositories/risk_analysis_repository.dart';
import 'package:provider/provider.dart';

class _RepoCall {
  const _RepoCall(
    this.name,
    this.profileId, {
    this.reportId,
    this.range,
    this.page,
  });

  final String name;
  final String? profileId;
  final int? reportId;
  final String? range;
  final int? page;
}

class _FakeRiskAnalysisRepository extends RiskAnalysisRepository {
  _FakeRiskAnalysisRepository({
    required this.latestReport,
    required this.detailById,
    required this.historyByRange,
  });

  final RiskReportEntity latestReport;
  final Map<int, RiskReportDetailEntity> detailById;
  final Map<String, Map<int, RiskHistoryEntity>> historyByRange;
  final List<_RepoCall> calls = [];

  @override
  Future<RiskReportEntity> fetchLatestReport(String? profileId) async {
    calls.add(_RepoCall('latest', profileId));
    return latestReport;
  }

  @override
  Future<RiskReportDetailEntity> fetchReportDetail(
    int reportId,
    String? profileId,
  ) async {
    calls.add(_RepoCall('detail', profileId, reportId: reportId));
    return detailById[reportId]!;
  }

  @override
  Future<RiskHistoryEntity> fetchHistory({
    required String? profileId,
    String range = '7d',
    int page = 1,
    int limit = 20,
  }) async {
    calls.add(_RepoCall('history', profileId, range: range, page: page));
    return historyByRange[range]![page]!;
  }
}

RiskReportEntity _report({required bool isStale, String profileId = 'self'}) {
  return RiskReportEntity(
    reportId: 12,
    profileId: profileId,
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
    isStale: isStale,
  );
}

RiskReportDetailEntity _detail({
  required int reportId,
  required bool isStale,
  String profileId = 'self',
}) {
  return RiskReportDetailEntity(
    reportId: reportId,
    profileId: profileId,
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
    isStale: isStale,
  );
}

RiskHistoryEntity _history({
  required String range,
  required List<RiskHistoryItemEntity> items,
  bool hasMore = false,
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
    items: items,
    page: 1,
    limit: 20,
    hasMore: hasMore,
  );
}

RiskHistoryItemEntity _historyItem({
  required int reportId,
  required String reasonPreview,
  required bool isStale,
}) {
  return RiskHistoryItemEntity(
    reportId: reportId,
    score: 44,
    healthScore: 56.0,
    level: RiskLevel.medium,
    displayStatus: 'Can theo doi',
    analyzedAt: DateTime(2026, 4, 16, 9, 15),
    reasonPreview: reasonPreview,
    isStale: isStale,
  );
}

Widget _buildApp({
  required _FakeRiskAnalysisRepository repository,
  String? profileId,
}) {
  return ChangeNotifierProvider<RiskReportProvider>(
    create: (_) => RiskReportProvider(repository: repository),
    child: MaterialApp(
      home: RiskReportScreen(profileId: profileId),
      onGenerateRoute: (settings) {
        final args = settings.arguments as Map<String, dynamic>?;
        switch (settings.name) {
          case AppRouter.riskReportDetail:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => ChangeNotifierProvider(
                create: (_) => RiskReportProvider(repository: repository),
                child: RiskReportDetailScreen(
                  reportId: args?['reportId'] as int? ?? 0,
                  profileId: args?['profileId'] as String?,
                ),
              ),
            );
          case AppRouter.riskHistory:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => ChangeNotifierProvider(
                create: (_) => RiskHistoryProvider(repository: repository),
                child: RiskHistoryScreen(
                  profileId: args?['profileId'] as String?,
                ),
              ),
            );
          case AppRouter.vitalDetail:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Scaffold(
                body: Text('vital:${args?['profileId']}:${args?['vitalType']}'),
              ),
            );
          case AppRouter.sleepReport:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) =>
                  Scaffold(body: Text('sleep:${args?['profileId']}')),
            );
        }
        return null;
      },
    ),
  );
}

Future<void> _popRoute(WidgetTester tester) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  navigator.pop();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'self flow uses CTA path from report to detail history and drilldowns',
    (tester) async {
      final repository = _FakeRiskAnalysisRepository(
        latestReport: _report(isStale: true),
        detailById: {
          12: _detail(reportId: 12, isStale: true),
          21: _detail(reportId: 21, isStale: false),
        },
        historyByRange: {
          '7d': {
            1: _history(
              range: '7d',
              items: [
                _historyItem(
                  reportId: 21,
                  reasonPreview:
                      'Chi so suc khoe dang on dinh hon so voi ky truoc.',
                  isStale: true,
                ),
              ],
            ),
          },
          '30d': {
            1: _history(
              range: '30d',
              items: [
                _historyItem(
                  reportId: 21,
                  reasonPreview: 'Da on dinh tro lai.',
                  isStale: false,
                ),
              ],
            ),
          },
          '90d': {
            1: _history(
              range: '90d',
              items: [
                _historyItem(
                  reportId: 21,
                  reasonPreview: 'Da on dinh tro lai.',
                  isStale: false,
                ),
              ],
            ),
          },
        },
      );

      await tester.pumpWidget(_buildApp(repository: repository));
      await tester.pumpAndSettle();

      expect(find.text('Báo cáo rủi ro sức khỏe'), findsOneWidget);
      expect(
        find.text(
          'Báo cáo này được tạo từ dữ liệu cũ. Hãy kiểm tra lại chỉ số gần nhất.',
        ),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('Xem giải thích AI'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Xem giải thích AI'));
      await tester.pumpAndSettle();
      expect(find.text('Giải thích báo cáo rủi ro'), findsOneWidget);
      expect(
        find.text(
          'Chi tiết này được tính từ dữ liệu cũ. Hãy đối chiếu với chỉ số hiện tại.',
        ),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('Chi tiết\nChỉ số HT'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      final vitalButton = find.widgetWithText(
        OutlinedButton,
        'Chi tiết\nChỉ số HT',
      );
      await tester.ensureVisible(vitalButton);
      tester.widget<OutlinedButton>(vitalButton).onPressed!.call();
      await tester.pumpAndSettle();
      expect(find.text('vital:null:hr'), findsOneWidget);

      await _popRoute(tester);
      final sleepButton = find.widgetWithText(
        OutlinedButton,
        'Báo cáo\nGiấc ngủ',
      );
      await tester.ensureVisible(sleepButton);
      tester.widget<OutlinedButton>(sleepButton).onPressed!.call();
      await tester.pumpAndSettle();
      expect(find.text('sleep:null'), findsOneWidget);

      await _popRoute(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Xem lịch sử'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Xem lịch sử'));
      await tester.pumpAndSettle();
      expect(find.text('Lịch sử đánh giá rủi ro'), findsOneWidget);
      expect(find.text('Điểm trung bình'), findsOneWidget);

      await tester.tap(find.text('30 ngày'));
      await tester.pumpAndSettle();
      expect(find.text('Da on dinh tro lai.'), findsOneWidget);

      await tester.tap(find.text('Da on dinh tro lai.'));
      await tester.pumpAndSettle();
      expect(find.text('Giải thích báo cáo rủi ro'), findsOneWidget);
      expect(
        repository.calls.where((call) => call.name == 'history').length,
        2,
      );
      expect(
        repository.calls.where((call) => call.name == 'history').last.range,
        '30d',
      );
    },
  );

  testWidgets(
    'linked profile flow preserves profileId through report detail history and drilldowns',
    (tester) async {
      final repository = _FakeRiskAnalysisRepository(
        latestReport: _report(isStale: false, profileId: '42'),
        detailById: {
          12: _detail(reportId: 12, isStale: false, profileId: '42'),
        },
        historyByRange: {
          '7d': {
            1: _history(
              range: '7d',
              items: [
                _historyItem(
                  reportId: 12,
                  reasonPreview: 'On dinh hon so voi ky truoc.',
                  isStale: false,
                ),
              ],
            ),
          },
        },
      );

      await tester.pumpWidget(
        _buildApp(repository: repository, profileId: '42'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hồ sơ người thân'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Xem giải thích AI'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Xem giải thích AI'));
      await tester.pumpAndSettle();
      expect(find.text('Hồ sơ người thân'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Chi tiết\nChỉ số HT'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      final vitalButton = find.widgetWithText(
        OutlinedButton,
        'Chi tiết\nChỉ số HT',
      );
      await tester.ensureVisible(vitalButton);
      tester.widget<OutlinedButton>(vitalButton).onPressed!.call();
      await tester.pumpAndSettle();
      expect(find.text('vital:42:hr'), findsOneWidget);

      await _popRoute(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Xem lịch sử'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Xem lịch sử'));
      await tester.pumpAndSettle();
      expect(find.text('Hồ sơ người thân'), findsOneWidget);
      expect(repository.calls.first.profileId, '42');
      expect(
        repository.calls
            .where((call) => call.name == 'history')
            .single
            .profileId,
        '42',
      );
    },
  );

  testWidgets('empty history state does not render summary cards', (
    tester,
  ) async {
    final repository = _FakeRiskAnalysisRepository(
      latestReport: _report(isStale: false),
      detailById: {12: _detail(reportId: 12, isStale: false)},
      historyByRange: {
        '7d': {1: _history(range: '7d', items: const [])},
      },
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<RiskHistoryProvider>(
        create: (_) => RiskHistoryProvider(repository: repository),
        child: const MaterialApp(home: RiskHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có lịch sử'), findsOneWidget);
    expect(find.text('Điểm trung bình'), findsNothing);
    expect(find.textContaining('Cao nhất:'), findsNothing);
  });
}
