import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/core/constants/api_endpoints.dart';
import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/health_monitoring/models/vital_signs.dart';
import 'package:healthguard/features/health_monitoring/providers/vital_signs_provider.dart';
import 'package:healthguard/features/health_monitoring/repositories/monitoring_repository.dart';

/// Pinned regressions for F-8 (M-9) — stale vitals must not be rendered as
/// if they were live readings.
///
/// Backend ships `is_stale=true` once the latest sample is older than the
/// `VITALS_STALE_AFTER` window (5 minutes today). The mobile UI used to
/// ignore that flag, so a watch that died 30 minutes ago kept painting its
/// final BPM/SpO₂ on the detail screen as if it were current. QA reported
/// users mistaking a dead watch for a healthy device.
///
/// New contract:
///   * `_isVitalsEmpty` returns true when stale → state goes to `empty`,
///     so the screen routes through the empty-data branch and skips the
///     critical-action rail (no false-positive SOS prompt on a dead device).
///   * `extractValue` returns `'--'` (or `'--/--'` for `bp`) when stale.
///   * `extractStatus` returns `VitalStatus.unknown` when stale.
///   * `provider.isStale` exposes the flag so the screen can render a
///     "Thiết bị mất kết nối" sub-message instead of an unexplained dash.
class _FakeApiClient implements ApiClient {
  _FakeApiClient(this._payload);

  final Map<String, dynamic> _payload;
  int callCount = 0;

  @override
  int? targetProfileId;

  @override
  String get baseUrl => 'http://localhost';

  @override
  Future<dynamic> get(
    String path, {
    bool requiresAuth = true,
    Map<String, dynamic>? queryParams,
    int? targetProfileId,
  }) async {
    callCount += 1;
    return _payload;
  }

  // Every other ApiClient surface (post/put/patch/delete/auth helpers) is
  // out of scope for these tests — fail loudly if anything tries to use
  // them so the test never silently mocks real network.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'VitalSignsProvider tests only need ApiClient.get; received '
      '${invocation.memberName}.',
    );
  }
}

// Mirrors a typical "all six channels populated" payload. Tests that need
// a different shape (e.g. the all-null regression) build the map inline
// instead of overloading this helper, which keeps the happy-path call
// sites short and the unusual cases self-documenting.
Map<String, dynamic> _vitalsJson({
  required bool isStale,
  double? heartRate = 88,
  double? spo2 = 97.5,
  double? bpSys = 118,
  double? bpDia = 76,
  String timestamp = '2026-04-19T08:00:00Z',
}) {
  return <String, dynamic>{
    'heart_rate': heartRate,
    'spo2': spo2,
    'temperature': 36.8,
    'respiratory_rate': 16,
    'blood_pressure_sys': bpSys,
    'blood_pressure_dia': bpDia,
    'timestamp': timestamp,
    'is_stale': isStale,
  };
}

VitalSignsProvider _buildProvider({
  required Map<String, dynamic> payload,
  String vitalType = 'hr',
}) {
  return VitalSignsProvider(
    repo: MonitoringRepository(client: _FakeApiClient(payload)),
    vitalType: vitalType,
  );
}

void main() {
  group('VitalSignsProvider stale handling', () {
    test(
        'fresh vitals (is_stale=false) populate state.success with the real '
        'numbers — sanity check that the new stale branch did not break the '
        'happy path', () async {
      final provider = _buildProvider(
        payload: _vitalsJson(isStale: false, heartRate: 88),
      );

      await provider.refresh();

      expect(provider.state, VitalsUIState.success);
      expect(provider.isStale, isFalse);
      expect(provider.value, '88');
      expect(provider.vitalStatus, isNot(VitalStatus.unknown));
    });

    test(
        'stale vitals route through state.empty even when every numeric '
        'field is populated — the watch died, the dashboard must not paint '
        'yesterday\'s 88 BPM as if it were live', () async {
      final provider = _buildProvider(
        payload: _vitalsJson(isStale: true, heartRate: 88, spo2: 97),
      );

      await provider.refresh();

      expect(provider.state, VitalsUIState.empty,
          reason:
              'Stale snapshots must collapse into the empty branch so the '
              'screen swaps in the "Thiết bị mất kết nối" sub-message.');
      expect(provider.isStale, isTrue,
          reason:
              'Screen layer reads this flag to differentiate "stale" from '
              '"never had data" (both share VitalsUIState.empty).');
    });

    test(
        'extractValue("hr") returns "--" when the latest snapshot is stale, '
        'even though heart_rate is non-null', () async {
      final provider = _buildProvider(
        payload: _vitalsJson(isStale: true, heartRate: 88),
        vitalType: 'hr',
      );

      await provider.refresh();

      expect(provider.value, '--',
          reason:
              'A stale 88 BPM rendered as "88" is the exact bug QA hit. '
              'extractValue must short-circuit to the placeholder.');
    });

    test(
        'extractValue("bp") returns "--/--" when stale so the dual-number '
        'placeholder stays consistent', () async {
      final provider = _buildProvider(
        payload: _vitalsJson(isStale: true, bpSys: 130, bpDia: 85),
        vitalType: 'bp',
      );

      await provider.refresh();

      expect(provider.value, '--/--');
    });

    test(
        'extractStatus returns unknown when stale so the SOS rail and '
        'status pill defer to the offline messaging', () async {
      // 88 BPM would normally classify as VitalStatus.normal. If we forgot
      // to gate `extractStatus` on isStale, the screen would paint a green
      // "Bình thường" pill on a dead device — a false negative that masks
      // the disconnect from the user.
      final provider = _buildProvider(
        payload: _vitalsJson(isStale: true, heartRate: 88),
        vitalType: 'hr',
      );

      await provider.refresh();

      expect(provider.vitalStatus, VitalStatus.unknown);
    });

    test(
        'truly empty vitals (all null, not stale) still route to '
        'state.empty but isStale stays false — caller can tell apart "no '
        'device ever paired" from "device went offline"', () async {
      // Inlined because the helper hardcodes temperature/respiratory_rate;
      // the empty-payload test needs every field to be null so it exercises
      // the original `_isVitalsEmpty` branch, not the new isStale branch.
      final provider = _buildProvider(
        payload: <String, dynamic>{
          'heart_rate': null,
          'spo2': null,
          'temperature': null,
          'respiratory_rate': null,
          'blood_pressure_sys': null,
          'blood_pressure_dia': null,
          'timestamp': '2026-04-19T08:00:00Z',
          'is_stale': false,
        },
      );

      await provider.refresh();

      expect(provider.state, VitalsUIState.empty);
      expect(provider.isStale, isFalse,
          reason:
              'Without is_stale the offline sub-message must not show — '
              'the user sees "Chưa có dữ liệu" instead of the misleading '
              '"Thiết bị mất kết nối".');
      expect(provider.value, '--');
      expect(provider.vitalStatus, VitalStatus.unknown);
    });
  });

  // F-12 (M-6) — 24h vitals chart wiring.
  //
  // Pre-fix `VitalSignsProvider.chartData` returned `const []` no matter
  // what, which made the "Biến động 24h qua" card render an empty
  // placeholder forever. These tests pin the new contract:
  //
  //   1. `loadTimeseries()` calls the new repo endpoint and caches the
  //      envelope so `chartData` can extract the channel.
  //   2. `chartData` returns the right Y-series shape per `vitalType`
  //      (1 line for HR/SpO₂/temp/RR, 2 lines for BP).
  //   3. Channel-level nulls are dropped, NOT zero-filled, so a sensor
  //      dropout doesn't render as a flatline cliff.
  //   4. BP sys/dia stay time-aligned — bucket dropped only when both
  //      sides are null.
  //   5. `loadTimeseries()` is idempotent unless `force: true` so the
  //      screen can call it from `startPolling()` without doubling the
  //      network round-trip.
  //   6. Errors from the timeseries call are swallowed (the live tile
  //      is the primary signal; chart placeholder is acceptable
  //      degraded UX) and a later retry is allowed.
  group('VitalSignsProvider 24h chart wiring (F-12)', () {
    test(
        'loadTimeseries() populates chartData for hr — single line of '
        'non-null heart_rate values', () async {
      final fake = _RoutingFakeApiClient(
        latestVitals: _vitalsJson(isStale: false, heartRate: 88),
        timeseries: _timeseriesJson(points: [
          {'ts': '2026-04-19T07:00:00Z', 'heart_rate': 70},
          {'ts': '2026-04-19T07:15:00Z', 'heart_rate': 72},
          {'ts': '2026-04-19T07:30:00Z', 'heart_rate': 88},
        ]),
      );
      final provider = VitalSignsProvider(
        repo: MonitoringRepository(client: fake),
        vitalType: 'hr',
      );

      await provider.loadTimeseries();

      expect(provider.chartData, hasLength(1),
          reason:
              'HR is a single-channel chart; chartData should expose one '
              'line, not two.');
      expect(provider.chartData.first, [70.0, 72.0, 88.0]);
      expect(fake.timeseriesCallCount, 1,
          reason:
              'Repo should hit the timeseries endpoint exactly once for '
              'a fresh load.');
    });

    test(
        'chartData drops null heart_rate buckets instead of zero-filling '
        'them — a watch dropout in bucket 2 must not render as a 0 BPM '
        'cliff that looks like cardiac arrest', () async {
      // Bucket 2 has no HR samples (sensor briefly disconnected). If
      // we converted null → 0 the line would crash from 70 to 0 to 88
      // and the user would see an alarming dip that never happened.
      final fake = _RoutingFakeApiClient(
        latestVitals: _vitalsJson(isStale: false),
        timeseries: _timeseriesJson(points: [
          {'ts': '2026-04-19T07:00:00Z', 'heart_rate': 70},
          {'ts': '2026-04-19T07:15:00Z', 'heart_rate': null},
          {'ts': '2026-04-19T07:30:00Z', 'heart_rate': 88},
        ]),
      );
      final provider = VitalSignsProvider(
        repo: MonitoringRepository(client: fake),
        vitalType: 'hr',
      );

      await provider.loadTimeseries();

      expect(provider.chartData.first, [70.0, 88.0],
          reason:
              'Null buckets must be dropped from the Y-series, not '
              'rendered as 0.');
    });

    test(
        'chartData for bp returns two parallel lines (sys + dia) and '
        'drops a bucket only when both sides are null so the lines stay '
        'time-aligned', () async {
      // Bucket 2: only sys available — drop both sides to keep lines
      //   aligned (a dia-only line of length N-1 vs sys length N would
      //   misalign the X-axis).
      // Bucket 3: both sys and dia null — drop.
      // Bucket 4: both populated — keep.
      final fake = _RoutingFakeApiClient(
        latestVitals: _vitalsJson(isStale: false),
        timeseries: _timeseriesJson(points: [
          {
            'ts': '2026-04-19T07:00:00Z',
            'blood_pressure_sys': 120,
            'blood_pressure_dia': 80,
          },
          {
            'ts': '2026-04-19T07:15:00Z',
            'blood_pressure_sys': 125,
            'blood_pressure_dia': null,
          },
          {
            'ts': '2026-04-19T07:30:00Z',
            'blood_pressure_sys': null,
            'blood_pressure_dia': null,
          },
          {
            'ts': '2026-04-19T07:45:00Z',
            'blood_pressure_sys': 118,
            'blood_pressure_dia': 78,
          },
        ]),
      );
      final provider = VitalSignsProvider(
        repo: MonitoringRepository(client: fake),
        vitalType: 'bp',
      );

      await provider.loadTimeseries();

      expect(provider.chartData, hasLength(2),
          reason: 'BP chart needs sys and dia as two separate lines.');
      expect(provider.chartData[0], [120.0, 118.0],
          reason:
              'Sys line drops bucket 2 (dia missing) and bucket 3 '
              '(both missing) to stay aligned with dia.');
      expect(provider.chartData[1], [80.0, 78.0],
          reason: 'Dia line must have the same length as sys.');
    });

    test(
        'chartData returns const [] when the timeseries response is '
        'empty — keeps the existing placeholder branch alive instead of '
        'crashing the chart with an empty inner list', () async {
      final fake = _RoutingFakeApiClient(
        latestVitals: _vitalsJson(isStale: false),
        timeseries: _timeseriesJson(points: const []),
      );
      final provider = VitalSignsProvider(
        repo: MonitoringRepository(client: fake),
        vitalType: 'hr',
      );

      await provider.loadTimeseries();

      expect(provider.chartData, isEmpty);
    });

    test(
        'loadTimeseries() is idempotent — a second call without force '
        'must not re-hit the network. The screen calls this from '
        'startPolling() so a route rebuild should not double-fetch.',
        () async {
      final fake = _RoutingFakeApiClient(
        latestVitals: _vitalsJson(isStale: false),
        timeseries: _timeseriesJson(points: [
          {'ts': '2026-04-19T07:00:00Z', 'heart_rate': 70},
        ]),
      );
      final provider = VitalSignsProvider(
        repo: MonitoringRepository(client: fake),
        vitalType: 'hr',
      );

      await provider.loadTimeseries();
      await provider.loadTimeseries();

      expect(fake.timeseriesCallCount, 1,
          reason:
              'Idempotent guard (_hasLoadedTimeseries) must short-circuit '
              'the second call so we do not hammer TimescaleDB.');
    });

    test(
        'loadTimeseries(force: true) bypasses the idempotent guard so '
        'pull-to-refresh actually re-pulls fresh chart data', () async {
      final fake = _RoutingFakeApiClient(
        latestVitals: _vitalsJson(isStale: false),
        timeseries: _timeseriesJson(points: [
          {'ts': '2026-04-19T07:00:00Z', 'heart_rate': 70},
        ]),
      );
      final provider = VitalSignsProvider(
        repo: MonitoringRepository(client: fake),
        vitalType: 'hr',
      );

      await provider.loadTimeseries();
      await provider.loadTimeseries(force: true);

      expect(fake.timeseriesCallCount, 2,
          reason:
              'force=true must override the cache so refresh() can '
              'replace the chart axis with whatever the user just saw '
              'on their watch.');
    });

    test(
        'loadTimeseries() swallows errors and resets to empty so the '
        'chart placeholder stays correct AND a later retry is allowed', () async {
      final fake = _RoutingFakeApiClient(
        latestVitals: _vitalsJson(isStale: false),
        timeseries: null, // null payload → repo-level cast throws.
        throwOnTimeseries: true,
      );
      final provider = VitalSignsProvider(
        repo: MonitoringRepository(client: fake),
        vitalType: 'hr',
      );

      await provider.loadTimeseries();

      expect(provider.chartData, isEmpty,
          reason:
              'A failed fetch must leave the chart in the empty-state '
              'so the screen falls through to the placeholder.');
      expect(fake.timeseriesCallCount, 1);

      // Now flip the fake to succeed and verify a non-forced retry runs
      // (proves _hasLoadedTimeseries was NOT set on the failure path).
      fake.throwOnTimeseries = false;
      fake.timeseries = _timeseriesJson(points: [
        {'ts': '2026-04-19T07:00:00Z', 'heart_rate': 99},
      ]);

      await provider.loadTimeseries();

      expect(fake.timeseriesCallCount, 2,
          reason:
              'Failed loads must not flip _hasLoadedTimeseries=true, '
              'otherwise the screen could never recover from a transient '
              'backend hiccup without a hard reload.');
      expect(provider.chartData.first, [99.0]);
    });
  });
}

// F-12 (M-6) test infra — path-aware fake that returns one payload for
// `/metrics/vital-signs/latest` and a different one for
// `/metrics/vitals/timeseries`. The simpler `_FakeApiClient` above
// returns the same payload for every path, which works for the stale
// tests but would feed the timeseries decoder a vitals-shaped map.
class _RoutingFakeApiClient implements ApiClient {
  _RoutingFakeApiClient({
    required this.latestVitals,
    required this.timeseries,
    this.throwOnTimeseries = false,
  });

  Map<String, dynamic> latestVitals;
  Map<String, dynamic>? timeseries;
  bool throwOnTimeseries;

  int latestVitalsCallCount = 0;
  int timeseriesCallCount = 0;

  @override
  int? targetProfileId;

  @override
  String get baseUrl => 'http://localhost';

  @override
  Future<dynamic> get(
    String path, {
    bool requiresAuth = true,
    Map<String, dynamic>? queryParams,
    int? targetProfileId,
  }) async {
    if (path == ApiEndpoints.vitalsTimeseries) {
      timeseriesCallCount += 1;
      if (throwOnTimeseries) {
        throw StateError('simulated timeseries failure');
      }
      return timeseries;
    }
    if (path == ApiEndpoints.latestVitals) {
      latestVitalsCallCount += 1;
      return latestVitals;
    }
    throw UnsupportedError('Unexpected path in _RoutingFakeApiClient: $path');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'F-12 chart tests only need ApiClient.get; received '
      '${invocation.memberName}.',
    );
  }
}

// Builds a `/metrics/vitals/timeseries` envelope with the supplied
// channel-level points. Defaults match the backend's 24h/15min config.
Map<String, dynamic> _timeseriesJson({
  required List<Map<String, dynamic>> points,
  String range = '24h',
  int bucketMinutes = 15,
}) {
  return <String, dynamic>{
    'range': range,
    'bucket_minutes': bucketMinutes,
    'data': points,
  };
}
