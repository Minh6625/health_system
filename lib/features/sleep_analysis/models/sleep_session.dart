class SleepSession {
  final int qualityScore;
  final int inBedMinutes;
  final int wakeCount;
  final Map<String, int> phases;
  final DateTime startTime;
  final DateTime endTime;

  SleepSession({
    required this.qualityScore,
    required this.inBedMinutes,
    required this.wakeCount,
    required this.phases,
    required this.startTime,
    required this.endTime,
  });

  factory SleepSession.fromJson(Map<String, dynamic> json) {
    final phaseMap = <String, int>{};
    final rawPhases = json['phases'];

    if (rawPhases is Map<String, dynamic>) {
      for (final entry in rawPhases.entries) {
        final value = entry.value;
        if (value is num) {
          phaseMap[entry.key] = value.toInt();
        }
      }
    }

    return SleepSession(
      qualityScore: (json['quality_score'] as num?)?.toInt() ?? 0,
      inBedMinutes: (json['in_bed_minutes'] as num?)?.toInt() ?? 0,
      wakeCount: (json['wake_count'] as num?)?.toInt() ?? 0,
      phases: phaseMap,
      startTime: DateTime.parse(json['start_time'] as String).toLocal(),
      endTime: DateTime.parse(json['end_time'] as String).toLocal(),
    );
  }

  double get qualityRatio {
    if (qualityScore <= 0) return 0;
    if (qualityScore >= 100) return 1;
    return qualityScore / 100;
  }

  String get inBedText {
    final hours = inBedMinutes ~/ 60;
    final minutes = inBedMinutes % 60;
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }
}
