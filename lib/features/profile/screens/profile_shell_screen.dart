import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/profile/providers/profile_provider.dart';
import 'package:healthguard/features/device/providers/device_provider.dart';
import 'package:healthguard/features/profile/screens/profile_screen.dart';
import 'package:healthguard/shared/presentation/shell/app_shell_bottom_nav.dart';
import 'package:healthguard/shared/presentation/emergency/emergency_sticky_bar.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';

const _kTeal = Color(0xFF0F766E);

/// Shell wrapper for the Profile tab.
/// Owns the Scaffold (AppBar + BottomNav) – ProfileScreen is a bare content widget.
/// Sub-pages are Navigator.push()-ed with their own AppBar + back button.
class ProfileShellScreen extends StatelessWidget {
  const ProfileShellScreen({super.key});

  Future<void> _onRefresh(BuildContext context) async {
    await context.read<ProfileProvider>().fetchProfile(force: true);
    if (context.mounted) {
      context.read<DeviceProvider>().fetchDevices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Hồ sơ'),
        backgroundColor: _kTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        // Reload button removed – user pulls down to refresh instead
      ),
      bottomNavigationBar: AppShellBottomNav(
        currentTab: AppMainTab.profile,
        onTabSelected: (tab) {
          switch (tab) {
            case AppMainTab.me:
              Navigator.pushReplacementNamed(context, AppRouter.dashboard);
              break;
            case AppMainTab.family:
              Navigator.pushReplacementNamed(
                  context, AppRouter.familyManagement);
              break;
            case AppMainTab.device:
              Navigator.pushReplacementNamed(context, AppRouter.device);
              break;
            case AppMainTab.profile:
              // Already here
              break;
          }
        },
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: _kTeal,
              onRefresh: () => _onRefresh(context),
              child: const ProfileScreen(),
            ),
          ),
          EmergencyStickyBar(
            emphasis: EmergencyBarEmphasis.defaultLevel,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
