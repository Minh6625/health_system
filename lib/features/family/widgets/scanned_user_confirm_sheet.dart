import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/widgets/remote_avatar.dart';
import 'package:healthguard/features/family/models/contact_tag.dart';

class ScannedUserConfirmSheet extends StatefulWidget {
  /// Callback trả về danh sách tags đã chọn + email
  final Function(List<ContactTag> tags, String email)? onConfirm;
  final VoidCallback onCancel;
  final bool fromPhoneSearch;
  final String? userName;
  final String? avatarUrl;
  final String? email;
  final String? phone;
  final bool isCancel;
  final bool isUnlink;
  final bool isAccept;
  final bool isReject;
  final String? statusMessage;
  final bool hideActions;
  final bool showTags;
  final String? cancelButtonText;
  final String? confirmButtonText;

  const ScannedUserConfirmSheet({
    super.key,
    required this.onConfirm,
    required this.onCancel,
    this.fromPhoneSearch = false,
    this.userName,
    this.avatarUrl,
    this.email,
    this.phone,
    this.isCancel = false,
    this.isUnlink = false,
    this.isAccept = false,
    this.isReject = false,
    this.statusMessage,
    this.hideActions = false,
    this.showTags = true,
    this.cancelButtonText,
    this.confirmButtonText,
  });

  @override
  State<ScannedUserConfirmSheet> createState() =>
      _ScannedUserConfirmSheetState();
}

class _ScannedUserConfirmSheetState extends State<ScannedUserConfirmSheet> {
  final List<String> _selectedTagIds = ['family'];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final effectiveShowTags =
        widget.showTags &&
        !widget.hideActions &&
        !widget.isCancel &&
        !widget.isUnlink &&
        !widget.isReject &&
        !widget.isAccept;

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: 32,
          ),
          decoration: const BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.strokeSoft,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              // User info
              RemoteAvatar(
                url: widget.avatarUrl,
                radius: 36,
                backgroundColor: AppColors.brandPrimaryLight,
                foregroundColor: AppColors.brandPrimary,
                fallbackText: widget.userName != null && widget.userName!.isNotEmpty
                    ? widget.userName![0].toUpperCase()
                    : 'A',
                fallbackTextStyle: const TextStyle(
                  fontSize: 28,
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.userName ?? 'Người dùng',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              if ((widget.email?.trim().isNotEmpty ?? false) ||
                  (widget.phone?.trim().isNotEmpty ?? false))
                Text(
                  widget.email?.trim().isNotEmpty == true
                      ? widget.email!
                      : widget.phone ?? '',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              if (widget.statusMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimaryLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFD5E3F5)),
                  ),
                  child: Text(
                    widget.statusMessage!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2F5F9C),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (effectiveShowTags) ...[
                // Tags – multi-select, từ ContactTagsConfig
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Gắn nhãn liên hệ (có thể chọn nhiều):',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ContactTagsConfig.defaultTags.map((tag) {
                    final isSelected = _selectedTagIds.contains(tag.id);
                    return FilterChip(
                      avatar: isSelected
                          ? Icon(Icons.check, size: 14, color: tag.color)
                          : null,
                      label: Text(tag.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            if (!_selectedTagIds.contains(tag.id)) {
                              _selectedTagIds.add(tag.id);
                            }
                          } else {
                            // Keep at least one tag selected.
                            if (_selectedTagIds.length > 1) {
                              _selectedTagIds.remove(tag.id);
                            }
                          }
                        });
                      },
                      selectedColor: tag.color.withValues(alpha: 0.12),
                      backgroundColor: AppColors.bgSurface,
                      checkmarkColor: tag.color,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: isSelected ? tag.color : AppColors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.radiusXl),
                        side: BorderSide(
                          color: isSelected ? tag.color : AppColors.strokeSoft,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Mặc định có tag "Gia đình". Bạn có thể thêm tag khác.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 28),
              ],
              if (!widget.hideActions)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : widget.onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.textSecondary),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.radiusMd),
                          ),
                        ),
                        child: Text(
                          widget.cancelButtonText ??
                              (widget.fromPhoneSearch ? 'Hủy' : 'Quét lại'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        key: const ValueKey('family-confirm-submit'),
                        onPressed: _isLoading
                            ? null
                            : () async {
                                setState(() {
                                  _isLoading = true;
                                });

                                final selectedTags = _selectedTagIds
                                    .map(ContactTagsConfig.findById)
                                    .whereType<ContactTag>()
                                    .toList();

                                await widget.onConfirm?.call(
                                  selectedTags,
                                  widget.email ?? widget.phone ?? '',
                                );

                                if (mounted) {
                                  setState(() {
                                    _isLoading = false;
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              (widget.isCancel ||
                                  widget.isUnlink ||
                                  widget.isReject)
                              ? Colors.red
                              : AppColors.brandPrimary,
                          foregroundColor: AppColors.bgSurface,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.radiusMd),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: AppColors.bgSurface,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                widget.confirmButtonText ??
                                    (widget.isUnlink
                                        ? 'Hủy kết nối'
                                        : widget.isCancel
                                        ? 'Hủy lời mời'
                                        : widget.isReject
                                        ? 'Từ chối'
                                        : widget.isAccept
                                        ? 'Xác nhận'
                                        : 'Gửi lời mời'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (_isLoading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.brandPrimary),
              ),
            ),
          ),
      ],
    );
  }
}
