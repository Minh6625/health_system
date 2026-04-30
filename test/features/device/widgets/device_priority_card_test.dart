import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/device/models/device_model.dart';
import 'package:healthguard/features/device/widgets/device_list/device_priority_card.dart';

/// F-16 (M-10) regression tests for `DevicePriorityCard`.
///
/// Tester complaint: "Khi kết nối 2 thiết bị thì không có phần note
/// là đang kết nối cái nào và kết nối cho ai." Mỗi card now shows
/// an explicit `Đang theo dõi: ${name}` line so users with multiple
/// devices can tell at a glance who each device is collecting data
/// for. These tests pin the rendering contract:
///
///   1. Badge appears when monitoredForName is a non-empty trimmed
///      string.
///   2. Badge is hidden when monitoredForName is null, empty, or
///      whitespace-only — a half-empty "Đang theo dõi: " row would
///      look broken.
///   3. The badge text uses the trimmed name (no leading/trailing
///      spaces) so a noisy AuthProvider value cannot break the
///      layout.
///   4. Pre-fix behavior is preserved: device name + status badge +
///      battery info still render the same way (regression guard
///      for the layout shift introduced by the M-10 patch).
void main() {
  DeviceModel makeDevice({String name = 'Watch chính'}) {
    return DeviceModel(
      id: 1,
      uuid: 'uuid-1',
      deviceName: name,
      deviceType: 'smartwatch',
      isActive: true,
      isOnline: true,
      batteryLevel: 80,
    );
  }

  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  group('DevicePriorityCard — F-16 (M-10) "Đang theo dõi" badge', () {
    testWidgets(
        'shows "Đang theo dõi: name" line when monitoredForName is set '
        '— this is the canonical fix for the tester report', (tester) async {
      await tester.pumpWidget(wrap(DevicePriorityCard(
        device: makeDevice(),
        needsAttention: false,
        onActionSelected: (_, _) {},
        onRefreshRequested: () {},
        monitoredForName: 'Nguyễn Văn A',
      )));

      expect(
        find.text('Đang theo dõi: Nguyễn Văn A'),
        findsOneWidget,
        reason:
            'The exact "Đang theo dõi: <name>" string is the user-visible '
            'fix; a missing or differently-formatted line means the '
            'tester complaint reverts.',
      );
      // Person-outline icon is the visual anchor so the line is
      // recognisable as an identity badge (not just another caption).
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    });

    testWidgets(
        'hides the badge when monitoredForName is null — the auth '
        'provider may not have resolved yet (race during cold start), '
        'and we prefer "no badge" over "Đang theo dõi: " with no name',
        (tester) async {
      await tester.pumpWidget(wrap(DevicePriorityCard(
        device: makeDevice(),
        needsAttention: false,
        onActionSelected: (_, _) {},
        onRefreshRequested: () {},
        monitoredForName: null,
      )));

      expect(find.textContaining('Đang theo dõi'), findsNothing);
      expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
    });

    testWidgets(
        'hides the badge when monitoredForName is an empty string — same '
        'graceful-degradation case as null but covers the API contract '
        '(some auth backends return "" instead of null for unset names)',
        (tester) async {
      await tester.pumpWidget(wrap(DevicePriorityCard(
        device: makeDevice(),
        needsAttention: false,
        onActionSelected: (_, _) {},
        onRefreshRequested: () {},
        monitoredForName: '',
      )));

      expect(find.textContaining('Đang theo dõi'), findsNothing);
    });

    testWidgets(
        'hides the badge when monitoredForName is whitespace-only — '
        'rendering "Đang theo dõi:    " would look like a layout bug',
        (tester) async {
      await tester.pumpWidget(wrap(DevicePriorityCard(
        device: makeDevice(),
        needsAttention: false,
        onActionSelected: (_, _) {},
        onRefreshRequested: () {},
        monitoredForName: '   ',
      )));

      expect(find.textContaining('Đang theo dõi'), findsNothing);
    });

    testWidgets(
        'trims the displayed name so leading/trailing spaces from the '
        'auth payload do not bleed into the UI', (tester) async {
      await tester.pumpWidget(wrap(DevicePriorityCard(
        device: makeDevice(),
        needsAttention: false,
        onActionSelected: (_, _) {},
        onRefreshRequested: () {},
        monitoredForName: '  Lê Thị B  ',
      )));

      expect(find.text('Đang theo dõi: Lê Thị B'), findsOneWidget);
      // Ensure the noisy variant did NOT render (negative assertion
      // is critical — equality on `find.text` would not catch it).
      expect(find.text('Đang theo dõi:   Lê Thị B  '), findsNothing);
    });

    testWidgets(
        'still renders device name + Online badge + battery pill when '
        'the M-10 line is added — regression guard so the layout '
        'change does not break existing visual contracts',
        (tester) async {
      await tester.pumpWidget(wrap(DevicePriorityCard(
        device: makeDevice(name: 'Watch dự phòng'),
        needsAttention: false,
        onActionSelected: (_, _) {},
        onRefreshRequested: () {},
        monitoredForName: 'Nguyễn Văn A',
      )));

      expect(find.text('Watch dự phòng'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Pin 80%'), findsOneWidget);
    });
  });
}
