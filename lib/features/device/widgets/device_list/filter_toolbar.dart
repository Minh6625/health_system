import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:healthguard/features/device/providers/device_provider.dart';

class FilterToolbar extends StatelessWidget {
  const FilterToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();

    if (provider.devices.isEmpty && provider.statusFilter == 'all' && provider.typeFilter == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(context, provider, 'all', 'Tất cả'),
              const SizedBox(width: 8),
              _buildFilterChip(context, provider, 'online', 'Ổn định'),
              const SizedBox(width: 8),
              _buildFilterChip(context, provider, 'offline', 'Offline'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: provider.typeFilter,
              hint: const Text('Tất cả loại', style: TextStyle(color: Color(0xFF5B7288))),
              icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF5B7288)),
              items: const [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Tất cả loại'),
                ),
                DropdownMenuItem<String?>(
                  value: 'smartwatch',
                  child: Text('Đồng hồ thông minh'),
                ),
                DropdownMenuItem<String?>(
                  value: 'fitness_band',
                  child: Text('Vòng đeo sức khỏe'),
                ),
                DropdownMenuItem<String?>(
                  value: 'medical_device',
                  child: Text('Thiết bị y tế'),
                ),
              ],
              onChanged: (value) {
                context.read<DeviceProvider>().setTypeFilter(value);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(BuildContext context, DeviceProvider provider, String value, String label) {
    final selected = provider.statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        context.read<DeviceProvider>().setStatusFilter(value);
      },
      selectedColor: const Color(0xFFE6FFFB), // brand.soft
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF0F766E) : const Color(0xFF5B7288),
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 14,
      ),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? const Color(0xFF0F766E) : Colors.grey.shade200,
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
