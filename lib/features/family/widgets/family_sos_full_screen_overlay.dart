import 'package:flutter/material.dart';
import 'package:healthguard/features/family/models/family_profile_snapshot.dart';

/// Full-screen modal overlay hiển thị khi có SOS active khi vào tab Theo dõi.
class FamilySOSFullScreenOverlay extends StatelessWidget {
  /// Danh sách profiles đang có SOS (có thể nhiều hơn 1).
  final List<FamilyProfileSnapshot> sosProfiles;
  /// Callback khi bấm "Xem ngay" — truyền sosId (KHÔNG phải profileId)
  final void Function(String sosId) onViewDetail;
  final VoidCallback onDismiss;

  const FamilySOSFullScreenOverlay({
    super.key,
    required this.sosProfiles,
    required this.onViewDetail,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final primary = sosProfiles.first;
    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon cảnh báo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE53935), width: 2),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFE53935),
                    size: 44,
                  ),
                ),
                const SizedBox(height: 24),
                // Tiêu đề
                const Text(
                  'Yêu cầu SOS!',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  sosProfiles.length == 1
                      ? '${primary.name} đang cần hỗ trợ khẩn cấp'
                      : '${sosProfiles.length} người đang cần hỗ trợ khẩn cấp',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Card thông tin người SOS
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: sosProfiles.map((p) => _buildProfileRow(p)).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                // CTA "Xem ngay"
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => onViewDetail(primary.sosId ?? primary.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Xem ngay',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Nút đóng
                TextButton(
                  onPressed: onDismiss,
                  child: const Text(
                    'Đóng',
                    style: TextStyle(color: Colors.white60, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileRow(FamilyProfileSnapshot p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFE53935).withValues(alpha: 0.2),
            child: Text(
              p.name.isNotEmpty ? p.name[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE53935),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  p.relation,
                  style: const TextStyle(fontSize: 13, color: Colors.white54),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
        ],
      ),
    );
  }
}
