import 'package:flutter/material.dart';
import 'package:healthguard/features/emergency/screens/emergency_sos_received_list_screen.dart';
import 'package:healthguard/features/emergency/screens/warning_screen.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';

class EmergencyMainScreen extends StatefulWidget {
  const EmergencyMainScreen({super.key});

  @override
  State<EmergencyMainScreen> createState() => _EmergencyMainScreenState();
}

class _EmergencyMainScreenState extends State<EmergencyMainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(
            'Khẩn cấp',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.bgSurface,
            ),
          ),
        ),
        centerTitle: false,
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: AppColors.bgSurface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: Container(
            color: AppColors.bgSurface,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.brandPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              indicator: UnderlineTabIndicator(
                borderSide:
                    BorderSide(color: AppColors.brandPrimary, width: 3.0),
                insets: const EdgeInsets.symmetric(horizontal: 24.0),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'SOS'),
                Tab(text: 'Danh sách SOS'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [WarningScreen(), EmergencySOSReceivedListScreen()],
      ),
    );
  }
}
