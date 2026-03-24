import 'package:flutter/material.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/family/providers/shared_family_mock_provider.dart';
import 'package:healthguard/features/family/models/family_profile_snapshot.dart';
import 'package:healthguard/features/home/presentation/widgets/vital_metric_card.dart';
import 'package:provider/provider.dart';

class PersonDetailScreen extends StatelessWidget {
  final String profileId;

  const PersonDetailScreen({super.key, required this.profileId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SharedFamilyMockProvider>();
    final snapshots = provider.generateDashboardSnapshots();
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
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Chi tiết thông tin',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (profile.isSosActive) _buildSosBanner(context),
            _buildHeroState(profile),
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
      color: const Color(0xFFE53935),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 26,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đang có yêu cầu SOS!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Vui lòng kiểm tra ngay',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
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
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFE53935),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
        : (profile.riskLevel != 'low' ? 'Cần theo dõi' : 'Đang ổn định');
    final statusColor = profile.isSosActive
        ? const Color(0xFFE53935)
        : (profile.riskLevel != 'low'
              ? const Color(0xFFF2A93B)
              : const Color(0xFF2E9B6F));

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFFEEF4FF),
            child: Text(
              profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2F80ED),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF12304A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF4FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        profile.relation,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF2F80ED),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
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
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                    const SizedBox(width: 8),
                    Text(
                      'Cập nhật 2p trước',
                      style: TextStyle(
                        color: Colors.grey.shade500,
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

  Widget _buildLiveVitals(BuildContext context, FamilyProfileSnapshot profile) {
    final items = _buildVitalItems(context, profile);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chỉ số gần nhất',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF12304A),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: VitalMetricCard(item: items[0])),
              const SizedBox(width: 12),
              Expanded(child: VitalMetricCard(item: items[1])),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: VitalMetricCard(item: items[2])),
              const SizedBox(width: 12),
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
    // HR visual state
    VitalMetricVisualState hrState;
    String hrStatus;
    final hr = profile.heartRate;
    if (hr < 50 || hr > 120) {
      hrState = VitalMetricVisualState.critical;
      hrStatus = 'Nguy hiểm';
    } else if (hr < 60 || hr > 100) {
      hrState = VitalMetricVisualState.warning;
      hrStatus = 'Cần chú ý';
    } else {
      hrState = VitalMetricVisualState.normal;
      hrStatus = 'Bình thường';
    }

    // SpO2 visual state
    VitalMetricVisualState spo2State;
    String spo2Status;
    final spo2 = profile.spo2;
    if (spo2 < 90) {
      spo2State = VitalMetricVisualState.critical;
      spo2Status = 'Nguy hiểm';
    } else if (spo2 < 95) {
      spo2State = VitalMetricVisualState.warning;
      spo2Status = 'Thấp';
    } else {
      spo2State = VitalMetricVisualState.normal;
      spo2Status = 'Bình thường';
    }

    // BP visual state
    VitalMetricVisualState bpState;
    String bpStatus;
    final sys = profile.bloodPressureSystolic ?? 0;
    final dia = profile.bloodPressureDiastolic ?? 0;
    if (sys > 160 || dia > 100) {
      bpState = VitalMetricVisualState.critical;
      bpStatus = 'Nguy hiểm';
    } else if (sys > 140 || dia > 90) {
      bpState = VitalMetricVisualState.warning;
      bpStatus = 'Cao';
    } else {
      bpState = VitalMetricVisualState.normal;
      bpStatus = 'Bình thường';
    }

    // Temp visual state
    VitalMetricVisualState tempState;
    String tempStatus;
    final temp = profile.bodyTemperature ?? 36.5;
    if (temp > 38.5) {
      tempState = VitalMetricVisualState.critical;
      tempStatus = 'Sốt cao';
    } else if (temp > 37.5) {
      tempState = VitalMetricVisualState.warning;
      tempStatus = 'Sốt nhẹ';
    } else {
      tempState = VitalMetricVisualState.normal;
      tempStatus = 'Bình thường';
    }

    return [
      VitalMetricItem(
        type: VitalMetricType.heartRate,
        label: 'Nhịp tim',
        value: '$hr bpm',
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
        value: '$spo2%',
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
      scoreColor = const Color(0xFF2E9B6F);
    } else if (profile.healthScoreLevel == 'Thấp') {
      scoreColor = const Color(0xFFE53935);
    } else {
      scoreColor = Colors.orange;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D253F), Color(0xFF163E57)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Color(0xFF81E6D9),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            // Điểm số lớn
            Text(
              '${profile.healthScore7Days}',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                color: scoreColor,
              ),
            ),
            const SizedBox(width: 16),
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
      qualityColor = const Color(0xFF2E9B6F);
    } else if (profile.sleepQuality == 'Kém') {
      qualityColor = const Color(0xFFE53935);
    } else {
      qualityColor = Colors.orange;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF131A2F), Color(0xFF1C274B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
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
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon tĩnh
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.bed_rounded,
                      color: Color(0xFFD8B4FE),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cảnh báo gần đây',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF12304A),
            ),
          ),
          const SizedBox(height: 12),
          _buildAlertItem(
            'Nhịp tim cao (112 bpm)',
            'Hôm nay, 14:30',
            const Color(0xFFF2A93B),
          ),
          _buildAlertItem(
            'Đã nhấn nút SOS',
            'Hôm qua, 09:15',
            const Color(0xFFE53935),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAlertItem(String title, String time, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF12304A),
                fontSize: 14,
              ),
            ),
          ),
          Text(
            time,
            style: const TextStyle(fontSize: 12, color: Color(0xFF5B7288)),
          ),
        ],
      ),
    );
  }
}
