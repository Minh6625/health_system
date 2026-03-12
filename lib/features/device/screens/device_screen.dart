import 'package:flutter/material.dart';
import 'package:healthguard/features/device/models/device_model.dart';
import 'package:healthguard/features/device/providers/device_provider.dart';
import 'package:provider/provider.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Thiết bị'),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => context.read<DeviceProvider>().fetchDevices(),
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
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.devices_other_outlined,
                      size: 68,
                      color: Colors.teal.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () => provider.fetchDevices(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchDevices(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _buildOverview(provider),
                const SizedBox(height: 16),
                if (provider.devices.isEmpty)
                  _buildEmptyState()
                else
                  ...provider.devices.map(_buildDeviceCard),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDeviceDialog,
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_link_rounded),
        label: const Text('Thêm thiết bị'),
      ),
    );
  }

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
              title: const Text('Đăng ký thiết bị'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Tên thiết bị'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: modelController,
                      decoration: const InputDecoration(labelText: 'Model'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: firmwareController,
                      decoration: const InputDecoration(labelText: 'Firmware'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: macController,
                      decoration: const InputDecoration(labelText: 'Địa chỉ MAC'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: serialController,
                      decoration: const InputDecoration(labelText: 'Số serial'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: mqttController,
                      decoration: const InputDecoration(labelText: 'MQTT Client ID'),
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 12),
                      Text(localError!, style: const TextStyle(color: Colors.red)),
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

  Widget _buildOverview(DeviceProvider provider) {
    final offlineCount = provider.devices.length - provider.onlineCount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF115E59), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22115E59),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quản lý thiết bị đã đăng ký',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Theo dõi pin, kết nối và đồng bộ của các thiết bị đeo.',
            style: TextStyle(color: Color(0xFFD4F4EF), height: 1.4),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _buildMetricTile('Tổng', provider.devices.length.toString())),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricTile('Online', provider.onlineCount.toString())),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricTile('Ngoại tuyến', offlineCount.toString())),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip(provider, 'all', 'Tất cả'),
              _buildFilterChip(provider, 'online', 'Online'),
              _buildFilterChip(provider, 'offline', 'Offline'),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0x1FFFFFFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                isExpanded: true,
                value: provider.typeFilter,
                dropdownColor: const Color(0xFF115E59),
                style: const TextStyle(color: Colors.white),
                hint: const Text(
                  'Lọc theo loại thiết bị',
                  style: TextStyle(color: Color(0xFFD4F4EF)),
                ),
                items: const [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tất cả loại', style: TextStyle(color: Colors.white)),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'smartwatch',
                    child: Text('Đồng hồ thông minh', style: TextStyle(color: Colors.white)),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'fitness_band',
                    child: Text('Vòng đeo sức khỏe', style: TextStyle(color: Colors.white)),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'medical_device',
                    child: Text('Thiết bị y tế', style: TextStyle(color: Colors.white)),
                  ),
                ],
                onChanged: (value) {
                  context.read<DeviceProvider>().setTypeFilter(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(DeviceProvider provider, String value, String label) {
    final selected = provider.statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        context.read<DeviceProvider>().setStatusFilter(value);
      },
      selectedColor: const Color(0xFF0F766E),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF0F766E),
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? const Color(0xFF0F766E) : Colors.grey.shade300,
      ),
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildMetricTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Color(0xFFD4F4EF))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.watch_off_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          Text(
            'Chưa có thiết bị nào',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Khi người dùng liên kết đồng hồ hoặc vòng đeo, danh sách sẽ hiển thị tại đây.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(DeviceModel device) {
    final statusColor =
        device.isOnline ? const Color(0xFF0F9D7A) : const Color(0xFF9CA3AF);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showDeviceDetailSheet(device),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6FFFB),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _iconForType(device.deviceType),
                        color: const Color(0xFF0F766E),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${device.typeLabel}${device.model != null ? ' · ${device.model}' : ''}',
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildStatusChip(device.isOnline, statusColor),
                        PopupMenuButton<String>(
                          onSelected: (value) => _handleDeviceAction(device, value),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Text('Đổi tên'),
                            ),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(device.isActive ? 'Tắt thiết bị' : 'Kích hoạt'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Xóa thiết bị'),
                            ),
                          ],
                          icon: const Icon(Icons.more_horiz),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildInfoPill(Icons.battery_6_bar, _batteryText(device)),
                    _buildInfoPill(Icons.network_cell, _signalText(device)),
                    _buildInfoPill(Icons.system_update_alt, _syncText(device)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMetaRow('Firmware', device.firmwareVersion ?? 'Chưa có'),
                _buildMetaRow('Serial', device.serialNumber ?? 'Chưa có'),
                _buildMetaRow('MAC', device.macAddress ?? 'Chưa có'),
                _buildMetaRow('MQTT', device.mqttClientId ?? 'Chưa có'),
                _buildMetaRow('Lần cuối online', _timeText(device.lastSeenAt)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDeviceDetailSheet(DeviceModel device) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device.displayName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                '${device.typeLabel}${device.model != null ? ' · ${device.model}' : ''}',
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              _buildMetaRow('Firmware', device.firmwareVersion ?? 'Chưa có'),
              _buildMetaRow('Serial', device.serialNumber ?? 'Chưa có'),
              _buildMetaRow('MAC', device.macAddress ?? 'Chưa có'),
              _buildMetaRow('MQTT', device.mqttClientId ?? 'Chưa có'),
              _buildMetaRow('Trạng thái', device.isOnline ? 'Online' : 'Offline'),
              _buildMetaRow('Lần sync', _timeText(device.lastSyncAt)),
              _buildMetaRow('Lần cuối online', _timeText(device.lastSeenAt)),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(bool isOnline, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isOnline ? 'Online' : 'Offline',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0F766E)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'smartwatch':
        return Icons.watch_outlined;
      case 'fitness_band':
        return Icons.fitness_center;
      case 'medical_device':
        return Icons.medical_services_outlined;
      default:
        return Icons.devices_other_outlined;
    }
  }

  String _batteryText(DeviceModel device) {
    if (device.batteryLevel == null) {
      return 'Pin --';
    }
    return 'Pin ${device.batteryLevel}%';
  }

  String _signalText(DeviceModel device) {
    if (device.signalStrength == null) {
      return 'Sóng --';
    }
    return 'RSSI ${device.signalStrength}';
  }

  String _syncText(DeviceModel device) {
    if (device.lastSyncAt == null) {
      return 'Chưa sync';
    }
    return 'Sync ${_relativeTime(device.lastSyncAt!)}';
  }

  String _timeText(DateTime? time) {
    if (time == null) {
      return 'Chưa có';
    }
    return _relativeTime(time);
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) {
      return 'vừa xong';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    }
    return '${diff.inDays} ngày trước';
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
                if (newName.isEmpty) {
                  return;
                }
                final success = await context.read<DeviceProvider>().updateDevice(
                  deviceId: device.id,
                  deviceName: newName,
                );
                if (!context.mounted) {
                  return;
                }
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
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final success = await context.read<DeviceProvider>().deleteDevice(device.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa thiết bị')),
      );
    }
  }
}
