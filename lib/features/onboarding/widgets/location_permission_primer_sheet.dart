import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/services/onboarding_permission_service.dart';
import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';
import '../../../shared/presentation/theme/app_spacing.dart';
import '../../../shared/presentation/theme/app_text_styles.dart';

/// F-15 (P-3): bottom-sheet primer that explains why the app needs
/// location permission BEFORE firing the OS-level permission dialog.
///
/// **Display contract.** This widget is presented exactly once per
/// install via [OnboardingPermissionService.shouldShowLocationPrimer].
/// Show it via [showLocationPermissionPrimer] which handles the
/// modal-bottom-sheet plumbing and the persistence write so callers
/// don't have to.
///
/// **Buttons.**
///   - "Cho phép" → primary CTA. Triggers
///     [OnboardingPermissionService.requestLocationPermission] which
///     surfaces the OS dialog. The widget closes either way (granted
///     or denied) and persists the "seen" flag so we never re-prompt
///     in this app session.
///   - "Để sau" → secondary CTA. Closes the sheet and persists the
///     "seen" flag without firing the OS dialog. The user's eventual
///     SOS attempt will still trigger the in-flow request from
///     `manual_sos_screen` so they're not locked out of SOS.
///
/// **Why a bottom sheet (not a full-screen route).** Less disruptive
/// than a route push on first dashboard load, and recoverable: a
/// confused user can swipe it away without committing to an action,
/// in which case the "seen" flag is still set (we want one primer
/// per install max — this is the gentlest possible nudge).
class LocationPermissionPrimerSheet extends StatefulWidget {
  const LocationPermissionPrimerSheet({
    super.key,
    required this.service,
    this.onResult,
  });

  /// The persistence/permission service. Injectable so widget tests
  /// can pass a fake without going through secure storage.
  final OnboardingPermissionService service;

  /// Optional callback invoked when the sheet closes, with the final
  /// permission state if the user tapped "Cho phép", or `null` if
  /// the user tapped "Để sau" / dismissed.
  final void Function(LocationPermission? result)? onResult;

  @override
  State<LocationPermissionPrimerSheet> createState() =>
      _LocationPermissionPrimerSheetState();
}

class _LocationPermissionPrimerSheetState
    extends State<LocationPermissionPrimerSheet> {
  bool _isRequesting = false;

  Future<void> _handleAllow() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);
    final result = await widget.service.requestLocationPermission();
    await widget.service.markLocationPrimerShown();
    if (!mounted) return;
    widget.onResult?.call(result);
    Navigator.of(context).pop();
  }

  Future<void> _handleDefer() async {
    await widget.service.markLocationPrimerShown();
    if (!mounted) return;
    widget.onResult?.call(null);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // SingleChildScrollView so the primer never overflows on small
      // phones (tested screens started at 6.5px overflow on a default
      // flutter_test viewport — real devices like iPhone SE 1st gen
      // would hit the same issue at 320x568 with system font scale up).
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gapLg,
          AppSpacing.gapLg,
          AppSpacing.gapLg,
          AppSpacing.gapMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Visual anchor — a generous icon block in the brand
            // colour so the primer reads as a feature explanation,
            // not an error alert.
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.radiusLg),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: AppColors.brandPrimary,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.gapLg),
            Text(
              'Bật vị trí để gửi SOS nhanh hơn',
              style: AppTextStyles.sectionTitle.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.gapSm),
            // Body explains *why* we need the permission so the
            // upcoming OS dialog (with its terse "Allow Healthguard
            // to access location?") has context. Keep wording
            // jargon-free — patients use this app, not engineers.
            Text(
              'Khi xảy ra tình huống khẩn cấp, ứng dụng cần biết vị trí '
              'của bạn để chia sẻ ngay với người thân và dịch vụ y tế. '
              'Cho phép một lần để không phải xác nhận lại mỗi khi gửi SOS.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.gapLg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isRequesting ? null : _handleDefer,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.gapMd,
                      ),
                      side: const BorderSide(color: AppColors.strokeSoft),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.radiusLg),
                      ),
                    ),
                    child: const Text(
                      'Để sau',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.gapMd),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _isRequesting ? null : _handleAllow,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.gapMd,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.radiusLg),
                      ),
                    ),
                    child: _isRequesting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Cho phép',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// F-15 (P-3): convenience entry point for showing the primer once.
///
/// Returns `true` when the primer was actually shown, `false` when
/// the gating check (`shouldShowLocationPrimer`) decided this user
/// is not a candidate (already seen, already granted, or
/// permanently denied at the OS level).
///
/// Callers (currently `home_dashboard_screen.dart`) should fire this
/// from a post-frame callback in `initState` so the dashboard has a
/// chance to render before the sheet animates up.
Future<bool> showLocationPermissionPrimer({
  required BuildContext context,
  required OnboardingPermissionService service,
  void Function(LocationPermission? result)? onResult,
}) async {
  final shouldShow = await service.shouldShowLocationPrimer();
  if (!shouldShow) return false;
  if (!context.mounted) return false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadii.radiusXl),
      ),
    ),
    builder: (sheetContext) => LocationPermissionPrimerSheet(
      service: service,
      onResult: onResult,
    ),
  );
  return true;
}
