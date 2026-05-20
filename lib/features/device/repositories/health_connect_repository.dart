// lib/features/device/repositories/health_connect_repository.dart
//
// Bridges the Flutter [HealthConnectService] (Phase 2 OS adapter) with
// the backend ingest endpoint introduced in the same phase.
//
// Responsibility split:
//   * [HealthConnectService] reads raw [HealthVitalReading] points.
//   * This repository groups those points into per-second
//     [MobileVitalSample] records the backend can store, then POSTs them
//     in one batch to `/metrics/vitals/ingest`.
//
// Grouping logic: Health Connect emits one point per channel per
// timestamp, but the `vitals` hypertable's primary key is
// `(device_id, time)`, so we coalesce all channels that fall on the
// same second into a single sample. This keeps the backend payload
// small and avoids redundant ON CONFLICT noise.

import 'dart:convert';

import 'package:health/health.dart';

import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/core/services/health_connect_service.dart';

class HealthConnectIngestResult {
  final int accepted;
  final int rejected;
  final int sentSamples;
  final List<int> riskEvaluatedDevices;

  const HealthConnectIngestResult({
    required this.accepted,
    required this.rejected,
    required this.sentSamples,
    required this.riskEvaluatedDevices,
  });

  bool get hadRejections => rejected > 0;
}

class HealthConnectRepository {
  HealthConnectRepository({
    HealthConnectService? service,
    ApiClient? apiClient,
  })  : _service = service ?? HealthConnectService.instance,
        _apiClient = apiClient ?? ApiClient();

  final HealthConnectService _service;
  final ApiClient _apiClient;

  /// Read everything from Health Connect since [since], collapse it into
  /// per-second [MobileVitalSample]s, and POST to the backend. Returns
  /// the boundary response so the provider can update lastSyncAt and
  /// surface counts in the UI.
  Future<HealthConnectIngestResult> syncSince({
    required int deviceId,
    required DateTime since,
    DateTime? now,
  }) async {
    final readings = await _service.readSince(since: since, now: now);
    if (readings.isEmpty) {
      return const HealthConnectIngestResult(
        accepted: 0,
        rejected: 0,
        sentSamples: 0,
        riskEvaluatedDevices: [],
      );
    }

    final samples = _groupReadings(readings);
    if (samples.isEmpty) {
      return const HealthConnectIngestResult(
        accepted: 0,
        rejected: 0,
        sentSamples: 0,
        riskEvaluatedDevices: [],
      );
    }

    // Cap each request at 1000 samples to match the backend
    // MobileVitalsBatch.max_length contract. Larger windows are split
    // into multiple posts and counts aggregated.
    const batchSize = 1000;
    var accepted = 0;
    var rejected = 0;
    final riskDevices = <int>{};

    for (var start = 0; start < samples.length; start += batchSize) {
      final end = (start + batchSize).clamp(0, samples.length);
      final chunk = samples.sublist(start, end);
      final body = {
        'device_id': deviceId,
        'samples': chunk.map((s) => s.toJson()).toList(),
      };
      final response = await _apiClient.post(
        '/metrics/vitals/ingest',
        body: body,
        requiresAuth: true,
      );
      if (response is Map<String, dynamic>) {
        accepted += (response['accepted'] as num?)?.toInt() ?? 0;
        rejected += (response['rejected'] as num?)?.toInt() ?? 0;
        final risk = response['risk_evaluated_devices'] as List?;
        if (risk != null) {
          riskDevices.addAll(
            risk.whereType<num>().map((v) => v.toInt()),
          );
        }
      }
    }

    return HealthConnectIngestResult(
      accepted: accepted,
      rejected: rejected,
      sentSamples: samples.length,
      riskEvaluatedDevices: riskDevices.toList(),
    );
  }

  /// Group readings by their second-precision timestamp into the schema
  /// the backend expects. We deliberately bucket on `dateFrom` (start)
  /// because Health Connect stores HR / SpO2 as instantaneous points
  /// where dateFrom == dateTo, and bucketing on the start keeps sleep /
  /// blood pressure samples aligned with the channels measured at the
  /// same moment.
  List<_MobileSample> _groupReadings(List<HealthVitalReading> readings) {
    final byBucket = <DateTime, _MobileSample>{};
    for (final r in readings) {
      final bucket = DateTime.fromMillisecondsSinceEpoch(
        r.startTime.millisecondsSinceEpoch ~/ 1000 * 1000,
        isUtc: r.startTime.isUtc,
      ).toUtc();
      final sample = byBucket.putIfAbsent(
        bucket,
        () => _MobileSample(timestamp: bucket),
      );
      _applyReading(sample, r);
    }
    return byBucket.values.where(_MobileSample.hasClinicalSignal).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  void _applyReading(_MobileSample sample, HealthVitalReading r) {
    switch (r.type) {
      case HealthDataType.HEART_RATE:
        sample.heartRate = r.value;
        break;
      case HealthDataType.BLOOD_OXYGEN:
        sample.spo2 = r.value;
        break;
      case HealthDataType.BODY_TEMPERATURE:
        sample.temperature = r.value;
        break;
      case HealthDataType.RESPIRATORY_RATE:
        sample.respiratoryRate = r.value;
        break;
      case HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
        sample.bloodPressureSys = r.value.round();
        break;
      case HealthDataType.BLOOD_PRESSURE_DIASTOLIC:
        sample.bloodPressureDia = r.value.round();
        break;
      default:
        // Steps / Sleep are not part of the vitals hypertable schema —
        // they will land in their own ingest path in a later phase.
        break;
    }
  }
}

class _MobileSample {
  _MobileSample({required this.timestamp});

  final DateTime timestamp;
  double? heartRate;
  double? spo2;
  double? temperature;
  double? respiratoryRate;
  int? bloodPressureSys;
  int? bloodPressureDia;

  static bool hasClinicalSignal(_MobileSample s) =>
      s.heartRate != null || s.spo2 != null;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'timestamp': timestamp.toUtc().toIso8601String(),
      'source': 'health_connect',
    };
    if (heartRate != null) map['heart_rate'] = heartRate;
    if (spo2 != null) map['spo2'] = spo2;
    if (temperature != null) map['temperature'] = temperature;
    if (respiratoryRate != null) map['respiratory_rate'] = respiratoryRate;
    if (bloodPressureSys != null) map['blood_pressure_sys'] = bloodPressureSys;
    if (bloodPressureDia != null) map['blood_pressure_dia'] = bloodPressureDia;
    return map;
  }

  @override
  String toString() => jsonEncode(toJson());
}
