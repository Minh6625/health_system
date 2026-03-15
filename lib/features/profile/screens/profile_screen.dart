import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/material.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/profile/models/user_profile_model.dart';
import 'package:healthguard/features/profile/providers/profile_provider.dart';
import 'package:healthguard/features/family/providers/target_profile_provider.dart';
import 'package:healthguard/features/device/providers/device_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProfileProvider>().fetchProfile();
      context.read<DeviceProvider>().fetchDevices();
    });
  }

  int? _calculateAge(DateTime? dob) {
    if (dob == null) return null;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Chưa cập nhật';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'patient':
        return 'Bệnh nhân';
      case 'caregiver':
        return 'Người chăm sóc';
      case 'admin':
        return 'Quản trị viên';
      default:
        return role;
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final passwordController = TextEditingController();
    bool obscure = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning_rounded, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  const Text('Xóa tài khoản'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      'Tài khoản và toàn bộ dữ liệu của bạn sẽ bị xóa sau 30 ngày. Hành động này không thể hoàn tác.',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Nhập mật khẩu xác nhận',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                  ),
                  child: const Text(
                    'Xóa tài khoản',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final password = passwordController.text.trim();
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập mật khẩu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final provider = context.read<ProfileProvider>();
    final success = await provider.deleteAccount(password: password);
    if (!mounted) return;

    if (success) {
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouter.login,
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Xóa tài khoản thất bại'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
    passwordController.dispose();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Xác nhận đăng xuất'),
          content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Đăng xuất',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    context.read<ProfileProvider>().clearProfile();
    context.read<TargetProfileProvider>().clearData();
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRouter.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF4F7FB),
          appBar: AppBar(
            title: const Text('Thông tin cá nhân'),
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                onPressed: profileProvider.isLoading
                    ? null
                    : () => context.read<ProfileProvider>().fetchProfile(),
                icon: const Icon(Icons.refresh),
                tooltip: 'Làm mới',
              ),
            ],
          ),
          body: _buildBody(context, profileProvider),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ProfileProvider profileProvider) {
    final deviceProvider = context.watch<DeviceProvider>();
    if (profileProvider.isLoading && profileProvider.profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (profileProvider.errorMessage != null &&
        profileProvider.profile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_off_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                profileProvider.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.read<ProfileProvider>().fetchProfile(),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final profile = profileProvider.profile;
    if (profile == null) return const SizedBox.shrink();

    final age = _calculateAge(profile.dateOfBirth);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(profile),
          const SizedBox(height: 20),
          _buildDeviceCard(context, deviceProvider),
          const SizedBox(height: 20),
          _buildSectionTitle('Thông tin cá nhân'),
          const SizedBox(height: 10),
          _buildInfoCard([
            _InfoRow(
              icon: Icons.person_outline,
              label: 'Họ và tên',
              value: profile.fullName,
            ),
            _InfoRow(
              icon: Icons.cake_outlined,
              label: 'Ngày sinh',
              value: _formatDate(profile.dateOfBirth),
            ),
            _InfoRow(
              icon: Icons.numbers_outlined,
              label: 'Tuổi',
              value: age != null ? '$age tuổi' : 'Chưa cập nhật',
            ),
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Số điện thoại',
              value: profile.phone ?? 'Chưa cập nhật',
            ),
            _InfoRow(
              icon: Icons.wc_outlined,
              label: 'Giới tính',
              value: profile.gender ?? 'Chưa cập nhật',
            ),
            _InfoRow(
              icon: Icons.bloodtype_outlined,
              label: 'Nhóm máu',
              value: profile.bloodType ?? 'Chưa cập nhật',
            ),
          ]),
          const SizedBox(height: 20),
          _buildSectionTitle('Thông tin y tế'),
          const SizedBox(height: 10),
          _buildInfoCard([
            _InfoRow(
              icon: Icons.height_outlined,
              label: 'Chiều cao',
              value: profile.heightCm != null
                  ? '${profile.heightCm!.toStringAsFixed(1)} cm'
                  : 'Chưa cập nhật',
            ),
            _InfoRow(
              icon: Icons.monitor_weight_outlined,
              label: 'Cân nặng',
              value: profile.weightKg != null
                  ? '${profile.weightKg!.toStringAsFixed(1)} kg'
                  : 'Chưa cập nhật',
            ),
            _InfoRow(
              icon: Icons.medication_outlined,
              label: 'Thuốc đang dùng',
              value: profile.medications.isNotEmpty
                  ? profile.medications.join(', ')
                  : 'Không có',
            ),
            _InfoRow(
              icon: Icons.warning_amber_outlined,
              label: 'Dị ứng',
              value: profile.allergies.isNotEmpty
                  ? profile.allergies.join(', ')
                  : 'Không có',
            ),
            _InfoRow(
              icon: Icons.history_edu_outlined,
              label: 'Tiền sử bệnh',
              value: profile.medicalConditions.isEmpty
                  ? 'Chưa cập nhật'
                  : profile.medicalConditions.join(', '),
            ),
          ]),
          const SizedBox(height: 20),
          _buildSectionTitle('Thông tin tài khoản'),
          const SizedBox(height: 10),
          _buildInfoCard([
            _InfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: profile.email,
            ),
            _InfoRow(
              icon: Icons.badge_outlined,
              label: 'Vai trò',
              value: _roleLabel(profile.role),
            ),
            _InfoRow(
              icon: Icons.verified_user_outlined,
              label: 'Xác minh email',
              value: profile.isVerified ? 'Đã xác minh' : 'Chưa xác minh',
              valueColor: profile.isVerified
                  ? Colors.green.shade700
                  : Colors.orange.shade700,
            ),
            _InfoRow(
              icon: Icons.toggle_on_outlined,
              label: 'Trạng thái',
              value: profile.isActive ? 'Đang hoạt động' : 'Bị khóa',
              valueColor: profile.isActive
                  ? Colors.green.shade700
                  : Colors.red.shade700,
            ),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Ngày tạo tài khoản',
              value: _formatDateTime(profile.createdAt),
            ),
            _InfoRow(
              icon: Icons.update_outlined,
              label: 'Cập nhật lần cuối',
              value: _formatDateTime(profile.updatedAt),
            ),
          ]),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/family-management');
              },
              icon: const Icon(Icons.family_restroom_outlined),
              label: const Text(
                'Quản lý Gia đình',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(
                  0xFF0369A1,
                ), // Different shade for variation
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.pushNamed(context, '/edit-profile');
                if (mounted) {
                  context.read<ProfileProvider>().fetchProfile();
                }
              },
              icon: const Icon(Icons.settings_outlined),
              label: const Text(
                'Cài đặt thông tin',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                'Đăng xuất',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _confirmDeleteAccount,
              icon: Icon(
                Icons.delete_forever_outlined,
                color: Colors.red.shade800,
              ),
              label: Text(
                'Xóa tài khoản',
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade800),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(UserProfileModel profile) {
    final avatar = profile.avatarUrl;
    final trimmedName = profile.fullName.trim();
    final initial = trimmedName.isNotEmpty
        ? trimmedName.substring(0, 1).toUpperCase()
        : 'U';

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
            color: const Color(0xFF0F766E).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: Colors.white,
            backgroundImage: avatar != null && avatar.isNotEmpty
                ? NetworkImage(avatar)
                : null,
            child: avatar == null || avatar.isEmpty
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
          const SizedBox(height: 12),
          Text(
            profile.fullName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profile.email,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _buildBadge(
                _roleLabel(profile.role),
                Colors.white.withValues(alpha: 0.2),
                Colors.white,
              ),
              _buildBadge(
                profile.isVerified ? 'Đã xác minh' : 'Chưa xác minh',
                profile.isVerified
                    ? Colors.green.shade400.withValues(alpha: 0.3)
                    : Colors.orange.shade400.withValues(alpha: 0.3),
                Colors.white,
              ),
              _buildBadge(
                profile.isActive ? 'Hoạt động' : 'Bị khóa',
                profile.isActive
                    ? Colors.green.shade400.withValues(alpha: 0.3)
                    : Colors.red.shade400.withValues(alpha: 0.3),
                Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
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
            color: Colors.black.withValues(alpha: 0.05),
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

  Widget _buildDeviceCard(BuildContext context, DeviceProvider provider) {
    if (provider.isLoading && provider.devices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasDevice = provider.devices.isNotEmpty;
    final deviceName = hasDevice
        ? provider.devices.first.deviceName
        : 'Chưa có kết nối';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pushNamed(context, '/device');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
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
                        deviceName ?? 'Chưa có thiết bị',
                        style: TextStyle(
                          fontSize: 14,
                          color: hasDevice
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                          fontWeight: hasDevice
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
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
