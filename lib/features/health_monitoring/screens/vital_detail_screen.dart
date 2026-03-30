import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/vital_signs.dart';
import '../providers/vital_signs_provider.dart';
import '../widgets/animated_vital_value.dart';
import '../widgets/mini_line_chart.dart';
import '../widgets/vital_detail_skeleton.dart';
import '../widgets/empty_chart_placeholder.dart';
import '../widgets/error_view.dart';

class VitalDetailScreen extends StatefulWidget {
  final String vitalType;
  final String? profileId;

  const VitalDetailScreen({
    super.key,
    required this.vitalType,
    this.profileId,
  });

  @override
  State<VitalDetailScreen> createState() => _VitalDetailScreenState();
}

class _VitalDetailScreenState extends State<VitalDetailScreen> {
  late final VitalSignsProvider _vitalsProvider;

  @override
  void initState() {
    super.initState();
    _vitalsProvider = VitalSignsProvider(
      vitalType: widget.vitalType,
      profileId: widget.profileId,
    )..startPolling();
  }

  @override
  void dispose() {
    _vitalsProvider.dispose();
    super.dispose();
  }

  Color _getStatusColor(VitalStatus status) => switch (status) {
        VitalStatus.normal => Colors.green.shade700,
        VitalStatus.warning => Colors.orange.shade700,
        VitalStatus.critical => Colors.red.shade700,
        VitalStatus.unknown => Colors.grey.shade700,
      };

  String _getStatusText(VitalStatus status) => switch (status) {
        VitalStatus.normal => 'Bình thường',
        VitalStatus.warning => 'Cảnh báo',
        VitalStatus.critical => 'Nguy hiểm',
        VitalStatus.unknown => 'Không rõ',
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vitalsProvider,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: _buildAppBar(_vitalsProvider),
          body: SafeArea(
            child: _buildBody(_vitalsProvider),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(VitalSignsProvider provider) {
    return AppBar(
      title: Column(
        children: [
          Text(
            provider.title.isNotEmpty ? provider.title : 'Chi tiết chỉ số',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (provider.linkedProfileName.isNotEmpty)
            Text(
              provider.linkedProfileName,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
        ],
      ),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      centerTitle: true,
    );
  }

  Widget _buildBody(VitalSignsProvider provider) {
    switch (provider.state) {
      case VitalsUIState.initial:
      case VitalsUIState.loading:
        return const VitalDetailSkeleton();
      case VitalsUIState.error:
        return ErrorView(
          message: 'Không thể tải dữ liệu.\nVui lòng kiểm tra kết nối mạng.',
          onRetry: () {
            provider.refresh();
          },
        );
      case VitalsUIState.empty:
      case VitalsUIState.success:
        return _buildContent(provider);
    }
  }

  Widget _buildContent(VitalSignsProvider provider) {
    final statusColor = _getStatusColor(provider.vitalStatus);
    final isCritical = provider.vitalStatus == VitalStatus.critical;
    final isEmpty = provider.state == VitalsUIState.empty;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Nổi bật hiện tại (Huge latest value)
                _buildVitalValueCard(provider, statusColor),
                
                const SizedBox(height: 24),

                // 2. Biểu đồ chuyên biệt (Mini chart - 24h trend)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Biến động 24h qua',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                         // TODO: navigate to history
                      },
                      child: const Text(
                        'Xem xu hướng',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (isEmpty || provider.chartData.isEmpty)
                  const EmptyChartPlaceholder(message: 'Chưa có dữ liệu xu hướng')
                else
                  Container(
                    height: 180,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: MiniLineChart(
                      linesData: provider.chartData,
                      lineColors: provider.chartColors,
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
                          provider.educationText,
                          style: TextStyle(
                            fontSize: 16, // Increase to 16sp per accessibility spec
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
        
        // 4. Cảnh báo hoặc SOS (Contextual actions)
        if (isCritical) 
          _buildCriticalAction(provider),
      ],
    );
  }

  Widget _buildVitalValueCard(VitalSignsProvider provider, Color statusColor) {
    final updatedAt = provider.vitals?.timestamp;

    return Container(
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
              _getStatusText(provider.vitalStatus),
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
                  value: provider.value,
                  fontSize: 84, // 84sp for elderly view
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Text(
                  provider.unit,
                  style: TextStyle(
                    fontSize: 28, // 28sp unit
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (updatedAt != null) ...[
            const SizedBox(height: 16),
            Text(
              'Cập nhật lúc ${DateFormat('HH:mm:ss').format(updatedAt.toLocal())}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCriticalAction(VitalSignsProvider provider) {
    if (provider.isSelf) {
      // Self + Critical -> SOS Button
      return Container(
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
            onPressed: () {
               // navigate to SOS trigger (left as TODO pending exact route)
            },
            icon: const Icon(Icons.emergency, size: 28),
            label: const Text(
              'GỌI CẤP CỨU',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 64), // Increased from 48 to 64
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
          ),
        ),
      );
    } else {
      // Linked + Critical -> Warning Banner, No SOS per UC007 / Requirement
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        color: Colors.red.shade50,
        child: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Chỉ số nguy hiểm! Vui lòng liên hệ ${provider.linkedProfileName.isNotEmpty ? provider.linkedProfileName : 'người thân'} ngay.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}
