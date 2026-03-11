import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:healthguard/features/emergency/providers/emergency_caregiver_provider.dart';
import 'package:healthguard/features/emergency/widgets/status_badge.dart';
import 'package:intl/intl.dart';

/// SOS Detail screen for Caregiver
class EmergencySOSDetailScreen extends StatefulWidget {
  final String sosId;

  const EmergencySOSDetailScreen({super.key, required this.sosId});

  @override
  State<EmergencySOSDetailScreen> createState() =>
      _EmergencySOSDetailScreenState();
}

class _EmergencySOSDetailScreenState extends State<EmergencySOSDetailScreen> {
  late EmergencyCaregiverProvider _provider;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _provider = context.read<EmergencyCaregiverProvider>();
      _provider.fetchSOSDetail(widget.sosId);
      _provider.subscribeToSOSUpdates(widget.sosId);
    }
  }

  @override
  void dispose() {
    _provider.unsubscribeFromSOSUpdates();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết SOS')),
      body: Consumer<EmergencyCaregiverProvider>(
        builder: (context, provider, child) {
          // Loading state
          if (provider.isLoadingDetail) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (provider.detailErrorMessage != null) {
            return _buildErrorState(provider.detailErrorMessage!);
          }

          // Success state
          if (provider.sosDetail != null) {
            return _buildDetailContent(provider);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildDetailContent(EmergencyCaregiverProvider provider) {
    final sos = provider.sosDetail!;

    return Column(
      children: [
        // Patient Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: sos.isActive ? const Color(0xFFD32F2F) : Colors.grey[200],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: sos.patient.photoUrl != null
                    ? CachedNetworkImageProvider(sos.patient.photoUrl!)
                    : null,
                backgroundColor: Colors.grey[400],
                child: sos.patient.photoUrl == null
                    ? const Icon(Icons.person, size: 40, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sos.patient.name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: sos.isActive ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StatusBadge(status: sos.status),
                  ],
                ),
              ),
              if (sos.isActive)
                const Icon(Icons.emergency, size: 32, color: Colors.white),
            ],
          ),
        ),

        // Map Placeholder
        Container(
          height: 250,
          width: double.infinity,
          color: Colors.grey[300],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map, size: 64, color: Colors.grey[600]),
              const SizedBox(height: 8),
              Text(
                'Map view',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              if (sos.location.latitude != null)
                Text(
                  'Lat: ${sos.location.latitude!.toStringAsFixed(6)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              if (sos.location.longitude != null)
                Text(
                  'Lng: ${sos.location.longitude!.toStringAsFixed(6)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
          ),
        ),

        // Details Section
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLocationInfo(sos),
                const SizedBox(height: 24),
                _buildTimeInfo(sos),
                const SizedBox(height: 24),
                _buildTriggerInfo(sos),
                if (sos.fallDetectionXAI != null) ...[
                  const SizedBox(height: 24),
                  _buildXAITimeline(sos.fallDetectionXAI!),
                ],
                if (sos.resolution != null) ...[
                  const SizedBox(height: 24),
                  _buildResolutionInfo(sos.resolution!),
                ],
                const SizedBox(height: 80), // Space for action buttons
              ],
            ),
          ),
        ),

        // Action Buttons
        _buildActionButtons(provider, sos),
      ],
    );
  }

  Widget _buildLocationInfo(sos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vị trí',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'GPS: ${sos.location.latitude.toStringAsFixed(6)}, '
          '${sos.location.longitude.toStringAsFixed(6)}',
        ),
        Text('Độ chính xác: ${sos.location.accuracy.toStringAsFixed(1)} mét'),
        Text(
          'Cập nhật: ${DateFormat('HH:mm:ss - dd/MM/yyyy').format(sos.location.lastUpdated)}',
        ),
      ],
    );
  }

  Widget _buildTimeInfo(sos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thời gian',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Kích hoạt: ${DateFormat('HH:mm:ss - dd/MM/yyyy').format(sos.triggerTime)}',
        ),
        Text('Đã trôi qua: ${_formatElapsedTime(sos.elapsedTime)}'),
      ],
    );
  }

  Widget _buildTriggerInfo(sos) {
    IconData icon;
    String label;

    switch (sos.triggerType) {
      case 'fall_detected':
        icon = Icons.arrow_downward;
        label = 'Phát hiện té ngã';
        break;
      case 'manual':
        icon = Icons.touch_app;
        label = 'Kích hoạt thủ công';
        break;
      case 'vital_critical':
        icon = Icons.error;
        label = 'Chỉ số sinh tồn tới hạn';
        break;
      default:
        icon = Icons.emergency;
        label = 'SOS khẩn cấp';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nguyên nhân',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ],
    );
  }

  Widget _buildXAITimeline(xai) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chi tiết phát hiện té ngã',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Độ tin cậy: ${xai.confidence.toStringAsFixed(1)}%'),
          const SizedBox(height: 12),
          const Text(
            'Timeline:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...xai.timeline.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 16)),
                  Expanded(child: Text('${event.time} - ${event.description}')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionInfo(resolution) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thông tin xử lý',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Đã xử lý bởi: ${resolution.resolvedBy}'),
          Text(
            'Thời gian: ${DateFormat('HH:mm:ss - dd/MM/yyyy').format(resolution.resolvedTime)}',
          ),
          if (resolution.notes != null) ...[
            const SizedBox(height: 8),
            Text('Ghi chú: ${resolution.notes}'),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(EmergencyCaregiverProvider provider, sos) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
                child: ElevatedButton.icon(
                  onPressed: () => provider.makePhoneCall(sos.patient.phone),
                  icon: const Icon(Icons.phone),
                  label: const Text('Gọi điện'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 56),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => provider.openMapNavigation(
                    sos.location.latitude,
                    sos.location.longitude,
                  ),
                  icon: const Icon(Icons.map),
                  label: const Text('Chỉ đường'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 56),
                  ),
                ),
              ),
            ],
          ),
          if (sos.isActive) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmSafety(provider, sos.id),
                icon: const Icon(Icons.check_circle),
                label: const Text('Xác nhận'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              style: const TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              context.read<EmergencyCaregiverProvider>().fetchSOSDetail(
                widget.sosId,
              );
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  String _formatElapsedTime(Duration duration) {
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

  Future<void> _confirmSafety(
    EmergencyCaregiverProvider provider,
    String sosId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xử lý'),
        content: const Text(
          'Bạn có chắc chắn muốn xác nhận đã xử lý sự kiện này?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await provider.resolveSOSByCaregiver(
        sosId: sosId,
        resolutionStatus: 'safe',
        notes: 'Người chăm sóc xác nhận đã xử lý',
      );

      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã xác nhận xử lý')));
      }
    }
  }
}
