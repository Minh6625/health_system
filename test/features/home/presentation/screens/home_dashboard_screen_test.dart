import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/device/models/device_model.dart';
import 'package:healthguard/features/home/presentation/screens/home_dashboard_screen.dart';
import 'package:healthguard/features/home/presentation/widgets/connection_status_strip.dart';

void main() {
  group('resolveDashboardConnectionState', () {
    DeviceModel buildDevice({
      required bool isActive,
      required bool isOnline,
      DateTime? lastSyncAt,
    }) {
      return DeviceModel(
        id: 1,
        uuid: 'device-1',
        deviceName: 'Watch 1',
        deviceType: 'smartwatch',
        isActive: isActive,
        isOnline: isOnline,
        lastSyncAt: lastSyncAt,
      );
    }

    test(
      'returns connected when active device is online even if vitals are stale',
      () {
        final now = DateTime(2026, 3, 30, 10, 0, 0);

        final state = resolveDashboardConnectionState(
          activeDevices: [
            buildDevice(
              isActive: true,
              isOnline: true,
              lastSyncAt: now.subtract(const Duration(minutes: 2)),
            ),
          ],
          isStale: true,
          now: now,
        );

        expect(state, DeviceConnectionUiState.connected);
      },
    );

    test(
      'returns connected when active device synced recently even if raw online is false',
      () {
        final now = DateTime(2026, 3, 30, 10, 0, 0);

        final state = resolveDashboardConnectionState(
          activeDevices: [
            buildDevice(
              isActive: true,
              isOnline: false,
              lastSyncAt: now.subtract(const Duration(minutes: 3)),
            ),
          ],
          isStale: true,
          now: now,
        );

        expect(state, DeviceConnectionUiState.connected);
      },
    );

    test(
      'returns offline when active device is stale and not recently synced',
      () {
        final now = DateTime(2026, 3, 30, 10, 0, 0);

        final state = resolveDashboardConnectionState(
          activeDevices: [
            buildDevice(
              isActive: true,
              isOnline: false,
              lastSyncAt: now.subtract(const Duration(minutes: 12)),
            ),
          ],
          isStale: true,
          now: now,
        );

        expect(state, DeviceConnectionUiState.offline);
      },
    );

    test('returns notPaired when there is no active device', () {
      final state = resolveDashboardConnectionState(
        activeDevices: const [],
        isStale: true,
      );

      expect(state, DeviceConnectionUiState.notPaired);
    });
  });
}
