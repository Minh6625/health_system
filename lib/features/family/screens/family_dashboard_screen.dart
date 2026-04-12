import 'dart:async';

import 'package:flutter/material.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';
import 'package:healthguard/features/family/providers/family_dashboard_provider.dart';
import 'package:healthguard/features/family/widgets/family_health_hero_card.dart';
import 'package:healthguard/features/family/widgets/family_onboarding_empty_state.dart';
import 'package:healthguard/features/family/widgets/family_profile_health_card.dart';
import 'package:healthguard/features/family/widgets/family_sos_full_screen_overlay.dart';
import 'package:healthguard/features/family/widgets/locked_profile_card.dart';
import 'package:provider/provider.dart';

import 'package:healthguard/features/auth/providers/auth_provider.dart';

class FamilyDashboardScreen extends StatefulWidget {
  const FamilyDashboardScreen({super.key});

  @override
  State<FamilyDashboardScreen> createState() => _FamilyDashboardScreenState();
}

class _FamilyDashboardScreenState extends State<FamilyDashboardScreen>
    with WidgetsBindingObserver {
  static const Duration _autoRefreshInterval = Duration(seconds: 1);

  Timer? _autoRefreshTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshDashboard();
      _startAutoRefresh();
    });
  }

  Future<void> _refreshDashboard({bool silent = false}) async {
    if (!mounted || _isRefreshing) return;

    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    _isRefreshing = true;
    try {
      await context.read<FamilyDashboardProvider>().loadDashboard(
        user.userId,
        silent: silent,
      );
    } finally {
      _isRefreshing = false;
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      _refreshDashboard(silent: true);
    });
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startAutoRefresh();
      _refreshDashboard(silent: true);
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopAutoRefresh();
    }
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const _FamilyDashboardContent();
  }
}

class _FamilyDashboardContent extends StatefulWidget {
  const _FamilyDashboardContent();

  @override
  State<_FamilyDashboardContent> createState() =>
      _FamilyDashboardContentState();
}

class _FamilyDashboardContentState extends State<_FamilyDashboardContent> {
  bool _sosOverlayShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<FamilyDashboardProvider>();
    if (!provider.isLoading && !_sosOverlayShown && provider.sosCount > 0) {
      _sosOverlayShown = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showSosOverlay(provider),
      );
    }
  }

  void _showSosOverlay(FamilyDashboardProvider provider) {
    if (!mounted) return;
    final sosProfiles = provider.displayList
        .where((p) => p.isSosActive)
        .toList();
    if (sosProfiles.isEmpty) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'SOS',
      pageBuilder: (context, _, _) => FamilySOSFullScreenOverlay(
        sosProfiles: sosProfiles,
        onViewDetail: (sosId) {
          Navigator.of(context).pop();
          // Sửa: navigate theo sosId đến EmergencySOSDetailScreen (không dùng personDetail)
          Navigator.of(context).pushNamed(
            AppRouter.emergencySosDetail,
            arguments: {'sosId': sosId},
          );
        },
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }

  void _onContactTapped(BuildContext context, String profileId) {
    Navigator.of(
      context,
    ).pushNamed(AppRouter.personDetail, arguments: {'profileId': profileId});
  }

  void _onManageContactsTapped(BuildContext context) {
    Navigator.of(
      context,
    ).pushNamed(AppRouter.familyManagement, arguments: {'initialTab': 1});
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FamilyDashboardProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: _buildBody(context, provider),
    );
  }

  Widget _buildBody(BuildContext context, FamilyDashboardProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
        ),
      );
    }

    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.critical),
            SizedBox(height: AppSpacing.gapLg),
            Text(
              'Có lỗi xảy ra khi tải dữ liệu',
              style: AppTextStyles.sectionTitle.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: AppSpacing.gapSm),
            ElevatedButton(
              onPressed: () {
                final auth = context.read<AuthProvider>();
                if (auth.currentUser != null) {
                  provider.loadDashboard(auth.currentUser!.userId);
                }
              },
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (provider.profiles.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          final auth = context.read<AuthProvider>();
          if (auth.currentUser != null) {
            provider.loadDashboard(auth.currentUser!.userId);
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            FamilyOnboardingEmptyState(
              onAddContact: () => _onManageContactsTapped(context),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final auth = context.read<AuthProvider>();
        if (auth.currentUser != null) {
          provider.loadDashboard(auth.currentUser!.userId);
        }
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: AppSpacing.sectionGapXl),
        // 4 fixed slots (Hero, [sos removed], [attention removed], Filter) + list + footer
        itemCount: 3 + provider.displayList.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              children: [
                FamilyHealthHeroCard(
                  totalCount: provider.totalTracked,
                  stableCount: provider.stableCount,
                  attentionCount: provider.attentionCount,
                ),
                SizedBox(height: AppSpacing.gapSm),
              ],
            );
          }
          if (index == 1) {
            return _buildFilterChips(context, provider);
          }
          if (index == 2) {
            return SizedBox(height: AppSpacing.gapSm);
          }

          final listIndex = index - 3;

          if (listIndex < provider.displayList.length) {
            final profile = provider.displayList[listIndex];
            if (!profile.hasViewVitalsPermission) {
              return LockedProfileCard(
                profile: profile,
                onManageRoles: () async {
                  await Navigator.of(context).pushNamed(
                    AppRouter.linkedContactDetail,
                    arguments: {'contactId': profile.id},
                  );
                  if (context.mounted) {
                    final auth = context.read<AuthProvider>();
                    if (auth.currentUser != null) {
                      context.read<FamilyDashboardProvider>().loadDashboard(
                        auth.currentUser!.userId,
                      );
                    }
                  }
                },
              );
            }
            return FamilyProfileHealthCard(
              profile: profile,
              onTap: () => _onContactTapped(context, profile.id),
            );
          }

          // Footer
          return Padding(
            padding: EdgeInsets.all(AppSpacing.sectionGapXl),
            child: OutlinedButton(
              onPressed: () => _onManageContactsTapped(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                side: const BorderSide(color: AppColors.brandPrimary),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadii.cardRadius,
                ),
              ),
              child: Text(
                'Quản lý liên hệ & quyền xem',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChips(
    BuildContext context,
    FamilyDashboardProvider provider,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.gapLg, vertical: 6),
      child: Row(
        children: [
          _buildChip(provider, 'Tất cả', FamilyFilter.all),
          _buildChip(provider, 'SOS', FamilyFilter.sos),
          _buildChip(provider, 'Cần chú ý', FamilyFilter.attention),
          _buildChip(provider, 'Ưu tiên', FamilyFilter.priority),
        ],
      ),
    );
  }

  Widget _buildChip(
    FamilyDashboardProvider provider,
    String label,
    FamilyFilter filter,
  ) {
    final isSelected = provider.currentFilter == filter;
    return Padding(
      padding: EdgeInsets.only(right: AppSpacing.gapSm),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          provider.setFilter(filter);
        },
        selectedColor: AppColors.bgElevated,
        backgroundColor: AppColors.bgPrimary,
        showCheckmark: false,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.radiusXl),
          side: BorderSide(
            color: isSelected
                ? AppColors.strokeSoft
                : AppColors.strokeSoft,
          ),
        ),
      ),
    );
  }
}
