import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/emergency/models/sos_event_model.dart';
import 'package:healthguard/features/emergency/widgets/sos_detail/emergency_sos_actions_block.dart';
import 'package:healthguard/features/emergency/widgets/sos_detail/emergency_sos_info_cards.dart';
import 'package:healthguard/features/emergency/widgets/sos_detail/emergency_sos_patient_header.dart';
import 'package:healthguard/features/emergency/widgets/sos_detail/emergency_sos_timeline_block.dart';
import 'package:healthguard/features/emergency/widgets/sos_detail/sos_trigger_helpers.dart';

// Phase 13 (W6) regression net for the EmergencySOSDetailScreen split.
//
// The detail screen used to be a 1015-line state object that owned the
// entire patient header, map, xai timeline, info cards and actions bar.
// We extracted those sections into dedicated widgets so the screen can
// stay focused on layout orchestration. Each test below pins one of the
// extracted widgets so a future contributor cannot regress its public
// contract without breaking the build.

PatientInfoModel _patient({String? photo}) => PatientInfoModel(
      id: '1',
      name: 'Nguyễn Văn A',
      photoUrl: photo,
      phone: '0900000000',
    );

LocationInfoModel _location({double? lat, double? lng}) => LocationInfoModel(
      latitude: lat,
      longitude: lng,
      accuracy: lat != null ? 12.5 : null,
      address: null,
      lastUpdated: DateTime(2026, 4, 26, 18, 0, 0),
    );

SOSEventModel _sos({
  String status = 'active',
  String triggerType = 'fall_detected',
  bool withGps = true,
  FallDetectionXAIModel? xai,
  ResolutionInfoModel? resolution,
}) {
  return SOSEventModel(
    id: 'sos-1',
    patient: _patient(),
    triggerType: triggerType,
    triggerTime: DateTime(2026, 4, 26, 17, 50, 0),
    status: status,
    location: withGps ? _location(lat: 10.7626, lng: 106.6602) : _location(),
    fallDetectionXAI: xai,
    resolution: resolution,
  );
}

Future<void> _pumpInScaffold(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('triggerLabelFor / triggerIconFor', () {
    test('maps fall_detected to Phát hiện té ngã + arrow_downward', () {
      expect(triggerLabelFor('fall_detected'), 'Phát hiện té ngã');
      expect(triggerIconFor('fall_detected'), Icons.arrow_downward);
    });

    test('maps manual to Kích hoạt thủ công + touch_app', () {
      expect(triggerLabelFor('manual'), 'Kích hoạt thủ công');
      expect(triggerIconFor('manual'), Icons.touch_app);
    });

    test('maps vital_critical to Chỉ số sinh tồn tới hạn + error', () {
      expect(triggerLabelFor('vital_critical'), 'Chỉ số sinh tồn tới hạn');
      expect(triggerIconFor('vital_critical'), Icons.error);
    });

    test('falls back to SOS khẩn cấp + emergency for unknown type', () {
      expect(triggerLabelFor('made_up_kind'), 'SOS khẩn cấp');
      expect(triggerIconFor('made_up_kind'), Icons.emergency);
    });
  });

  group('EmergencySOSPatientHeader', () {
    testWidgets('renders patient name and trigger label', (tester) async {
      await _pumpInScaffold(
        tester,
        EmergencySOSPatientHeader(sos: _sos()),
      );
      // Active SOS: the warning shake controller `.repeat()`s forever, so
      // `pumpAndSettle` would time out. A single `pump()` is enough to lay
      // the widget out for the text assertions.
      await tester.pump();

      expect(find.text('Nguyễn Văn A'), findsOneWidget);
      expect(find.text('Phát hiện té ngã'), findsOneWidget);
    });

    testWidgets('shows the warning icon while SOS is active', (tester) async {
      await _pumpInScaffold(
        tester,
        EmergencySOSPatientHeader(sos: _sos(status: 'active')),
      );
      // See note above: warning shake never settles.
      await tester.pump();

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('hides the warning icon once SOS is resolved',
        (tester) async {
      await _pumpInScaffold(
        tester,
        EmergencySOSPatientHeader(sos: _sos(status: 'resolved')),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });
  });

  group('EmergencySOSTimelineBlock', () {
    testWidgets('renders confidence as percent and lists timeline events',
        (tester) async {
      final xai = FallDetectionXAIModel(
        confidence: 0.83,
        timeline: [
          TimelineEventModel(time: '17:50:00', description: 'Bắt đầu rơi'),
          TimelineEventModel(time: '17:50:01', description: 'Chạm sàn'),
        ],
        triggerReason: 'Phát hiện gia tốc bất thường',
      );
      await _pumpInScaffold(
        tester,
        EmergencySOSTimelineBlock(xai: xai),
      );
      await tester.pumpAndSettle();

      expect(find.text('Độ tin cậy: 83%'), findsOneWidget);
      expect(find.text('Phát hiện gia tốc bất thường'), findsOneWidget);
      expect(find.text('17:50:00 - Bắt đầu rơi'), findsOneWidget);
      expect(find.text('17:50:01 - Chạm sàn'), findsOneWidget);
    });

    testWidgets('omits the trigger reason line when it is empty',
        (tester) async {
      final xai = FallDetectionXAIModel(
        confidence: 0.5,
        timeline: const [],
        triggerReason: '   ',
      );
      await _pumpInScaffold(
        tester,
        EmergencySOSTimelineBlock(xai: xai),
      );
      await tester.pumpAndSettle();

      // Only the structural labels and the confidence line should render.
      expect(find.text('Độ tin cậy: 50%'), findsOneWidget);
      expect(find.text('   '), findsNothing);
    });
  });

  group('EmergencySOSInfoCards', () {
    testWidgets('LocationInfoCard formats GPS coordinates and accuracy',
        (tester) async {
      await _pumpInScaffold(
        tester,
        EmergencySOSLocationInfoCard(sos: _sos(withGps: true)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('GPS: 10.762600'), findsOneWidget);
      expect(find.textContaining('Độ chính xác: 12.5 mét'), findsOneWidget);
    });

    testWidgets('LocationInfoCard falls back to "Không có dữ liệu" when GPS missing',
        (tester) async {
      await _pumpInScaffold(
        tester,
        EmergencySOSLocationInfoCard(sos: _sos(withGps: false)),
      );
      await tester.pumpAndSettle();

      expect(find.text('GPS: Không có dữ liệu'), findsOneWidget);
    });

    testWidgets('TimeInfoCard renders the trigger timestamp', (tester) async {
      await _pumpInScaffold(
        tester,
        EmergencySOSTimeInfoCard(sos: _sos()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Kích hoạt: 17:50:00 - 26/04/2026'),
          findsOneWidget);
      // Elapsed text depends on `DateTime.now()`, so just assert the prefix.
      expect(find.textContaining('Đã trôi qua: '), findsOneWidget);
    });

    testWidgets('ResolutionInfoCard renders status, resolver and notes',
        (tester) async {
      final resolution = ResolutionInfoModel(
        resolutionStatus: 'safe',
        resolvedBy: 'Caregiver A',
        resolvedTime: DateTime(2026, 4, 26, 18, 5, 0),
        notes: 'Đã xác nhận an toàn.',
      );
      await _pumpInScaffold(
        tester,
        EmergencySOSResolutionInfoCard(resolution: resolution),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đã xử lý bởi: Caregiver A'), findsOneWidget);
      expect(find.text('Trạng thái xử lý: safe'), findsOneWidget);
      expect(find.text('Ghi chú: Đã xác nhận an toàn.'), findsOneWidget);
    });
  });

  group('EmergencySOSActionsBlock', () {
    testWidgets('calls onCall when "Gọi điện" is tapped', (tester) async {
      var callCount = 0;
      await _pumpInScaffold(
        tester,
        EmergencySOSActionsBlock(
          sos: _sos(),
          isResolving: false,
          onCall: () => callCount++,
          onNavigate: () {},
          onConfirmResolve: () {},
        ),
      );
      await tester.tap(find.text('Gọi điện'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
    });

    testWidgets('disables "Chỉ đường" when GPS is missing', (tester) async {
      await _pumpInScaffold(
        tester,
        EmergencySOSActionsBlock(
          sos: _sos(withGps: false),
          isResolving: false,
          onCall: () {},
          onNavigate: null,
          onConfirmResolve: () {},
        ),
      );
      await tester.pumpAndSettle();

      final navigateButton = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Chỉ đường'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(navigateButton.onPressed, isNull);
    });

    testWidgets('hides the resolve button once SOS is resolved',
        (tester) async {
      await _pumpInScaffold(
        tester,
        EmergencySOSActionsBlock(
          sos: _sos(status: 'resolved'),
          isResolving: false,
          onCall: () {},
          onNavigate: () {},
          onConfirmResolve: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận'), findsNothing);
    });

    testWidgets('shows spinner copy while isResolving=true', (tester) async {
      await _pumpInScaffold(
        tester,
        EmergencySOSActionsBlock(
          sos: _sos(),
          isResolving: true,
          onCall: () {},
          onNavigate: () {},
          onConfirmResolve: () {},
        ),
      );
      await tester.pump();

      expect(find.text('Đang xác nhận...'), findsOneWidget);
    });
  });
}
