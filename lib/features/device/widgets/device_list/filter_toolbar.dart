import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:healthguard/features/device/providers/device_provider.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';

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
              SizedBox(width: AppSpacing.gapSm),
              _buildFilterChip(context, provider, 'online', 'Ổn định'),
              SizedBox(width: AppSpacing.gapSm),
              _buildFilterChip(context, provider, 'offline', 'Offline'),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.sectionGapSm),
        Container(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.gapLg),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppRadii.radiusMd),
            border: Border.all(color: AppColors.strokeSoft),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: provider.typeFilter,
              hint: Text('Tất cả loại', style: TextStyle(color: AppColors.textSecondary)),
              icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
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
      selectedColor: AppColors.bgElevated,
      labelStyle: TextStyle(
        color: selected ? AppColors.brandPrimary : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 14,
      ),
      backgroundColor: AppColors.bgSurface,
      side: BorderSide(
        color: selected ? AppColors.brandPrimary : AppColors.strokeSoft,
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.radiusXl)),
    );
  }
}
