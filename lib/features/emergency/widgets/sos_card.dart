import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:healthguard/features/emergency/models/sos_event_model.dart';
import 'package:healthguard/features/emergency/widgets/status_badge.dart';
import 'package:intl/intl.dart';

/// Card widget for displaying SOS event in list
class SOSCard extends StatelessWidget {
  final SOSEventModel sos;
  final VoidCallback onTap;
  final VoidCallback onCallPressed;
  final VoidCallback onMapPressed;

  const SOSCard({
    super.key,
    required this.sos,
    required this.onTap,
    required this.onCallPressed,
    required this.onMapPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: sos.isActive
            ? const BorderSide(color: Color(0xFFD32F2F), width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Patient Photo
              _buildPatientPhoto(),
              const SizedBox(width: 16),

              // Info Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sos.patient.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    StatusBadge(status: sos.status),
                    const SizedBox(height: 8),
                    _buildTriggerTypeRow(),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimeAgo(sos.triggerTime),
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              // Quick Actions
              Column(
                children: [
                  _buildQuickActionButton(
                    icon: Icons.phone,
                    label: 'Gọi',
                    color: const Color(0xFF4CAF50),
                    onPressed: onCallPressed,
                  ),
                  const SizedBox(height: 8),
                  _buildQuickActionButton(
                    icon: Icons.map,
                    label: 'Đường',
                    color: const Color(0xFF2196F3),
                    onPressed: onMapPressed,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientPhoto() {
    return Container(
      decoration: sos.isActive
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD32F2F).withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            )
          : null,
      child: CircleAvatar(
        radius: 30,
        backgroundImage: sos.patient.photoUrl != null
            ? CachedNetworkImageProvider(sos.patient.photoUrl!)
            : null,
        backgroundColor: Colors.grey[300],
        child: sos.patient.photoUrl == null
            ? const Icon(Icons.person, size: 30, color: Colors.white)
            : null,
      ),
    );
  }

  Widget _buildTriggerTypeRow() {
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
        label = 'Chỉ số tới hạn';
        break;
      default:
        icon = Icons.emergency;
        label = 'SOS khẩn cấp';
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 60,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final duration = DateTime.now().difference(time);

    if (duration.inMinutes < 1) {
      return 'Vừa xong';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes} phút trước';
    } else if (duration.inHours < 24) {
      return '${duration.inHours} giờ trước';
    } else if (duration.inDays == 1) {
      return 'Hôm qua';
    } else if (duration.inDays < 7) {
      return '${duration.inDays} ngày trước';
    } else {
      return DateFormat('dd/MM/yyyy').format(time);
    }
  }
}
