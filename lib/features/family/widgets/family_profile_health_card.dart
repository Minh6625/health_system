import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/features/family/models/family_profile_snapshot.dart';

class FamilyProfileHealthCard extends StatelessWidget {
  final FamilyProfileSnapshot profile;
  final VoidCallback onTap;

  const FamilyProfileHealthCard({
    super.key,
    required this.profile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isNoData = !profile.hasVitalsData;

    Color cardColor;
    Color iconBgColor;
    Color iconColor;

    if (isNoData) {
      cardColor = AppColors.bgPrimary;
      iconBgColor = AppColors.strokeSoft;
      iconColor = AppColors.textSecondary;
    } else if (profile.isSosActive) {
      cardColor = AppStateColors.criticalBg;
      iconBgColor = AppColors.critical;
      iconColor = Colors.white;
    } else if (profile.riskLevel == 'high') {
      cardColor = AppStateColors.criticalBg;
      iconBgColor = AppStateColors.criticalBg;
      iconColor = AppColors.critical;
    } else if (profile.riskLevel == 'medium') {
      cardColor = AppStateColors.warningBg;
      iconBgColor = AppStateColors.warningBg;
      iconColor = AppColors.warning;
    } else {
      cardColor = Colors.white;
      iconBgColor = AppColors.bgPrimary;
      iconColor = AppColors.brandPrimary;
    }

    final diffSecondsRaw = DateTime.now()
        .difference(profile.lastUpdated)
        .inSeconds;
    final diffSeconds = diffSecondsRaw < 0 ? 0 : diffSecondsRaw;
    final snappedDiffSeconds = (diffSeconds ~/ 30) * 30;
    String updatedText;
    if (isNoData) {
      updatedText = 'Chưa có dữ liệu đo';
    } else {
      if (snappedDiffSeconds < 30) {
        updatedText = 'Vừa cập nhật';
      } else {
        final diffMinutes = snappedDiffSeconds ~/ 60;
        final remainSeconds = snappedDiffSeconds % 60;

        if (diffMinutes == 0) {
          updatedText = 'Vừa cập nhật $remainSeconds giây trước';
        } else if (remainSeconds == 0) {
          updatedText = 'Vừa cập nhật $diffMinutes phút trước';
        } else {
          updatedText =
              'Vừa cập nhật ${diffMinutes}p$remainSeconds giây trước';
        }
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadii.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: profile.isSosActive
            ? Border.all(color: AppColors.critical, width: 1.5)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: iconBgColor,
                      child: Text(
                        profile.name.isNotEmpty
                            ? profile.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: iconColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${profile.relation} — ${profile.name}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (profile.isSosActive ||
                                  profile.riskLevel == 'high') ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.critical,
                                  size: 18,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (isNoData || profile.specialNote.isNotEmpty)
                            Text(
                              isNoData
                                  ? (profile.vitalsDataMessage ??
                                        'Chưa có dữ liệu sức khỏe')
                                  : profile.specialNote,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isNoData
                                    ? AppColors.textSecondary
                                    : (profile.isSosActive ||
                                              profile.riskLevel == 'high'
                                          ? AppColors.critical
                                          : AppColors.warning),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Vitals: Row 1 — HR + SpO2
                Row(
                  children: [
                    _buildVitalItem(
                      Icons.favorite_rounded,
                      isNoData ? '--' : '${profile.heartRate}',
                      'bpm',
                      isNoData
                          ? AppColors.textSecondary
                          : AppColors.critical,
                    ),
                    const SizedBox(width: 16),
                    _buildVitalItem(
                      Icons.water_drop_rounded,
                      isNoData ? '--' : '${profile.spo2}',
                      '%',
                      isNoData
                          ? AppColors.textSecondary
                          : AppColors.brandPrimary,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Vitals: Row 2 — BP + Temp
                Row(
                  children: [
                    _buildVitalItem(
                      Icons.monitor_heart_outlined,
                      isNoData
                          ? '--/--'
                          : (profile.bloodPressureDisplay ?? '--/--'),
                      'mmHg',
                      isNoData
                          ? AppColors.textSecondary
                          : AppColors.success,
                    ),
                    const SizedBox(width: 16),
                    _buildVitalItem(
                      Icons.thermostat_rounded,
                      isNoData
                          ? '--'
                          : (profile.bodyTemperatureDisplay ?? '--'),
                      '°C',
                      isNoData
                          ? AppColors.textSecondary
                          : AppColors.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      updatedText,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Row(
                      children: const [
                        Text(
                          'Xem',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: AppColors.brandPrimary,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVitalItem(
    IconData icon,
    String value,
    String unit,
    Color iconColor,
  ) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '$value ',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            unit,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
