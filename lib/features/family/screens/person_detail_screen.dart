import 'package:flutter/material.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/family/providers/family_dashboard_provider.dart';
import 'package:healthguard/features/family/models/family_profile_snapshot.dart';
import 'package:healthguard/features/home/presentation/widgets/vital_metric_card.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:provider/provider.dart';

class PersonDetailScreen extends StatelessWidget {
  final String profileId;

  const PersonDetailScreen({super.key, required this.profileId});

  String _buildUpdatedText(DateTime lastUpdated) {
    final diffSecondsRaw = DateTime.now().difference(lastUpdated).inSeconds;
    final diffSeconds = diffSecondsRaw < 0 ? 0 : diffSecondsRaw;
    final snappedDiffSeconds = (diffSeconds ~/ 30) * 30;

    if (snappedDiffSeconds < 30) {
      return 'Vừa cập nhật';
    }

    final diffMinutes = snappedDiffSeconds ~/ 60;
    final remainSeconds = snappedDiffSeconds % 60;

    if (diffMinutes == 0) {
      return 'Cập nhật $remainSeconds giây trước';
    }
    if (remainSeconds == 0) {
      return 'Cập nhật ${diffMinutes}p trước';
    }
    return 'Cập nhật ${diffMinutes}p$remainSeconds giây trước';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FamilyDashboardProvider>();
    final snapshots = provider.profiles;
    final profile = snapshots.isNotEmpty
        ? snapshots.firstWhere(
            (p) => p.id == profileId,
            orElse: () => snapshots.first,
          )
        : null;

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết thông tin')),
        body: const Center(child: Text('Không tìm thấy dữ liệu')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(
          'Chi tiết thông tin',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        centerTitle: true,
        backgroundColor: AppColors.bgSurface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (profile.isSosActive) _buildSosBanner(context),
            _buildHeroState(profile),
            if (!profile.hasVitalsData) _buildNoVitalsDataBanner(profile),
            _buildLiveVitals(context, profile),
            _buildHealthScoreBanner(context, profile),
            _buildSleepCard(context, profile),
            _buildAlertHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildSosBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.emergency,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.gapLg, vertical: AppSpacing.sectionGapSm),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppColors.bgSurface,
            size: 26,
          ),
          SizedBox(width: AppSpacing.sectionGapSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đang có yêu cầu SOS!',
                  style: TextStyle(
                    color: AppColors.bgSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Vui lòng kiểm tra ngay',
                  style: TextStyle(color: AppColors.bgSurface.withValues(alpha: 0.7), fontSize: 13),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chuyển đến màn SOS')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bgSurface,
              foregroundColor: AppColors.emergency,
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.gapSm),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.radiusSm),
              ),
            ),
            child: const Text(
              'Xem',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroState(FamilyProfileSnapshot profile) {
    final statusLabel = profile.isSosActive
        ? 'Khẩn cấp'
        : (!profile.hasVitalsData
              ? 'Chưa có dữ liệu'
              : (profile.riskLevel != 'low' ? 'Cần theo dõi' : 'Đang ổn định'));
    final statusColor = profile.isSosActive
        ? AppColors.emergency
        : (!profile.hasVitalsData
              ? AppColors.textSecondary
              : (profile.riskLevel != 'low'
                    ? AppColors.warning
                    : AppColors.success));

    return Container(
      color: AppColors.bgSurface,
      padding: EdgeInsets.all(AppSpacing.sectionGapXl),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.brandPrimaryLight,
            child: Text(
              profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'U',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.gapLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: AppSpacing.gapSm),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.gapSm,
                        vertical: AppSpacing.gapXs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimaryLight,
                        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
                      ),
                      child: Text(
                        profile.relation,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.gapSm),
                Wrap(
                  spacing: AppSpacing.gapSm,
                  runSpacing: AppSpacing.gapXs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '• ${_buildUpdatedText(profile.lastUpdated)}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoVitalsDataBanner(FamilyProfileSnapshot profile) {
    final message =
        profile.vitalsDataMessage ??
        'Người dùng chưa có dữ liệu sức khỏe để hiển thị.';

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.gapLg, AppSpacing.sectionGapSm, AppSpacing.gapLg, 0),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppSpacing.sectionGapSm),
        decoration: BoxDecoration(
          color: AppStateColors.warningBg,
          borderRadius: BorderRadius.circular(AppRadii.radiusMd),
          border: Border.all(color: AppColors.warning),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: AppColors.warning,
              size: 20,
            ),
            SizedBox(width: AppSpacing.gapSm),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7A5A0A),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveVitals(BuildContext context, FamilyProfileSnapshot profile) {
    final items = _buildVitalItems(context, profile);
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.gapLg, AppSpacing.gapLg, AppSpacing.gapLg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chỉ số gần nhất',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppSpacing.sectionGapSm),
          Row(
            children: [
              Expanded(child: VitalMetricCard(item: items[0])),
              SizedBox(width: AppSpacing.sectionGapSm),
              Expanded(child: VitalMetricCard(item: items[1])),
            ],
          ),
          SizedBox(height: AppSpacing.sectionGapSm),
          Row(
            children: [
              Expanded(child: VitalMetricCard(item: items[2])),
              SizedBox(width: AppSpacing.sectionGapSm),
              Expanded(child: VitalMetricCard(item: items[3])),
            ],
          ),
        ],
      ),
    );
  }

  List<VitalMetricItem> _buildVitalItems(
    BuildContext context,
    FamilyProfileSnapshot profile,
  ) {
    if (!profile.hasVitalsData) {
      return [
        VitalMetricItem(
          type: VitalMetricType.heartRate,
          label: 'Nhịp tim',
          value: '-- bpm',
          statusLabel: 'Chưa có dữ liệu',
          visualState: VitalMetricVisualState.empty,
          onTap: () => Navigator.pushNamed(
            context,
            AppRouter.vitalDetail,
            arguments: {'profileId': profile.id, 'vitalType': 'hr'},
          ),
        ),
        VitalMetricItem(
          type: VitalMetricType.spo2,
          label: 'SpO2',
          value: '--%',
          statusLabel: 'Chưa có dữ liệu',
          visualState: VitalMetricVisualState.empty,
          onTap: () => Navigator.pushNamed(
            context,
            AppRouter.vitalDetail,
            arguments: {'profileId': profile.id, 'vitalType': 'spo2'},
          ),
        ),
        VitalMetricItem(
          type: VitalMetricType.bloodPressure,
          label: 'Huyết áp',
          value: '--/--',
          statusLabel: 'Chưa có dữ liệu',
          visualState: VitalMetricVisualState.empty,
          onTap: () => Navigator.pushNamed(
            context,
            AppRouter.vitalDetail,
            arguments: {'profileId': profile.id, 'vitalType': 'bp'},
          ),
        ),
        VitalMetricItem(
          type: VitalMetricType.temperature,
          label: 'Nhiệt độ',
          value: '--°C',
          statusLabel: 'Chưa có dữ liệu',
          visualState: VitalMetricVisualState.empty,
          onTap: () => Navigator.pushNamed(
            context,
            AppRouter.vitalDetail,
            arguments: {'profileId': profile.id, 'vitalType': 'temp'},
          ),
        ),
      ];
    }

    // HR visual state
    VitalMetricVisualState hrState;
    String hrStatus;
    final hr = profile.heartRate;
    if (hr <= 0) {
      hrState = VitalMetricVisualState.empty;
      hrStatus = 'Chưa có dữ liệu';
    } else if (hr < 50 || hr > 120) {
      hrState = VitalMetricVisualState.critical;
      hrStatus = 'Nguy cấp';
    } else if (hr < 60 || hr > 100) {
      hrState = VitalMetricVisualState.warning;
      hrStatus = 'Cảnh báo';
    } else {
      hrState = VitalMetricVisualState.normal;
      hrStatus = 'Bình thường';
    }

    // SpO2 visual state
    VitalMetricVisualState spo2State;
    String spo2Status;
    final spo2 = profile.spo2;
    if (spo2 <= 0) {
      spo2State = VitalMetricVisualState.empty;
      spo2Status = 'Chưa có dữ liệu';
    } else if (spo2 < 90) {
      spo2State = VitalMetricVisualState.critical;
      spo2Status = 'Nguy cấp';
    } else if (spo2 < 95) {
      spo2State = VitalMetricVisualState.warning;
      spo2Status = 'Cảnh báo';
    } else {
      spo2State = VitalMetricVisualState.normal;
      spo2Status = 'Bình thường';
    }

    // BP visual state
    VitalMetricVisualState bpState;
    String bpStatus;
    final sys = profile.bloodPressureSystolic;
    final dia = profile.bloodPressureDiastolic;
    if (sys == null || dia == null) {
      bpState = VitalMetricVisualState.empty;
      bpStatus = 'Chưa có dữ liệu';
    } else if (sys >= 180 || dia >= 120 || sys < 80 || dia < 50) {
      bpState = VitalMetricVisualState.critical;
      bpStatus = 'Nguy cấp';
    } else if (sys >= 140 || dia >= 90 || sys < 90 || dia < 60) {
      bpState = VitalMetricVisualState.warning;
      bpStatus = 'Cảnh báo';
    } else {
      bpState = VitalMetricVisualState.normal;
      bpStatus = 'Bình thường';
    }

    // Temp visual state
    VitalMetricVisualState tempState;
    String tempStatus;
    final temp = profile.bodyTemperature;
    if (temp == null) {
      tempState = VitalMetricVisualState.empty;
      tempStatus = 'Chưa có dữ liệu';
    } else if (temp >= 39 || temp < 35) {
      tempState = VitalMetricVisualState.critical;
      tempStatus = 'Nguy cấp';
    } else if (temp >= 37.5 || temp < 36) {
      tempState = VitalMetricVisualState.warning;
      tempStatus = 'Cảnh báo';
    } else {
      tempState = VitalMetricVisualState.normal;
      tempStatus = 'Bình thường';
    }

    return [
      VitalMetricItem(
        type: VitalMetricType.heartRate,
        label: 'Nhịp tim',
        value: hr > 0 ? '$hr bpm' : '-- bpm',
        statusLabel: hrStatus,
        visualState: hrState,
        onTap: () => Navigator.pushNamed(
          context,
          AppRouter.vitalDetail,
          arguments: {'profileId': profile.id, 'vitalType': 'hr'},
        ),
      ),
      VitalMetricItem(
        type: VitalMetricType.spo2,
        label: 'SpO2',
        value: spo2 > 0 ? '$spo2%' : '--%',
        statusLabel: spo2Status,
        visualState: spo2State,
        onTap: () => Navigator.pushNamed(
          context,
          AppRouter.vitalDetail,
          arguments: {'profileId': profile.id, 'vitalType': 'spo2'},
        ),
      ),
      VitalMetricItem(
        type: VitalMetricType.bloodPressure,
        label: 'Huyết áp',
        value: profile.bloodPressureDisplay ?? '--/--',
        statusLabel: bpStatus,
        visualState: bpState,
        onTap: () => Navigator.pushNamed(
          context,
          AppRouter.vitalDetail,
          arguments: {'profileId': profile.id, 'vitalType': 'bp'},
        ),
      ),
      VitalMetricItem(
        type: VitalMetricType.temperature,
        label: 'Nhiệt độ',
        value: profile.bodyTemperatureDisplay ?? '--°C',
        statusLabel: tempStatus,
        visualState: tempState,
        onTap: () => Navigator.pushNamed(
          context,
          AppRouter.vitalDetail,
          arguments: {'profileId': profile.id, 'vitalType': 'temp'},
        ),
      ),
    ];
  }

  Widget _buildHealthScoreBanner(
    BuildContext context,
    FamilyProfileSnapshot profile,
  ) {
    // Chỉ hiển thị khi có score hợp lệ
    if (profile.healthScore7Days == 0) return const SizedBox.shrink();

    Color scoreColor;
    if (profile.healthScoreLevel == 'Cao') {
      scoreColor = AppColors.success;
    } else if (profile.healthScoreLevel == 'Thấp') {
      scoreColor = AppColors.emergency;
    } else {
      scoreColor = AppColors.warning;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.gapLg, AppSpacing.gapLg, AppSpacing.gapLg, 0),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.gapLg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D253F), Color(0xFF163E57)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadii.radiusLg),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D253F).withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon trái
            Container(
              padding: EdgeInsets.all(AppSpacing.sectionGapSm),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.radiusMd),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Color(0xFF81E6D9),
                size: 28,
              ),
            ),
            SizedBox(width: AppSpacing.gapLg),
            // Điểm số lớn
            Text(
              '${profile.healthScore7Days}',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                color: scoreColor,
              ),
            ),
            SizedBox(width: AppSpacing.gapLg),
            // Nhãn
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Điểm sức khoẻ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.healthScoreLevel,
                    style: TextStyle(
                      color: scoreColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Chevron
            const Icon(Icons.chevron_right, color: Colors.white38, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepCard(BuildContext context, FamilyProfileSnapshot profile) {
    final hours = profile.sleepDurationMinutes ~/ 60;
    final minutes = profile.sleepDurationMinutes % 60;
    final formattedDuration = '$hours giờ $minutes phút';

    Color qualityColor;
    if (profile.sleepQuality == 'Tốt') {
      qualityColor = AppColors.success;
    } else if (profile.sleepQuality == 'Kém') {
      qualityColor = AppColors.emergency;
    } else {
      qualityColor = AppColors.warning;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.gapLg, AppSpacing.gapLg, AppSpacing.gapLg, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF131A2F), Color(0xFF1C274B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadii.radiusLg),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF131A2F).withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pushNamed(
              context,
              AppRouter.sleepReport,
              arguments: {'profileId': profile.id},
            ),
            borderRadius: BorderRadius.circular(AppRadii.radiusLg),
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.gapLg),
              child: Row(
                children: [
                  // Icon tĩnh
                  Container(
                    padding: EdgeInsets.all(AppSpacing.sectionGapSm),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadii.radiusMd),
                    ),
                    child: const Icon(
                      Icons.bed_rounded,
                      color: Color(0xFFD8B4FE),
                      size: 28,
                    ),
                  ),
                  SizedBox(width: AppSpacing.gapLg),
                  // Nội dung
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Giấc ngủ',
                          style: TextStyle(
                            color: Color(0xFFD8B4FE),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedDuration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Chất lượng: ${profile.sleepQuality}',
                          style: TextStyle(
                            color: qualityColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlertHistory() {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.gapLg, AppSpacing.gapLg, AppSpacing.gapLg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cảnh báo gần đây',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppSpacing.sectionGapSm),
          _buildAlertItem(
            'Nhịp tim cao (112 bpm)',
            'Hôm nay, 14:30',
            AppColors.warning,
          ),
          _buildAlertItem(
            'Đã nhấn nút SOS',
            'Hôm qua, 09:15',
            AppColors.emergency,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAlertItem(String title, String time, Color color) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.gapSm),
      padding: EdgeInsets.all(AppSpacing.sectionGapSm),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: AppSpacing.sectionGapSm),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            time,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
