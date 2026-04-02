import 'package:flutter/material.dart';
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
      cardColor = const Color(0xFFF8FAFC);
      iconBgColor = const Color(0xFFE2E8F0);
      iconColor = const Color(0xFF5B7288);
    } else if (profile.isSosActive) {
      cardColor = const Color(0xFFFDEEEE);
      iconBgColor = const Color(0xFFD95C5C);
      iconColor = Colors.white;
    } else if (profile.riskLevel == 'high') {
      cardColor = const Color(0xFFFDEEEE);
      iconBgColor = const Color(0xFFFDEEEE);
      iconColor = const Color(0xFFD95C5C);
    } else if (profile.riskLevel == 'medium') {
      cardColor = const Color(0xFFFDF4E5);
      iconBgColor = const Color(0xFFFDF4E5);
      iconColor = const Color(0xFFF2A93B);
    } else {
      cardColor = Colors.white;
      iconBgColor = const Color(0xFFF4F7FB);
      iconColor = const Color(0xFF2F80ED);
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
          updatedText = 'Vừa cập nhật ${remainSeconds} giây trước';
        } else if (remainSeconds == 0) {
          updatedText = 'Vừa cập nhật ${diffMinutes} phút trước';
        } else {
          updatedText =
              'Vừa cập nhật ${diffMinutes}p${remainSeconds} giây trước';
        }
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: profile.isSosActive
            ? Border.all(color: const Color(0xFFD95C5C), width: 1.5)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
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
                                  color: Color(0xFF12304A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (profile.isSosActive ||
                                  profile.riskLevel == 'high') ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xFFD95C5C),
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
                                    ? const Color(0xFF5B7288)
                                    : (profile.isSosActive ||
                                              profile.riskLevel == 'high'
                                          ? const Color(0xFFD95C5C)
                                          : const Color(0xFFF2A93B)),
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
                          ? const Color(0xFF5B7288)
                          : const Color(0xFFD95C5C),
                    ),
                    const SizedBox(width: 16),
                    _buildVitalItem(
                      Icons.water_drop_rounded,
                      isNoData ? '--' : '${profile.spo2}',
                      '%',
                      isNoData
                          ? const Color(0xFF5B7288)
                          : const Color(0xFF2F80ED),
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
                          ? const Color(0xFF5B7288)
                          : const Color(0xFF2E9B6F),
                    ),
                    const SizedBox(width: 16),
                    _buildVitalItem(
                      Icons.thermostat_rounded,
                      isNoData
                          ? '--'
                          : (profile.bodyTemperatureDisplay ?? '--'),
                      '°C',
                      isNoData
                          ? const Color(0xFF5B7288)
                          : const Color(0xFFF2A93B),
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
                        color: Color(0xFF5B7288),
                      ),
                    ),
                    Row(
                      children: const [
                        Text(
                          'Xem',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2F80ED),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: Color(0xFF2F80ED),
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
                color: Color(0xFF12304A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            unit,
            style: const TextStyle(fontSize: 12, color: Color(0xFF5B7288)),
          ),
        ],
      ),
    );
  }
}
