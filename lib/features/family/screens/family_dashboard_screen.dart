import 'package:flutter/material.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/family/providers/family_dashboard_mock_provider.dart';
import 'package:healthguard/features/family/widgets/family_health_hero_card.dart';
import 'package:healthguard/features/family/widgets/family_onboarding_empty_state.dart';
import 'package:healthguard/features/family/widgets/family_profile_health_card.dart';
import 'package:healthguard/features/family/widgets/family_sos_full_screen_overlay.dart';
import 'package:healthguard/features/family/widgets/locked_profile_card.dart';
import 'package:provider/provider.dart';

class FamilyDashboardScreen extends StatelessWidget {
  const FamilyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final provider = FamilyDashboardMockProvider();
        Future.microtask(() => provider.loadDashboard());
        return provider;
      },
      child: const _FamilyDashboardContent(),
    );
  }
}

class _FamilyDashboardContent extends StatefulWidget {
  const _FamilyDashboardContent();

  @override
  State<_FamilyDashboardContent> createState() => _FamilyDashboardContentState();
}

class _FamilyDashboardContentState extends State<_FamilyDashboardContent> {
  bool _sosOverlayShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<FamilyDashboardMockProvider>();
    if (!provider.isLoading && !_sosOverlayShown && provider.sosCount > 0) {
      _sosOverlayShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showSosOverlay(provider));
    }
  }

  void _showSosOverlay(FamilyDashboardMockProvider provider) {
    if (!mounted) return;
    final sosProfiles = provider.displayList.where((p) => p.isSosActive).toList();
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
    Navigator.of(context).pushNamed(
      AppRouter.personDetail,
      arguments: {'profileId': profileId},
    );
  }

  void _onManageContactsTapped(BuildContext context) {
    Navigator.of(context).pushNamed(
      AppRouter.familyManagement,
      arguments: {'initialTab': 1},
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FamilyDashboardMockProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: _buildBody(context, provider),
    );
  }

  Widget _buildBody(BuildContext context, FamilyDashboardMockProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2F80ED))),
      );
    }

    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFC94A4A)),
            const SizedBox(height: 16),
            const Text(
              'Có lỗi xảy ra khi tải dữ liệu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF12304A)),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => provider.loadDashboard(),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (provider.profiles.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => provider.loadDashboard(),
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
      onRefresh: () async => provider.loadDashboard(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
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
                const SizedBox(height: 8),
              ],
            );
          }
          if (index == 1) {
            return _buildFilterChips(context, provider);
          }
          if (index == 2) {
            return const SizedBox(height: 8);
          }

          final listIndex = index - 3;

          if (listIndex < provider.displayList.length) {
            final profile = provider.displayList[listIndex];
            if (!profile.hasViewVitalsPermission) {
              return LockedProfileCard(
                profile: profile,
                onManageRoles: () => Navigator.of(context).pushNamed(AppRouter.linkedContactDetail, arguments: {'contactId': profile.id}),
              );
            }
            return FamilyProfileHealthCard(
              profile: profile,
              onTap: () => _onContactTapped(context, profile.id),
            );
          }

          // Footer
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: OutlinedButton(
              onPressed: () => _onManageContactsTapped(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                side: const BorderSide(color: Color(0xFF2F80ED)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Quản lý liên hệ & quyền xem',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2F80ED),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, FamilyDashboardMockProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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

  Widget _buildChip(FamilyDashboardMockProvider provider, String label, FamilyFilter filter) {
    final isSelected = provider.currentFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          provider.setFilter(filter);
        },
        selectedColor: const Color(0xFFE8EEF6),
        backgroundColor: const Color(0xFFF8FAFC),
        showCheckmark: false,
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF12304A) : const Color(0xFF5B7288),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? const Color(0xFFB8CAE0) : const Color(0xFFD8E3EE),
          ),
        ),
      ),
    );
  }
}
