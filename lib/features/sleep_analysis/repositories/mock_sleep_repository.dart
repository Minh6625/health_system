import 'package:healthguard/features/sleep_analysis/models/sleep_session.dart';
import 'package:healthguard/features/sleep_analysis/repositories/sleep_repository.dart';

/// Mock repository trả dữ liệu giả để test UI mà không cần backend.
/// Thay thế bằng [SleepRepositoryImpl] khi API sẵn sàng.
class MockSleepRepository implements SleepRepository {
  @override
  Future<SleepSession?> getLatestSleep({String? patientId}) async {
    // Giả lập độ trễ network
    await Future.delayed(const Duration(milliseconds: 800));
    final now = DateTime.now();
    final reportDate = DateTime(now.year, now.month, now.day);

    return SleepSession(
      sessionId: 'mock-session-001',
      sleepDate: reportDate,
      startTime: DateTime.now().subtract(const Duration(hours: 8, minutes: 15)),
      endTime: DateTime.now().subtract(const Duration(minutes: 10)),
      inBedMinutes: 495, // 8h 15m
      sleepMinutes: 452, // 7h 32m
      awakeMinutes: 43, // 43m
      efficiencyRatio: 0.91,
      qualityScore: 82,
      qualityLabel: 'GOOD', // GOOD | AVERAGE | POOR
      wakeCount: 3,
      phases: SleepPhasesDTO(
        lightMinutes: 210, // 3h 30m
        deepMinutes: 145, // 2h 25m
        remMinutes: 97, // 1h 37m
      ),
    );
  }

  @override
  Future<List<SleepSession>> getSleepHistory({
    required DateTime from,
    required DateTime to,
    String? patientId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final now = DateTime.now();

    // Dữ liệu 7 ngày gần nhất (T2 → CN)
    final mockScores = [74, 68, 81, 55, 82, 77, 90];
    final mockLabels = [
      'AVERAGE',
      'AVERAGE',
      'GOOD',
      'POOR',
      'GOOD',
      'GOOD',
      'GOOD',
    ];

    return List.generate(7, (i) {
      final dayOffset = 6 - i;
      final date = now.subtract(Duration(days: dayOffset));
      // Đẩy về đúng thứ trong tuần (Mon=1..Sun=7)
      final weekdayTarget = (i + 1); // 1..7
      final diff = weekdayTarget - date.weekday;
      final reportDate = date.add(Duration(days: diff));

      return SleepSession(
        sessionId: 'mock-session-history-$i',
        sleepDate: DateTime(reportDate.year, reportDate.month, reportDate.day),
        startTime: DateTime(
          reportDate.year,
          reportDate.month,
          reportDate.day,
        ).subtract(const Duration(hours: 1)),
        endTime: DateTime(
          reportDate.year,
          reportDate.month,
          reportDate.day,
          6,
          30,
        ),
        inBedMinutes: 450 + (i * 7),
        sleepMinutes: 420 + (i * 5),
        awakeMinutes: 30 + (i * 2),
        efficiencyRatio: 0.85 + (i * 0.01),
        qualityScore: mockScores[i],
        qualityLabel: mockLabels[i],
        wakeCount: 2 + (i % 3),
        phases: SleepPhasesDTO(
          lightMinutes: 190 + (i * 3),
          deepMinutes: 130 + (i * 4),
          remMinutes: 100 + (i * 2),
        ),
      );
    });
  }

  @override
  Future<SleepSession?> getSessionByDate(
    DateTime date, {
    String? patientId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final reportDate = DateTime(date.year, date.month, date.day);

    // Giả lập trạng thái "Empty" cho các ngày chia hết cho 5
    if (reportDate.day % 5 == 0) {
      return null;
    }

    // Return a mock session with a slightly different score for the selected date
    final score = 55 + (reportDate.day % 40); // varies by day
    final label = score >= 70 ? 'GOOD' : (score >= 50 ? 'AVERAGE' : 'POOR');
    return SleepSession(
      sessionId: 'mock-session-date-${reportDate.day}',
      sleepDate: reportDate,
      startTime: reportDate.subtract(const Duration(hours: 1)),
      endTime: DateTime(
        reportDate.year,
        reportDate.month,
        reportDate.day,
        6,
        30,
      ),
      inBedMinutes: 450,
      sleepMinutes: 390 + (reportDate.day % 60),
      awakeMinutes: 60 - (reportDate.day % 30),
      efficiencyRatio: 0.80 + (reportDate.day % 10) * 0.01,
      qualityScore: score,
      qualityLabel: label,
      wakeCount: 1 + (reportDate.day % 4),
      phases: SleepPhasesDTO(
        lightMinutes: 180 + (reportDate.day % 30),
        deepMinutes: 120 + (reportDate.day % 20),
        remMinutes: 90 + (reportDate.day % 15),
      ),
    );
  }
}
