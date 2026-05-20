import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/family/models/recent_alert_item.dart';
import 'package:healthguard/features/family/repositories/family_repository.dart';
import 'package:healthguard/features/family/widgets/alert_history_section.dart';

class _FakeRepository extends FamilyRepository {
  _FakeRepository();

  RecentAlertsResponse? response;
  Object? error;

  @override
  Future<RecentAlertsResponse> fetchRecentAlerts(
    int patientUserId, {
    int days = 7,
    int limit = 10,
  }) async {
    if (error != null) throw error!;
    return response ??
        RecentAlertsResponse(
          items: const <RecentAlertItem>[],
          windowDays: days,
          totalInWindow: 0,
        );
  }
}

RecentAlertItem _alertFixture({
  String uuid = 'uuid-1',
  String title = 'Cảnh báo sức khoẻ',
  String? message = 'Risk score 72',
  RecentAlertSeverity severity = RecentAlertSeverity.high,
  RecentAlertType type = RecentAlertType.riskHigh,
}) {
  return RecentAlertItem(
    id: 1,
    uuid: uuid,
    alertType: type,
    rawAlertType: 'risk_high',
    severity: severity,
    rawSeverity: 'high',
    title: title,
    message: message,
    occurredAt: DateTime.utc(2026, 5, 20, 9, 0),
  );
}

Future<void> _settle(WidgetTester tester) async {
  // pump() to flush the post-frame load(), pumpAndSettle to drain async.
  await tester.pump();
  await tester.pumpAndSettle();
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('AlertHistorySection', () {
    testWidgets('granted+empty: shows quiet-window empty state', (tester) async {
      final repo = _FakeRepository()
        ..response = RecentAlertsResponse(
          items: const <RecentAlertItem>[],
          windowDays: 7,
          totalInWindow: 0,
        );

      await tester.pumpWidget(
        _wrap(
          AlertHistorySection(
            profileId: '42',
            firstName: 'Bố An',
            repositoryOverride: repo,
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('Chưa có cảnh báo gần đây'), findsOneWidget);
      expect(find.textContaining('Bố An'), findsOneWidget);
    });

    testWidgets('granted+items: renders one card per alert', (tester) async {
      final repo = _FakeRepository()
        ..response = RecentAlertsResponse(
          items: [
            _alertFixture(uuid: 'a', title: 'Cảnh báo 1'),
            _alertFixture(uuid: 'b', title: 'Cảnh báo 2'),
            _alertFixture(uuid: 'c', title: 'Cảnh báo 3'),
          ],
          windowDays: 7,
          totalInWindow: 3,
        );

      await tester.pumpWidget(
        _wrap(
          AlertHistorySection(
            profileId: '42',
            firstName: 'Bố An',
            repositoryOverride: repo,
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('Cảnh báo 1'), findsOneWidget);
      expect(find.text('Cảnh báo 2'), findsOneWidget);
      expect(find.text('Cảnh báo 3'), findsOneWidget);
      expect(find.text('Chưa có cảnh báo gần đây'), findsNothing);
    });

    testWidgets('permission denied: shows the dedicated banner', (tester) async {
      final repo = _FakeRepository()
        ..error = const RecentAlertsPermissionDeniedException(
          'You do not have permission',
        );

      await tester.pumpWidget(
        _wrap(
          AlertHistorySection(
            profileId: '42',
            firstName: 'Bố An',
            repositoryOverride: repo,
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('Chưa được chia sẻ cảnh báo'), findsOneWidget);
      expect(find.textContaining('Quyền chia sẻ'), findsOneWidget);
      // Should NOT show empty/granted copy in this state.
      expect(find.text('Chưa có cảnh báo gần đây'), findsNothing);
    });

    testWidgets('generic error: shows inline retry button', (tester) async {
      final repo = _FakeRepository()..error = Exception('boom');

      await tester.pumpWidget(
        _wrap(
          AlertHistorySection(
            profileId: '42',
            firstName: 'Bố An',
            repositoryOverride: repo,
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('Không tải được cảnh báo gần đây'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('non-numeric profileId surfaces error state, not crash',
        (tester) async {
      // The provider guards against non-numeric ids — important because the
      // dashboard occasionally returns synthetic placeholder ids during the
      // first frame after login.
      final repo = _FakeRepository();

      await tester.pumpWidget(
        _wrap(
          AlertHistorySection(
            profileId: 'NaN',
            firstName: 'Bố An',
            repositoryOverride: repo,
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('Không tải được cảnh báo gần đây'), findsOneWidget);
    });
  });
}
