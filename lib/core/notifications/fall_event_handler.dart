/// Routes incoming FCM "fall_alert" pushes into the
/// [FallAlertScreen] full-screen overlay.
///
/// Phase 4B-full slice 2d (mobile half). The push payload shape is
/// pinned by the backend's
/// `PushNotificationService.send_fall_critical_alert` (see
/// `backend/docs/risk-contract-baseline.md` §7k):
///
/// ```json
/// {
///   "type": "fall_alert",
///   "event_type": "fall_detected",
///   "fall_event_id": "42",
///   "fall_event_uuid": "11111111-...",
///   "confidence": "0.910",
///   "title": "Phát hiện ngã",
///   "body": "Bạn có ổn không?",
///   "click_action": "FLUTTER_NOTIFICATION_CLICK"
/// }
/// ```
///
/// All values are strings (FCM data envelope constraint). The parser
/// here turns them back into typed values so the rest of the app can
/// work with [FallEvent] / [DateTime] / [double].
library;

import 'package:flutter/material.dart';

import 'package:healthguard/features/fall/models/fall_event.dart';
import 'package:healthguard/features/fall/repositories/fall_event_repository.dart';
import 'package:healthguard/features/fall/screens/fall_alert_screen.dart';

/// Discriminator used by the backend's `send_fall_critical_alert`.
const String _fallAlertType = 'fall_alert';

/// Build a synthetic [FallEvent] from the FCM data payload.
///
/// Returns ``null`` when:
///
/// * The data is not a fall_alert push (``data.type != 'fall_alert'``).
/// * Any required field (``fall_event_id``, ``fall_event_uuid``) is
///   missing or unparseable.
///
/// Successful pushes need at minimum the id + uuid; everything else
/// falls back to safe defaults so an older app build can still
/// render the alert against a newer backend that adds extra fields.
///
/// The returned event has ``status = detected`` and
/// ``user_responded_at = null`` because, by definition, a freshly
/// pushed event has no user response yet. The full row will be
/// re-fetched via [FallEventRepository.getEvent] when the user
/// dismisses or the alert opens — at which point GPS / address /
/// model_version etc. land too. The synthetic event here is only
/// rich enough to render the [FallAlertScreen] header + countdown.
FallEvent? parseFallEventFromPushData(Map<String, dynamic> data) {
  if (data['type']?.toString() != _fallAlertType) return null;

  final idStr = data['fall_event_id']?.toString();
  final uuidStr = data['fall_event_uuid']?.toString();
  if (idStr == null || uuidStr == null || uuidStr.isEmpty) return null;

  final id = int.tryParse(idStr);
  if (id == null) return null;

  // Confidence is best-effort — server formats with 3 decimals but
  // we accept anything parseable + clamp to [0, 1].
  double confidence = 0.0;
  final raw = data['confidence']?.toString();
  if (raw != null) {
    final parsed = double.tryParse(raw);
    if (parsed != null) {
      confidence = parsed.clamp(0.0, 1.0).toDouble();
    }
  }

  // detected_at is not in the push envelope (saves payload bytes);
  // use ``DateTime.now()`` so the alert screen header has a sensible
  // timestamp even before the full row arrives. The fall-history
  // refresh later will overwrite this with the persisted value.
  return FallEvent(
    id: id,
    uuid: uuidStr,
    deviceId: 0,  // not in the push payload — full row supplies it
    detectedAt: DateTime.now(),
    confidence: confidence,
    status: FallEventStatus.detected,
  );
}

/// Push the [FallAlertScreen] overlay onto the navigator.
///
/// Idempotent in spirit: uses [Navigator.pushReplacementNamed]-style
/// guard so a duplicate push (FCM retries are common) doesn't stack
/// two alert screens on top of each other.
///
/// Returns the Future that resolves when the alert is dismissed.
/// Callers usually fire-and-forget — the dismiss workflow handles
/// itself via the FallEventProvider injected at the screen level.
Future<void> presentFallAlert(
  BuildContext context,
  FallEvent event, {
  bool replaceCurrent = false,
}) async {
  // Drop any existing fall alert before opening a new one.
  // ModalRoute.of returns null on the very first push (no current
  // route to compare to); the canPop guard below handles the case
  // where the navigator stack is empty.
  final navigator = Navigator.of(context);
  if (replaceCurrent && navigator.canPop()) {
    final currentRoute = ModalRoute.of(context);
    if (currentRoute?.settings.name == FallAlertScreen.routeName) {
      navigator.pop();
    }
  }

  await navigator.push<void>(
    MaterialPageRoute(
      settings: const RouteSettings(name: FallAlertScreen.routeName),
      builder: (_) => FallAlertScreen(event: event),
      // Fullscreen so back-button + system gestures are deferred to
      // the screen's PopScope guard.
      fullscreenDialog: true,
    ),
  );
}

/// Hydrate the alert with full server-side state after presenting the
/// synthetic event from the push payload.
///
/// Best-effort: a network failure leaves the synthetic event in
/// place and the alert screen renders with the stub fields it
/// already has. Returns the freshly-fetched event on success, or
/// ``null`` on any failure (including HTTP 404 — the row was deleted
/// between the push and the GET).
Future<FallEvent?> hydrateFallEvent(
  FallEvent stub, {
  FallEventRepository? repository,
  String? patientId,
}) async {
  final repo = repository ?? FallEventRepositoryImpl();
  try {
    return await repo.getEvent(stub.id, patientId: patientId);
  } catch (_) {
    return null;
  }
}
