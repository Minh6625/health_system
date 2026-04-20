import 'package:flutter/material.dart';

class SleepPhasesDTO {
  final int lightMinutes;
  final int deepMinutes;
  final int remMinutes;

  const SleepPhasesDTO({
    required this.lightMinutes,
    required this.deepMinutes,
    required this.remMinutes,
  });

  factory SleepPhasesDTO.fromJson(Map<String, dynamic> json) {
    return SleepPhasesDTO(
      lightMinutes: (json['light'] as num?)?.toInt() ?? 0,
      deepMinutes: (json['deep'] as num?)?.toInt() ?? 0,
      remMinutes: (json['rem'] as num?)?.toInt() ?? 0,
    );
  }

  int get totalMinutes => lightMinutes + deepMinutes + remMinutes;

  double get lightRatio => totalMinutes > 0 ? lightMinutes / totalMinutes : 0;
  double get deepRatio => totalMinutes > 0 ? deepMinutes / totalMinutes : 0;
  double get remRatio => totalMinutes > 0 ? remMinutes / totalMinutes : 0;
}

class SleepSession {
  final String sessionId;
  final DateTime sleepDate;
  final DateTime startTime;
  final DateTime endTime;
  final int inBedMinutes;
  final int sleepMinutes;
  final int awakeMinutes;
  final double efficiencyRatio;
  final int qualityScore;
  final String qualityLabel; // GOOD, AVERAGE, POOR
  final int wakeCount;
  final SleepPhasesDTO? phases;

  const SleepSession({
    required this.sessionId,
    required this.sleepDate,
    required this.startTime,
    required this.endTime,
    required this.inBedMinutes,
    required this.sleepMinutes,
    required this.awakeMinutes,
    required this.efficiencyRatio,
    required this.qualityScore,
    required this.qualityLabel,
    required this.wakeCount,
    this.phases,
  });

  factory SleepSession.fromJson(Map<String, dynamic> json) {
    SleepPhasesDTO? phases;
    final rawPhases = json['phases'];
    if (rawPhases is Map<String, dynamic>) {
      phases = SleepPhasesDTO.fromJson(rawPhases);
    }

    return SleepSession(
      sessionId: json['session_id'] as String? ?? '',
      sleepDate: _parseSleepDate(
        json['sleep_date'] as String?,
        json['end_time'] as String?,
      ),
      startTime: DateTime.parse(json['start_time'] as String).toLocal(),
      endTime: DateTime.parse(json['end_time'] as String).toLocal(),
      inBedMinutes: (json['in_bed_minutes'] as num?)?.toInt() ?? 0,
      sleepMinutes: (json['sleep_minutes'] as num?)?.toInt() ?? 0,
      awakeMinutes: (json['awake_minutes'] as num?)?.toInt() ?? 0,
      efficiencyRatio: (json['efficiency_ratio'] as num?)?.toDouble() ?? 0.0,
      qualityScore: (json['quality_score'] as num?)?.toInt() ?? 0,
      qualityLabel: json['quality_label'] as String? ?? 'AVERAGE',
      wakeCount: (json['wake_count'] as num?)?.toInt() ?? 0,
      phases: phases,
    );
  }

  // ── Computed Getters ──────────────────────────────────────────────────────

  double get qualityRatio {
    if (qualityScore <= 0) return 0;
    if (qualityScore >= 100) return 1;
    return qualityScore / 100;
  }

  String get inBedText => _formatMinutes(inBedMinutes);
  String get sleepText => _formatMinutes(sleepMinutes);
  String get awakeText => _formatMinutes(awakeMinutes);

  static String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  Color get qualityColor {
    switch (qualityLabel.toUpperCase()) {
      case 'GOOD':
        return const Color(0xFF4CAF50);
      case 'POOR':
        return const Color(0xFFEF5350);
      case 'AVERAGE':
      default:
        return const Color(0xFFFFC400);
    }
  }

  String get qualityLabelVi {
    switch (qualityLabel.toUpperCase()) {
      case 'GOOD':
        return 'Tốt';
      case 'POOR':
        return 'Kém';
      case 'AVERAGE':
      default:
        return 'Trung bình';
    }
  }

  /// Build wave points for the sleep chart from phases
  List<double> buildWavePoints() {
    if (phases == null) return _fallbackWave;
    final total = phases!.totalMinutes;
    if (total <= 0) return _fallbackWave;

    final lightR = phases!.lightRatio;
    final deepR = phases!.deepRatio;
    final remR = phases!.remRatio;

    return [
      0.9, 0.2,
      0.45, 0.6 * lightR + 0.2,
      0.15, 0.4 * deepR + 0.35,
      0.7, 0.28, 0.16,
      0.55 * remR + 0.35,
      0.74, 0.52, 0.33,
      0.25 + (1 - lightR - deepR - remR).clamp(0, 1),
      0.92, 0.7, 0.31, 0.46, 0.18, 0.2, 0.86,
    ];
  }

  static const List<double> _fallbackWave = [
    0.95, 0.15, 0.32, 0.58, 0.14, 0.43, 0.67,
    0.27, 0.11, 0.38, 0.74, 0.52, 0.33, 0.28,
    0.92, 0.87, 0.31, 0.46, 0.12, 0.18, 0.89,
  ];

  static DateTime _parseSleepDate(String? sleepDate, String? endTime) {
    if (sleepDate != null && sleepDate.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(sleepDate);
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }
    }

    final fallbackEndTime = DateTime.parse(endTime!).toLocal();
    return DateTime(
      fallbackEndTime.year,
      fallbackEndTime.month,
      fallbackEndTime.day,
    );
  }
}
