import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/profile/models/user_profile_model.dart';
import 'package:healthguard/features/profile/providers/profile_provider.dart';
import 'package:healthguard/features/device/providers/device_provider.dart';
import 'package:healthguard/features/profile/widgets/profile_widgets.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';

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

  // ── Helpers ──────────────────────────────────────────────────────────────

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

  // ── Logout ───────────────────────────────────────────────────────────────

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.radiusLg)),
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.critical,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.radiusSm)),
            ),
            child: const Text('Đăng xuất',
                style: TextStyle(color: AppColors.bgSurface)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    context.read<ProfileProvider>().clearProfile();
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRouter.login,
      (route) => false,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, _) {
        return _buildBody(context, profileProvider);
      },
    );
  }

  Widget _buildBody(BuildContext context, ProfileProvider profileProvider) {
    // First load: no cached data yet → show skeleton
    if (profileProvider.isLoading && profileProvider.profile == null) {
      return const ProfileSkeletonBody();
    }

    // Error
    if (profileProvider.errorMessage != null &&
        profileProvider.profile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_outlined,
                  size: 64, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                profileProvider.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () =>
                    context.read<ProfileProvider>().fetchProfile(force: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.bgSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final profile = profileProvider.profile;
    if (profile == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroCard(profile),
          const SizedBox(height: 24),

          // ── Tài khoản ──────────────────────────────────────────────
          const ProfileSectionLabel('Tài khoản'),
          ProfileSectionCard(
            child: Column(
              children: [
                ProfileMenuTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Chỉnh sửa hồ sơ',
                  subtitle: 'Tên, ngày sinh, số điện thoại…',
                  isFirst: true,
                  onTap: () async {
                    await Navigator.pushNamed(context, AppRouter.editProfile);
                    if (mounted) {
                      profileProvider.fetchProfile();
                    }
                  },
                ),
                const ProfileMenuDivider(),
                ProfileMenuTile(
                  icon: Icons.medical_information_outlined,
                  title: 'Thông tin y tế',
                  subtitle: 'Nhóm máu, chiều cao, bệnh nền…',
                  onTap: () async {
                    await Navigator.pushNamed(context, AppRouter.medicalInfo);
                    if (mounted) {
                      profileProvider.fetchProfile();
                    }
                  },
                ),
                const ProfileMenuDivider(),
                ProfileMenuTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Đổi mật khẩu',
                  isLast: true,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRouter.changePassword),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Kết nối ────────────────────────────────────────────────
          const ProfileSectionLabel('Kết nối'),
          ProfileSectionCard(
            child: Column(
              children: [
                _DeviceTile(isFirst: true, isLast: false),
                const ProfileMenuDivider(),
                ProfileMenuTile(
                  icon: Icons.family_restroom_rounded,
                  iconColor: AppColors.info,
                  title: 'Quản lý gia đình',
                  subtitle: 'Liên kết, danh bạ, người chăm sóc',
                  isLast: true,
                  onTap: () => Navigator.pushNamed(
                      context, AppRouter.familyManagement),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Danger Zone ────────────────────────────────────────────
          const ProfileSectionLabel('Vùng nguy hiểm'),
          DangerZoneCard(
            children: [
              DangerMenuTile(
                icon: Icons.logout_rounded,
                title: 'Đăng xuất',
                isFirst: true,
                onTap: _confirmLogout,
              ),
              Divider(
                height: 1,
                indent: 70,
                color: AppColors.critical.withValues(alpha: 0.2),
              ),
              DangerMenuTile(
                icon: Icons.delete_forever_outlined,
                title: 'Xóa tài khoản',
                subtitle: 'Dữ liệu sẽ bị xóa sau 30 ngày',
                isLast: true,
                onTap: () =>
                    Navigator.pushNamed(context, AppRouter.deleteAccount),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Hero Card ─────────────────────────────────────────────────────────────

  Widget _buildHeroCard(UserProfileModel profile) {
    final trimmedName = profile.fullName.trim();
    final initial =
        trimmedName.isNotEmpty ? trimmedName.substring(0, 1).toUpperCase() : 'U';
    final age = _calculateAge(profile.dateOfBirth);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandPrimary, AppColors.brandPrimaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPrimary.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.bgSurface,
            backgroundImage: (profile.avatarUrl?.isNotEmpty ?? false)
                ? NetworkImage(profile.avatarUrl!)
                : null,
            child: (profile.avatarUrl?.isNotEmpty ?? false)
                ? null
                : Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 34,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.fullName,
            style: const TextStyle(
              color: AppColors.bgSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profile.email,
            style: TextStyle(
              color: AppColors.bgSurface.withValues(alpha: 0.82),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _HeroBadge(_roleLabel(profile.role)),
              if (age != null) _HeroBadge('$age tuổi'),
              _HeroBadge(
                profile.isVerified ? 'Đã xác minh ✓' : 'Chưa xác minh',
                bgColor: profile.isVerified
                    ? AppColors.success.withValues(alpha: 0.28)
                    : AppColors.warning.withValues(alpha: 0.28),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helpers
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBadge extends StatelessWidget {
  final String label;
  final Color? bgColor;

  const _HeroBadge(this.label, {this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor ?? AppColors.bgSurface.withValues(alpha: 0.18),
        borderRadius: AppRadii.pillRadius,
        border: Border.all(color: AppColors.bgSurface.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.bgSurface,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Reads DeviceProvider and renders a tappable device tile.
class _DeviceTile extends StatelessWidget {
  final bool isFirst;
  final bool isLast;

  const _DeviceTile({required this.isFirst, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
    final hasDevice = deviceProvider.devices.isNotEmpty;
    final deviceName = hasDevice
        ? (deviceProvider.devices.first.deviceName ?? 'Thiết bị của tôi')
        : 'Chưa có thiết bị';

    return ProfileMenuTile(
      icon: Icons.watch_rounded,
      iconColor: hasDevice ? AppColors.success : AppColors.brandPrimary,
      title: 'Thiết bị kết nối',
      subtitle: deviceName,
      isFirst: isFirst,
      isLast: isLast,
      onTap: () => Navigator.pushNamed(context, AppRouter.device),
    );
  }
}
