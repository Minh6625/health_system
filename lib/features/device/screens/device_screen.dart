import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:healthguard/features/device/mock/device_mock_data.dart';
import 'package:healthguard/features/device/models/device_model.dart';
import 'package:healthguard/features/device/providers/device_provider.dart';
import 'package:healthguard/features/device/screens/device_connect_screen.dart';
import 'package:healthguard/features/device/widgets/device_list/device_priority_card.dart';
import 'package:healthguard/features/device/widgets/device_list/device_health_hero_card.dart';
import 'package:healthguard/features/device/widgets/device_list/device_onboarding_empty_state.dart';
import 'package:healthguard/features/device/widgets/device_list/attention_zone_card.dart';
import 'package:healthguard/features/device/widgets/device_list/filter_toolbar.dart';
import 'package:healthguard/features/device/widgets/device_list/add_device_primary_action.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';
import 'package:provider/provider.dart';

import 'package:healthguard/shared/presentation/shell/app_shell_bottom_nav.dart';
import 'package:healthguard/shared/presentation/shell/main_scaffold_shell.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().fetchDevices();
    });
  }

  void _navigateToConnect() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DeviceConnectScreen()),
    ).then((_) {
      if (mounted) context.read<DeviceProvider>().fetchDevices(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffoldShell(
      bottomNavigation: AppShellBottomNav(
        currentTab: AppMainTab.device,
        deviceHasAttentionBadge: context.watch<DeviceProvider>().needsAttentionDevices.isNotEmpty,
        onTabSelected: (tab) {
          if (tab == AppMainTab.device) return;
          
          switch (tab) {
            case AppMainTab.me:
              Navigator.pushReplacementNamed(context, '/dashboard');
              break;
            case AppMainTab.family:
              Navigator.pushReplacementNamed(context, '/family-management');
              break;
            case AppMainTab.profile:
              Navigator.pushReplacementNamed(context, '/profile');
              break;
            case AppMainTab.device:
              break;
          }
        },
      ),
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          title: const Text('Thiết bị'),
          automaticallyImplyLeading: false, // No back button for main tabs
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: Colors.white,
          actions: [
          // ── Debug menu để test các State Mock ──
          // `kDebugMode` is a `const bool` that is `false` in profile and
          // release builds, so the entire PopupMenuButton tree is
          // tree-shaken out of any non-debug binary. This guarantees the
          // mock-scenarios menu cannot leak into a production app even if
          // the runtime `DeviceMockConfig.useMockData` flag is
          // misconfigured.
          if (kDebugMode && DeviceMockConfig.useMockData)
            PopupMenuButton<MockListScenario>(
              icon: const Icon(Icons.bug_report),
              tooltip: 'Mock Scenarios',
              onSelected: (scenario) {
                DeviceMockConfig.listScenario = scenario;
                context.read<DeviceProvider>().fetchDevices(forceRefresh: true);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: MockListScenario.normal, child: Text('Test: Demo (Normal)')),
                PopupMenuItem(value: MockListScenario.empty, child: Text('Test: Empty State')),
                PopupMenuItem(value: MockListScenario.allOffline, child: Text('Test: All Offline')),
                PopupMenuItem(value: MockListScenario.error, child: Text('Test: API Error')),
              ],
            ),
          IconButton(
            onPressed: () => context.read<DeviceProvider>().fetchDevices(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.devices.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null && provider.devices.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sectionGapXl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.devices_other_outlined,
                      size: 68,
                      color: AppColors.brandPrimaryLight,
                    ),
                    const SizedBox(height: AppSpacing.sectionGapMd),
                    Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sectionGapLg),
                    ElevatedButton.icon(
                      onPressed: () => provider.fetchDevices(forceRefresh: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.fetchDevices(forceRefresh: true),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(
                      left: AppSpacing.sectionGapMd,
                      right: AppSpacing.sectionGapMd,
                      top: AppSpacing.sectionGapMd,
                      bottom: AppSpacing.sectionGapXl,
                    ),
                    children: [
                      const DeviceHealthHeroCard(),
                      const SizedBox(height: AppSpacing.sectionGapMd),
                      if (provider.needsAttentionDevices.isNotEmpty) ...[
                        const AttentionZoneCard(),
                        const SizedBox(height: AppSpacing.sectionGapMd),
                      ],
                      const FilterToolbar(),
                      const SizedBox(height: AppSpacing.sectionGapMd),
                      if (provider.devices.isEmpty)
                        const DeviceOnboardingEmptyState()
                      else
                        ...provider.devices.map((device) => DevicePriorityCard(
                              device: device,
                              needsAttention: provider.needsAttentionDevices.contains(device),
                              onActionSelected: (d, action) => _handleDeviceAction(d, action),
                              onRefreshRequested: () {
                                if (mounted) context.read<DeviceProvider>().fetchDevices(forceRefresh: true);
                              },
                            )),
                    ],
                  ),
                ),
              ),
              AddDevicePrimaryAction(onPressed: _navigateToConnect),
            ],
          );
        },
      ),
    ));
  }



  Future<void> _handleDeviceAction(DeviceModel device, String action) async {
    switch (action) {
      case 'rename':
        await _showRenameDialog(device);
        break;
      case 'toggle':
        await _toggleDevice(device);
        break;
      case 'delete':
        await _deleteDevice(device);
        break;
    }
  }

  Future<void> _showRenameDialog(DeviceModel device) async {
    final controller = TextEditingController(text: device.displayName);
    final renamed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Đổi tên thiết bị'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Tên mới'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isEmpty) return;
                final success = await context.read<DeviceProvider>().updateDevice(
                  deviceId: device.id,
                  deviceName: newName,
                );
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(success);
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (renamed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật tên thiết bị')),
      );
    }
  }

  Future<void> _toggleDevice(DeviceModel device) async {
    final success = await context.read<DeviceProvider>().updateDevice(
      deviceId: device.id,
      isActive: !device.isActive,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            device.isActive ? 'Đã tắt thiết bị' : 'Đã kích hoạt thiết bị',
          ),
        ),
      );
    }
  }

  Future<void> _deleteDevice(DeviceModel device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xóa thiết bị'),
          content: Text('Bạn chắc chắn muốn xóa ${device.displayName}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.critical),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // ignore: use_build_context_synchronously
    final success = await context.read<DeviceProvider>().deleteDevice(device.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa thiết bị')),
      );
    }
  }

  // Keeping original add device dialog logic just in case user needs manual entry without ble scan
  // ignore: unused_element
  Future<void> _showAddDeviceDialog() async {
    final nameController = TextEditingController();
    final modelController = TextEditingController();
    final firmwareController = TextEditingController();
    final macController = TextEditingController();
    final serialController = TextEditingController();
    final mqttController = TextEditingController();
    var selectedType = 'smartwatch';
    String? localError;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Đăng ký thiết bị (Manual)'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Tên thiết bị'),
                    ),
                    const SizedBox(height: AppSpacing.gapMd),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(labelText: 'Loại thiết bị'),
                      items: const [
                        DropdownMenuItem(
                          value: 'smartwatch',
                          child: Text('Đồng hồ thông minh'),
                        ),
                        DropdownMenuItem(
                          value: 'fitness_band',
                          child: Text('Vòng đeo sức khỏe'),
                        ),
                        DropdownMenuItem(
                          value: 'medical_device',
                          child: Text('Thiết bị y tế'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedType = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.gapMd),
                    TextField(
                      controller: modelController,
                      decoration: const InputDecoration(labelText: 'Model'),
                    ),
                    const SizedBox(height: AppSpacing.gapMd),
                    TextField(
                      controller: firmwareController,
                      decoration: const InputDecoration(labelText: 'Firmware'),
                    ),
                    const SizedBox(height: AppSpacing.gapMd),
                    TextField(
                      controller: macController,
                      decoration: const InputDecoration(labelText: 'Địa chỉ MAC'),
                    ),
                    const SizedBox(height: AppSpacing.gapMd),
                    TextField(
                      controller: serialController,
                      decoration: const InputDecoration(labelText: 'Số serial'),
                    ),
                    const SizedBox(height: AppSpacing.gapMd),
                    TextField(
                      controller: mqttController,
                      decoration: const InputDecoration(labelText: 'MQTT Client ID'),
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: AppSpacing.gapMd),
                      Text(localError!, style: const TextStyle(color: AppColors.critical)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) {
                      setState(() {
                        localError = 'Tên thiết bị là bắt buộc';
                      });
                      return;
                    }

                    final success = await context.read<DeviceProvider>().addDevice(
                      deviceName: nameController.text.trim(),
                      deviceType: selectedType,
                      model: _nullIfEmpty(modelController.text),
                      firmwareVersion: _nullIfEmpty(firmwareController.text),
                      macAddress: _nullIfEmpty(macController.text),
                      serialNumber: _nullIfEmpty(serialController.text),
                      mqttClientId: _nullIfEmpty(mqttController.text),
                    );

                    if (!context.mounted) {
                      return;
                    }

                    if (success) {
                      Navigator.of(dialogContext).pop(true);
                    } else {
                      setState(() {
                        localError = context.read<DeviceProvider>().errorMessage;
                      });
                    }
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    modelController.dispose();
    firmwareController.dispose();
    macController.dispose();
    serialController.dispose();
    mqttController.dispose();

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm thiết bị mới')),
      );
    }
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
