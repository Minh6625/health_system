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
  /// Returns a [FallDismissResult] that distinguishes:
  /// * [FallDismissOutcome.success] with the updated event (status
  ///   may be `dismissed` or `escalated` if auto-SOS already fired —
  ///   caller decides UX).
  /// * [FallDismissOutcome.notFoundOrForbidden] — backend answered 404
  ///   (event missing or caller is not the owner / linked caregiver).
  /// * [FallDismissOutcome.serverError] — backend answered 5xx.
  /// * [FallDismissOutcome.networkError] — timeout / no connection /
  ///   transport-level failure.
  Future<FallDismissResult> dismiss(
    int id, {
    String? reason,
    String? patientId,
  });

  /// Module FA-2 (Option 3-Lite): submit the post-dismiss stand-up
  /// survey answer.  Called from [FallStandUpSurveyScreen] after the
  /// user has tapped "Tôi ổn" on the initial fall alert.
  ///
  /// * ``canStand=true``  — user stood up.
  /// * ``canStand=false`` — user said OK but cannot stand; backend
  ///                      fans a softer follow-up push to caregivers.
  /// * ``canStand=null + skipped=true`` — user tapped "Bỏ qua" or
  ///                      the 15s timer expired.
  ///
  /// Returns the updated event (with ``surveyAnswers`` populated) on
  /// success.  Returns ``null`` on 404; rethrows on anything else so
  /// the caller can decide whether to retry.
  Future<FallEvent?> submitSurvey(
    int id, {
    required bool? canStand,
    required bool skipped,
    String? patientId,
  });
}

/// Outcome of a dismiss call. Lets the UI surface a distinct message
/// per failure mode instead of the same generic "Không thể bỏ qua"
/// snackbar for every error.
enum FallDismissOutcome {
  /// Backend returned 200 with a valid event payload. The event field
  /// is non-null; its `status` may be `dismissed` (clean cancel) or
  /// `escalated` (dismiss arrived after auto-SOS already fired).
  success,

  /// Backend answered 404 — event doesn't exist OR the caller has no
  /// ownership / accepted-caregiver link to it.
  notFoundOrForbidden,

  /// Backend answered 5xx.
  serverError,

  /// Transport-level failure (timeout, socket, host lookup).
  networkError,
}

/// Outcome + (optional) updated event for a dismiss call.
class FallDismissResult {
  const FallDismissResult({required this.outcome, this.event});

  final FallDismissOutcome outcome;
  final FallEvent? event;

  bool get isSuccess => outcome == FallDismissOutcome.success;
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
      if (_classify(e) == FallDismissOutcome.notFoundOrForbidden) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<FallDismissResult> dismiss(
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
        return const FallDismissResult(outcome: FallDismissOutcome.serverError);
      }
      final inner = response['fall_event'];
      if (inner is! Map<String, dynamic>) {
        return const FallDismissResult(outcome: FallDismissOutcome.serverError);
      }
      return FallDismissResult(
        outcome: FallDismissOutcome.success,
        event: FallEvent.fromJson(inner),
      );
    } catch (e) {
      if (e is SessionExpiredException) rethrow;
      return FallDismissResult(outcome: _classify(e));
    }
  }

  @override
  Future<FallEvent?> submitSurvey(
    int id, {
    required bool? canStand,
    required bool skipped,
    String? patientId,
  }) async {
    try {
      final body = <String, dynamic>{
        'can_stand': canStand,
        'skipped': skipped,
      };
      final response = await _client.post(
        ApiEndpoints.fallEventSurvey(id),
        body: body,
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
      if (_classify(e) == FallDismissOutcome.notFoundOrForbidden) {
        return null;
      }
      rethrow;
    }
  }

  /// Map a thrown error from [ApiClient] to a [FallDismissOutcome].
  ///
  /// [ApiClient._mapException] re-wraps as plain `Exception(message)`,
  /// so we string-match. Backend HTTPException(404) detail is in
  /// Vietnamese ("Không tìm thấy sự kiện ngã"); _getErrorMessage falls
  /// back to "Not found" only when the body is unparseable. Match both.
  FallDismissOutcome _classify(Object e) {
    final msg = e.toString();
    if (msg.contains('Network error') ||
        msg.contains('SocketException') ||
        msg.contains('TimeoutException') ||
        msg.contains('Failed host lookup') ||
        msg.contains('Connection refused')) {
      return FallDismissOutcome.networkError;
    }
    if (msg.contains('404') ||
        msg.contains('Not found') ||
        msg.contains('Không tìm thấy')) {
      return FallDismissOutcome.notFoundOrForbidden;
    }
    if (msg.contains('500') ||
        msg.contains('502') ||
        msg.contains('503') ||
        msg.contains('Lỗi server') ||
        msg.contains('Service unavailable')) {
      return FallDismissOutcome.serverError;
    }
    // Default: unknown server-side message — treat as server error so
    // the user sees "thử lại sau" rather than "mất kết nối" (which
    // would be wrong if the request actually reached the server).
    return FallDismissOutcome.serverError;
  }

  int? _parseTargetProfileId(String? patientId) {
    if (patientId == null || patientId.trim().isEmpty) {
      return null;
    }
    return int.tryParse(patientId.trim());
  }
}
