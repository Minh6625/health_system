import 'dart:async';
import 'package:healthguard/core/constants/api_endpoints.dart';
import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/sleep_analysis/models/sleep_session.dart';

// ── Abstract Interface ────────────────────────────────────────────────────────

abstract class SleepRepository {
  /// Returns the latest sleep session, or null if no data available (404).
  Future<SleepSession?> getLatestSleep({String? patientId});

  /// Returns a list of sessions within [from]..[to] range.
  /// Returns empty list if no history found.
  Future<List<SleepSession>> getSleepHistory({
    required DateTime from,
    required DateTime to,
    String? patientId,
  });

  /// Returns the first session on a given calendar date, or null if none.
  Future<SleepSession?> getSessionByDate(DateTime date, {String? patientId});
}

// ── Implementation ────────────────────────────────────────────────────────────

class SleepRepositoryImpl implements SleepRepository {
  SleepRepositoryImpl({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<SleepSession?> getLatestSleep({String? patientId}) async {
    try {
      final json = await _client.get(
        ApiEndpoints.latestSleep,
        targetProfileId: _parseTargetProfileId(patientId),
      );
      if (json == null) return null;
      return SleepSession.fromJson(json);
    } catch (e) {
      final msg = e.toString();
      // Backend 404 → no sleep data yet → return null (Empty state, not Error)
      if (msg.contains('Not found') || msg.contains('404')) {
        return null;
      }
      // Rethrow network/timeout/parse errors → provider shows Error state
      rethrow;
    }
  }

  @override
  Future<List<SleepSession>> getSleepHistory({
    required DateTime from,
    required DateTime to,
    String? patientId,
  }) async {
    try {
      final response = await _client.get(
        ApiEndpoints.sleepHistory,
        queryParams: {
          'from_date': _formatReportDate(from),
          'to_date': _formatReportDate(to),
        },
        targetProfileId: _parseTargetProfileId(patientId),
      );

      // Response can be a Map with a list field, or directly a List
      dynamic rawList;
      if (response is List) {
        rawList = response;
      } else if (response is Map) {
        rawList = response['data'] ?? response['items'] ?? response['sessions'];
      }
      
      if (rawList is List) {
        return rawList
            .whereType<Map<String, dynamic>>()
            .map(SleepSession.fromJson)
            .toList();
      }
      return [];
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Not found') || msg.contains('404')) {
        return [];
      }
      rethrow;
    }
  }

  @override
  Future<SleepSession?> getSessionByDate(DateTime date, {String? patientId}) async {
    final reportDate = DateTime(date.year, date.month, date.day);
    final sessions = await getSleepHistory(
      from: reportDate,
      to: reportDate,
      patientId: patientId,
    );
    for (final session in sessions) {
      if (_isSameReportDay(session.sleepDate, reportDate)) {
        return session;
      }
    }
    return null;
  }

  int? _parseTargetProfileId(String? patientId) {
    if (patientId == null || patientId.trim().isEmpty) {
      return null;
    }
    return int.tryParse(patientId.trim());
  }

  String _formatReportDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  bool _isSameReportDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
