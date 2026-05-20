import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/profile/providers/clinician_audience_provider.dart';

/// Phase 8 / Phase 4B-full slice 4a settings screen.
///
/// Hosts the **Chế độ chuyên môn** toggle that flips the risk-report
/// detail surface from the lean patient DTO to the clinician DTO with
/// raw SHAP + model_request_id. Visible only to users whose
/// authenticated role is in [clinicianRoles] — patient-mode binaries
/// never render the toggle, so the surface is undiscoverable for the
/// vast majority of users.
class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  static const String routeName = '/profile/settings';

  /// Roles the toggle is visible to. Mirrors the backend's
  /// `CLINICIAN_ROLES = {"clinician", "admin"}` (see
  /// `backend/app/core/audience.py`). Lower-cased for case-tolerant
  /// matching.
  static const Set<String> clinicianRoles = {'clinician', 'admin'};

  /// Returns `true` when the supplied role string permits the
  /// clinician audience. Trims + lowercases before checking so a
  /// caretaker accidentally entering `"Clinician"` in the DB still
  /// works.
  static bool isClinicianRole(String? role) {
    if (role == null) return false;
    return clinicianRoles.contains(role.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().currentUser;
    final showClinicianToggle = isClinicianRole(user?.role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          if (showClinicianToggle)
            const _ClinicianToggleTile()
          else
            _NoAdvancedSettingsHint(theme: theme),
        ],
      ),
    );
  }
}


/// Switch + description block for "Chế độ chuyên môn".
///
/// Watches [ClinicianAudienceProvider] so the switch flips visually
/// the moment the user taps it — even before secure-storage write
/// completes (the provider updates its in-memory state before the
/// async write).
class _ClinicianToggleTile extends StatelessWidget {
  const _ClinicianToggleTile();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<ClinicianAudienceProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Chuyên môn',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SwitchListTile.adaptive(
          value: provider.enabled,
          onChanged: provider.isInitialized
              ? (value) => provider.setEnabled(value)
              : null,
          title: const Text('Chế độ chuyên môn'),
          subtitle: const Text(
            'Hiển thị thêm dữ liệu kỹ thuật (SHAP, mã yêu cầu mô hình) '
            'trong báo cáo chi tiết. Chỉ dành cho nhân viên y tế.',
          ),
          secondary: Icon(
            Icons.medical_information_outlined,
            color: theme.colorScheme.primary,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
          child: Text(
            provider.enabled
                ? 'Đang xem ở góc nhìn chuyên môn.'
                : 'Đang xem ở góc nhìn bệnh nhân (mặc định).',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        // Phase 2 (Health Connect): entry point that drives the Mi
        // Fitness <-> Health Connect bridge. Available to every user, not
        // gated on the clinician toggle, because data sync is the core
        // mechanism for getting real Redmi Watch 3 readings into the app.
        const Divider(height: 32),
        ListTile(
          leading: Icon(
            Icons.health_and_safety_rounded,
            color: theme.colorScheme.primary,
          ),
          title: const Text('Đồng bộ Health Connect'),
          subtitle: const Text(
            'Kết nối Mi Fitness ↔ Health Connect để lấy dữ liệu thật từ '
            'đồng hồ Redmi Watch.',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).pushNamed(
            '/health-connect-settings',
          ),
        ),
      ],
    );
  }
}


/// Placeholder shown to non-clinician users so the screen isn't blank.
class _NoAdvancedSettingsHint extends StatelessWidget {
  const _NoAdvancedSettingsHint({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.tune_rounded,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có cài đặt nâng cao',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Các cài đặt chuyên môn sẽ xuất hiện khi tài khoản của '
            'bạn được cấp quyền y tế.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
