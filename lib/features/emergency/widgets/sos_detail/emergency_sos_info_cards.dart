import 'package:flutter/material.dart';
import 'package:healthguard/features/emergency/models/sos_event_model.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';
import 'package:intl/intl.dart';

/// "Vị trí" card showing the GPS coordinates, accuracy and freshness.
///
/// Falls back to a "GPS: Không có dữ liệu" line when the SOS payload does
/// not carry valid latitude/longitude (e.g. patient never granted location
/// permission, or no GPS fix at trigger time).
class EmergencySOSLocationInfoCard extends StatelessWidget {
  final SOSEventModel sos;

  const EmergencySOSLocationInfoCard({super.key, required this.sos});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gapLg),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        boxShadow: AppShadows.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, size: 20, color: AppColors.info),
              const SizedBox(width: AppSpacing.gapSm),
              Text(
                'Vị trí',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapMd),
          if (sos.location.latitude != null && sos.location.longitude != null)
            Text(
              'GPS: ${sos.location.latitude!.toStringAsFixed(6)}, '
              '${sos.location.longitude!.toStringAsFixed(6)}',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            Text(
              'GPS: Không có dữ liệu',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: AppSpacing.gapXs),
          if (sos.location.accuracy != null)
            Text(
              'Độ chính xác: ${sos.location.accuracy!.toStringAsFixed(1)} mét',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: AppSpacing.gapXs),
          Text(
            'Cập nhật: ${DateFormat('HH:mm:ss - dd/MM/yyyy').format(sos.location.lastUpdated)}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Thời gian" card showing the SOS trigger timestamp and elapsed duration
/// since the alert was first raised.
class EmergencySOSTimeInfoCard extends StatelessWidget {
  final SOSEventModel sos;

  const EmergencySOSTimeInfoCard({super.key, required this.sos});

  String _formatElapsed(Duration duration) {
    if (duration.inMinutes < 1) {
      return 'Vừa xong';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes} phút';
    } else if (duration.inHours < 24) {
      return '${duration.inHours} giờ';
    } else {
      return '${duration.inDays} ngày';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gapLg),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        boxShadow: AppShadows.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, size: 20, color: AppColors.info),
              const SizedBox(width: AppSpacing.gapSm),
              Text(
                'Thời gian',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapMd),
          Text(
            'Kích hoạt: ${DateFormat('HH:mm:ss - dd/MM/yyyy').format(sos.triggerTime)}',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.gapXs),
          Text(
            'Đã trôi qua: ${_formatElapsed(sos.elapsedTime)}',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Thông tin xử lý" card rendered when the SOS already carries a
/// caregiver-issued resolution payload (status, who resolved it, when, and
/// any optional notes).
class EmergencySOSResolutionInfoCard extends StatelessWidget {
  final ResolutionInfoModel resolution;

  const EmergencySOSResolutionInfoCard({super.key, required this.resolution});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gapLg),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        border: Border.all(color: AppColors.success, width: 2),
        boxShadow: AppShadows.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, size: 20, color: AppColors.success),
              const SizedBox(width: AppSpacing.gapSm),
              Text(
                'Thông tin xử lý',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapMd),
          Text(
            'Đã xử lý bởi: ${resolution.resolvedBy}',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.gapXs),
          Text(
            'Thời gian: ${DateFormat('HH:mm:ss - dd/MM/yyyy').format(resolution.resolvedTime)}',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.gapXs),
          Text(
            'Trạng thái xử lý: ${resolution.resolutionStatus}',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (resolution.notes != null) ...[
            const SizedBox(height: AppSpacing.gapSm),
            Text(
              'Ghi chú: ${resolution.notes}',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
