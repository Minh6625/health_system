import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/family/models/recent_alert_item.dart';
import 'package:healthguard/features/family/providers/person_alerts_provider.dart';
import 'package:healthguard/features/family/repositories/family_repository.dart';
import 'package:healthguard/features/family/widgets/alert_history_item.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';

/// "Cảnh báo gần đây" section at the bottom of PersonDetailScreen.
///
/// Owns its own [PersonAlertsProvider] (scoped to the section, not the
/// screen) so:
///   * Re-mounting the section after a navigation away cleanly resets
///     state without affecting other dashboard data.
///   * Failures here never bring down the rest of the detail screen — the
///     section degrades to an inline error/retry, never bubbles up.
///
/// State machine handled here:
///   loading → skeleton
///   permissionDenied → warning banner
///   error → inline retry
///   granted + empty → friendly "no alerts in window" copy
///   granted + items → list of [AlertHistoryItem]
class AlertHistorySection extends StatelessWidget {
  const AlertHistorySection({
    super.key,
    required this.profileId,
    required this.firstName,
    this.repositoryOverride,
  });

  /// ``FamilyProfileSnapshot.id`` — string at the boundary, parsed inside the
  /// provider; see ``PersonAlertsProvider.load`` for the int.tryParse guard.
  final String profileId;

  /// Pre-extracted first name from the profile so the empty/error copy can
  /// reference the patient ("Cảnh báo về Bố An sẽ hiển thị tại đây") without
  /// re-implementing the same name-splitting heuristic in three places.
  final String firstName;

  /// Wired through to the provider for tests; production callers omit this.
  final FamilyRepository? repositoryOverride;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PersonAlertsProvider>(
      create: (_) =>
          PersonAlertsProvider(repository: repositoryOverride)..load(profileId),
      child: _SectionBody(profileId: profileId, firstName: firstName),
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.profileId, required this.firstName});

  final String profileId;
  final String firstName;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PersonAlertsProvider>();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gapLg,
        0,
        AppSpacing.gapLg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(),
          SizedBox(height: AppSpacing.sectionGapSm),
          _buildBody(context, provider),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PersonAlertsProvider provider,
  ) {
    switch (provider.status) {
      case PersonAlertsStatus.initial:
      case PersonAlertsStatus.loading:
        return const _LoadingSkeleton();
      case PersonAlertsStatus.permissionDenied:
        return _PermissionDeniedBanner(firstName: firstName);
      case PersonAlertsStatus.error:
        return _ErrorState(
          message: provider.errorMessage,
          onRetry: () => provider.reload(profileId),
        );
      case PersonAlertsStatus.granted:
        if (provider.items.isEmpty) {
          return _EmptyState(
            firstName: firstName,
            windowDays: provider.windowDays,
          );
        }
        return _AlertList(items: provider.items);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Cảnh báo gần đây',
      style: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          height: 72,
          margin: EdgeInsets.only(bottom: AppSpacing.gapSm),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppRadii.radiusMd),
            border: Border.all(color: AppColors.strokeSoft),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.firstName, required this.windowDays});

  final String firstName;
  final int windowDays;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.gapLg,
        vertical: AppSpacing.sectionGapXl,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.textSecondary,
            size: 36,
          ),
          SizedBox(height: AppSpacing.gapSm),
          const Text(
            'Chưa có cảnh báo gần đây',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppSpacing.gapXs),
          Text(
            'Cảnh báo về $firstName trong $windowDays ngày qua sẽ hiển thị tại đây.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionDeniedBanner extends StatelessWidget {
  const _PermissionDeniedBanner({required this.firstName});

  final String firstName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.gapLg),
      decoration: BoxDecoration(
        color: AppStateColors.warningBg,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.lock_outline_rounded,
                color: AppColors.warning,
                size: 22,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chưa được chia sẻ cảnh báo',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.gapSm),
          Text(
            '$firstName chưa cho phép bạn nhận cảnh báo. '
            'Hãy nhờ họ vào "Quyền chia sẻ" trong liên hệ và bật mục '
            '"Cho phép nhận cảnh báo SOS của tôi".',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.gapLg),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.critical,
            size: 32,
          ),
          SizedBox(height: AppSpacing.gapSm),
          const Text(
            'Không tải được cảnh báo gần đây',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (message != null && message!.isNotEmpty) ...[
            SizedBox(height: AppSpacing.gapXs),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          SizedBox(height: AppSpacing.gapSm),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}

class _AlertList extends StatefulWidget {
  const _AlertList({required this.items});

  final List<RecentAlertItem> items;

  @override
  State<_AlertList> createState() => _AlertListState();
}

class _AlertListState extends State<_AlertList> {
  /// How many cards to render before the "Xem thêm" CTA collapses the rest.
  /// Three is a deliberate compromise: small enough that the section never
  /// dominates the scroll view on a 6.1" phone, large enough that a quiet
  /// week (1–2 incidents) still shows everything without an extra tap.
  static const int _initialVisible = 3;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final all = widget.items;
    final hasOverflow = all.length > _initialVisible;
    final visible = (_expanded || !hasOverflow)
        ? all
        : all.sublist(0, _initialVisible);
    final hiddenCount = all.length - visible.length;

    return Column(
      children: [
        for (final alert in visible)
          AlertHistoryItem(
            key: ValueKey(alert.uuid),
            alert: alert,
            onTap: () => _onTap(context, alert),
          ),
        if (hasOverflow) _buildToggle(hiddenCount),
      ],
    );
  }

  Widget _buildToggle(int hiddenCount) {
    final label = _expanded
        ? 'Thu gọn'
        : 'Xem thêm $hiddenCount cảnh báo';
    final icon = _expanded
        ? Icons.expand_less_rounded
        : Icons.expand_more_rounded;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: () => setState(() => _expanded = !_expanded),
          icon: Icon(icon, size: 18, color: AppColors.brandPrimary),
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.brandPrimary,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.radiusMd),
            ),
          ),
        ),
      ),
    );
  }

  /// Deep-link routing — keep it defensive: an unknown link.type degrades to
  /// a bottom sheet with the raw message, never a navigation crash. The
  /// concrete route names match ``app_router.dart``; if either route is
  /// renamed, the fallback bottom sheet kicks in instead of throwing.
  void _onTap(BuildContext context, RecentAlertItem alert) {
    final link = alert.deepLink;
    if (link == null) {
      _showDetailSheet(context, alert);
      return;
    }
    switch (link.type) {
      case RecentAlertDeepLinkType.sosEvent:
        Navigator.of(context).pushNamed(
          AppRouter.emergencySosDetail,
          arguments: link.id.toString(),
        );
        return;
      case RecentAlertDeepLinkType.riskScore:
      case RecentAlertDeepLinkType.fallEvent:
      case RecentAlertDeepLinkType.alert:
      case RecentAlertDeepLinkType.unknown:
        _showDetailSheet(context, alert);
    }
  }

  void _showDetailSheet(BuildContext context, RecentAlertItem alert) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gapLg,
          AppSpacing.gapLg,
          AppSpacing.gapLg,
          AppSpacing.sectionGapXl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              alert.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (alert.message != null && alert.message!.isNotEmpty) ...[
              SizedBox(height: AppSpacing.gapSm),
              Text(
                alert.message!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
