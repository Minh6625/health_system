import 'package:flutter/material.dart';
import 'package:healthguard/features/emergency/models/sos_event_model.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';

/// Sticky action bar at the bottom of the SOS detail screen.
///
/// Hosts the three caregiver actions:
///
/// * "Gọi điện" - dial the patient (`onCall`)
/// * "Chỉ đường" - open external maps navigation (`onNavigate`, disabled
///   when the SOS does not have GPS coordinates)
/// * "Xác nhận" - resolve the SOS as safe (`onConfirmResolve`,
///   only rendered while the event is still active)
///
/// All side effects live in the parent screen so this widget stays purely
/// presentational. The `isResolving` flag drives the in-progress spinner
/// and disabled state on the resolve button.
class EmergencySOSActionsBlock extends StatelessWidget {
  final SOSEventModel sos;
  final bool isResolving;
  final VoidCallback onCall;
  final VoidCallback? onNavigate;
  final VoidCallback onConfirmResolve;

  const EmergencySOSActionsBlock({
    super.key,
    required this.sos,
    required this.isResolving,
    required this.onCall,
    required this.onNavigate,
    required this.onConfirmResolve,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gapLg),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.success,
                        AppColors.success.withValues(alpha: 0.85),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.radiusSm),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: onCall,
                    icon: const Icon(Icons.phone),
                    label: const Text('Gọi điện'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppColors.bgSurface,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size(0, 56),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.gapLg),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.brandPrimary,
                        AppColors.brandPrimary.withValues(alpha: 0.85),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.radiusSm),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.map),
                    label: const Text('Chỉ đường'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppColors.bgSurface,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size(0, 56),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (sos.isActive) ...[
            const SizedBox(height: AppSpacing.gapMd),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('emergency-sos-detail-resolve-button'),
                onPressed: isResolving ? null : onConfirmResolve,
                icon: isResolving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(isResolving ? 'Đang xác nhận...' : 'Xác nhận'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 56),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
