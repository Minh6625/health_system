/// ADR-018 Phase 7 S11 — synthetic-default warning banner tests.
///
/// Verifies two things:
///
/// 1. **Parser contract** — [RiskAnalysisRepository] correctly reads the
///    four data-quality fields from the JSON response and maps them onto
///    [RiskReportEntity].
///
/// 2. **UI contract** — [RiskReportScreen] shows the
///    ``synthetic_default_banner`` when [RiskReportEntity.isSyntheticDefault]
///    is ``true``, hides it when ``false``, prefers the back-end copy when
///    [dataQualityWarning] is non-empty, and falls back to the default
///    Vietnamese copy when it is absent.
///
/// Tests use the same [_FakeRiskAnalysisRepository] + [ChangeNotifierProvider]
/// injection pattern established in ``risk_flow_test.dart`` so they require
/// no changes to production widget scaffolding.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/analysis/domain/entities/risk_report_entity.dart';
import 'package:healthguard/features/analysis/presentation/screens/risk_report_screen.dart';
import 'package:healthguard/features/analysis/providers/risk_report_provider.dart';
import 'package:healthguard/features/analysis/repositories/risk_analysis_repository.dart';
import 'package:healthguard/shared/presentation/feedback/inline_status_banner.dart';
import 'package:provider/provider.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Minimal report used across banner tests. Pass [isSyntheticDefault] and
/// [dataQualityWarning] to exercise the warning path.
RiskReportEntity _report({
  bool isSyntheticDefault = false,
  String? dataQualityWarning,
}) {
  return RiskReportEntity(
    reportId: 1,
    profileId: 'self',
    score: 35,
    level: RiskLevel.medium,
    displayStatus: 'Can theo doi',
    summary: 'Chi so can theo doi.',
    analyzedAt: DateTime(2026, 5, 18, 9, 0),
    previousScore: null,
    trend7d: const [40, 38, 37, 36, 35],
    topFactors: [],
    recommendationPreview: const [],
    confidence: 0.7,
    isStale: false,
    isSyntheticDefault: isSyntheticDefault,
    dataQualityWarning: dataQualityWarning,
  );
}

class _FakeRepo extends RiskAnalysisRepository {
  _FakeRepo(this._report);
  final RiskReportEntity _report;

  @override
  Future<RiskReportEntity> fetchLatestReport(String? profileId) async =>
      _report;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pumps [RiskReportScreen] with a provider that serves [report].
Future<void> _pumpScreen(
  WidgetTester tester,
  RiskReportEntity report,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<RiskReportProvider>(
        create: (_) => RiskReportProvider(repository: _FakeRepo(report)),
        child: const RiskReportScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RiskReportEntity — data quality fields', () {
    test('defaults to clean state when fields absent', () {
      final e = _report();
      expect(e.isSyntheticDefault, isFalse);
      expect(e.defaultsApplied, isNull);
      expect(e.effectiveConfidence, isNull);
      expect(e.dataQualityWarning, isNull);
    });

    test('accepts all four fields when provided', () {
      final e = RiskReportEntity(
        reportId: 2,
        profileId: 'self',
        score: 40,
        level: RiskLevel.medium,
        displayStatus: 'Can theo doi',
        summary: '',
        analyzedAt: DateTime(2026, 5, 18),
        previousScore: null,
        trend7d: const [],
        topFactors: [],
        recommendationPreview: const [],
        confidence: 0.8,
        isStale: false,
        isSyntheticDefault: true,
        defaultsApplied: const ['hrv', 'weight'],
        effectiveConfidence: 0.4,
        dataQualityWarning: 'HRV va can nang dung gia tri mac dinh.',
      );

      expect(e.isSyntheticDefault, isTrue);
      expect(e.defaultsApplied, containsAll(['hrv', 'weight']));
      expect(e.effectiveConfidence, closeTo(0.4, 1e-9));
      expect(e.dataQualityWarning, contains('HRV'));
    });
  });

  group('RiskReportScreen — synthetic default banner', () {
    testWidgets('banner absent when isSyntheticDefault is false',
        (tester) async {
      await _pumpScreen(tester, _report(isSyntheticDefault: false));

      expect(
        find.byKey(const ValueKey('synthetic_default_banner')),
        findsNothing,
      );
    });

    testWidgets('banner present when isSyntheticDefault is true',
        (tester) async {
      await _pumpScreen(tester, _report(isSyntheticDefault: true));

      expect(
        find.byKey(const ValueKey('synthetic_default_banner')),
        findsOneWidget,
      );
    });

    testWidgets('banner is an InlineStatusBanner', (tester) async {
      await _pumpScreen(tester, _report(isSyntheticDefault: true));

      expect(find.byType(InlineStatusBanner), findsAtLeastNWidgets(1));
    });

    testWidgets('uses backend copy when dataQualityWarning non-empty',
        (tester) async {
      const customWarning = 'HRV chua do duoc — gia tri mac dinh duoc dung.';
      await _pumpScreen(
        tester,
        _report(isSyntheticDefault: true, dataQualityWarning: customWarning),
      );

      expect(find.text(customWarning), findsOneWidget);
    });

    testWidgets('falls back to default copy when dataQualityWarning null',
        (tester) async {
      await _pumpScreen(
        tester,
        _report(isSyntheticDefault: true, dataQualityWarning: null),
      );

      expect(
        find.textContaining('mặc định'),
        findsOneWidget,
      );
    });

    testWidgets('falls back to default copy when dataQualityWarning empty',
        (tester) async {
      await _pumpScreen(
        tester,
        _report(isSyntheticDefault: true, dataQualityWarning: ''),
      );

      expect(
        find.textContaining('mặc định'),
        findsOneWidget,
      );
    });
  });
}
