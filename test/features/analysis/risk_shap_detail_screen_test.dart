import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:healthguard/features/analysis/domain/entities/risk_report_detail_entity.dart';
import 'package:healthguard/features/analysis/domain/entities/risk_report_entity.dart';
import 'package:healthguard/features/analysis/presentation/screens/risk_shap_detail_screen.dart';

/// Builds a minimal [RiskReportDetailEntity] with a configurable SHAP
/// payload. Most fields are filled with neutral defaults — the screen
/// only reads ``reportId``, ``shapDetails``, and ``modelRequestId``.
RiskReportDetailEntity _detail({
  ShapWaterfall? shap,
  String? modelRequestId,
}) {
  return RiskReportDetailEntity(
    reportId: 17,
    profileId: 'self',
    score: 18,
    healthScore: 82,
    level: RiskLevel.low,
    displayStatus: 'Ổn định',
    summary: 'OK',
    analyzedAt: DateTime.utc(2026, 4, 27, 10),
    previousScore: null,
    trend7d: const [24, 21, 19, 18],
    breakdown: const [],
    xaiExplanation: '',
    recommendations: const [],
    recommendationPreview: const [],
    topFactors: const [],
    snapshot: SnapshotMetrics(
      heartRate: 75, spO2: 97, sysBp: 120, diaBp: 80,
      bodyTemp: 36.5, hrv: 45, mapVal: 93,
    ),
    confidence: 0.92,
    isStale: false,
    shapDetails: shap,
    modelRequestId: modelRequestId,
  );
}

void main() {
  group('RiskShapDetailScreen', () {
    testWidgets('renders the unavailable state when shapDetails is null',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: RiskShapDetailScreen(detail: _detail())),
      );

      expect(find.text('Không có SHAP cho báo cáo này'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('renders the unavailable state when available=false',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RiskShapDetailScreen(
            detail: _detail(
              shap: const ShapWaterfall(
                available: false, baseValue: 0, values: [],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Không có SHAP cho báo cáo này'), findsOneWidget);
    });

    testWidgets('renders one bar per contribution sorted by absolute impact',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RiskShapDetailScreen(
            detail: _detail(
              shap: const ShapWaterfall(
                available: true,
                baseValue: 0.05,
                values: [
                  ShapContribution(
                    feature: 'spo2', shapValue: -0.18, impact: 0.18,
                  ),
                  ShapContribution(
                    feature: 'heart_rate', shapValue: 0.42, impact: 0.42,
                  ),
                  ShapContribution(
                    feature: 'temp', shapValue: 0.05, impact: 0.05,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Header metrics.
      expect(find.text('Báo cáo #17'), findsOneWidget);
      expect(find.textContaining('Base value'), findsOneWidget);

      // One LinearProgressIndicator per bar.
      expect(find.byType(LinearProgressIndicator), findsNWidgets(3));

      // Feature labels rendered.
      expect(find.text('heart_rate'), findsOneWidget);
      expect(find.text('spo2'), findsOneWidget);
      expect(find.text('temp'), findsOneWidget);

      // Sorted: heart_rate (impact 0.42) renders BEFORE spo2 (0.18)
      // BEFORE temp (0.05). Verify by comparing positions on screen.
      final hrPos = tester.getCenter(find.text('heart_rate')).dy;
      final spPos = tester.getCenter(find.text('spo2')).dy;
      final tempPos = tester.getCenter(find.text('temp')).dy;
      expect(hrPos, lessThan(spPos));
      expect(spPos, lessThan(tempPos));
    });

    testWidgets('renders + signed value for positive contributions',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RiskShapDetailScreen(
            detail: _detail(
              shap: const ShapWaterfall(
                available: true,
                baseValue: 0,
                values: [
                  ShapContribution(
                    feature: 'heart_rate', shapValue: 0.42, impact: 0.42,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      // ``+0.420`` appears in both the bar and the header's total
      // metric (the only contribution IS the total). Either occurrence
      // is fine — what we're pinning is the leading-``+`` formatting
      // for positive values.
      expect(find.text('+0.420'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders unsigned negative value for protective contributions',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RiskShapDetailScreen(
            detail: _detail(
              shap: const ShapWaterfall(
                available: true,
                baseValue: 0,
                values: [
                  ShapContribution(
                    feature: 'spo2', shapValue: -0.18, impact: 0.18,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      // Negative numbers carry their own '-' sign — we don't add one.
      // Same story as the positive case: bar + header both render it.
      expect(find.text('-0.180'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows model_request_id row when present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RiskShapDetailScreen(
            detail: _detail(
              shap: const ShapWaterfall(
                available: true, baseValue: 0,
                values: [
                  ShapContribution(
                    feature: 'a', shapValue: 0.1, impact: 0.1,
                  ),
                ],
              ),
              modelRequestId: 'req-abc-123',
            ),
          ),
        ),
      );

      expect(find.text('Mã yêu cầu mô hình'), findsOneWidget);
      expect(find.text('req-abc-123'), findsOneWidget);
      // The copy button is rendered.
      expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
    });

    testWidgets('hides model_request_id row when null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RiskShapDetailScreen(
            detail: _detail(
              shap: const ShapWaterfall(
                available: true, baseValue: 0,
                values: [
                  ShapContribution(
                    feature: 'a', shapValue: 0.1, impact: 0.1,
                  ),
                ],
              ),
              modelRequestId: null,
            ),
          ),
        ),
      );
      expect(find.text('Mã yêu cầu mô hình'), findsNothing);
      expect(find.byIcon(Icons.copy_outlined), findsNothing);
    });

    testWidgets('disclaimer is always visible on the active screen',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RiskShapDetailScreen(
            detail: _detail(
              shap: const ShapWaterfall(
                available: true, baseValue: 0,
                values: [
                  ShapContribution(
                    feature: 'a', shapValue: 0.1, impact: 0.1,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(
        find.textContaining('không phải chẩn đoán y khoa'),
        findsOneWidget,
      );
    });

    testWidgets('caps the visible bar count at 20 even with 30 contributions',
        (tester) async {
      // The screen takes(20) to keep the list scannable on phones.
      // Build 30 distinctive features and verify only the top-20 by
      // impact (feat_0..feat_19) appear in the rendered tree, while
      // the dropped 10 (feat_20..feat_29) do not.
      final manyContribs = List<ShapContribution>.generate(
        30,
        (i) => ShapContribution(
          // ``feat_NN`` (zero-padded) so sort order matches index order.
          feature: 'feat_${i.toString().padLeft(2, '0')}',
          shapValue: (30 - i) * 0.01,  // descending so top 20 = i=0..19
          impact: (30 - i) * 0.01,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RiskShapDetailScreen(
            detail: _detail(
              shap: ShapWaterfall(
                available: true,
                baseValue: 0,
                values: manyContribs,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The 20th feature (last kept by take(20)) IS in the tree.
      // ListView is lazy on viewport but the ``children`` list passes
      // through every entry, so finder picks up off-screen rows too
      // when they're built via SliverList/SliverChildList. ListView
      // (default) is virtualised → use a different assertion strategy:
      // scroll to the bottom and verify the last KEPT feature (feat_19)
      // is present, while a DROPPED feature (feat_20) is NOT.
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('feat_19'), 100, scrollable: scrollable,
      );
      expect(find.text('feat_19'), findsOneWidget);
      // Confirm dropped features never render even after fully
      // scrolling.
      expect(find.text('feat_20'), findsNothing);
      expect(find.text('feat_29'), findsNothing);
    });
  });
}
