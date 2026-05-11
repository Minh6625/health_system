import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/analysis/presentation/widgets/recommendation_preview_card.dart';

/// Pinned regressions for F-10 (M-2) — the "Xem đầy đủ" CTA on the risk
/// report's recommendation preview used to be a styled `Text` widget with
/// no gesture handler, so tapping it did nothing. Users mistook it for a
/// broken link because the brand-color styling matched a real button.
///
/// New contract:
///   * When the host screen does not pass `onSeeAll`, the CTA is hidden
///     entirely — no clickable-looking label that silently fails.
///   * When `onSeeAll` is wired, tapping the CTA invokes the callback
///     exactly once and the underlying widget surface is large enough to
///     act as a proper InkWell (so accessibility tooling and the real
///     keyboard-driver story stay sane).
void main() {
  group('RecommendationPreviewCard "Xem đầy đủ" CTA', () {
    testWidgets(
        'hides the CTA entirely when onSeeAll is null so the widget never '
        'renders a dead clickable-looking label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecommendationPreviewCard(
              recommendations: <String>['Nghỉ ngơi và đo lại.'],
            ),
          ),
        ),
      );

      // The card itself still renders (recommendations is non-empty)…
      expect(find.text('Khuyến nghị'), findsOneWidget);
      expect(find.text('Nghỉ ngơi và đo lại.'), findsOneWidget);
      // …but the dead CTA must not.
      expect(find.text('Xem đầy đủ'), findsNothing,
          reason:
              'Without an onSeeAll callback the CTA must be hidden; '
              'rendering it as a non-interactive Text is the original M-2 '
              'bug.');
      expect(
        find.byKey(const ValueKey('recommendation-preview-see-all')),
        findsNothing,
      );
    });

    testWidgets(
        'renders an InkWell-wrapped CTA when onSeeAll is provided and '
        'invokes the callback exactly once on tap', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecommendationPreviewCard(
              recommendations: const <String>['Nghỉ ngơi và đo lại.'],
              onSeeAll: () => tapCount += 1,
            ),
          ),
        ),
      );

      final ctaFinder =
          find.byKey(const ValueKey('recommendation-preview-see-all'));
      expect(ctaFinder, findsOneWidget,
          reason: 'CTA must render when onSeeAll is wired.');
      expect(find.text('Xem đầy đủ'), findsOneWidget);

      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();

      expect(tapCount, 1,
          reason:
              'Tapping the CTA must invoke onSeeAll exactly once. Without '
              'this guarantee the host screen cannot rely on the callback '
              'to push the recommendation detail route.');
    });

    testWidgets('collapses to SizedBox.shrink when recommendations is empty',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecommendationPreviewCard(
              recommendations: <String>[],
            ),
          ),
        ),
      );

      // Whole card disappears — the title, the CTA, everything. Without
      // this the empty-recommendations case would render a "Xem đầy đủ"
      // link with nothing to "see all" of.
      expect(find.text('Khuyến nghị'), findsNothing);
      expect(find.text('Xem đầy đủ'), findsNothing);
    });
  });
}
