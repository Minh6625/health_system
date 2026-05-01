import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

import 'package:healthguard/features/profile/widgets/profile_widgets.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Permission status enum
// ─────────────────────────────────────────────────────────────────────────────
enum _PermStatus {
  notChecked,
  loading,
  granted,
  denied,
  permanentlyDenied,
}

// ─────────────────────────────────────────────────────────────────────────────
// PermissionsSection
// Shows location, notification, and full-screen intent permission statuses.
// ─────────────────────────────────────────────────────────────────────────────
class PermissionsSection extends StatefulWidget {
  const PermissionsSection({super.key});

  @override
  State<PermissionsSection> createState() => _PermissionsSectionState();
}

class _PermissionsSectionState extends State<PermissionsSection>
    with WidgetsBindingObserver {
  final _plugin = FlutterLocalNotificationsPlugin();

  _PermStatus _locStatus = _PermStatus.loading;
  _PermStatus _notifStatus = _PermStatus.loading;

  // Full-screen is only checked on user tap (calling on init may open Settings
  // on Android 14+ if not yet granted, which would be unexpected).
  _PermStatus _fullscreenStatus = _PermStatus.notChecked;

  bool _isAndroid() => !kIsWeb && Platform.isAndroid;

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin {
    if (!_isAndroid()) return null;
    return _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLocation();
    _checkNotification();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh when user returns from Settings.
    if (state == AppLifecycleState.resumed) {
      _checkLocation();
      _checkNotification();
      if (_fullscreenStatus != _PermStatus.notChecked) {
        _refreshFullScreen();
      }
    }
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _checkLocation() async {
    if (!mounted) return;
    setState(() => _locStatus = _PermStatus.loading);
    try {
      if (kIsWeb) {
        if (mounted) setState(() => _locStatus = _PermStatus.denied);
        return;
      }
      final permission = await Geolocator.checkPermission();
      if (!mounted) return;
      setState(() {
        _locStatus = switch (permission) {
          LocationPermission.always ||
          LocationPermission.whileInUse =>
            _PermStatus.granted,
          LocationPermission.deniedForever => _PermStatus.permanentlyDenied,
          _ => _PermStatus.denied,
        };
      });
    } catch (_) {
      if (mounted) setState(() => _locStatus = _PermStatus.denied);
    }
  }

  Future<void> _requestLocation() async {
    if (_locStatus == _PermStatus.permanentlyDenied) {
      await Geolocator.openAppSettings();
      return;
    }
    if (!mounted) return;
    setState(() => _locStatus = _PermStatus.loading);
    try {
      final permission = await Geolocator.requestPermission();
      if (!mounted) return;
      setState(() {
        _locStatus = switch (permission) {
          LocationPermission.always ||
          LocationPermission.whileInUse =>
            _PermStatus.granted,
          LocationPermission.deniedForever => _PermStatus.permanentlyDenied,
          _ => _PermStatus.denied,
        };
      });
    } catch (_) {
      if (mounted) setState(() => _locStatus = _PermStatus.denied);
    }
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<void> _checkNotification() async {
    if (!mounted) return;
    setState(() => _notifStatus = _PermStatus.loading);
    try {
      final androidPlugin = _androidPlugin;
      if (androidPlugin == null) {
        // Non-Android: treat as granted.
        if (mounted) setState(() => _notifStatus = _PermStatus.granted);
        return;
      }
      // requestNotificationsPermission returns current state without showing
      // a dialog if the permission was already determined (granted or denied).
      // It will only show the system dialog on the very first request on
      // Android 13+.
      final granted =
          await androidPlugin.requestNotificationsPermission() ?? true;
      if (mounted) {
        setState(
          () =>
              _notifStatus =
                  granted ? _PermStatus.granted : _PermStatus.denied,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _notifStatus = _PermStatus.denied);
    }
  }

  // ── Full-screen intent ────────────────────────────────────────────────────

  // Safe refresh: re-check without opening Settings if already granted.
  Future<void> _refreshFullScreen() async {
    if (!mounted) return;
    final androidPlugin = _androidPlugin;
    if (androidPlugin == null) {
      if (mounted) setState(() => _fullscreenStatus = _PermStatus.granted);
      return;
    }
    try {
      // On Android < 14: returns null (granted by manifest).
      // On Android 14+, granted: returns true without opening Settings.
      // On Android 14+, denied: would open Settings — we skip this silently
      // and keep the current status; user must tap the tile to trigger it.
      setState(() => _fullscreenStatus = _PermStatus.loading);
      final result = await androidPlugin.requestFullScreenIntentPermission();
      if (!mounted) return;
      setState(() {
        _fullscreenStatus =
            (result == null || result)
                ? _PermStatus.granted
                : _fullscreenStatus == _PermStatus.loading
                ? _PermStatus.denied
                : _fullscreenStatus;
      });
    } catch (_) {
      if (mounted) setState(() => _fullscreenStatus = _PermStatus.denied);
    }
  }

  // Called when user actively taps the full-screen tile.
  Future<void> _handleFullScreen() async {
    final androidPlugin = _androidPlugin;
    if (androidPlugin == null) {
      setState(() => _fullscreenStatus = _PermStatus.granted);
      return;
    }

    if (!mounted) return;
    setState(() => _fullscreenStatus = _PermStatus.loading);

    try {
      final result = await androidPlugin.requestFullScreenIntentPermission();
      if (!mounted) return;

      if (result == null || result) {
        setState(() => _fullscreenStatus = _PermStatus.granted);
        return;
      }

      // Permission not granted on Android 14+.
      // The system has already opened Settings. Show the guide sheet.
      setState(() => _fullscreenStatus = _PermStatus.denied);
      if (mounted) {
        await _showFullScreenGuide();
      }
    } catch (_) {
      if (mounted) setState(() => _fullscreenStatus = _PermStatus.denied);
    }
  }

  Future<void> _showFullScreenGuide() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => _FullScreenGuideSheet(
            onOpenSettings: () async {
              Navigator.of(ctx).pop();
              final ap = _androidPlugin;
              if (ap != null) {
                await ap.requestFullScreenIntentPermission();
              }
            },
          ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionLabel('Quyền truy cập'),
        ProfileSectionCard(
          child: Column(
            children: [
              _PermissionTile(
                icon: Icons.location_on_outlined,
                iconColor: AppColors.info,
                title: 'Vị trí',
                description: 'Xác định tọa độ khi phát hiện té ngã',
                status: _locStatus,
                isFirst: true,
                onTap:
                    _locStatus == _PermStatus.granted ? null : _requestLocation,
              ),
              const ProfileMenuDivider(),
              _PermissionTile(
                icon: Icons.notifications_outlined,
                iconColor: AppColors.warning,
                title: 'Thông báo',
                description: 'Nhận cảnh báo SOS và sức khỏe kịp thời',
                status: _notifStatus,
                onTap:
                    _notifStatus == _PermStatus.granted
                        ? null
                        : _checkNotification,
              ),
              const ProfileMenuDivider(),
              _PermissionTile(
                icon: Icons.fullscreen_rounded,
                iconColor: AppColors.critical,
                title: 'Hiển thị toàn màn hình',
                description:
                    'Tự động mở cảnh báo khẩn cấp khi đang dùng app khác',
                status: _fullscreenStatus,
                isLast: true,
                onTap:
                    _fullscreenStatus == _PermStatus.granted
                        ? null
                        : _handleFullScreen,
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              _checkLocation();
              _checkNotification();
              if (_fullscreenStatus != _PermStatus.notChecked) {
                _refreshFullScreen();
              }
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Kiểm tra lại'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              textStyle: const TextStyle(fontSize: 13),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PermissionTile
// Single row inside the permissions card.
// ─────────────────────────────────────────────────────────────────────────────
class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final _PermStatus status;
  final VoidCallback? onTap;
  final bool isFirst;
  final bool isLast;

  const _PermissionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.status,
    this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  Widget _buildTrailing(BuildContext context) {
    switch (status) {
      case _PermStatus.notChecked:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Kiểm tra',
              style: TextStyle(fontSize: 12, color: AppColors.brandPrimary),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.touch_app_rounded,
              color: AppColors.brandPrimary,
              size: 16,
            ),
          ],
        );
      case _PermStatus.loading:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.brandPrimary,
          ),
        );
      case _PermStatus.granted:
        return const Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 24,
        );
      case _PermStatus.permanentlyDenied:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Mở cài đặt',
              style: TextStyle(fontSize: 12, color: AppColors.brandPrimary),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.open_in_new_rounded,
              color: AppColors.brandPrimary,
              size: 15,
            ),
          ],
        );
      case _PermStatus.denied:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cấp quyền',
              style: TextStyle(fontSize: 12, color: AppColors.warning),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.warning,
              size: 14,
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInteractive =
        status != _PermStatus.loading && status != _PermStatus.granted;

    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: isFirst ? Radius.circular(AppRadii.radiusLg) : Radius.zero,
        bottom: isLast ? Radius.circular(AppRadii.radiusLg) : Radius.zero,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isInteractive ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadii.radiusSm),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildTrailing(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FullScreenGuideSheet
// Step-by-step guide for granting USE_FULL_SCREEN_INTENT on Android 14+.
// ─────────────────────────────────────────────────────────────────────────────
class _FullScreenGuideSheet extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _FullScreenGuideSheet({required this.onOpenSettings});

  static const _steps = [
    'Nhấn "Mở cài đặt" bên dưới',
    'Tìm HealthGuard trong danh sách ứng dụng',
    'Chọn "Quyền đặc biệt" (Special app access)',
    'Chọn "Hiển thị toàn màn hình" (Display over other apps)',
    'Bật công tắc cho HealthGuard',
    'Quay lại app, nhấn "Kiểm tra lại"',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.critical.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.fullscreen_rounded,
                    color: AppColors.critical,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Cấp quyền Hiển thị toàn màn hình',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Quyền này cho phép cảnh báo SOS và phát hiện té ngã tự động '
              'mở toàn màn hình khi bạn đang dùng ứng dụng khác hoặc '
              'khi màn hình khóa.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppStateColors.infoBg,
                borderRadius: BorderRadius.circular(AppRadii.radiusMd),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hướng dẫn từng bước',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.info,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._steps.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: AppColors.info,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${entry.key + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                entry.value,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Đóng'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: const Text('Mở cài đặt'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
