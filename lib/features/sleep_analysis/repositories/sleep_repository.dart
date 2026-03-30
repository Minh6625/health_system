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
      final path = _buildPath(ApiEndpoints.latestSleep, patientId: patientId);
      final json = await _client.get(path);
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
      final fromStr = from.toUtc().toIso8601String();
      final toStr = to.toUtc().toIso8601String();
      final path =
          '${ApiEndpoints.sleepHistory}?from=${Uri.encodeComponent(fromStr)}&to=${Uri.encodeComponent(toStr)}';
      final fullPath = _buildPath(path, patientId: patientId);

      final response = await _client.get(fullPath);

      // Response can be a Map with a list field, or directly a List
      final rawList = response['data'] ?? response['items'] ?? response['sessions'];
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
  Future<SleepSession?> getSessionByDate(DateTime date,
      {String? patientId}) async {
    // Query a 1-day window starting at midnight of the given date
    final from = DateTime(date.year, date.month, date.day);
    final to = from.add(const Duration(days: 1));
    final sessions = await getSleepHistory(
      from: from,
      to: to,
      patientId: patientId,
    );
    return sessions.isNotEmpty ? sessions.first : null;
  }

  String _buildPath(String base, {String? patientId}) {
    if (patientId != null && patientId.isNotEmpty) {
      final separator = base.contains('?') ? '&' : '?';
      return '$base${separator}patient_id=${Uri.encodeComponent(patientId)}';
    }
    return base;
  }
}
