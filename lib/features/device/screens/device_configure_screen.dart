import 'package:flutter/material.dart';
import 'package:healthguard/features/device/models/device_model.dart';
import 'package:healthguard/features/device/providers/device_configure_provider.dart';
import 'package:healthguard/features/device/widgets/device_configure/configure_hero_header.dart';
import 'package:healthguard/features/device/widgets/device_configure/config_section_card.dart';
import 'package:healthguard/features/device/widgets/device_configure/danger_zone_card.dart';
import 'package:healthguard/features/device/widgets/device_configure/dirty_footer_bar.dart';
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
            child: const Text('Thoát (Không lưu)', style: TextStyle(color: Colors.red)),
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
        content: const Text('Thiết bị sẽ bị xóa khỏi tài khoản của bạn. Hành động này không thể hoàn tác.', style: TextStyle(color: Colors.red)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.unpairDevice();
              if (success && context.mounted) {
                // Return 'deleted' so Detail screen can route all the way back to list
                Navigator.of(context).pop('deleted');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
        backgroundColor: const Color(0xFFF4F7FB),
        appBar: AppBar(
          title: const Text('Cấu hình thiết bị', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF12304A))),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Color(0xFF12304A)),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ConfigureHeroHeader(device: widget.device),
            const SizedBox(height: 24),

            ConfigSectionCard(
              title: 'Cơ bản',
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Tên thiết bị',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  onChanged: provider.updateName,
                ),
              ],
            ),
            const SizedBox(height: 24),

            ConfigSectionCard(
              title: 'Theo dõi & cảnh báo',
              children: [
                SwitchListTile(
                  title: const Text('Rung khi cảnh báo', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Thiết bị sẽ rung khi có bất thường.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  value: provider.vibrationAlert,
                  onChanged: provider.updateVibration,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: const Color(0xFF0F766E),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                SwitchListTile(
                  title: const Text('Theo dõi giấc ngủ', style: TextStyle(fontWeight: FontWeight.w600)),
                  value: provider.sleepTracking,
                  onChanged: provider.updateSleepTracking,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: const Color(0xFF0F766E),
                ),
                const SizedBox(height: 12),
                const Text('Cảnh báo pin yếu định mức', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: provider.lowBatteryThreshold,
                        min: 5,
                        max: 40,
                        divisions: 7,
                        label: '${provider.lowBatteryThreshold.round()}%',
                        activeColor: const Color(0xFF0F766E),
                        onChanged: provider.updateBatteryThreshold,
                      ),
                    ),
                    Text('${provider.lowBatteryThreshold.round()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            ConfigSectionCard(
              title: 'Đồng bộ',
              children: [
                DropdownButtonFormField<String>(
                  initialValue: provider.syncInterval,
                  decoration: InputDecoration(
                    labelText: 'Tần suất đồng bộ dữ liệu',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                const SizedBox(height: 12),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Color(0xFF5B7288)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cấu hình sẽ tự động đồng bộ khi thiết bị online.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF5B7288), height: 1.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

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
                  backgroundColor: Color(0xFF0F9D7A),
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
