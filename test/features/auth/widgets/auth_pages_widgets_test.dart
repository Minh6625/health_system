import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/auth/widgets/auth_pages/auth_get_started_cta.dart';
import 'package:healthguard/features/auth/widgets/auth_pages/auth_page_indicator.dart';

// Phase 14 (W8) regression net for the AuthPagesScreen split: pin the
// public contract of the two extracted widgets so a future contributor
// cannot regress the welcome-page CTA tap or the dot indicator without
// breaking the build.

Future<void> _pumpInBlackBackground(WidgetTester tester, Widget child) async {
  // Black background mimics the StartScreen gradient and makes the white
  // dots actually visible during golden runs.
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [Positioned.fill(child: child)]),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AuthPageIndicator', () {
    testWidgets('renders one dot per page', (tester) async {
      await _pumpInBlackBackground(
        tester,
        const Align(
          alignment: Alignment.bottomCenter,
          child: AuthPageIndicator(pageCount: 3, currentPage: 0),
        ),
      );

      expect(find.byType(AnimatedContainer), findsNWidgets(3));
    });

    testWidgets('the active dot is wider than inactive dots', (tester) async {
      await _pumpInBlackBackground(
        tester,
        const Align(
          alignment: Alignment.bottomCenter,
          child: AuthPageIndicator(pageCount: 2, currentPage: 1),
        ),
      );

      final dots = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .toList();
      // Active dot stretches to 32px, inactive dots stay 8px.
      final widths = dots.map((d) => (d.constraints?.maxWidth)).toList();
      expect(widths.contains(32.0), isTrue);
      expect(widths.contains(8.0), isTrue);
    });
  });

  group('AuthGetStartedCta', () {
    testWidgets('renders the Vietnamese label and forward arrow',
        (tester) async {
      await _pumpInBlackBackground(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: AuthGetStartedCta(onTap: () {}),
        ),
      );

      expect(find.text('Bắt đầu ngay'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('fires onTap when tapped', (tester) async {
      var taps = 0;
      await _pumpInBlackBackground(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: AuthGetStartedCta(onTap: () => taps++),
        ),
      );

      await tester.tap(find.text('Bắt đầu ngay'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('honors the opacity prop', (tester) async {
      await _pumpInBlackBackground(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: AuthGetStartedCta(onTap: () {}, opacity: 0.0),
        ),
      );

      final fade = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
      expect(fade.opacity, 0.0);
    });
  });
}
