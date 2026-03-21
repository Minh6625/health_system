import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProfileSectionCard
// White card with rounded corners and a soft shadow — wraps any section content.
// ─────────────────────────────────────────────────────────────────────────────
class ProfileSectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const ProfileSectionCard({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ProfileMenuTile
// Standard 48dp touch-target list tile for the profile hub menu.
// ─────────────────────────────────────────────────────────────────────────────
class ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isFirst;
  final bool isLast;

  const ProfileMenuTile({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? const Color(0xFF0F766E);
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(16) : Radius.zero,
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: effectiveIconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: effectiveIconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF12304A),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF5B7288),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ProfileMenuDivider
// Thin divider for between ProfileMenuTile items inside a card.
// ─────────────────────────────────────────────────────────────────────────────
class ProfileMenuDivider extends StatelessWidget {
  const ProfileMenuDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 70,
      endIndent: 0,
      color: AppColors.strokeSoft,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ProfileSectionLabel
// Section header label above a card group.
// ─────────────────────────────────────────────────────────────────────────────
class ProfileSectionLabel extends StatelessWidget {
  final String text;

  const ProfileSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: Color(0xFF5B7288),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DangerZoneCard
// Red-tinted card for destructive actions (logout, delete account).
// ─────────────────────────────────────────────────────────────────────────────
class DangerZoneCard extends StatelessWidget {
  final List<Widget> children;

  const DangerZoneCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppStateColors.criticalBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.critical.withValues(alpha: 0.25)),
      ),
      child: Column(children: children),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DangerMenuTile
// Like ProfileMenuTile but red-themed for destructive actions.
// ─────────────────────────────────────────────────────────────────────────────
class DangerMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isFirst;
  final bool isLast;

  const DangerMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(16) : Radius.zero,
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.critical.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.critical.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: AppColors.critical),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.critical,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.critical.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.critical.withValues(alpha: 0.6),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton / Shimmer Widgets
// Pure-Flutter shimmer — no external packages needed.
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    // Start repeating only after the first frame to avoid any layout-phase
    // animation kicks that can trigger mouse_tracker assertions.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.stop();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius ?? BorderRadius.circular(6),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFE8EEF3),
                  Color.lerp(const Color(0xFFE8EEF3), const Color(0xFFF8FAFC),
                      _anim.value)!,
                  const Color(0xFFE8EEF3),
                ],
                stops: const [0.0, 0.5, 1.0],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Skeleton for the hero card (avatar circle + name + email lines).
class ProfileHeroSkeleton extends StatelessWidget {
  const ProfileHeroSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _ShimmerBox(width: 88, height: 88, borderRadius: BorderRadius.circular(44)),
          const SizedBox(height: 16),
          _ShimmerBox(width: 160, height: 18, borderRadius: BorderRadius.circular(8)),
          const SizedBox(height: 8),
          _ShimmerBox(width: 220, height: 13, borderRadius: BorderRadius.circular(6)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ShimmerBox(width: 70, height: 24, borderRadius: BorderRadius.circular(12)),
              const SizedBox(width: 8),
              _ShimmerBox(width: 70, height: 24, borderRadius: BorderRadius.circular(12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuTileSkeleton extends StatelessWidget {
  final bool showDivider;
  const _MenuTileSkeleton({this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _ShimmerBox(width: 40, height: 40, borderRadius: BorderRadius.circular(10)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(width: 130, height: 14, borderRadius: BorderRadius.circular(6)),
                    const SizedBox(height: 6),
                    _ShimmerBox(width: 90, height: 11, borderRadius: BorderRadius.circular(5)),
                  ],
                ),
              ),
              _ShimmerBox(width: 16, height: 16, borderRadius: BorderRadius.circular(4)),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, indent: 70, color: AppColors.strokeSoft),
      ],
    );
  }
}

/// Skeleton for a labeled card section with N tile rows.
class ProfileMenuSkeleton extends StatelessWidget {
  final int tileCount;
  const ProfileMenuSkeleton({super.key, this.tileCount = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: _ShimmerBox(width: 80, height: 11, borderRadius: BorderRadius.circular(5)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: List.generate(
              tileCount,
              (i) => _MenuTileSkeleton(showDivider: i < tileCount - 1),
            ),
          ),
        ),
      ],
    );
  }
}

/// Full skeleton layout that mirrors the ProfileScreen hub structure.
/// Show this when isLoading == true and profile == null (first load).
class ProfileSkeletonBody extends StatelessWidget {
  const ProfileSkeletonBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ProfileHeroSkeleton(),
          SizedBox(height: 24),
          ProfileMenuSkeleton(tileCount: 3),
          SizedBox(height: 20),
          ProfileMenuSkeleton(tileCount: 2),
          SizedBox(height: 20),
          ProfileMenuSkeleton(tileCount: 2),
        ],
      ),
    );
  }
}
