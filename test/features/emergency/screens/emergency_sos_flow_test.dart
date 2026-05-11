import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/emergency/models/sos_event_model.dart';
import 'package:healthguard/features/emergency/providers/emergency_caregiver_provider.dart';
import 'package:healthguard/features/emergency/repositories/emergency_caregiver_repository.dart';
import 'package:healthguard/features/emergency/screens/emergency_sos_detail_screen.dart';
import 'package:healthguard/features/emergency/screens/emergency_sos_received_list_screen.dart';
import 'package:provider/provider.dart';

class _FakeEmergencyCaregiverRepository extends EmergencyCaregiverRepository {
  _FakeEmergencyCaregiverRepository({
    required List<SOSEventModel> initialAlerts,
    Map<String, SOSEventModel>? detailById,
    this.listError,
  }) : _alerts = List<SOSEventModel>.from(initialAlerts),
       _detailById =
           detailById ?? {for (final alert in initialAlerts) alert.id: alert};

  final Object? listError;
  final List<SOSEventModel> _alerts;
  final Map<String, SOSEventModel> _detailById;
  final List<String> requestedStatuses = <String>[];
  final List<String> requestedDetails = <String>[];
  final List<Map<String, String?>> resolvedCalls = <Map<String, String?>>[];

  @override
  Future<SOSAlertsResult> getSOSAlerts({required String status}) async {
    requestedStatuses.add(status);
    if (listError != null) {
      throw listError!;
    }

    final filtered = switch (status) {
      'active' => _alerts.where((alert) => alert.status == 'active').toList(),
      'resolved' =>
        _alerts.where((alert) => alert.status == 'resolved').toList(),
      _ => List<SOSEventModel>.from(_alerts),
    };

    return SOSAlertsResult(
      sosAlerts: filtered,
      totalCount: _alerts.length,
      activeCount: _alerts.where((alert) => alert.status == 'active').length,
      resolvedCount: _alerts
          .where((alert) => alert.status == 'resolved')
          .length,
    );
  }

  @override
  Future<SOSEventModel> getSOSDetail({required String sosId}) async {
    requestedDetails.add(sosId);
    return _detailById[sosId]!;
  }

  @override
  Future<void> resolveSOSByCaregiver({
    required String sosId,
    required String resolutionStatus,
    String? notes,
  }) async {
    resolvedCalls.add({
      'sosId': sosId,
      'resolutionStatus': resolutionStatus,
      'notes': notes,
    });
    final current = _detailById[sosId]!;
    final resolved = _resolvedEvent(
      current,
      resolutionStatus: resolutionStatus,
      notes: notes,
    );
    _detailById[sosId] = resolved;
    final index = _alerts.indexWhere((alert) => alert.id == sosId);
    if (index >= 0) {
      _alerts[index] = resolved;
    }
  }
}

SOSEventModel _event({
  required String id,
  required String patientName,
  required String triggerType,
  required String status,
  ResolutionInfoModel? resolution,
}) {
  return SOSEventModel(
    id: id,
    patient: PatientInfoModel(
      id: 'patient-$id',
      name: patientName,
      photoUrl: null,
      phone: '0900123456',
    ),
    triggerType: triggerType,
    triggerTime: DateTime(2026, 4, 20, 10, int.parse(id)),
    status: status,
    location: LocationInfoModel(
      latitude: null,
      longitude: null,
      accuracy: null,
      address: '$patientName street',
      lastUpdated: DateTime(2026, 4, 20, 10, int.parse(id)),
    ),
    resolution: resolution,
  );
}

SOSEventModel _resolvedEvent(
  SOSEventModel current, {
  required String resolutionStatus,
  String? notes,
}) {
  return SOSEventModel(
    id: current.id,
    patient: current.patient,
    triggerType: current.triggerType,
    triggerTime: current.triggerTime,
    status: 'resolved',
    location: current.location,
    fallDetectionXAI: current.fallDetectionXAI,
    resolution: ResolutionInfoModel(
      resolutionStatus: resolutionStatus,
      resolvedBy: 'Caregiver Test',
      resolvedTime: DateTime(2026, 4, 20, 11),
      notes: notes,
    ),
  );
}

Widget _buildApp(_FakeEmergencyCaregiverRepository repository) {
  return ChangeNotifierProvider(
    create: (_) => EmergencyCaregiverProvider(repository),
    child: MaterialApp(
      home: const EmergencySOSReceivedListScreen(enableAutoRefresh: false),
      onGenerateRoute: (settings) {
        final args = settings.arguments as Map<String, dynamic>?;
        if (settings.name == AppRouter.emergencySosDetail) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => EmergencySOSDetailScreen(
              sosId: args?['sosId'] as String? ?? '',
              enableAutoRefresh: false,
            ),
          );
        }
        return null;
      },
    ),
  );
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 3),
  Duration step = const Duration(milliseconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Timed out waiting for $finder');
}

void main() {
  testWidgets(
    'caregiver can search filter open detail resolve and refresh list',
    (tester) async {
      final active = _event(
        id: '1',
        patientName: 'An Nguyen',
        triggerType: 'manual',
        status: 'active',
      );
      final resolved = _event(
        id: '2',
        patientName: 'Binh Tran',
        triggerType: 'vital_critical',
        status: 'resolved',
        resolution: ResolutionInfoModel(
          resolutionStatus: 'assisted',
          resolvedBy: 'Another Caregiver',
          resolvedTime: DateTime(2026, 4, 20, 9),
          notes: 'Handled earlier',
        ),
      );
      final repository = _FakeEmergencyCaregiverRepository(
        initialAlerts: <SOSEventModel>[active, resolved],
      );

      await tester.pumpWidget(_buildApp(repository));
      await _pumpUntilVisible(tester, find.byKey(const ValueKey('sos-card-1')));

      expect(find.byKey(const ValueKey('sos-card-2')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('sos-search-field')),
        'An Nguyen',
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('sos-card-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('sos-card-2')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('sos-search-field')),
        '',
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('sos-filter-resolved')));
      await tester.pump();
      await _pumpUntilVisible(tester, find.byKey(const ValueKey('sos-card-2')));
      expect(find.byKey(const ValueKey('sos-card-1')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('sos-filter-all')));
      await tester.pump();
      await _pumpUntilVisible(tester, find.byKey(const ValueKey('sos-card-1')));

      await tester.tap(find.byKey(const ValueKey('sos-card-1')));
      await tester.pump();
      await _pumpUntilVisible(
        tester,
        find.byKey(const ValueKey('emergency-sos-detail-screen')),
      );

      expect(find.text('Thủ công'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('emergency-sos-detail-resolve-button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('emergency-sos-detail-resolve-button')),
      );
      await tester.pump();
      await _pumpUntilVisible(
        tester,
        find.byKey(const ValueKey('emergency-sos-detail-resolve-dialog')),
      );

      await tester.tap(
        find.byKey(const ValueKey('emergency-sos-detail-resolve-confirm')),
      );
      await tester.pump();
      await _pumpUntilVisible(
        tester,
        find.textContaining('Trạng thái xử lý: safe'),
      );

      expect(repository.resolvedCalls, hasLength(1));

      await tester.pageBack();
      await tester.pumpAndSettle();
      await _pumpUntilVisible(
        tester,
        find.byKey(const ValueKey('emergency-sos-list-screen')),
      );

      await tester.tap(
        find.byKey(const ValueKey('sos-filter-resolved')),
        warnIfMissed: false,
      );
      await tester.pump();
      await _pumpUntilVisible(tester, find.byKey(const ValueKey('sos-card-1')));

      expect(
        repository.requestedStatuses,
        containsAll(<String>['all', 'resolved']),
      );
      expect(repository.requestedDetails, contains('1'));
    },
  );

  // F-9 (G-6): pinned regression for the SOS search-trim fix.
  //
  // Before this fix `_searchController.text.toLowerCase()` was stored as the
  // search query verbatim, so an accidental trailing space (very common on
  // touch keyboards after autocorrect) made the contains() check compare
  // "an nguyen" against "an nguyen " and silently drop every match. QA
  // reported caregivers thinking patients had vanished from the list when
  // the only "bug" was a stray space they couldn't see in the search field.
  //
  // The fix trims the controller text before lowercasing. This test pins
  // that trim by typing the patient name with a trailing space and
  // asserting the matching card stays on screen.
  testWidgets(
    'F-9 (G-6): SOS search trims trailing whitespace so "An Nguyen " '
    'still matches the patient "An Nguyen"',
    (tester) async {
      final active = _event(
        id: '1',
        patientName: 'An Nguyen',
        triggerType: 'manual',
        status: 'active',
      );
      final other = _event(
        id: '2',
        patientName: 'Binh Tran',
        triggerType: 'manual',
        status: 'active',
      );
      final repository = _FakeEmergencyCaregiverRepository(
        initialAlerts: <SOSEventModel>[active, other],
      );

      await tester.pumpWidget(_buildApp(repository));
      await _pumpUntilVisible(tester, find.byKey(const ValueKey('sos-card-1')));

      // Sanity: both cards visible before any search.
      expect(find.byKey(const ValueKey('sos-card-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('sos-card-2')), findsOneWidget);

      // Type the target name with a trailing space — the exact shape of
      // input QA hit on the touch keyboard.
      await tester.enterText(
        find.byKey(const ValueKey('sos-search-field')),
        'An Nguyen ',
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('sos-card-1')),
        findsOneWidget,
        reason:
            'Trailing whitespace must not hide the matching patient. '
            'Without the .trim() in the search listener this expectation '
            'fails because contains("an nguyen ") returns false.',
      );
      expect(
        find.byKey(const ValueKey('sos-card-2')),
        findsNothing,
        reason:
            'Filter still has to actually filter — only the matching '
            'patient should remain after a trimmed-but-real query.',
      );
    },
  );

  testWidgets('shows empty state when caregiver has no SOS alerts', (
    tester,
  ) async {
    final repository = _FakeEmergencyCaregiverRepository(
      initialAlerts: const [],
    );

    await tester.pumpWidget(_buildApp(repository));
    await _pumpUntilVisible(
      tester,
      find.byKey(const ValueKey('sos-list-empty')),
    );

    expect(find.text('Không có SOS nào trong 30 ngày qua'), findsOneWidget);
  });

  testWidgets('shows error state when SOS list fetch fails', (tester) async {
    final repository = _FakeEmergencyCaregiverRepository(
      initialAlerts: const [],
      listError: Exception('Network error'),
    );

    await tester.pumpWidget(_buildApp(repository));
    await _pumpUntilVisible(
      tester,
      find.byKey(const ValueKey('sos-list-error')),
    );

    expect(find.textContaining('Lỗi kết nối mạng'), findsOneWidget);
  });
}
