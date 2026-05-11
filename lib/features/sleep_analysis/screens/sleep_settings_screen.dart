import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';

class SleepSettingsScreen extends StatelessWidget {
  const SleepSettingsScreen({super.key});

  // Preview defaults for the disabled shell. When the feature ships these
  // become real state hooked to a settings provider.
  static const bool _previewTrackingEnabled = true;
  static const bool _previewReminderEnabled = true;
  static const TimeOfDay _previewTargetBedtime = TimeOfDay(
    hour: 22,
    minute: 30,
  );

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
          _buildComingSoonBanner(),
          const SizedBox(height: AppSpacing.gapLg),

          // Preview UI: chỉ hiển thị shell để user biết tính năng sắp có,
          // toggle / picker bị disable hoàn toàn cho đến khi backend & local
          // notification scheduling sẵn sàng.
          IgnorePointer(
            child: Opacity(
              opacity: 0.5,
              child: Column(
                children: [
                  _buildCard(
                    child: SwitchListTile(
                      title: const Text(
                        'Theo dõi tự động',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'Tự động ghi nhận giấc ngủ qua VSmartwatch',
                        style: TextStyle(color: Color(0xFF90A6C3)),
                      ),
                      value: _previewTrackingEnabled,
                      activeThumbColor: const Color(0xFF48D6FF),
                      onChanged: null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.gapLg),
                  _buildCard(
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text(
                            'Mục tiêu đi ngủ',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: Text(
                            _previewTargetBedtime.format(context),
                            style: const TextStyle(
                              color: Color(0xFF48D6FF),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: null,
                        ),
                        const Divider(color: Color(0x3348D6FF), height: 1),
                        SwitchListTile(
                          title: const Text(
                            'Nhắc nhở giờ ngủ',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Gửi thông báo trước 30 phút',
                            style: TextStyle(
                              color: Color(0xFF90A6C3),
                              fontSize: 13,
                            ),
                          ),
                          value: _previewReminderEnabled,
                          activeThumbColor: const Color(0xFF48D6FF),
                          onChanged: null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoonBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gapLg),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2B42),
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: const Color(0x5548D6FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(
            Icons.construction_rounded,
            color: Color(0xFF48D6FF),
            size: 28,
          ),
          SizedBox(width: AppSpacing.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tính năng đang phát triển',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Cài đặt theo dõi và nhắc nhở giờ ngủ sẽ sớm có. Hiện tại chỉ hiển thị bản xem trước.',
                  style: TextStyle(
                    color: Color(0xFFCCDEF5),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
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
