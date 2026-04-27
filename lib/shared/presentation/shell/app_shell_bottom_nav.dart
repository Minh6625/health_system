import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../feedback/semantic_badge.dart';
import '../theme/app_bottom_nav_tokens.dart';
import '../theme/app_text_styles.dart';

enum AppMainTab { me, family, device, profile }

class AppShellBottomNav extends StatelessWidget {
  final AppMainTab currentTab;
  final bool familyHasAlertBadge;
  final bool deviceHasAttentionBadge;
  final ValueChanged<AppMainTab> onTabSelected;

  const AppShellBottomNav({
    super.key,
    required this.currentTab,
    this.familyHasAlertBadge = false,
    this.deviceHasAttentionBadge = false,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(top: BorderSide(color: AppColors.strokeSoft, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppBottomNavTokens.heightBase,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTabItem(
                context,
                tab: AppMainTab.me,
                iconData: Icons.home_rounded,
                label: 'Tôi',
                semanticLabel: 'Tab Sức khoẻ của tôi',
              ),
              _buildTabItem(
                context,
                tab: AppMainTab.family,
                iconData: Icons.family_restroom_rounded,
                label: 'Gia đình',
                semanticLabel: 'Tab Gia đình',
                hasBadge: familyHasAlertBadge,
                badgeLevel: SemanticBadgeLevel.critical,
              ),
              _buildTabItem(
                context,
                tab: AppMainTab.device,
                iconData: Icons.watch_rounded,
                label: 'Thiết bị',
                semanticLabel: 'Tab Thiết bị',
                hasBadge: deviceHasAttentionBadge,
                badgeLevel: SemanticBadgeLevel.warning,
              ),
              _buildTabItem(
                context,
                tab: AppMainTab.profile,
                iconData: Icons.person_rounded,
                label: 'Hồ sơ',
                semanticLabel: 'Tab Hồ sơ',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(
    BuildContext context, {
    required AppMainTab tab,
    required IconData iconData,
    required String label,
    required String semanticLabel,
    bool hasBadge = false,
    SemanticBadgeLevel badgeLevel = SemanticBadgeLevel.critical,
  }) {
    final isActive = currentTab == tab;

    return Semantics(
      label: hasBadge ? '$semanticLabel, có báo động' : semanticLabel,
      selected: isActive,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTabSelected(tab),
          customBorder: RoundedRectangleBorder(
            borderRadius: AppRadii.pillRadius,
          ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.fastOutSlowIn,
              constraints: const BoxConstraints(
                minWidth: AppBottomNavTokens.minTouchWidth,
                minHeight: AppBottomNavTokens.minTouchHeight,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? AppColors.brandPrimary.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: AppRadii.activeNavIndicatorRadius,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        isActive ? iconData : _getOutlineIcon(iconData),
                        size: AppBottomNavTokens.iconSize,
                        color: isActive
                            ? AppColors.brandPrimary
                            : AppColors.textSecondary,
                      ),
                      if (hasBadge)
                        Positioned(
                          top: -4,
                          right: -8,
                          child: tab == AppMainTab.family
                              ? Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: AppColors.emergency,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.bgSurface, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.priority_high_rounded,
                                    size: 8,
                                    color: Colors.white,
                                  ),
                                )
                              : SemanticBadge.dot(level: badgeLevel),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: isActive
                        ? AppTextStyles.navLabelActive.copyWith(color: AppColors.brandPrimary)
                        : AppTextStyles.navLabel,
                    child: Text(label),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }

  IconData _getOutlineIcon(IconData solidIcon) {
    if (solidIcon == Icons.home_rounded) return Icons.home_outlined;
    if (solidIcon == Icons.family_restroom_rounded) return Icons.family_restroom_outlined;
    if (solidIcon == Icons.watch_rounded) return Icons.watch_outlined;
    if (solidIcon == Icons.person_rounded) return Icons.person_outline_rounded;
    return solidIcon;
  }
}
