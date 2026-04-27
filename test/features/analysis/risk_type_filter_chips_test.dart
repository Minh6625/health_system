import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:healthguard/features/analysis/presentation/widgets/risk_type_filter_chips.dart';

void main() {
  group('kRiskTypeFilters', () {
    test('contains the canonical filter set + the All pseudo-option', () {
      // The values must match
      // ``MonitoringService.RISK_HISTORY_TYPE_FILTERS`` on the backend
      // (Phase 4A-full slice 3b). Add one in both places when we add
      // a new risk type.
      final values = kRiskTypeFilters.map((o) => o.value).toList();
      expect(values, [null, 'general', 'sleep', 'fall']);
    });

    test('every option has a non-empty Vietnamese label', () {
      for (final option in kRiskTypeFilters) {
        expect(option.label.trim(), isNotEmpty,
            reason: 'value=${option.value}');
      }
    });
  });

  group('RiskTypeFilterChips', () {
    testWidgets('renders one ChoiceChip per option', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RiskTypeFilterChips(
              selectedValue: null,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      // Tất cả + Sức khoẻ + Giấc ngủ + Té ngã = 4 chips.
      expect(find.byType(ChoiceChip), findsNWidgets(4));
      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Sức khoẻ'), findsOneWidget);
      expect(find.text('Giấc ngủ'), findsOneWidget);
      expect(find.text('Té ngã'), findsOneWidget);
    });

    testWidgets(
        'highlights the chip that matches selectedValue=null (All)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RiskTypeFilterChips(
              selectedValue: null,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      // The "Tất cả" chip should be the selected one.
      final allChip = tester.widget<ChoiceChip>(
        find.ancestor(
          of: find.text('Tất cả'),
          matching: find.byType(ChoiceChip),
        ),
      );
      expect(allChip.selected, isTrue);
    });

    testWidgets(
        'highlights the chip that matches selectedValue=sleep',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RiskTypeFilterChips(
              selectedValue: 'sleep',
              onChanged: (_) {},
            ),
          ),
        ),
      );
      final sleepChip = tester.widget<ChoiceChip>(
        find.ancestor(
          of: find.text('Giấc ngủ'),
          matching: find.byType(ChoiceChip),
        ),
      );
      expect(sleepChip.selected, isTrue);
      // And the "Tất cả" chip should NOT be selected.
      final allChip = tester.widget<ChoiceChip>(
        find.ancestor(
          of: find.text('Tất cả'),
          matching: find.byType(ChoiceChip),
        ),
      );
      expect(allChip.selected, isFalse);
    });

    testWidgets('tapping a non-active chip fires onChanged with its value',
        (tester) async {
      String? tappedValue = 'sentinel';
      var callCount = 0;
      void onChanged(String? value) {
        tappedValue = value;
        callCount++;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RiskTypeFilterChips(
              selectedValue: null,  // All is selected
              onChanged: onChanged,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Giấc ngủ'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
      expect(tappedValue, 'sleep');
    });

    testWidgets(
        'tapping the active chip is a no-op (does not fire onChanged)',
        (tester) async {
      var callCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RiskTypeFilterChips(
              selectedValue: 'fall',  // Té ngã is selected
              onChanged: (_) => callCount++,
            ),
          ),
        ),
      );

      // Tapping the already-selected chip would normally trigger
      // ChoiceChip's deselect behaviour. Our widget swallows that
      // because the screen always has SOMETHING selected.
      await tester.tap(find.text('Té ngã'));
      await tester.pumpAndSettle();

      expect(callCount, 0);
    });

    testWidgets('switching from one filter to another reports null first '
        'when "Tất cả" is tapped', (tester) async {
      String? lastValue = 'sentinel';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RiskTypeFilterChips(
              selectedValue: 'sleep',  // start with sleep selected
              onChanged: (value) => lastValue = value,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tất cả'));
      await tester.pumpAndSettle();

      // "Tất cả" -> null (no filter on the wire).
      expect(lastValue, isNull);
    });
  });
}
