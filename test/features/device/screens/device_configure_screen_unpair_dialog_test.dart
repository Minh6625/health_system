import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/device/models/device_model.dart';
import 'package:healthguard/features/device/screens/device_configure_screen.dart';

/// Pinned regressions for F-11 (M-8) — unpair dialog must escalate the
/// warning when the device is currently online.
///
/// Before this fix the unpair confirmation said only "this can't be undone",
/// which doesn't tell the user *what* they are losing. QA reported users
/// accidentally unpairing devices that were actively streaming vital signs
/// because the dialog read like a generic "are you sure" prompt.
///
/// New contract:
///   * Online device → dialog calls out vital monitoring + SOS being
///     interrupted, AND the destructive button is disabled until the user
///     ticks an acknowledge-risk checkbox.
///   * Offline device → original short confirmation, no checkbox; making
///     offline users tick a checkbox just to delete a dead device would be
///     busywork.
DeviceModel _device({
  required bool isOnline,
}) {
  return DeviceModel(
    id: 1,
    uuid: '00000000-0000-0000-0000-000000000001',
    deviceName: 'My Watch',
    deviceType: 'smartwatch',
    isActive: true,
    isOnline: isOnline,
  );
}

Widget _buildHarness(DeviceModel device) {
  return MaterialApp(
    home: DeviceConfigureScreen(device: device),
  );
}

/// The configure screen wraps its body in a `ListView`, which uses a
/// SliverList that lazy-realizes only the children currently in the
/// viewport. The default 800x600 test surface puts the danger zone below
/// the fold, so its widgets never enter the tree and finders return
/// nothing. Stretching the surface tall enough that every section fits
/// avoids needing to drive a manual drag scroll for every assertion.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets(
      'F-11 (M-8): online device shows escalated warning text and gates '
      'the destructive button behind the acknowledge-risk checkbox',
      (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_buildHarness(_device(isOnline: true)));
    await tester.pumpAndSettle();

    // Open the unpair dialog by tapping the danger-zone unpair button.
    // The DangerZoneCard wires its onUnpair to _showUnpairDialog and
    // labels the button "Ngắt kết nối thiết bị". We scroll to the bottom of
    // the configure screen first because the danger zone sits below the
    // notification toggles and the test viewport may not include it.
    // DangerZoneCard renders the unpair button via `ElevatedButton.icon`
    // (which Flutter wraps in a private subtype). Targeting the visible
    // label is the most stable selector — it survives the private-class
    // refactor and still pinpoints the exact control the user taps.
    final unpairTrigger = find.text('Ngắt kết nối thiết bị');
    expect(unpairTrigger, findsOneWidget,
        reason:
            'Sanity check: the danger zone surfaces an "Ngắt kết nối '
            'thiết bị" control that opens the unpair dialog.');
    // The configure screen has multiple scrollables (notification list,
    // outer ListView). `ensureVisible` walks up to the nearest scrollable
    // ancestor of the target, which avoids the "too many scrollables"
    // ambiguity that `scrollUntilVisible` hits here.
    await tester.ensureVisible(unpairTrigger);
    await tester.pumpAndSettle();
    await tester.tap(unpairTrigger);
    await tester.pumpAndSettle();

    // Escalated warning copy must appear for online devices.
    expect(
      find.textContaining('đang hoạt động và theo dõi sức khỏe'),
      findsOneWidget,
      reason:
          'Online dialog must call out that the device is currently '
          'monitoring the user — generic "cannot undo" copy is what got '
          'us into M-8 in the first place.',
    );
    // Two widgets legitimately mention "cảnh báo SOS": the warning
    // paragraph above the checkbox, and the checkbox label itself. Both
    // are intentional — repeating the consequence next to the consent
    // checkbox makes it harder to tick without reading. Asserting at
    // least one shields the test from copy tweaks but still pins the
    // SOS-loss messaging being present.
    expect(
      find.textContaining('cảnh báo SOS'),
      findsAtLeastNWidgets(1),
      reason:
          'User must hear that SOS coverage is one of the things they '
          'are about to lose.',
    );

    // Acknowledge-risk row must render with the checkbox.
    final ackRow =
        find.byKey(const ValueKey('unpair-acknowledge-risk-row'));
    final ackCheckbox =
        find.byKey(const ValueKey('unpair-acknowledge-risk-checkbox'));
    expect(ackRow, findsOneWidget);
    expect(ackCheckbox, findsOneWidget);

    // Confirm button starts disabled. We assert via the underlying
    // ElevatedButton.onPressed being null because Flutter renders both
    // states with the same widget tree, only the callback differs.
    final confirmButton = find.byKey(const ValueKey('unpair-confirm-button'));
    expect(confirmButton, findsOneWidget);
    var buttonWidget = tester.widget<ElevatedButton>(confirmButton);
    expect(buttonWidget.onPressed, isNull,
        reason:
            'Online + un-acknowledged risk must leave the destructive '
            'button disabled. Without this gate the user can tap "Ngắt '
            'kết nối" before reading the warning.');

    // Tick the checkbox via tapping the wide row (also covers the
    // 48dp accessibility target).
    await tester.tap(ackRow);
    await tester.pumpAndSettle();

    buttonWidget = tester.widget<ElevatedButton>(confirmButton);
    expect(buttonWidget.onPressed, isNotNull,
        reason:
            'Once the user explicitly acknowledges the risk, the '
            'destructive button must enable so they can proceed.');
  });

  testWidgets(
      'F-11 (M-8): offline device keeps the short confirmation and the '
      'destructive button is enabled immediately (no busywork checkbox)',
      (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_buildHarness(_device(isOnline: false)));
    await tester.pumpAndSettle();

    final unpairTrigger = find.text('Ngắt kết nối thiết bị');
    expect(unpairTrigger, findsOneWidget);
    await tester.ensureVisible(unpairTrigger);
    await tester.pumpAndSettle();
    await tester.tap(unpairTrigger);
    await tester.pumpAndSettle();

    // The escalated copy must NOT appear — offline devices aren't
    // streaming anything, so the extra paragraph would be a lie.
    expect(
      find.textContaining('đang hoạt động và theo dõi sức khỏe'),
      findsNothing,
      reason:
          'Offline device must not get the "đang hoạt động" warning '
          'because that copy would be factually wrong.',
    );

    // No checkbox row.
    expect(
      find.byKey(const ValueKey('unpair-acknowledge-risk-row')),
      findsNothing,
      reason:
          'Offline path stays as a single-step confirmation; gating it '
          'behind a checkbox is busywork that drives users away from '
          'cleaning up dead device records.',
    );

    // The destructive button is enabled from the start.
    final confirmButton = find.byKey(const ValueKey('unpair-confirm-button'));
    final buttonWidget = tester.widget<ElevatedButton>(confirmButton);
    expect(buttonWidget.onPressed, isNotNull);
  });
}
