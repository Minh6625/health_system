import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:healthguard/features/fall/models/fall_event.dart';
import 'package:healthguard/features/fall/providers/fall_event_provider.dart';
import 'package:healthguard/features/fall/widgets/fall_countdown_ring.dart';

/// Full-screen "fall detected" overlay.
///
/// Phase 4B-full slice 2c (mobile half). Shown when the FCM push for
/// a freshly-detected fall arrives (slice 2d wires the push handler).
///
/// UX contract:
///
/// * 30-second countdown via [FallCountdownRing]; on elapse the
///   backend's auto-SOS workflow takes over (the widget just calls
///   [Navigator.pop] — no extra dispatch needed).
/// * Two action buttons: "Tôi ổn" (dismisses the alert via the
///   provider's dismiss API) and "Cần giúp đỡ" (closes the screen
///   without dismissing — the backend's auto-SOS still escalates).
/// * Disclaimer strip at the bottom matches the existing risk surfaces
///   so users know this is an AI prediction, not a clinical diagnosis.
class FallAlertScreen extends StatelessWidget {
  /// The freshly-detected event the alert is rendering for.
  final FallEvent event;

  /// Override the countdown duration in tests so [FallAlertScreen]
  /// pumpWidget tests don't take 30 seconds.
  final Duration? testCountdownOverride;

  /// Called when the countdown elapses without user action. Defaults
  /// to closing the screen via [Navigator.pop]; the backend's
  /// auto-SOS workflow handles the actual escalation.
  final VoidCallback? onElapsed;

  const FallAlertScreen({
    super.key,
    required this.event,
    this.testCountdownOverride,
    this.onElapsed,
  });

  static const String routeName = '/fall/alert';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return PopScope(
      canPop: false,  // user must tap a button — no Android back-out.
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(
                  'Phát hiện ngã',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bạn có ổn không?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                FallCountdownRing(
                  duration:
                      testCountdownOverride ?? const Duration(seconds: 30),
                  onElapsed: () {
                    final cb = onElapsed;
                    if (cb != null) {
                      cb();
                      return;
                    }
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Nếu bạn không phản hồi trong 30 giây, hệ thống sẽ tự '
                  'động gửi cảnh báo SOS đến người thân.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                _buildActions(context),
                const SizedBox(height: 16),
                _DisclaimerStrip(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<FallEventProvider>(
      builder: (context, provider, _) {
        final isDismissing = provider.isDismissing;
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: isDismissing
                    ? null
                    : () => _onDismiss(context, provider),
                icon: isDismissing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Tôi ổn'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: theme.textTheme.titleMedium,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isDismissing
                    ? null
                    : () => _onConfirm(context),
                icon: const Icon(Icons.support_agent_rounded),
                label: const Text('Cần giúp đỡ'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: theme.textTheme.titleMedium,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onDismiss(
    BuildContext context,
    FallEventProvider provider,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await provider.dismiss(event.id, reason: 'Tôi ổn');
    if (!ok && context.mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Không thể bỏ qua — vui lòng thử lại'),
        ),
      );
      return;
    }
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  void _onConfirm(BuildContext context) {
    // Just close the alert; the backend's auto-SOS workflow already
    // engaged when the fall was detected, so we don't need to fire a
    // separate "I need help" call.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}

class _DisclaimerStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đây là cảnh báo do AI dự đoán, không phải chẩn đoán y khoa.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
