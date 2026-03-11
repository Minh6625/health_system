import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vital_signs.dart';
import '../providers/vital_signs_provider.dart';
import '../widgets/vital_card.dart';

class HealthMonitoringScreen extends StatefulWidget {
  const HealthMonitoringScreen({super.key});

  @override
  State<HealthMonitoringScreen> createState() =>
      _HealthMonitoringScreenState();
}

class _HealthMonitoringScreenState extends State<HealthMonitoringScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch initial data and start auto-refresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<VitalSignsProvider>();
      provider.fetchLatestVitals();
      provider.startAutoRefresh();
    });
  }

  @override
  void dispose() {
    // Stop auto-refresh when leaving screen
    context.read<VitalSignsProvider>().stopAutoRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Giám Sát Sức Khỏe'),
        backgroundColor: Colors.blue.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<VitalSignsProvider>().fetchLatestVitals();
            },
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: Consumer<VitalSignsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.currentVitals == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (provider.errorMessage != null &&
              provider.currentVitals == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    provider.errorMessage!,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => provider.fetchLatestVitals(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          final vitals = provider.currentVitals;
          if (vitals == null) {
            return Center(
              child: Text(
                'Không có dữ liệu',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchLatestVitals(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Last update timestamp
                  _buildTimestampCard(vitals),
                  const SizedBox(height: 16),
                  // Vital signs grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.0,
                    children: [
                      // Heart Rate
                      VitalCard(
                        title: 'Nhịp tim',
                        value: vitals.heartRate?.toStringAsFixed(0) ?? '--',
                        unit: 'BPM',
                        icon: Icons.favorite,
                        status: vitals.getHeartRateStatus(),
                        onTap: () {
                          // TODO: Navigate to detail view
                        },
                      ),
                      // SpO2
                      VitalCard(
                        title: 'Oxy máu',
                        value: vitals.spo2?.toStringAsFixed(1) ?? '--',
                        unit: '%',
                        icon: Icons.water_drop,
                        status: vitals.getSpo2Status(),
                        onTap: () {
                          // TODO: Navigate to detail view
                        },
                      ),
                      // Temperature
                      VitalCard(
                        title: 'Nhiệt độ',
                        value: vitals.temperature?.toStringAsFixed(1) ?? '--',
                        unit: '°C',
                        icon: Icons.thermostat,
                        status: vitals.getTemperatureStatus(),
                        onTap: () {
                          // TODO: Navigate to detail view
                        },
                      ),
                      // Respiratory Rate
                      VitalCard(
                        title: 'Nhịp thở',
                        value:
                            vitals.respiratoryRate?.toStringAsFixed(0) ?? '--',
                        unit: '/phút',
                        icon: Icons.air,
                        status: vitals.getRespiratoryRateStatus(),
                        onTap: () {
                          // TODO: Navigate to detail view
                        },
                      ),
                      // Blood Pressure - spans 2 columns
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Blood Pressure Card (wider)
                  _buildBloodPressureCard(vitals),
                  const SizedBox(height: 24),
                  // Quick actions
                  _buildQuickActions(context),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimestampCard(VitalSigns vitals) {
    final timeDiff = DateTime.now().difference(vitals.timestamp);
    String timeAgo;
    if (timeDiff.inSeconds < 60) {
      timeAgo = 'Vừa xong';
    } else if (timeDiff.inMinutes < 60) {
      timeAgo = '${timeDiff.inMinutes} phút trước';
    } else {
      timeAgo = '${timeDiff.inHours} giờ trước';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: vitals.isStale ? Colors.orange.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              vitals.isStale ? Colors.orange.shade200 : Colors.blue.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            vitals.isStale ? Icons.warning_amber : Icons.check_circle,
            color:
                vitals.isStale ? Colors.orange.shade700 : Colors.blue.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              vitals.isStale
                  ? 'Dữ liệu cũ - Cập nhật $timeAgo'
                  : 'Cập nhật $timeAgo',
              style: TextStyle(
                fontSize: 13,
                color: vitals.isStale
                    ? Colors.orange.shade900
                    : Colors.blue.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (vitals.isStale)
            Icon(
              Icons.sync_problem,
              color: Colors.orange.shade700,
              size: 20,
            ),
        ],
      ),
    );
  }

  Widget _buildBloodPressureCard(VitalSigns vitals) {
    final sysStatus = vitals.getBloodPressureSysStatus();
    final diaStatus = vitals.getBloodPressureDiaStatus();
    // Use worse status
    final overallStatus =
        sysStatus.index > diaStatus.index ? sysStatus : diaStatus;

    Color backgroundColor;
    Color borderColor;
    Color iconColor;

    switch (overallStatus) {
      case VitalStatus.normal:
        backgroundColor = Colors.green.shade50;
        borderColor = Colors.green.shade200;
        iconColor = Colors.green.shade700;
        break;
      case VitalStatus.warning:
        backgroundColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade300;
        iconColor = Colors.orange.shade700;
        break;
      case VitalStatus.critical:
        backgroundColor = Colors.red.shade50;
        borderColor = Colors.red.shade300;
        iconColor = Colors.red.shade700;
        break;
      case VitalStatus.unknown:
        backgroundColor = Colors.grey.shade50;
        borderColor = Colors.grey.shade300;
        iconColor = Colors.grey.shade700;
        break;
    }

    return InkWell(
      onTap: () {
        // TODO: Navigate to detail view
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: iconColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.monitor_heart,
              size: 40,
              color: iconColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Huyết áp',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        vitals.bloodPressureSys?.toStringAsFixed(0) ?? '--',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: iconColor,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          ' / ',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Text(
                        vitals.bloodPressureDia?.toStringAsFixed(0) ?? '--',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'mmHg',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tâm thu / Tâm trương',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hành động nhanh',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.history,
                label: 'Lịch sử',
                onTap: () {
                  // TODO: Navigate to history
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.analytics,
                label: 'Thống kê',
                onTap: () {
                  // TODO: Navigate to statistics
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.blue.shade700, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
