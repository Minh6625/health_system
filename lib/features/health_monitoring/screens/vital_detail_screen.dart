import 'package:flutter/material.dart';
import '../models/vital_signs.dart';
import '../widgets/animated_vital_value.dart';
import '../widgets/mini_line_chart.dart';

/// Micro-view screen showing details of a specific vital sign.
/// Displays huge current value, a 24h trend chart, education text, and SOS if critical.
class VitalDetailScreen extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final VitalStatus status;
  final List<List<double>> chartData;
  final List<Color> chartColors;
  final String educationText;
  final VoidCallback? onSosTap;

  const VitalDetailScreen({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.status,
    required this.chartData,
    required this.chartColors,
    required this.educationText,
    this.onSosTap,
  });

  Color _getStatusColor() => switch (status) {
        VitalStatus.normal => Colors.green.shade700,
        VitalStatus.warning => Colors.orange.shade700,
        VitalStatus.critical => Colors.red.shade700,
        VitalStatus.unknown => Colors.grey.shade700,
      };

  String _getStatusText() => switch (status) {
        VitalStatus.normal => 'Bình thường',
        VitalStatus.warning => 'Cảnh báo',
        VitalStatus.critical => 'Nguy hiểm',
        VitalStatus.unknown => 'Không rõ',
      };

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final isCritical = status == VitalStatus.critical;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Nổi bật hiện tại (Huge latest value)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _getStatusText(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                AnimatedVitalValue(
                                  value: value,
                                  fontSize: 84, // TO QUÁ KHỔ per plan
                                  color: statusColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  unit,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 2. Biểu đồ chuyên biệt (Mini chart - 24h trend)
                    Text(
                      'Biến động 24h qua',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 180,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: MiniLineChart(
                        linesData: chartData,
                        lineColors: chartColors,
                        height: 140,
                        xLabels: const ['6h', '9h', '12h', '15h', '18h', '21h', '0h', 'Bây giờ'],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 3. Kiến thức y khoa (Education Text)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              educationText,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.4,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 4. Nút Cấp cứu (Contextual SOS)
            if (isCritical)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Semantics(
                  button: true,
                  label: 'Gọi bác sĩ hoặc người thân ngay lập tức',
                  child: ElevatedButton.icon(
                    onPressed: onSosTap,
                    icon: const Icon(Icons.emergency, size: 28),
                    label: const Text(
                      'GỌI CẤP CỨU',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 64),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
