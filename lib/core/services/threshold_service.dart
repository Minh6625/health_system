import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:healthguard/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single-source-of-truth clinical thresholds fetched from the BE
/// ``GET /api/v1/mobile/settings/thresholds`` endpoint.
///
/// The BE projects values from
/// ``Iot_Simulator_clean/pre_model_trigger/health_rules/rules_config.json``
/// so backend, simulator and mobile share one set of cut-offs.
///
/// Strategy:
/// - On first app launch the service fetches the endpoint and caches the
///   payload in SharedPreferences.
/// - Subsequent launches surface the cached values immediately while the
///   service refreshes in the background.
/// - When the network is unreachable the built-in defaults (snapshotted
///   from rules_config v2.0.0) keep the UI usable.
class HeartRateThresholds {
  final double urgentLow;
  final double sendLow;
  final double watchHigh;
  final double sendHigh;
  final double urgentHigh;

  const HeartRateThresholds({
    required this.urgentLow,
    required this.sendLow,
    required this.watchHigh,
    required this.sendHigh,
    required this.urgentHigh,
  });

  factory HeartRateThresholds.fromJson(Map<String, dynamic> json) {
    return HeartRateThresholds(
      urgentLow: (json['urgent_low'] as num).toDouble(),
      sendLow: (json['send_low'] as num).toDouble(),
      watchHigh: (json['watch_high'] as num).toDouble(),
      sendHigh: (json['send_high'] as num).toDouble(),
      urgentHigh: (json['urgent_high'] as num).toDouble(),
    );
  }
}

class Spo2Thresholds {
  final double urgentLow;
  final double sendLow;
  final double watchLow;

  const Spo2Thresholds({
    required this.urgentLow,
    required this.sendLow,
    required this.watchLow,
  });

  factory Spo2Thresholds.fromJson(Map<String, dynamic> json) {
    return Spo2Thresholds(
      urgentLow: (json['urgent_low'] as num).toDouble(),
      sendLow: (json['send_low'] as num).toDouble(),
      watchLow: (json['watch_low'] as num).toDouble(),
    );
  }
}

class BodyTempThresholds {
  final double urgentLow;
  final double sendLow;
  final double watchHigh;
  final double sendHigh;
  final double urgentHigh;

  const BodyTempThresholds({
    required this.urgentLow,
    required this.sendLow,
    required this.watchHigh,
    required this.sendHigh,
    required this.urgentHigh,
  });

  factory BodyTempThresholds.fromJson(Map<String, dynamic> json) {
    return BodyTempThresholds(
      urgentLow: (json['urgent_low'] as num).toDouble(),
      sendLow: (json['send_low'] as num).toDouble(),
      watchHigh: (json['watch_high'] as num).toDouble(),
      sendHigh: (json['send_high'] as num).toDouble(),
      urgentHigh: (json['urgent_high'] as num).toDouble(),
    );
  }
}

class RespRateThresholds {
  final double urgentLow;
  final double watchHigh;
  final double sendHigh;
  final double urgentHigh;

  const RespRateThresholds({
    required this.urgentLow,
    required this.watchHigh,
    required this.sendHigh,
    required this.urgentHigh,
  });

  factory RespRateThresholds.fromJson(Map<String, dynamic> json) {
    return RespRateThresholds(
      urgentLow: (json['urgent_low'] as num).toDouble(),
      watchHigh: (json['watch_high'] as num).toDouble(),
      sendHigh: (json['send_high'] as num).toDouble(),
      urgentHigh: (json['urgent_high'] as num).toDouble(),
    );
  }
}

class SysBpThresholds {
  final double urgentLow;
  final double sendLow;
  final double watchHigh;
  final double sendHigh;
  final double urgentHigh;

  const SysBpThresholds({
    required this.urgentLow,
    required this.sendLow,
    required this.watchHigh,
    required this.sendHigh,
    required this.urgentHigh,
  });

  factory SysBpThresholds.fromJson(Map<String, dynamic> json) {
    return SysBpThresholds(
      urgentLow: (json['urgent_low'] as num).toDouble(),
      sendLow: (json['send_low'] as num).toDouble(),
      watchHigh: (json['watch_high'] as num).toDouble(),
      sendHigh: (json['send_high'] as num).toDouble(),
      urgentHigh: (json['urgent_high'] as num).toDouble(),
    );
  }
}

class DiaBpThresholds {
  final double watchHigh;
  final double sendHigh;
  final double urgentHigh;

  const DiaBpThresholds({
    required this.watchHigh,
    required this.sendHigh,
    required this.urgentHigh,
  });

  factory DiaBpThresholds.fromJson(Map<String, dynamic> json) {
    return DiaBpThresholds(
      watchHigh: (json['watch_high'] as num).toDouble(),
      sendHigh: (json['send_high'] as num).toDouble(),
      urgentHigh: (json['urgent_high'] as num).toDouble(),
    );
  }
}

class ThresholdConfig {
  final String version;
  final HeartRateThresholds heartRate;
  final Spo2Thresholds spo2;
  final BodyTempThresholds bodyTemp;
  final RespRateThresholds respRate;
  final SysBpThresholds sysBp;
  final DiaBpThresholds diaBp;

  const ThresholdConfig({
    required this.version,
    required this.heartRate,
    required this.spo2,
    required this.bodyTemp,
    required this.respRate,
    required this.sysBp,
    required this.diaBp,
  });

  /// Built-in defaults snapshotted from rules_config v2.0.0 so the app
  /// works offline before the first /settings/thresholds fetch.
  static const ThresholdConfig defaults = ThresholdConfig(
    version: '2.0.0-default',
    heartRate: HeartRateThresholds(
      urgentLow: 40,
      sendLow: 50,
      watchHigh: 110,
      sendHigh: 130,
      urgentHigh: 131,
    ),
    spo2: Spo2Thresholds(urgentLow: 90, sendLow: 94, watchLow: 95),
    bodyTemp: BodyTempThresholds(
      urgentLow: 35.0,
      sendLow: 36.0,
      watchHigh: 37.5,
      sendHigh: 39.0,
      urgentHigh: 39.1,
    ),
    respRate: RespRateThresholds(
      urgentLow: 8,
      watchHigh: 20,
      sendHigh: 24,
      urgentHigh: 25,
    ),
    sysBp: SysBpThresholds(
      urgentLow: 90,
      sendLow: 100,
      watchHigh: 139,
      sendHigh: 140,
      urgentHigh: 180,
    ),
    diaBp: DiaBpThresholds(watchHigh: 89, sendHigh: 90, urgentHigh: 120),
  );

  factory ThresholdConfig.fromJson(Map<String, dynamic> json) {
    final vitals = json['vitals'] as Map<String, dynamic>;
    return ThresholdConfig(
      version: (json['version'] as String?) ?? defaults.version,
      heartRate: HeartRateThresholds.fromJson(
        vitals['heart_rate'] as Map<String, dynamic>,
      ),
      spo2: Spo2Thresholds.fromJson(vitals['spo2'] as Map<String, dynamic>),
      bodyTemp: BodyTempThresholds.fromJson(
        vitals['body_temp'] as Map<String, dynamic>,
      ),
      respRate: RespRateThresholds.fromJson(
        vitals['resp_rate'] as Map<String, dynamic>,
      ),
      sysBp: SysBpThresholds.fromJson(
        vitals['sys_bp'] as Map<String, dynamic>,
      ),
      diaBp: DiaBpThresholds.fromJson(
        vitals['dia_bp'] as Map<String, dynamic>,
      ),
    );
  }
}

/// Fetches + caches the BE threshold contract.
///
/// Intentionally singleton-style so any widget can call
/// ``ThresholdService.instance.config`` synchronously after
/// ``initialize()`` has run during app start.
class ThresholdService {
  ThresholdService._({ApiClient? apiClient}) : _apiClient = apiClient;

  static final ThresholdService _instance = ThresholdService._();

  factory ThresholdService() => _instance;

  static ThresholdService get instance => _instance;

  static const String _prefsKey = 'threshold_config_cache_v1';
  static const String _endpoint = '/settings/thresholds';

  final ApiClient? _apiClient;

  ThresholdConfig _config = ThresholdConfig.defaults;
  bool _initialized = false;

  ThresholdConfig get config => _config;
  bool get isInitialized => _initialized;

  /// Load cached config from SharedPreferences (synchronous-ish,
  /// awaited once during app start), then kick off a background
  /// refresh. The caller does NOT need to await the refresh — UI
  /// renders immediately with the cached / default config.
  Future<void> initialize({ApiClient? apiClient}) async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_prefsKey);
      if (cached != null && cached.isNotEmpty) {
        try {
          final parsed = jsonDecode(cached) as Map<String, dynamic>;
          _config = ThresholdConfig.fromJson(parsed);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('ThresholdService cache parse error: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ThresholdService prefs read error: $e');
      }
    }

    // Fire-and-forget refresh from BE.
    unawaited(refresh(apiClient: apiClient));
  }

  /// Fetch the latest config from BE and update the in-memory + cached copy.
  ///
  /// Errors are swallowed (logged in debug mode) — the UI keeps using
  /// the previous config so a transient outage does not blank the
  /// vital cards.
  Future<void> refresh({ApiClient? apiClient}) async {
    final client = apiClient ?? _apiClient ?? ApiClient();
    try {
      final result = await client.get(_endpoint, requiresAuth: false);
      if (result is! Map<String, dynamic>) {
        return;
      }
      final next = ThresholdConfig.fromJson(result);
      _config = next;

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, jsonEncode(result));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('ThresholdService prefs write error: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ThresholdService refresh failed: $e');
      }
    }
  }
}
