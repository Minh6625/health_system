import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';

class SleepSettingsScreen extends StatefulWidget {
  const SleepSettingsScreen({super.key});

  @override
  State<SleepSettingsScreen> createState() => _SleepSettingsScreenState();
}

class _SleepSettingsScreenState extends State<SleepSettingsScreen> {
  bool _isTrackingEnabled = true;
  bool _isReminderEnabled = true;
  TimeOfDay _targetBedtime = const TimeOfDay(hour: 22, minute: 30);

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _targetBedtime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF48D6FF),
              onPrimary: Color(0xFF07162B),
              surface: Color(0xFF0D1E38),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _targetBedtime) {
      setState(() {
        _targetBedtime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071220),
      appBar: AppBar(
        title: const Text('Cài đặt theo dõi giấc ngủ'),
        backgroundColor: const Color(0xFF071220),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: AppSpacing.cardPadding,
        children: [
          _buildCard(
            child: SwitchListTile(
              title: const Text('Theo dõi tự động', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Tự động ghi nhận giấc ngủ qua VSmartwatch', style: TextStyle(color: Color(0xFF90A6C3))),
              value: _isTrackingEnabled,
              activeThumbColor: const Color(0xFF48D6FF),
              onChanged: (val) => setState(() => _isTrackingEnabled = val),
            ),
          ),
          const SizedBox(height: AppSpacing.gapLg),
          
          if (_isTrackingEnabled) ...[
            _buildCard(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Mục tiêu đi ngủ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    trailing: Text(
                      _targetBedtime.format(context),
                      style: const TextStyle(color: Color(0xFF48D6FF), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onTap: () => _selectTime(context),
                  ),
                  const Divider(color: Color(0x3348D6FF), height: 1),
                  SwitchListTile(
                    title: const Text('Nhắc nhở giờ ngủ', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Gửi thông báo trước 30 phút', style: TextStyle(color: Color(0xFF90A6C3), fontSize: 13)),
                    value: _isReminderEnabled,
                    activeThumbColor: const Color(0xFF48D6FF),
                    onChanged: (val) => setState(() => _isReminderEnabled = val),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1E38),
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: const Color(0x332C4367)),
      ),
      child: child,
    );
  }
}
