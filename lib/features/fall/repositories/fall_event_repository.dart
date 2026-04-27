import 'package:healthguard/core/constants/api_endpoints.dart';
import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/fall/models/fall_event.dart';

/// Mobile-side gateway for the backend's fall-events read + dismiss
/// surface (Phase 4B-full slice 2c, baseline doc §7j).
///
/// All three routes JOIN through ``devices.user_id`` server-side, so
/// the repository never has to embed a user id in the URL — the
/// X-Target-Profile-Id header (handled by [ApiClient]) is enough.
abstract class FallEventRepository {
  /// Paginated list of fall events for the active profile.
  ///
  /// [limit] is bounded server-side to ``[1, 100]`` (FastAPI Query
  /// validation rejects out-of-range values with HTTP 422).
  Future<FallEventList> listEvents({
    int limit = 20,
    int offset = 0,
    String? patientId,
  });

  /// Fetch one fall event by id. Returns ``null`` when the backend
  /// answers HTTP 404 (covers both "doesn't exist" and "not yours";
  /// the route deliberately doesn't distinguish to avoid the
  /// enumeration leak).
  Future<FallEvent?> getEvent(int id, {String? patientId});

  /// Mark a fall event as user-cancelled.
  ///
  /// Idempotent on the server — re-dismissing refreshes the response
  /// timestamp and overwrites the reason. Returns the updated event
  /// so the caller can swap it into local state without a follow-up
  /// GET. Returns ``null`` when the event is not found / not owned
  /// (HTTP 404).
  Future<FallEvent?> dismiss(int id, {String? reason, String? patientId});
}

class FallEventRepositoryImpl implements FallEventRepository {
  FallEventRepositoryImpl({ApiClient? client})
    : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<FallEventList> listEvents({
    int limit = 20,
    int offset = 0,
    String? patientId,
  }) async {
    final response = await _client.get(
      ApiEndpoints.fallEvents,
      queryParams: {'limit': limit, 'offset': offset},
      targetProfileId: _parseTargetProfileId(patientId),
    );
    if (response is! Map<String, dynamic>) {
      // Empty body / unexpected shape → treat as no events. The
      // Flutter UI shows the empty-state widget either way.
      return FallEventList(items: const [], total: 0, limit: limit, offset: offset);
    }
    return FallEventList.fromJson(response);
  }

  @override
  Future<FallEvent?> getEvent(int id, {String? patientId}) async {
    try {
      final response = await _client.get(
        ApiEndpoints.fallEventDetail(id),
        targetProfileId: _parseTargetProfileId(patientId),
      );
      if (response is! Map<String, dynamic>) {
        return null;
      }
      return FallEvent.fromJson(response);
    } catch (e) {
      if (_is404(e)) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<FallEvent?> dismiss(
    int id, {
    String? reason,
    String? patientId,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (reason != null && reason.trim().isNotEmpty) {
        body['reason'] = reason.trim();
      }
      final response = await _client.post(
        ApiEndpoints.fallEventDismiss(id),
        body: body.isEmpty ? null : body,
        targetProfileId: _parseTargetProfileId(patientId),
      );
      if (response is! Map<String, dynamic>) {
        return null;
      }
      final inner = response['fall_event'];
      if (inner is! Map<String, dynamic>) {
        return null;
      }
      return FallEvent.fromJson(inner);
    } catch (e) {
      if (_is404(e)) {
        return null;
      }
      rethrow;
    }
  }

  bool _is404(Object e) {
    final msg = e.toString();
    return msg.contains('Not found') || msg.contains('404');
  }

  int? _parseTargetProfileId(String? patientId) {
    if (patientId == null || patientId.trim().isEmpty) {
      return null;
    }
    return int.tryParse(patientId.trim());
  }
}
