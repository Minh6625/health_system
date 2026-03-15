import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:healthguard/features/family/models/relationship.dart';
import 'package:healthguard/features/family/providers/target_profile_provider.dart';
import 'package:healthguard/features/profile/providers/profile_provider.dart';

class UserDetailScreen extends StatefulWidget {
  final int userId;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final bool isActive;

  const UserDetailScreen({
    super.key,
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.isActive = true,
  });

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final targetProvider = Provider.of<TargetProfileProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final currentUserId = profileProvider.profile?.userId;

    Relationship? relationship;
    if (currentUserId != null) {
      try {
        relationship = targetProvider.relationships.firstWhere(
          (r) =>
              (r.patientId == currentUserId &&
                  r.caregiverId == widget.userId) ||
              (r.caregiverId == currentUserId && r.patientId == widget.userId),
        );
      } catch (_) {
        relationship = null;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Thông tin người dùng'),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 20),
            _buildSectionTitle('Thiết bị kết nối'),
            const SizedBox(height: 10),
            _buildDeviceCard(),
            const SizedBox(height: 20),
            _buildSectionTitle('Thông tin cá nhân'),
            const SizedBox(height: 10),
            _buildInfoCard([
              _InfoRow(
                icon: Icons.person_outline,
                label: 'Họ và tên',
                value: widget.name,
              ),
              _InfoRow(
                icon: Icons.cake_outlined,
                label: 'Ngày sinh',
                value: 'Chưa cập nhật',
              ),
              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'Số điện thoại',
                value: widget.phone ?? 'Chưa cập nhật',
              ),
              _InfoRow(
                icon: Icons.wc_outlined,
                label: 'Giới tính',
                value: 'Chưa cập nhật',
              ),
            ]),
            const SizedBox(height: 48),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(
        context,
        targetProvider,
        currentUserId,
        relationship,
      ),
    );
  }

  Widget _buildHeaderCard() {
    final initial = widget.name.isNotEmpty ? widget.name[0].toUpperCase() : 'U';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.white,
                backgroundImage:
                    widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                    ? NetworkImage(widget.avatarUrl!)
                    : null,
                child: widget.avatarUrl == null || widget.avatarUrl!.isEmpty
                    ? Text(
                        initial,
                        style: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                        ),
                      )
                    : null,
              ),
              if (widget.isActive)
                Positioned(
                  bottom: 2,
                  right: 4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.email,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F766E),
      ),
    );
  }

  Widget _buildInfoCard(List<_InfoRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final idx = entry.key;
          final row = entry.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(row.icon, size: 20, color: const Color(0xFF0F766E)),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Text(
                        row.label,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        row.value,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: row.valueColor ?? Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (idx < rows.length - 1)
                Divider(height: 1, indent: 48, color: Colors.grey.shade100),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDeviceCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.watch, color: Color(0xFF0F766E)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thiết bị kết nối',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chưa có thiết bị',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(
    BuildContext context,
    TargetProfileProvider provider,
    int? currentUserId,
    Relationship? relationship,
  ) {
    if (currentUserId == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: _buildButtons(provider, currentUserId, relationship),
      ),
    );
  }

  Widget _buildButtons(
    TargetProfileProvider provider,
    int currentUserId,
    Relationship? relationship,
  ) {
    if (_isProcessing) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (relationship == null) {
      return ElevatedButton(
        onPressed: () async {
          setState(() => _isProcessing = true);
          await provider.requestAccess(widget.email, background: true);
          if (mounted) {
            setState(() => _isProcessing = false);
            Navigator.pop(context, true);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
        ),
        child: const Text(
          'Gửi liên kết',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );
    }

    if (relationship.status == 'accepted') {
      return OutlinedButton(
        onPressed: () async {
          setState(() => _isProcessing = true);
          await provider.removeRelationship(relationship.id, background: true);
          if (mounted) {
            setState(() => _isProcessing = false);
            Navigator.pop(context, true);
          }
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red.shade600,
          side: BorderSide(color: Colors.red.shade200, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text(
          'Hủy liên kết',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );
    }

    if (relationship.status == 'pending') {
      if (relationship.caregiverId == currentUserId) {
        return OutlinedButton(
          onPressed: () async {
            setState(() => _isProcessing = true);
            await provider.removeRelationship(
              relationship.id,
              background: true,
            );
            if (mounted) {
              setState(() => _isProcessing = false);
              Navigator.pop(context, true);
            }
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey.shade700,
            side: BorderSide(color: Colors.grey.shade400, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text(
            'Hủy yêu cầu',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        );
      } else {
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  setState(() => _isProcessing = true);
                  await provider.removeRelationship(
                    relationship.id,
                    background: true,
                  );
                  if (mounted) {
                    setState(() => _isProcessing = false);
                    Navigator.pop(context, true);
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Hủy',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  setState(() => _isProcessing = true);
                  await provider.acceptRequest(
                    relationship.id,
                    background: true,
                  );
                  if (mounted) {
                    setState(() => _isProcessing = false);
                    Navigator.pop(context, true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: const Text(
                  'Xác nhận',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      }
    }
    return const SizedBox.shrink();
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
}
