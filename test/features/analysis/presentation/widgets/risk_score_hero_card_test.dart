import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/analysis/domain/entities/risk_report_entity.dart';
import 'package:healthguard/features/analysis/presentation/widgets/risk_score_hero_card.dart';

void main() {
  testWidgets(
    'RiskScoreHeroCard hides fake delta when previous score is missing',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RiskScoreHeroCard(
              report: RiskReportEntity(
                reportId: 12,
                profileId: 'self',
                score: 41,
                level: RiskLevel.medium,
                displayStatus: 'Cần theo dõi',
                summary: 'Một vài chỉ số cần theo dõi thêm.',
                analyzedAt: DateTime(2026, 4, 19, 8, 30),
                previousScore: null,
                trend7d: const [52, 49, 48, 45, 44, 43, 41],
                topFactors: [TopFactor(key: 'heart_rate', label: 'Nhịp tim')],
                recommendationPreview: const ['Nghỉ ngơi và đo lại.'],
                confidence: 0.84,
                isStale: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Chưa có lần đo trước để so sánh'), findsOneWidget);
      expect(find.textContaining('so với lần trước'), findsNothing);
    },
  );
}
