// ignore_for_file: avoid_print

// 📦 device_mock_data.dart
// Centralized mock/demo data for DEVICE module screens.
//
// Usage:
//   - [DeviceConnectProvider] → uses [MockBleDiscovery.nearbyDevices]
//   - [DeviceStatusDetailProvider] (mock mode) → uses [DeviceMockSnapshots]
//
// ⚙️  To enable mock mode:
//   Set `MOCK_DEVICE=true` in `.env.*`
//
// ⚠️  DEMO NOTE
//   BLE discovery is being mocked to demonstrate the connection UX.
//   This is NOT a real BLE integration. Device data continues to come
//   from the Python IoT simulator via MQTT/HTTP.

import 'package:healthguard/features/device/models/device_model.dart';


// ---------------------------------------------------------------------------
// 1. Global mock config flag
// ---------------------------------------------------------------------------

enum MockListScenario {
  normal,
  empty,
  error,
  allOffline,
}

class DeviceMockConfig {
  DeviceMockConfig._();

  /// Set to [true] to use local mock instead of real API calls.
  /// In production builds this should be [false].
  static bool useMockData = false; // ✅ Using live API data from backend

  /// Simulated network delay for mock API calls (ms).
  static const int fakeApiDelayMs = 800;

  /// Simulated BLE pairing delay (ms).
  static const int fakePairingDelayMs = 2500;

  /// Choose which list scenario to demo. Change to [empty] or [error] to test edge cases.
  static MockListScenario listScenario = MockListScenario.normal;
}

// ---------------------------------------------------------------------------
// 2. BLE Device + Discovery mock list  (used by DeviceConnectProvider)
// ---------------------------------------------------------------------------

/// A mock BLE device discovered during a scan.
class MockBleDevice {
  final String id;
  final String name;
  final String macAddress;
  final String deviceType;
  final int rssi;

  MockBleDevice({
    required this.id,
    required this.name,
    required this.macAddress,
    required this.deviceType,
    required this.rssi,
  });
}

class MockBleDiscovery {
  MockBleDiscovery._();

  /// Nearby BLE devices that will appear progressively during a mock scan.
  /// Each entry carries an [appearsAtSecond] so the scan timer knows WHEN
  /// to surface each device (counting down from 30s).
  static final List<MockBleDiscoveryEntry> nearbyDevices = [
    MockBleDiscoveryEntry(
      device: MockBleDevice(
        id: 'demo-ble-001',
        name: 'VSmart Watch A1',
        macAddress: 'AA:BB:CC:11:22:33',
        deviceType: 'smartwatch',
        rssi: -58,
      ),
      appearsAtSecond: 28, // appears ~2s after scan starts (30-28=2s elapsed)
    ),
    MockBleDiscoveryEntry(
      device: MockBleDevice(
        id: 'demo-ble-002',
        name: 'Health Band B2',
        macAddress: 'DD:EE:FF:44:55:66',
        deviceType: 'fitness_band',
        rssi: -67,
      ),
      appearsAtSecond: 25, // appears ~5s after scan starts
    ),
    MockBleDiscoveryEntry(
      device: MockBleDevice(
        id: 'demo-ble-003',
        name: 'VSmartwatch Pro',
        macAddress: '11:22:33:AA:BB:CC',
        deviceType: 'smartwatch',
        rssi: -72,
      ),
      appearsAtSecond: 20, // appears ~10s after scan starts
    ),
  ];
}

class MockBleDiscoveryEntry {
  final MockBleDevice device;

  /// The scan countdown value at which this device should appear.
  /// (Countdown runs 30 → 0; a lower value means it appears later.)
  final int appearsAtSecond;

  const MockBleDiscoveryEntry({
    required this.device,
    required this.appearsAtSecond,
  });
}

// ---------------------------------------------------------------------------
// 3. DeviceModel Snapshots  (used by DeviceStatusDetailProvider mock mode)
// ---------------------------------------------------------------------------

/// Pre-built [DeviceModel] objects for UI preview / demo.
class DeviceMockSnapshots {
  DeviceMockSnapshots._();

  static final DateTime _now = DateTime.now();

  // ── 3a. Normal / healthy device ──────────────────────────────────────────
  static final DeviceModel normalDevice = DeviceModel(
    id: 101,
    uuid: 'uuid-demo-101',
    deviceName: 'VSmart Watch A1',
    deviceType: 'smartwatch',
    model: 'A1',
    firmwareVersion: '1.0.3',
    macAddress: 'AA:BB:CC:11:22:33',
    serialNumber: 'VS-A1-2026-0001',
    mqttClientId: 'device-101',
    isActive: true,
    isOnline: true,
    batteryLevel: 67,
    signalStrength: -58,
    lastSyncAt: _now.subtract(const Duration(minutes: 5)),
    lastSeenAt: _now.subtract(const Duration(minutes: 4)),
    registeredAt: _now.subtract(const Duration(days: 30)),
  );

  // ── 3b. Low battery device (< 20%) ───────────────────────────────────────
  static final DeviceModel lowBatteryDevice = DeviceModel(
    id: 102,
    uuid: 'uuid-demo-102',
    deviceName: 'Health Band B2',
    deviceType: 'fitness_band',
    model: 'B2',
    firmwareVersion: '2.1.0',
    macAddress: 'DD:EE:FF:44:55:66',
    serialNumber: 'HB-B2-2026-0002',
    mqttClientId: 'device-102',
    isActive: true,
    isOnline: true,
    batteryLevel: 12, // ← triggers low-battery banner
    signalStrength: -67,
    lastSyncAt: _now.subtract(const Duration(hours: 1)),
    lastSeenAt: _now.subtract(const Duration(hours: 1)),
    registeredAt: _now.subtract(const Duration(days: 15)),
  );

  // ── 3c. Offline device ───────────────────────────────────────────────────
  static final DeviceModel offlineDevice = DeviceModel(
    id: 103,
    uuid: 'uuid-demo-103',
    deviceName: 'VSmartwatch Pro',
    deviceType: 'smartwatch',
    model: 'Pro',
    firmwareVersion: '1.5.2',
    macAddress: '11:22:33:AA:BB:CC',
    serialNumber: 'VS-PRO-2026-0003',
    mqttClientId: 'device-103',
    isActive: true,
    isOnline: false, // ← triggers offline banner
    batteryLevel: 45,
    signalStrength: null,
    lastSyncAt: _now.subtract(const Duration(hours: 6)),
    lastSeenAt: _now.subtract(const Duration(hours: 5, minutes: 30)),
    registeredAt: _now.subtract(const Duration(days: 60)),
  );

  // ── 3d. Critically low battery + offline ─────────────────────────────────
  static final DeviceModel criticalDevice = DeviceModel(
    id: 104,
    uuid: 'uuid-demo-104',
    deviceName: 'Medical Sensor C3',
    deviceType: 'medical_device',
    model: 'C3',
    firmwareVersion: null,       // missing firmware → shows "--"
    macAddress: null,            // missing MAC → shows "--"
    serialNumber: null,
    mqttClientId: 'device-104',
    isActive: true,
    isOnline: false,
    batteryLevel: 5,             // critically low
    signalStrength: null,
    lastSyncAt: _now.subtract(const Duration(days: 1)),
    lastSeenAt: _now.subtract(const Duration(days: 1)),
    registeredAt: _now.subtract(const Duration(days: 7)),
  );

  // ── 3e. Device with missing optional fields ───────────────────────────────
  /// Tests graceful "--" / "Chưa có" rendering in the technical info section.
  static final DeviceModel sparseDevice = DeviceModel(
    id: 105,
    uuid: 'uuid-demo-105',
    deviceName: null,           // falls back to displayName "Thiet bi #105"
    deviceType: 'smartwatch',
    model: null,
    firmwareVersion: null,
    macAddress: null,
    serialNumber: null,
    mqttClientId: null,
    isActive: true,
    isOnline: true,
    batteryLevel: null,         // shows "--"
    signalStrength: null,
    lastSyncAt: null,           // shows "Chưa có"
    lastSeenAt: null,
    registeredAt: null,
  );

  // ── Helper: get by demo ID ────────────────────────────────────────────────
  /// Returns the matching snapshot or [normalDevice] as the default.
  static DeviceModel getById(int id) {
    switch (id) {
      case 101:
        return normalDevice;
      case 102:
        return lowBatteryDevice;
      case 103:
        return offlineDevice;
      case 104:
        return criticalDevice;
      case 105:
        return sparseDevice;
      default:
        return normalDevice;
    }
  }

  /// All snapshots, useful for a preview/demo gallery.
  static List<DeviceModel> get all => [
        normalDevice,
        lowBatteryDevice,
        offlineDevice,
        criticalDevice,
        sparseDevice,
      ];
}
