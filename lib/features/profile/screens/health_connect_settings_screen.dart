// lib/features/profile/screens/health_connect_settings_screen.dart
//
// Phase 2 settings surface for the Mi Fitness -> Health Connect bridge.
// One screen drives three jobs the user needs in order to demo the
// "real watch data" pipeline:
//   1. See Health Connect availability + permission state at a glance.
//   2. Trigger an on-demand sync without leaving the app.
//   3. Jump back into Mi Fitness when Health Connect has gone dry.
//
// Doubles as the "Health Connect chua ket noi" CTA target on the
// dashboard, so we deliberately keep the layout dense rather than
// breaking it across multiple screens.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:healthguard/core/services/health_connect_service.dart';
import 'package:healthguard/features/device/providers/device_provider.dart';
import 'package:healthguard/features/device/providers/health_sync_provider.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';

class HealthConnectSettingsScreen extends StatefulWidget {
  const HealthConnectSettingsScreen({super.key});

  @override
  State<HealthConnectSettingsScreen> createState() =>
      _HealthConnectSettingsScreenState();
}

class _HealthConnectSettingsScreenState
    extends State<HealthConnectSettingsScreen> {
  HealthConnectAvailability? _availability;
  HealthPermissionState? _permission;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() => _checking = true);
    final svc = HealthConnectService.instance;
    final availability = await svc.checkAvailability();
    final perm = availability == HealthConnectAvailability.available
        ? await svc.hasPermissions()
        : HealthPermissionState.unknown;
    if (!mounted) return;
    setState(() {
      _availability = availability;
      _permission = perm;
      _checking = false;
    });
  }

  Future<void> _requestPermissions() async {
    final perm = await HealthConnectService.instance.requestPermissions();
    if (!mounted) return;
    setState(() => _permission = perm);
    await _refreshStatus();
  }

  Future<void> _manualSync() async {
    final sync = context.read<HealthSyncProvider>();
    final devices = context.read<DeviceProvider>();
    final firstDevice = devices.devices.isNotEmpty
        ? devices.devices.first
        : null;
    if (firstDevice == null) {
      _showSnack('Chưa có thiết bị nào được ghép nối. Hãy ghép Redmi Watch '
          'trước trong tab Thiết bị.');
      return;
    }
    if (sync.activeDeviceId != firstDevice.id) {
      await sync.start(firstDevice.id);
    } else {
      await sync.manualRefresh();
    }
  }

  Future<void> _openMiFitness() async {
    // Mi Fitness exposes a custom scheme for direct entry. Falling back
    // to the Play Store URL handles cases where the app is not installed
    // (the user might have removed it but kept HC permissions).
    final candidates = [
      Uri.parse('mifitness://'),
      Uri.parse('https://play.google.com/store/apps/details?id=com.xiaomi.wearable'),
    ];
    for (final uri in candidates) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    _showSnack('Không thể mở Mi Fitness. Hãy mở thủ công.');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<HealthSyncProvider>();
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text('Health Connect', style: AppTextStyles.sectionTitle),
        backgroundColor: AppColors.bgSurface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshStatus,
          child: ListView(
            padding: EdgeInsets.all(AppSpacing.sectionGapLg),
            children: [
              _StatusCard(
                availability: _availability,
                permission: _permission,
                checking: _checking,
                onGrant: _requestPermissions,
                onRefresh: _refreshStatus,
              ),
              SizedBox(height: AppSpacing.sectionGapMd),
              _SyncCard(sync: sync, onManual: _manualSync),
              SizedBox(height: AppSpacing.sectionGapMd),
              _MiFitnessCard(onOpen: _openMiFitness),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final HealthConnectAvailability? availability;
  final HealthPermissionState? permission;
  final bool checking;
  final VoidCallback onGrant;
  final VoidCallback onRefresh;

  const _StatusCard({
    required this.availability,
    required this.permission,
    required this.checking,
    required this.onGrant,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.sectionGapMd),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_iconForAvailability(), color: _colorForAvailability()),
              SizedBox(width: AppSpacing.gapSm),
              Expanded(
                child: Text(
                  _titleForAvailability(),
                  style: AppTextStyles.sectionTitle.copyWith(fontSize: 18),
                ),
              ),
              if (checking)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          SizedBox(height: AppSpacing.gapSm),
          Text(
            _bodyForAvailability(),
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          SizedBox(height: AppSpacing.gapMd),
          if (availability == HealthConnectAvailability.available &&
              permission != HealthPermissionState.granted)
            ElevatedButton.icon(
              onPressed: onGrant,
              icon: const Icon(Icons.shield_outlined),
              label: const Text('Cấp quyền đọc dữ liệu'),
            )
          else if (availability != null &&
              availability != HealthConnectAvailability.available)
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Kiểm tra lại'),
            ),
        ],
      ),
    );
  }

  IconData _iconForAvailability() {
    switch (availability) {
      case HealthConnectAvailability.available:
        return permission == HealthPermissionState.granted
            ? Icons.verified_user_rounded
            : Icons.lock_open_rounded;
      case HealthConnectAvailability.needsUpdate:
        return Icons.update_rounded;
      case HealthConnectAvailability.notInstalled:
        return Icons.download_rounded;
      case HealthConnectAvailability.notSupported:
        return Icons.block_rounded;
      case null:
        return Icons.hourglass_empty_rounded;
    }
  }

  Color _colorForAvailability() {
    switch (availability) {
      case HealthConnectAvailability.available:
        return permission == HealthPermissionState.granted
            ? AppColors.success
            : AppColors.warning;
      case HealthConnectAvailability.notSupported:
        return AppColors.critical;
      case _:
        return AppColors.warning;
    }
  }

  String _titleForAvailability() {
    switch (availability) {
      case HealthConnectAvailability.available:
        return permission == HealthPermissionState.granted
            ? 'Đã sẵn sàng đồng bộ'
            : 'Cần cấp quyền đọc';
      case HealthConnectAvailability.needsUpdate:
        return 'Health Connect cần cập nhật';
      case HealthConnectAvailability.notInstalled:
        return 'Health Connect chưa được cài đặt';
      case HealthConnectAvailability.notSupported:
        return 'Thiết bị không hỗ trợ Health Connect';
      case null:
        return 'Đang kiểm tra trạng thái...';
    }
  }

  String _bodyForAvailability() {
    switch (availability) {
      case HealthConnectAvailability.available:
        return permission == HealthPermissionState.granted
            ? 'App đã có thể đọc nhịp tim, SpO2, bước chân và giấc ngủ '
                'từ Mi Fitness.'
            : 'Hãy bật quyền cho HealthGuard trong Health Connect để đồng '
                'bộ dữ liệu thật từ Redmi Watch 3.';
      case HealthConnectAvailability.needsUpdate:
        return 'Phiên bản Health Connect hiện tại không tương thích. '
            'Cập nhật từ Play Store rồi quay lại.';
      case HealthConnectAvailability.notInstalled:
        return 'Cài Health Connect (miễn phí) từ Play Store, sau đó bật '
            'liên kết với Mi Fitness.';
      case HealthConnectAvailability.notSupported:
        return 'Android phiên bản này chưa hỗ trợ Health Connect. Vui lòng '
            'dùng máy Android 9 trở lên.';
      case null:
        return '';
    }
  }
}

class _SyncCard extends StatelessWidget {
  final HealthSyncProvider sync;
  final VoidCallback onManual;
  const _SyncCard({required this.sync, required this.onManual});

  @override
  Widget build(BuildContext context) {
    final last = sync.lastSyncAt;
    final fmt = DateFormat('HH:mm:ss · dd/MM');
    final hasError = sync.state == HealthSyncState.error;
    return Container(
      padding: EdgeInsets.all(AppSpacing.sectionGapMd),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Đồng bộ dữ liệu',
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 18)),
          SizedBox(height: AppSpacing.gapSm),
          Text(
            last == null
                ? 'Chưa có lần đồng bộ nào.'
                : 'Lần cuối: ${fmt.format(last.toLocal())}',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          if (sync.lastBatchSent > 0) ...[
            SizedBox(height: AppSpacing.gapXs),
            Text(
              'Đã gửi ${sync.lastBatchSent} bản ghi · '
              'lưu ${sync.lastBatchAccepted} · loại '
              '${sync.lastBatchRejected}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (hasError) ...[
            SizedBox(height: AppSpacing.gapSm),
            Text(
              sync.errorMessage ?? 'Lỗi đồng bộ chưa rõ.',
              style: AppTextStyles.caption.copyWith(color: AppColors.critical),
            ),
          ],
          SizedBox(height: AppSpacing.gapMd),
          ElevatedButton.icon(
            onPressed: sync.state == HealthSyncState.syncing ? null : onManual,
            icon: sync.state == HealthSyncState.syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(sync.state == HealthSyncState.syncing
                ? 'Đang đồng bộ...'
                : 'Đồng bộ ngay'),
          ),
        ],
      ),
    );
  }
}

class _MiFitnessCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _MiFitnessCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.sectionGapMd),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Mi Fitness',
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 18)),
          SizedBox(height: AppSpacing.gapSm),
          Text(
            'Khi Health Connect không có dữ liệu mới, hãy mở Mi Fitness '
            'và kéo xuống để bắt đồng hồ đẩy dữ liệu lên.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          SizedBox(height: AppSpacing.gapMd),
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Mở Mi Fitness'),
          ),
        ],
      ),
    );
  }
}
