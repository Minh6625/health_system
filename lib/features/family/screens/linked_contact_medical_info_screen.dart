import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:healthguard/features/family/models/linked_contact_medical_info_model.dart';
import 'package:healthguard/features/family/providers/linked_contact_medical_info_provider.dart';
import 'package:healthguard/features/family/repositories/family_repository.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';

/// P-4: caregiver-facing read-only view of a patient's medical profile.
///
/// Why a separate screen (vs. inlining on PersonDetailScreen):
///   * Different permission scope — vitals are gated by ``can_view_vitals``;
///     medical info by ``can_view_medical_info``. A patient may grant one
///     and not the other, so the entry/empty-state logic differs.
///   * Audit clarity — a route landing implies an explicit caregiver intent
///     to view PII-adjacent data; logging this hop is easier than logging
///     scroll positions on a parent screen.
///   * Reusability — the same screen could be linked from emergency SOS
///     detail later (paramedic flow) without dragging the parent context.
class LinkedContactMedicalInfoScreen extends StatelessWidget {
  /// The linked-contact id (matches ``LinkedContactModel.id``). The backend
  /// accepts either a real ``user_id`` or a ``relationship_id`` so the
  /// caller doesn't need to disambiguate.
  final String contactId;

  /// Optional pre-known display name to render in the app bar before the
  /// fetch completes. Avoids the awkward "Người dùng" placeholder during
  /// the loading flash.
  final String? prefilledName;

  /// Repository hook for tests; wires through to the provider so a
  /// fake repo can drive every state.
  final FamilyRepository? repositoryOverride;

  const LinkedContactMedicalInfoScreen({
    super.key,
    required this.contactId,
    this.prefilledName,
    this.repositoryOverride,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LinkedContactMedicalInfoProvider>(
      create: (_) =>
          LinkedContactMedicalInfoProvider(repository: repositoryOverride)
            ..load(contactId),
      child: _ScreenBody(
        contactId: contactId,
        prefilledName: prefilledName,
      ),
    );
  }
}

class _ScreenBody extends StatelessWidget {
  const _ScreenBody({required this.contactId, this.prefilledName});

  final String contactId;
  final String? prefilledName;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LinkedContactMedicalInfoProvider>();

    // App-bar title: live data wins, then the pre-filled hint, then a
    // generic fallback. Never shows the raw id (which is a DB integer
    // and means nothing to the caregiver).
    final headerName =
        provider.info?.displayName ??
        (prefilledName?.trim().isNotEmpty == true ? prefilledName : null) ??
        'Liên hệ';

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          'Hồ sơ y tế · $headerName',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.load(contactId),
        child: _buildContent(context, provider),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    LinkedContactMedicalInfoProvider provider,
  ) {
    switch (provider.status) {
      case MedicalInfoStatus.initial:
      case MedicalInfoStatus.loading:
        return const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
          ),
        );

      case MedicalInfoStatus.permissionDenied:
        return _PermissionDeniedState(
          contactName:
              prefilledName?.trim().isNotEmpty == true ? prefilledName : null,
        );

      case MedicalInfoStatus.notFound:
        return _GenericEmptyState(
          icon: Icons.link_off_rounded,
          title: 'Không tìm thấy liên hệ',
          message:
              'Có thể liên kết đã bị huỷ. Hãy quay lại danh sách và thử lại.',
        );

      case MedicalInfoStatus.error:
        return _ErrorState(
          message: provider.errorMessage,
          onRetry: () => provider.load(contactId),
        );

      case MedicalInfoStatus.ready:
        final info = provider.info;
        if (info == null) {
          // Defensive: ready without data shouldn't happen, but treat as
          // empty rather than crashing.
          return _GenericEmptyState(
            icon: Icons.medical_information_outlined,
            title: 'Chưa có dữ liệu',
            message: 'Người này chưa cập nhật hồ sơ y tế.',
          );
        }
        return _ReadyContent(info: info);
    }
  }
}

// ---------------------------------------------------------------------------
// State widgets
// ---------------------------------------------------------------------------

class _PermissionDeniedState extends StatelessWidget {
  const _PermissionDeniedState({this.contactName});

  final String? contactName;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // ListView (not Center+Column) so the parent RefreshIndicator stays
      // pullable even in the empty state — caregiver can pull-to-refresh
      // after asking the patient to enable sharing.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.gapLg,
        vertical: AppSpacing.sectionGapXl,
      ),
      children: [
        Container(
          padding: EdgeInsets.all(AppSpacing.gapLg),
          decoration: BoxDecoration(
            color: AppStateColors.warningBg,
            borderRadius: BorderRadius.circular(AppRadii.radiusLg),
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.warning,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chưa được chia sẻ hồ sơ y tế',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.gapSm),
              Text(
                contactName != null && contactName!.isNotEmpty
                    ? '$contactName chưa cho phép bạn xem hồ sơ y tế (nhóm máu, chiều cao/cân nặng, thuốc đang dùng, dị ứng, tiền sử bệnh).'
                    : 'Người này chưa cho phép bạn xem hồ sơ y tế (nhóm máu, chiều cao/cân nặng, thuốc đang dùng, dị ứng, tiền sử bệnh).',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: AppSpacing.gapSm),
              const Text(
                'Hãy nhờ họ vào "Quyền chia sẻ" trong liên hệ và bật mục "Cho phép xem hồ sơ y tế của tôi".',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GenericEmptyState extends StatelessWidget {
  const _GenericEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.gapLg,
        vertical: AppSpacing.sectionGapXl,
      ),
      children: [
        SizedBox(height: AppSpacing.sectionGapXl),
        Icon(icon, size: 48, color: AppColors.textSecondary),
        SizedBox(height: AppSpacing.gapSm),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: AppSpacing.gapSm),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.gapLg,
        vertical: AppSpacing.sectionGapXl,
      ),
      children: [
        SizedBox(height: AppSpacing.sectionGapXl),
        const Icon(
          Icons.error_outline_rounded,
          size: 48,
          color: AppColors.critical,
        ),
        SizedBox(height: AppSpacing.gapSm),
        const Text(
          'Có lỗi khi tải hồ sơ y tế',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (message != null && message!.isNotEmpty) ...[
          SizedBox(height: AppSpacing.gapSm),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        SizedBox(height: AppSpacing.gapLg),
        Center(
          child: ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Ready content
// ---------------------------------------------------------------------------

class _ReadyContent extends StatelessWidget {
  const _ReadyContent({required this.info});

  final LinkedContactMedicalInfoModel info;

  static const _conditionLabels = <String, String>{
    'hypertension': 'Cao huyết áp',
    'heart_disease': 'Bệnh tim mạch',
    'diabetes': 'Tiểu đường',
    'stroke': 'Đột quỵ',
    'other': 'Khác',
  };

  String _displayCondition(String raw) {
    return _conditionLabels[raw] ?? raw;
  }

  @override
  Widget build(BuildContext context) {
    if (info.isEmpty) {
      return _GenericEmptyState(
        icon: Icons.medical_information_outlined,
        title: 'Chưa có hồ sơ y tế',
        message:
            '${info.displayName} chưa cập nhật hồ sơ y tế. Hãy nhờ họ điền thông tin trong mục "Hồ sơ y tế" trên hồ sơ cá nhân.',
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gapLg,
        AppSpacing.gapLg,
        AppSpacing.gapLg,
        AppSpacing.sectionGapXl,
      ),
      children: [
        // Privacy reminder so the caregiver knows the data is patient-curated
        // and not a clinical record.
        Container(
          padding: EdgeInsets.all(AppSpacing.gapSm),
          decoration: BoxDecoration(
            color: AppStateColors.infoBg,
            borderRadius: BorderRadius.circular(AppRadii.radiusSm),
          ),
          child: Row(
            children: const [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.brandPrimary,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Thông tin do người dùng tự khai báo. Chỉ dùng để tham khảo.',
                  style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.gapLg),

        _SectionLabel('Chỉ số cơ thể'),
        _SectionCard(
          children: [
            _KeyValueRow(
              label: 'Nhóm máu',
              value: info.bloodType?.isNotEmpty == true
                  ? info.bloodType!
                  : 'Chưa cập nhật',
              valueIsMuted: info.bloodType == null || info.bloodType!.isEmpty,
            ),
            _Divider(),
            _KeyValueRow(
              label: 'Chiều cao',
              value: info.heightCm != null
                  ? '${info.heightCm} cm'
                  : 'Chưa cập nhật',
              valueIsMuted: info.heightCm == null,
            ),
            _Divider(),
            _KeyValueRow(
              label: 'Cân nặng',
              value: info.weightKg != null
                  ? '${info.weightKg!.toStringAsFixed(1)} kg'
                  : 'Chưa cập nhật',
              valueIsMuted: info.weightKg == null,
            ),
          ],
        ),

        SizedBox(height: AppSpacing.sectionGapXl),
        _SectionLabel('Thuốc đang dùng'),
        _SectionCard(
          children: [
            _ChipsOrEmpty(
              items: info.medications,
              emptyText: 'Chưa khai báo thuốc đang dùng.',
            ),
          ],
        ),

        SizedBox(height: AppSpacing.sectionGapXl),
        _SectionLabel('Dị ứng'),
        _SectionCard(
          children: [
            _ChipsOrEmpty(
              items: info.allergies,
              emptyText: 'Chưa khai báo dị ứng.',
            ),
          ],
        ),

        SizedBox(height: AppSpacing.sectionGapXl),
        _SectionLabel('Tiền sử bệnh'),
        _SectionCard(
          children: [
            _ChipsOrEmpty(
              items: info.medicalConditions
                  .map(_displayCondition)
                  .toList(growable: false),
              emptyText: 'Chưa khai báo tiền sử bệnh.',
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Small composable widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusLg),
        border: Border.all(color: AppColors.strokeSoft),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.gapLg,
        vertical: AppSpacing.gapSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({
    required this.label,
    required this.value,
    this.valueIsMuted = false,
  });

  final String label;
  final String value;
  final bool valueIsMuted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.gapSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: valueIsMuted ? FontWeight.w400 : FontWeight.w600,
                color: valueIsMuted
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                fontStyle:
                    valueIsMuted ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppColors.strokeSoft,
    );
  }
}

class _ChipsOrEmpty extends StatelessWidget {
  const _ChipsOrEmpty({required this.items, required this.emptyText});

  final List<String> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.gapSm),
        child: Text(
          emptyText,
          style: const TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.gapSm),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final item in items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(AppRadii.radiusSm),
              ),
              child: Text(
                item,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
