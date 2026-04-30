import 'dart:async';

import 'package:flutter/material.dart';
import 'package:healthguard/features/device/models/device_model.dart';
import 'package:healthguard/features/device/providers/device_configure_provider.dart';
import 'package:healthguard/features/device/providers/device_provider.dart';
import 'package:healthguard/features/device/utils/device_name_constraints.dart';
import 'package:healthguard/features/device/widgets/device_configure/configure_hero_header.dart';
import 'package:healthguard/features/device/widgets/device_configure/config_section_card.dart';
import 'package:healthguard/features/device/widgets/device_configure/danger_zone_card.dart';
import 'package:healthguard/features/device/widgets/device_configure/dirty_footer_bar.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';
import 'package:provider/provider.dart';

class DeviceConfigureScreen extends StatelessWidget {
  final DeviceModel device;

  const DeviceConfigureScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DeviceConfigureProvider(device),
      child: _DeviceConfigureContent(device: device),
    );
  }
}

class _DeviceConfigureContent extends StatefulWidget {
  final DeviceModel device;
  const _DeviceConfigureContent({required this.device});

  @override
  State<_DeviceConfigureContent> createState() => _DeviceConfigureContentState();
}

class _DeviceConfigureContentState extends State<_DeviceConfigureContent> {
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.device.displayName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showDiscardDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy thay đổi?'),
        content: const Text('Bạn có những thay đổi chưa lưu. Bạn có chắc chắn muốn thoát và hủy bỏ các thay đổi này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tiếp tục chỉnh sửa'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop(); // Actually pop the screen
            },
            child: const Text('Thoát (Không lưu)', style: TextStyle(color: AppColors.critical)),
          ),
        ],
      ),
    );
  }

  void _showUnpairDialog(BuildContext context, DeviceConfigureProvider provider) {
    // F-11 (M-8): when the device is currently online (still streaming
    // vitals + SOS coverage), users were unpairing without realising they'd
    // cut off live monitoring. The original dialog only said "this can't be
    // undone", which doesn't tell the user *what* they're losing. The fix:
    //
    //   * Online path  → stronger red warning that calls out vital
    //     monitoring + SOS, AND a checkbox the user must tick before the
    //     destructive button enables. Forces them to slow down and read.
    //   * Offline path → keep the original short confirmation; making
    //     offline users tick a checkbox just to delete a dead device would
    //     be busywork.
    //
    // We use a StatefulBuilder so the checkbox state is local to the
    // dialog and disposed with it.
    final bool isOnline = widget.device.isOnline;

    showDialog(
      context: context,
      builder: (ctx) {
        // State lives in the OUTER builder closure (called once per
        // showDialog) so it survives the inner StatefulBuilder rebuilds
        // triggered by setDialogState. Putting `acknowledgedRisk` inside
        // the StatefulBuilder.builder would reset it to !isOnline on
        // every rebuild and the checkbox could never stay checked.
        var acknowledgedRisk = !isOnline; // offline path is pre-acked.
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // Setter wrapper so we can rebuild the dialog when the checkbox
            // toggles. Closure-captured into the Checkbox below.
            void toggleAck(bool? value) {
              setDialogState(() {
                acknowledgedRisk = value ?? false;
              });
            }

            return AlertDialog(
            title: const Text('Ngắt kết nối thiết bị?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isOnline) ...[
                  // Stronger warning that names the consequences. The
                  // generic "can't be undone" line is genuinely true for
                  // both paths, but online users need to hear about the
                  // monitoring loss specifically.
                  const Text(
                    'Thiết bị này đang hoạt động và theo dõi sức khỏe của bạn.',
                    style: TextStyle(
                      color: AppColors.critical,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.gapSm),
                  const Text(
                    'Ngắt kết nối sẽ dừng cập nhật chỉ số sinh tồn và '
                    'tắt cảnh báo SOS tự động cho đến khi bạn ghép nối '
                    'lại thiết bị.',
                    style: TextStyle(color: AppColors.critical),
                  ),
                  const SizedBox(height: AppSpacing.gapSm),
                ],
                const Text(
                  'Thiết bị sẽ bị xóa khỏi tài khoản của bạn. Hành động này không thể hoàn tác.',
                  style: TextStyle(color: AppColors.critical),
                ),
                if (isOnline) ...[
                  const SizedBox(height: AppSpacing.gapMd),
                  // Inline checkbox row keeps the tap target wide so the
                  // user can tap the label, not just the tiny box.
                  InkWell(
                    key: const ValueKey('unpair-acknowledge-risk-row'),
                    onTap: () => toggleAck(!acknowledgedRisk),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.gapXs,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            key: const ValueKey(
                                'unpair-acknowledge-risk-checkbox'),
                            value: acknowledgedRisk,
                            onChanged: toggleAck,
                          ),
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: AppSpacing.gapMd,
                              ),
                              child: Text(
                                'Tôi hiểu việc ngắt kết nối sẽ dừng theo '
                                'dõi sức khỏe và cảnh báo SOS.',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                key: const ValueKey('unpair-confirm-button'),
                onPressed: acknowledgedRisk
                    ? () async {
                        Navigator.pop(ctx);
                        final success = await provider.unpairDevice();
                        if (!context.mounted) return;
                        if (success) {
                          // Return 'deleted' so Detail screen can route all the way back to list
                          Navigator.of(context).pop('deleted');
                        } else {
                          // Surface the real backend error instead of silently closing.
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                provider.errorMessage ??
                                    'Hủy ghép nối thiết bị thất bại',
                              ),
                              backgroundColor: AppColors.critical,
                            ),
                          );
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.critical,
                  disabledBackgroundColor:
                      AppColors.critical.withValues(alpha: 0.4),
                ),
                child: const Text(
                  'Ngắt kết nối',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceConfigureProvider>();

    return PopScope(
      canPop: !provider.isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showDiscardDialog(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          title: Text('Cấu hình thiết bị', style: AppTextStyles.sectionTitle),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sectionGapMd, vertical: AppSpacing.sectionGapMd),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ConfigureHeroHeader(device: widget.device),
            const SizedBox(height: AppSpacing.sectionGapXl),

            ConfigSectionCard(
              title: 'Cơ bản',
              children: [
                // QA M-13: same input constraints as the rename dialog —
                // hard length cap (matches backend max_length=100) and a
                // safe-character allow-list so users cannot type the
                // special characters QA flagged. Built-in counter from
                // `maxLength` shows live `xx/100` instead of letting users
                // discover the limit only after a 422.
                TextField(
                  controller: _nameController,
                  maxLength: kDeviceNameMaxLength,
                  inputFormatters: deviceNameInputFormatters(),
                  decoration: InputDecoration(
                    labelText: 'Tên thiết bị',
                    helperText:
                        'Tối đa $kDeviceNameMaxLength ký tự. Không dùng ký tự đặc biệt.',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.radiusMd)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sectionGapMd, vertical: AppSpacing.sectionGapMd),
                  ),
                  onChanged: provider.updateName,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGapXl),

            // Notification toggles match the backend `DeviceSettingsRequest`
            // schema 1:1 (notify_high_hr / notify_low_spo2 / notify_high_bp).
            // Two earlier controls — a battery-threshold slider and a sync
            // interval dropdown — were removed because saveChanges() never
            // forwarded them to any endpoint, so the UI was lying about
            // persistence.
            ConfigSectionCard(
              title: 'Cảnh báo sinh hiệu',
              children: [
                SwitchListTile(
                  title: Text('Cảnh báo nhịp tim cao', style: AppTextStyles.bodyMedium),
                  subtitle: Text(
                    'Gửi thông báo khi nhịp tim vượt ngưỡng an toàn.',
                    style: AppTextStyles.caption,
                  ),
                  value: provider.notifyHighHr,
                  onChanged: provider.updateNotifyHighHr,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.brandPrimary,
                ),
                const Divider(height: 1, color: AppColors.strokeSoft),
                SwitchListTile(
                  title: Text('Cảnh báo SpO₂ thấp', style: AppTextStyles.bodyMedium),
                  subtitle: Text(
                    'Gửi thông báo khi nồng độ oxy trong máu xuống thấp.',
                    style: AppTextStyles.caption,
                  ),
                  value: provider.notifyLowSpo2,
                  onChanged: provider.updateNotifyLowSpo2,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.brandPrimary,
                ),
                const Divider(height: 1, color: AppColors.strokeSoft),
                SwitchListTile(
                  title: Text('Cảnh báo huyết áp cao', style: AppTextStyles.bodyMedium),
                  subtitle: Text(
                    'Gửi thông báo khi huyết áp tâm thu vượt ngưỡng.',
                    style: AppTextStyles.caption,
                  ),
                  value: provider.notifyHighBp,
                  onChanged: provider.updateNotifyHighBp,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.brandPrimary,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGapXl),

            DangerZoneCard(
              isUnpairing: provider.isUnpairing,
              onUnpair: () => _showUnpairDialog(context, provider),
            ),
            const SizedBox(height: 48), // Padding equivalent to sticky footer if user scrolls to bottom
          ],
        ),
        bottomNavigationBar: DirtyFooterBar(
          isVisible: provider.isDirty,
          isSaving: provider.isSaving,
          onSave: () async {
            final success = await provider.saveChanges();
            if (!context.mounted) return;
            if (success) {
              // Bug 2 audit: invalidate the DeviceProvider list cache so a
              // subsequent navigation (pop to Detail → pop to List → re-
              // enter Configure for the same device) seeds the toggles
              // from the freshly persisted `calibration_data` instead of
              // the stale snapshot the list was holding. Fire-and-forget
              // because the success snackbar + pop should not wait on a
              // background list reload — Detail's own
              // `fetchDeviceDetail()` already refreshes what the user
              // sees next.
              unawaited(
                context
                    .read<DeviceProvider>()
                    .fetchDevices(forceRefresh: true),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Lưu thay đổi thành công'),
                  backgroundColor: AppColors.success,
                  duration: Duration(seconds: 2),
                ),
              );
              Navigator.of(context).pop(true);
              return;
            }
            // F-7 (M-7): surface failure feedback honestly. Before this the
            // screen swallowed the error and only the SnackBar from the
            // dialog (rename-from-list flow) ever told the user anything,
            // which meant a partial-success rename looked like a hard error
            // without explanation. Now we tint the snackbar based on
            // hasPartialSuccess so the user can tell apart "name persisted,
            // toggles need retry" from "nothing was saved".
            final message = provider.errorMessage;
            if (message == null) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: provider.hasPartialSuccess
                    ? AppColors.warning
                    : AppColors.critical,
                duration: const Duration(seconds: 4),
              ),
            );
          },
        ),
      ),
    );
  }
}
