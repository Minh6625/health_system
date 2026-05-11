/// F-12 (M-6): vitals time-series payload returned by
/// `/metrics/vitals/timeseries`.
///
/// Each [VitalsTimeseriesPoint] is one downsampled bucket; the chart on
/// `vital_detail_screen.dart` reads a single channel (heart_rate / spo2 /
/// bp / temp / rr) per bucket. Channel-level `null` means the sensor had
/// no samples in that bucket — the chart MUST treat it as a gap, not a
/// zero, otherwise the line would crash to the floor every time the
/// device disconnects mid-interval.
class VitalsTimeseriesPoint {
  const VitalsTimeseriesPoint({
    required this.timestamp,
    this.heartRate,
    this.spo2,
    this.temperature,
    this.respiratoryRate,
    this.bloodPressureSys,
    this.bloodPressureDia,
  });

  final DateTime timestamp;
  final double? heartRate;
  final double? spo2;
  final double? temperature;
  final double? respiratoryRate;
  final double? bloodPressureSys;
  final double? bloodPressureDia;

  factory VitalsTimeseriesPoint.fromJson(Map<String, dynamic> json) {
    final ts = json['ts'];
    DateTime parsed;
    if (ts is DateTime) {
      parsed = ts.toLocal();
    } else {
      // Backend serialises bucket timestamps in UTC; without `.toLocal()`
      // the chart would label all points in UTC and Vietnamese users
      // would see a 7-hour offset from the live "Bây giờ" anchor.
      parsed = DateTime.parse(ts.toString()).toLocal();
    }

    double? toDouble(Object? raw) {
      if (raw == null) return null;
      if (raw is num) return raw.toDouble();
      return null;
    }

    return VitalsTimeseriesPoint(
      timestamp: parsed,
      heartRate: toDouble(json['heart_rate']),
      spo2: toDouble(json['spo2']),
      temperature: toDouble(json['temperature']),
      respiratoryRate: toDouble(json['respiratory_rate']),
      bloodPressureSys: toDouble(json['blood_pressure_sys']),
      bloodPressureDia: toDouble(json['blood_pressure_dia']),
    );
  }
}

/// Envelope that wraps the bucketed [VitalsTimeseriesPoint] list with
/// the metadata the chart needs to label its X-axis (which range, how
/// many minutes per bucket).
class VitalsTimeseries {
  const VitalsTimeseries({
    required this.range,
    required this.bucketMinutes,
    required this.data,
  });

  /// Echoes the validated server range. Today only `"24h"` is wired into
  /// the UI; `"7d"` and `"30d"` are reserved for future range tabs and
  /// the server silently coerces unknown values to `"24h"`.
  final String range;

  /// Width of each bucket on the time axis. The screen uses this to
  /// pick X-axis tick spacing instead of hard-coding a value that would
  /// drift from the server when the range list expands.
  final int bucketMinutes;

  final List<VitalsTimeseriesPoint> data;

  factory VitalsTimeseries.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final points = <VitalsTimeseriesPoint>[];
    if (rawData is List) {
      for (final entry in rawData) {
        if (entry is Map) {
          points.add(
            VitalsTimeseriesPoint.fromJson(
              Map<String, dynamic>.from(entry),
            ),
          );
        }
      }
    }

    return VitalsTimeseries(
      range: json['range'] as String? ?? '24h',
      bucketMinutes: (json['bucket_minutes'] as num?)?.toInt() ?? 15,
      data: points,
    );
  }

  /// Empty envelope used as the initial provider value so the chart
  /// can render its placeholder without a null check at every read.
  static const VitalsTimeseries empty = VitalsTimeseries(
    range: '24h',
    bucketMinutes: 15,
    data: <VitalsTimeseriesPoint>[],
  );
}
