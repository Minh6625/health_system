import 'package:flutter/material.dart';
import 'package:healthguard/features/device/models/device_model.dart';
import 'package:healthguard/features/device/providers/device_configure_provider.dart';
import 'package:healthguard/features/device/widgets/device_configure/configure_hero_header.dart';
import 'package:healthguard/features/device/widgets/device_configure/config_section_card.dart';
import 'package:healthguard/features/device/widgets/device_configure/danger_zone_card.dart';
import 'package:healthguard/features/device/widgets/device_configure/dirty_footer_bar.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';
import 'package:provider/provider.dart';

class DeviceConfigureScreen extends StatelessWidget {
  final DeviceModel device;

  const DeviceConfigureScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DeviceConfigureProvider(device),
      child: _DeviceConfigureContent(device: device),
    );
  }
}

class _DeviceConfigureContent extends StatefulWidget {
  final DeviceModel device;
  const _DeviceConfigureContent({required this.device});

  @override
  State<_DeviceConfigureContent> createState() => _DeviceConfigureContentState();
}

class _DeviceConfigureContentState extends State<_DeviceConfigureContent> {
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.device.displayName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showDiscardDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy thay đổi?'),
        content: const Text('Bạn có những thay đổi chưa lưu. Bạn có chắc chắn muốn thoát và hủy bỏ các thay đổi này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tiếp tục chỉnh sửa'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop(); // Actually pop the screen
            },
            child: const Text('Thoát (Không lưu)', style: TextStyle(color: AppColors.critical)),
          ),
        ],
      ),
    );
  }

  void _showUnpairDialog(BuildContext context, DeviceConfigureProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ngắt kết nối thiết bị?'),
        content: const Text('Thiết bị sẽ bị xóa khỏi tài khoản của bạn. Hành động này không thể hoàn tác.', style: TextStyle(color: AppColors.critical)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.unpairDevice();
              if (!context.mounted) return;
              if (success) {
                // Return 'deleted' so Detail screen can route all the way back to list
                Navigator.of(context).pop('deleted');
              } else {
                // Surface the real backend error instead of silently closing.
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      provider.errorMessage ?? 'Hủy ghép nối thiết bị thất bại',
                    ),
                    backgroundColor: AppColors.critical,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.critical),
            child: const Text('Ngắt kết nối', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceConfigureProvider>();

    return PopScope(
      canPop: !provider.isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showDiscardDialog(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          title: Text('Cấu hình thiết bị', style: AppTextStyles.sectionTitle),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sectionGapMd, vertical: AppSpacing.sectionGapMd),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ConfigureHeroHeader(device: widget.device),
            const SizedBox(height: AppSpacing.sectionGapXl),

            ConfigSectionCard(
              title: 'Cơ bản',
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Tên thiết bị',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.radiusMd)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sectionGapMd, vertical: AppSpacing.sectionGapMd),
                  ),
                  onChanged: provider.updateName,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGapXl),

            // Notification toggles match the backend `DeviceSettingsRequest`
            // schema 1:1 (notify_high_hr / notify_low_spo2 / notify_high_bp).
            // Two earlier controls — a battery-threshold slider and a sync
            // interval dropdown — were removed because saveChanges() never
            // forwarded them to any endpoint, so the UI was lying about
            // persistence.
            ConfigSectionCard(
              title: 'Cảnh báo sinh hiệu',
              children: [
                SwitchListTile(
                  title: Text('Cảnh báo nhịp tim cao', style: AppTextStyles.bodyMedium),
                  subtitle: Text(
                    'Gửi thông báo khi nhịp tim vượt ngưỡng an toàn.',
                    style: AppTextStyles.caption,
                  ),
                  value: provider.notifyHighHr,
                  onChanged: provider.updateNotifyHighHr,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.brandPrimary,
                ),
                const Divider(height: 1, color: AppColors.strokeSoft),
                SwitchListTile(
                  title: Text('Cảnh báo SpO₂ thấp', style: AppTextStyles.bodyMedium),
                  subtitle: Text(
                    'Gửi thông báo khi nồng độ oxy trong máu xuống thấp.',
                    style: AppTextStyles.caption,
                  ),
                  value: provider.notifyLowSpo2,
                  onChanged: provider.updateNotifyLowSpo2,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.brandPrimary,
                ),
                const Divider(height: 1, color: AppColors.strokeSoft),
                SwitchListTile(
                  title: Text('Cảnh báo huyết áp cao', style: AppTextStyles.bodyMedium),
                  subtitle: Text(
                    'Gửi thông báo khi huyết áp tâm thu vượt ngưỡng.',
                    style: AppTextStyles.caption,
                  ),
                  value: provider.notifyHighBp,
                  onChanged: provider.updateNotifyHighBp,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.brandPrimary,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGapXl),

            DangerZoneCard(
              isUnpairing: provider.isUnpairing,
              onUnpair: () => _showUnpairDialog(context, provider),
            ),
            const SizedBox(height: 48), // Padding equivalent to sticky footer if user scrolls to bottom
          ],
        ),
        bottomNavigationBar: DirtyFooterBar(
          isVisible: provider.isDirty,
          isSaving: provider.isSaving,
          onSave: () async {
            final success = await provider.saveChanges();
            if (success && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Lưu thay đổi thành công'),
                  backgroundColor: AppColors.success,
                  duration: Duration(seconds: 2),
                ),
              );
              Navigator.of(context).pop(true);
            }
          },
        ),
      ),
    );
  }
}
