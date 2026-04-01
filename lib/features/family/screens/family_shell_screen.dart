import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/emergency/providers/emergency_caregiver_provider.dart';
import 'package:healthguard/features/emergency/screens/emergency_sos_received_list_screen.dart';
import 'package:healthguard/features/family/screens/contact_list_screen.dart';
import 'package:healthguard/features/family/screens/family_dashboard_screen.dart';
import 'package:healthguard/features/family/providers/family_dashboard_provider.dart';
import 'package:healthguard/features/family/providers/shared_family_mock_provider.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/shared/presentation/shell/app_shell_bottom_nav.dart';
import 'package:healthguard/shared/presentation/shell/main_scaffold_shell.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';

class FamilyShellScreen extends StatefulWidget {
  /// 0 = Theo dõi, 1 = Liên hệ, 2 = SOS
  final int initialTab;

  const FamilyShellScreen({super.key, this.initialTab = 0});

  @override
  State<FamilyShellScreen> createState() => _FamilyShellScreenState();
}

class _FamilyShellScreenState extends State<FamilyShellScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late SharedFamilyMockProvider _familyProvider;

  // Mock: canReceiveAlerts luôn = true trong dev
  // Sau này check từ API: user có ít nhất 1 relationship với can_receive_alerts = true
  final bool _canReceiveAlerts = true;

  int get _tabCount => _canReceiveAlerts ? 3 : 2;

  @override
  void initState() {
    super.initState();
    _familyProvider = SharedFamilyMockProvider();
    _tabController = TabController(length: _tabCount, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshTabBadges();
    });

    if (widget.initialTab != 0 && widget.initialTab < _tabCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tabController.animateTo(widget.initialTab);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _navigateToAddContact() async {
    await Navigator.pushNamed(context, AppRouter.addContact);
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    if (auth.currentUser != null) {
      await _familyProvider.loadInitialData(auth.currentUser!.userId);
      await _refreshTabBadges();
    }
  }

  Future<void> _refreshTabBadges() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    await context.read<FamilyDashboardProvider>().loadDashboard(user.userId);
    await context.read<EmergencyCaregiverProvider>().fetchSOSAlerts('all');
  }

  Widget _buildTabLabelWithBadge({
    required String label,
    required int count,
    Color badgeColor = const Color(0xFFD95C5C),
  }) {
    if (count <= 0) {
      return Text(label);
    }

    final displayCount = count.toString();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label),
        const SizedBox(width: 6),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              displayCount,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _familyProvider,
      child: MainScaffoldShell(
        bottomNavigation: AppShellBottomNav(
          currentTab: AppMainTab.family,
          onTabSelected: (tab) {
            if (tab == AppMainTab.family) return;
            switch (tab) {
              case AppMainTab.me:
                Navigator.pushReplacementNamed(context, '/dashboard');
                break;
              case AppMainTab.device:
                Navigator.pushReplacementNamed(context, '/device');
                break;
              case AppMainTab.profile:
                Navigator.pushReplacementNamed(context, '/profile');
                break;
              case AppMainTab.family:
                break;
            }
          },
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFF4F7FB),
          appBar: AppBar(
            title: const Text(
              'Gia đình',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF12304A),
              ),
            ),
            backgroundColor: const Color(0xFFF4F7FB),
            elevation: 0,
            centerTitle: true,
            automaticallyImplyLeading: false,
            actions: [
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, child) {
                  // Nút thêm liên hệ chỉ hiện ở tab "Liên hệ" (index 1)
                  if (_tabController.index == 1) {
                    return IconButton(
                      icon: const Icon(
                        Icons.person_add,
                        color: Color(0xFF12304A),
                      ),
                      tooltip: 'Thêm liên hệ',
                      onPressed: _navigateToAddContact,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Segmented Control Tab Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: const Color(0xFF2F80ED),
                    ),
                    labelColor: Colors.white,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    unselectedLabelColor: const Color(0xFF5B7288),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                    tabs: [
                      Tab(
                        child: Selector<FamilyDashboardProvider, int>(
                          selector: (context, provider) =>
                              provider.trackingAlertCount,
                          builder: (context, trackingCount, child) {
                            return _buildTabLabelWithBadge(
                              label: 'Theo dõi',
                              count: trackingCount,
                              badgeColor: const Color(0xFFEF6C00),
                            );
                          },
                        ),
                      ),
                      // Tab Liên hệ với badge pending
                      Tab(
                        child: Selector<SharedFamilyMockProvider, int>(
                          selector: (context, provider) =>
                              provider.pendingRequests.length,
                          builder: (context, pendingCount, child) {
                            return _buildTabLabelWithBadge(
                              label: 'Liên hệ',
                              count: pendingCount,
                            );
                          },
                        ),
                      ),
                      // Tab SOS chỉ hiện khi canReceiveAlerts = true
                      if (_canReceiveAlerts)
                        Tab(
                          child: Selector<EmergencyCaregiverProvider, int>(
                            selector: (context, provider) =>
                                provider.activeCount,
                            builder: (context, activeCount, child) {
                              return _buildTabLabelWithBadge(
                                label: 'SOS',
                                count: activeCount,
                                badgeColor: AppColors.emergency,
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 0: Theo dõi
                    const FamilyDashboardScreen(),
                    // Tab 1: Liên hệ
                    const ContactListScreen(),
                    // Tab 2: SOS (chỉ khi canReceiveAlerts)
                    if (_canReceiveAlerts)
                      const EmergencySOSReceivedListScreen(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
