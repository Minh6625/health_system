import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:healthguard/features/fall/models/fall_event.dart';
import 'package:healthguard/features/fall/providers/fall_event_provider.dart';
import 'package:healthguard/features/fall/widgets/fall_countdown_ring.dart';

/// Module FA-2 — Option 3-Lite "stand-up" survey.
///
/// Pushed onto the navigator by [FallAlertScreen._onDismiss] *after*
/// the user tapped "Tôi ổn" on the initial fall alert.  Shows three
/// large buttons + a 15-second countdown:
///
/// * 🟢 **Có, tôi đứng dậy được**  → ``can_stand=true``  → caregiver
///                                    sees patient marked OK + standing.
/// * 🟠 **Không, cần ai đó giúp**  → ``can_stand=false`` → caregiver
///                                    receives a soft follow-up push
///                                    (no SOS takeover).
/// * ⚪ **Bỏ qua**                  → ``can_stand=null,  skipped=true``
/// * Timer expires                  → same as "Bỏ qua" (default-to-
///                                    safety: don't escalate, the user
///                                    already confirmed they're OK).
///
/// Design principles (see plan ``fall-sos-pipeline-fix-and-option3-
/// lite-survey-5f71ba.md``):
///
/// * **Elderly-friendly UX** — buttons are ≥ 80 dp tall with 18 sp
///   text so shaky hands + dim eyes can still tap accurately.
/// * **Default-to-safety on timeout** — auto-skip rather than
///   auto-escalate; the user already proved they're conscious by
///   tapping "Tôi ổn" upstream.
/// * **Non-blocking submit** — best-effort POST; a network failure
///   doesn't trap the user on this screen.
class FallStandUpSurveyScreen extends StatefulWidget {
  /// The fall event the survey belongs to.  Comes straight from the
  /// hydrated event the upstream [FallAlertScreen] dismissed against.
  final FallEvent event;

  /// Override the survey countdown duration in tests so widget tests
  /// don't take 15 real seconds.
  final Duration? testCountdownOverride;

  /// Called after the survey result is submitted (or skipped).
  /// Defaults to popping the screen.
  final VoidCallback? onClose;

  const FallStandUpSurveyScreen({
    super.key,
    required this.event,
    this.testCountdownOverride,
    this.onClose,
  });

  static const String routeName = '/fall/stand-up-survey';

  @override
  State<FallStandUpSurveyScreen> createState() =>
      _FallStandUpSurveyScreenState();
}

class _FallStandUpSurveyScreenState extends State<FallStandUpSurveyScreen> {
  /// Guard so a slow network call + a timer expiry don't both fire
  /// `submitSurvey` on the same instance.
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return PopScope(
      // Prevent Android back-button from skipping the survey silently.
      // The user can still tap "Bỏ qua" which is the explicit skip.
      canPop: false,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(
                  'Bạn có thể đứng dậy được không?',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Câu hỏi này giúp người thân biết tình trạng của bạn.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                FallCountdownRing(
                  duration: widget.testCountdownOverride ??
                      const Duration(seconds: 15),
                  size: 160,
                  onElapsed: _onTimerElapsed,
                ),
                const SizedBox(height: 24),
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
        final isBusy = provider.isSubmittingSurvey || _submitted;
        return Column(
          children: [
            // 🟢 Primary good outcome: stood up.
            _largeButton(
              context: context,
              label: 'Có, tôi đứng dậy được',
              icon: Icons.check_circle_outline_rounded,
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              busy: isBusy,
              onPressed: () => _submit(canStand: true, skipped: false),
            ),
            const SizedBox(height: 12),
            // 🟠 Soft-alert outcome: caregiver should call.
            _largeButton(
              context: context,
              label: 'Không, cần ai đó giúp',
              icon: Icons.support_agent_rounded,
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              busy: isBusy,
              onPressed: () => _submit(canStand: false, skipped: false),
            ),
            const SizedBox(height: 12),
            // ⚪ Skip — no escalation, no follow-up push.
            _ghostButton(
              context: context,
              label: 'Bỏ qua',
              busy: isBusy,
              onPressed: () => _submit(canStand: null, skipped: true),
            ),
          ],
        );
      },
    );
  }

  /// Submit the survey answer + close the screen.  Idempotent guard
  /// (``_submitted``) prevents a slow click + a timer expiry from
  /// firing the API twice.
  Future<void> _submit({
    required bool? canStand,
    required bool skipped,
  }) async {
    if (_submitted) return;
    _submitted = true;
    final provider = context.read<FallEventProvider>();
    final navigator = Navigator.of(context);

    // Best-effort: a failure leaves the audit gap but the user still
    // gets to leave the screen — they already confirmed they're OK
    // upstream so trapping them here would be cruel.
    await provider.submitSurvey(
      widget.event.id,
      canStand: canStand,
      skipped: skipped,
    );

    final cb = widget.onClose;
    if (cb != null) {
      cb();
      return;
    }
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  /// Timer expired without the user tapping anything.  Default-to-
  /// safety means: skip silently, do NOT escalate.  The user already
  /// said "Tôi ổn" upstream — trusting that signal.
  void _onTimerElapsed() {
    if (_submitted) return;
    _submit(canStand: null, skipped: true);
  }

  Widget _largeButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color foregroundColor,
    required bool busy,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      // ≥ 80 dp tall — elderly-friendly tap target.
      height: 80,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 24),
        label: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: theme.textTheme.titleMedium,
        ),
      ),
    );
  }

  Widget _ghostButton({
    required BuildContext context,
    required String label,
    required bool busy,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: TextButton(
        onPressed: busy ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          textStyle: theme.textTheme.titleMedium,
        ),
        child: Text(label),
      ),
    );
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
              'Nếu không trả lời, hệ thống vẫn ghi nhận bạn đã ổn '
              '(do đã xác nhận ở bước trước).',
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
