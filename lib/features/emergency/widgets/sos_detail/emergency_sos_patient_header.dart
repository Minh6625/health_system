import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:healthguard/features/emergency/models/sos_event_model.dart';
import 'package:healthguard/features/emergency/widgets/sos_detail/sos_trigger_helpers.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';

/// Top of the SOS detail screen: avatar + patient name + trigger chip,
/// with a wobbling warning icon overlay while the SOS is still active.
///
/// The widget owns its own `AnimationController` so the warning shake is
/// managed locally; the parent screen only needs to pass the current
/// [SOSEventModel]. The animation starts when [SOSEventModel.isActive] is
/// `true` and stops cleanly the moment the SOS becomes resolved (or the
/// widget is disposed).
class EmergencySOSPatientHeader extends StatefulWidget {
  final SOSEventModel sos;

  const EmergencySOSPatientHeader({super.key, required this.sos});

  @override
  State<EmergencySOSPatientHeader> createState() =>
      _EmergencySOSPatientHeaderState();
}

class _EmergencySOSPatientHeaderState extends State<EmergencySOSPatientHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _warningAnimationController;
  bool _isWarningAnimating = false;

  @override
  void initState() {
    super.initState();
    _warningAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _syncWarningAnimation(widget.sos.isActive);
  }

  @override
  void didUpdateWidget(covariant EmergencySOSPatientHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sos.isActive != oldWidget.sos.isActive) {
      _syncWarningAnimation(widget.sos.isActive);
    }
  }

  void _syncWarningAnimation(bool shouldAnimate) {
    if (shouldAnimate && !_isWarningAnimating) {
      _warningAnimationController.repeat();
      _isWarningAnimating = true;
      return;
    }
    if (!shouldAnimate && _isWarningAnimating) {
      _warningAnimationController.stop();
      _warningAnimationController.value = 0;
      _isWarningAnimating = false;
    }
  }

  @override
  void dispose() {
    _warningAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sos = widget.sos;
    return Stack(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(AppSpacing.gapLg),
          padding: const EdgeInsets.all(AppSpacing.gapLg),
          decoration: BoxDecoration(
            color: sos.isActive
                ? AppColors.critical.withValues(alpha: 0.15)
                : AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppRadii.radiusMd),
            boxShadow: [
              BoxShadow(
                color: sos.isActive
                    ? AppColors.critical.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: sos.patient.photoUrl != null
                        ? CachedNetworkImageProvider(sos.patient.photoUrl!)
                        : null,
                    backgroundColor: AppColors.strokeSoft,
                    child: sos.patient.photoUrl == null
                        ? const Icon(
                            Icons.person,
                            size: 32,
                            color: AppColors.bgSurface,
                          )
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.gapMd),
                  Expanded(
                    child: Text(
                      sos.patient.name,
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: AppSpacing.gapMd),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gapMd,
                  vertical: AppSpacing.gapSm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(AppRadii.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      triggerIconFor(sos.triggerType),
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.gapSm),
                    Text(
                      triggerLabelFor(sos.triggerType),
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (sos.isActive)
          Positioned(
            top: 28,
            right: 28,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _warningAnimationController,
                builder: (context, child) {
                  final wave = math.sin(
                    _warningAnimationController.value * math.pi * 2 * 4,
                  );
                  return Transform.translate(
                    offset: Offset(wave * 4, 0),
                    child: Transform.rotate(
                      angle: wave * 0.10,
                      child: child,
                    ),
                  );
                },
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.critical,
                  size: 40,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
