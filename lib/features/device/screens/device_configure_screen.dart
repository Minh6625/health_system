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

            ConfigSectionCard(
              title: 'Theo dõi & cảnh báo',
              children: [
                SwitchListTile(
                  title: Text('Rung khi cảnh báo', style: AppTextStyles.bodyMedium),
                  subtitle: Text('Thiết bị sẽ rung khi có bất thường.', style: AppTextStyles.caption),
                  value: provider.vibrationAlert,
                  onChanged: provider.updateVibration,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.brandPrimary,
                ),
                const Divider(height: 1, color: AppColors.strokeSoft),
                SwitchListTile(
                  title: Text('Theo dõi giấc ngủ', style: AppTextStyles.bodyMedium),
                  value: provider.sleepTracking,
                  onChanged: provider.updateSleepTracking,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.brandPrimary,
                ),
                const SizedBox(height: AppSpacing.gapMd),
                Text('Cảnh báo pin yếu định mức', style: AppTextStyles.bodyMedium),
                const SizedBox(height: AppSpacing.gapSm),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: provider.lowBatteryThreshold,
                        min: 5,
                        max: 40,
                        divisions: 7,
                        label: '${provider.lowBatteryThreshold.round()}%',
                        activeColor: AppColors.brandPrimary,
                        onChanged: provider.updateBatteryThreshold,
                      ),
                    ),
                    Text('${provider.lowBatteryThreshold.round()}%', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGapXl),

            ConfigSectionCard(
              title: 'Đồng bộ',
              children: [
                DropdownButtonFormField<String>(
                  initialValue: provider.syncInterval,
                  decoration: InputDecoration(
                    labelText: 'Tần suất đồng bộ dữ liệu',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.radiusMd)),
                  ),
                  items: const [
                    DropdownMenuItem(value: '15m', child: Text('Mỗi 15 phút (Tốn pin)')),
                    DropdownMenuItem(value: '1h', child: Text('Mỗi 1 giờ (Khuyên dùng)')),
                    DropdownMenuItem(value: '6h', child: Text('Mỗi 6 giờ (Tiết kiệm pin)')),
                    DropdownMenuItem(value: 'manual', child: Text('Chỉ đồng bộ thủ công')),
                  ],
                  onChanged: (val) {
                    if (val != null) provider.updateSyncInterval(val);
                  },
                ),
                const SizedBox(height: AppSpacing.gapMd),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.gapSm),
                    Expanded(
                      child: Text(
                        'Cấu hình sẽ tự động đồng bộ khi thiết bị online.',
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ],
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
