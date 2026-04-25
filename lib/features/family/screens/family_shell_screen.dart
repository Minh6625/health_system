import 'dart:async';

import 'package:flutter/material.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/emergency/providers/emergency_caregiver_provider.dart';
import 'package:healthguard/features/emergency/screens/emergency_sos_received_list_screen.dart';
import 'package:healthguard/features/family/providers/family_dashboard_provider.dart';
import 'package:healthguard/features/family/providers/family_relationship_provider.dart';
import 'package:healthguard/features/family/screens/contact_list_screen.dart';
import 'package:healthguard/features/family/screens/family_dashboard_screen.dart';
import 'package:healthguard/shared/presentation/shell/app_shell_bottom_nav.dart';
import 'package:healthguard/shared/presentation/shell/main_scaffold_shell.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:provider/provider.dart';

class FamilyShellScreen extends StatefulWidget {
  const FamilyShellScreen({
    super.key,
    this.initialTab = 0,
    this.enableAutoRefresh = true,
    this.badgeRefreshInterval = const Duration(seconds: 2),
  });

  /// 0 = Theo dõi, 1 = Liên hệ, 2 = SOS
  final int initialTab;
  final bool enableAutoRefresh;
  final Duration badgeRefreshInterval;

  @override
  State<FamilyShellScreen> createState() => _FamilyShellScreenState();
}

class _FamilyShellScreenState extends State<FamilyShellScreen>
    // _syncTabController disposes the existing TabController and creates a new
    // one when the caregiver's `can_receive_alerts` permission flips, so the
    // state legitimately needs more than one ticker over its lifetime.
    // SingleTickerProviderStateMixin would assert on the second creation.
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  late FamilyRelationshipProvider _familyProvider;
  late AuthProvider _authProvider;
  Timer? _badgeRefreshTimer;
  bool _isRefreshingBadges = false;
  bool _canReceiveAlerts = false;
  int? _lastRefreshedUserId;

  int get _tabCount => _canReceiveAlerts ? 3 : 2;
  int _clampTabIndex(int index) {
    final maxIndex = _tabCount - 1;
    if (index < 0) {
      return 0;
    }
    if (index > maxIndex) {
      return maxIndex;
    }
    return index;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _familyProvider = context.read<FamilyRelationshipProvider>();
    _authProvider = context.read<AuthProvider>();
    _authProvider.addListener(_handleAuthChanged);
    _canReceiveAlerts = _familyProvider.canReceiveAlerts;
    _tabController = TabController(
      length: _tabCount,
      vsync: this,
      initialIndex: _clampTabIndex(widget.initialTab),
    );
    _tabController.addListener(_handleTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshTabBadges();
      if (widget.enableAutoRefresh) {
        _startBadgeAutoRefresh();
      }
    });
  }

  @override
  void dispose() {
    _stopBadgeAutoRefresh();
    WidgetsBinding.instance.removeObserver(this);
    _authProvider.removeListener(_handleAuthChanged);
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _syncTabController(bool canReceiveAlerts) {
    if (_canReceiveAlerts == canReceiveAlerts) {
      return;
    }

    final previousIndex = _tabController.index;
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();

    _canReceiveAlerts = canReceiveAlerts;
    _tabController = TabController(
      length: _tabCount,
      vsync: this,
      initialIndex: _clampTabIndex(previousIndex),
    );
    _tabController.addListener(_handleTabChanged);
    if (mounted) {
      setState(() {});
    }
  }

  void _handleAuthChanged() {
    if (!mounted) {
      return;
    }

    final userId = _authProvider.currentUser?.userId;
    if (userId == null || userId == _lastRefreshedUserId) {
      return;
    }

    _refreshTabBadges(silent: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (widget.enableAutoRefresh) {
        _startBadgeAutoRefresh();
      }
      _refreshTabBadges(silent: true);
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopBadgeAutoRefresh();
    }
  }

  void _startBadgeAutoRefresh() {
    if (!widget.enableAutoRefresh) {
      return;
    }
    _badgeRefreshTimer?.cancel();
    _badgeRefreshTimer = Timer.periodic(widget.badgeRefreshInterval, (_) {
      _refreshTabBadges(silent: true);
    });
  }

  void _stopBadgeAutoRefresh() {
    _badgeRefreshTimer?.cancel();
    _badgeRefreshTimer = null;
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }
    _refreshTabBadges(silent: true);
  }

  Future<void> _navigateToAddContact() async {
    await Navigator.pushNamed(context, AppRouter.addContact);
    if (mounted) {
      await _refreshTabBadges();
    }
  }

  Future<void> _refreshTabBadges({bool silent = false}) async {
    if (!mounted || _isRefreshingBadges) {
      return;
    }

    final user = context.read<AuthProvider>().currentUser;
    if (user == null) {
      return;
    }
    _lastRefreshedUserId = user.userId;

    _isRefreshingBadges = true;
    try {
      await _familyProvider.load(user.userId, silent: silent);
      _syncTabController(_familyProvider.canReceiveAlerts);

      final futures = <Future<void>>[
        context.read<FamilyDashboardProvider>().loadDashboard(
              user.userId,
              silent: silent,
            ),
      ];

      if (_canReceiveAlerts && _tabController.index != 2) {
        futures.add(
          context.read<EmergencyCaregiverProvider>().fetchSOSAlerts(
                'all',
                silent: silent,
              ),
        );
      }

      await Future.wait(futures);
    } finally {
      _isRefreshingBadges = false;
    }
  }

  Widget _buildTabLabelWithBadge({
    required String label,
    required int count,
    Color badgeColor = AppColors.critical,
  }) {
    if (count <= 0) {
      return Text(label);
    }

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
              count.toString(),
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
    return MainScaffoldShell(
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
        key: const ValueKey('family-shell-screen'),
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          title: Text(
            'Gia đình',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          backgroundColor: AppColors.bgPrimary,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            AnimatedBuilder(
              animation: _tabController,
              builder: (context, child) {
                if (_tabController.index == 1) {
                  return IconButton(
                    icon: const Icon(
                      Icons.person_add,
                      color: AppColors.textPrimary,
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
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.gapLg,
                vertical: AppSpacing.gapSm,
              ),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(AppRadii.radiusXxl),
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
                    borderRadius: BorderRadius.circular(AppRadii.radiusXxl),
                    color: AppColors.brandPrimary,
                  ),
                  labelColor: AppColors.bgSurface,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  unselectedLabelColor: AppColors.textSecondary,
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                  tabs: [
                    Tab(
                      key: const ValueKey('family-tab-dashboard'),
                      child: Selector<FamilyDashboardProvider, int>(
                        selector: (context, provider) =>
                            provider.trackingAlertCount,
                        builder: (context, trackingCount, child) {
                          return _buildTabLabelWithBadge(
                            label: 'Theo dõi',
                            count: trackingCount,
                            badgeColor: AppColors.warning,
                          );
                        },
                      ),
                    ),
                    Tab(
                      key: const ValueKey('family-tab-contacts'),
                      child: Selector<FamilyRelationshipProvider, int>(
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
                    if (_canReceiveAlerts)
                      Tab(
                        key: const ValueKey('family-tab-sos'),
                        child: Selector<EmergencyCaregiverProvider, int>(
                          selector: (context, provider) => provider.activeCount,
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
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  FamilyDashboardScreen(
                    enableAutoRefresh: widget.enableAutoRefresh,
                  ),
                  const ContactListScreen(),
                  if (_canReceiveAlerts)
                    EmergencySOSReceivedListScreen(
                      enableAutoRefresh: widget.enableAutoRefresh,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
