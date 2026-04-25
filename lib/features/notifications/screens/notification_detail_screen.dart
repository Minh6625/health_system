import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';
import '../utils/notification_severity.dart';
import '../utils/notification_vital_insight.dart';
import '../widgets/notification_detail_section.dart';
import '../widgets/notification_info_chip.dart';
import '../widgets/notification_vital_insight_card.dart';

/// Detail screen pushed when the user taps a notification card. Re-fetches
/// the full notification body via API; reports back to the list so unread
/// badges stay in sync.
///
/// `internal` visibility — only opened from `NotificationsScreen`.
class NotificationDetailScreen extends StatefulWidget {
  const NotificationDetailScreen({
    super.key,
    required this.initialItem,
    required this.apiClient,
    required this.onDetailLoaded,
  });

  final Map<String, dynamic> initialItem;
  final ApiClient apiClient;
  final ValueChanged<Map<String, dynamic>> onDetailLoaded;

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  Map<String, dynamic>? _item;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  DateTime? _parseDateTimeValue(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toLocal();
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  Future<void> _loadDetail() async {
    final id = widget.initialItem['id'];
    if (id == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Thiếu mã thông báo để tải chi tiết';
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final result = await widget.apiClient.get('/notifications/$id');
      final detail = result is Map<String, dynamic>
          ? result
          : Map<String, dynamic>.from(result as Map);
      if (!mounted) return;

      widget.onDetailLoaded(Map<String, dynamic>.from(detail));
      setState(() {
        _item = detail;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 28,
              color: AppColors.critical,
            ),
            const SizedBox(height: 10),
            const Text(
              'Không thể tải chi tiết thông báo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Đã xảy ra lỗi không xác định',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: _loadDetail, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }

  Widget _skeletonBlock({double? width, double height = 12}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.strokeSoft,
        borderRadius: BorderRadius.circular(AppRadii.radiusSm),
      ),
    );
  }

  Widget _buildInitialSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(AppRadii.radiusMd),
              border: Border.all(color: AppColors.strokeSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonBlock(width: 210, height: 18),
                const SizedBox(height: 12),
                _skeletonBlock(width: double.infinity, height: 12),
                const SizedBox(height: 8),
                _skeletonBlock(width: 240, height: 12),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _skeletonBlock(width: 78, height: 24),
                    const SizedBox(width: 8),
                    _skeletonBlock(width: 92, height: 24),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(AppRadii.radiusMd),
              border: Border.all(color: AppColors.strokeSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonBlock(width: 150, height: 16),
                const SizedBox(height: 12),
                _skeletonBlock(width: double.infinity, height: 12),
                const SizedBox(height: 8),
                _skeletonBlock(width: double.infinity, height: 12),
                const SizedBox(height: 8),
                _skeletonBlock(width: 190, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;

    if (item == null) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(title: const Text('Chi tiết thông báo')),
        body: _isLoading ? _buildInitialSkeleton() : _buildLoadError(),
      );
    }

    final type = (item['alert_type'] as String?) ?? 'general';
    final severity = (item['severity'] as String?) ?? 'normal';
    final title = (item['title'] as String?) ?? 'Thông báo';
    final message = (item['message'] as String?) ?? '';
    final notificationId = item['id']?.toString() ?? '--';
    final alertTypeLabel = notificationAlertTypeLabel(type);
    final severityLabel = notificationSeverityLabel(severity);
    final severityColor = notificationSeverityColor(severity);
    final createdAt = notificationCreatedAt(item);
    final createdAtText = createdAt != null
        ? notificationDateTimeLabel(createdAt)
        : '--';
    final createdAgoText = createdAt != null
        ? notificationTimeAgoLabel(createdAt)
        : '--';
    final readStatusText = item['is_read'] == true ? 'Đã đọc' : 'Chưa đọc';
    final readAt = _parseDateTimeValue(item['read_at']);
    final readAtText = readAt != null
        ? notificationDateTimeLabel(readAt)
        : null;
    final relatedFields = buildNotificationRelatedFields(item);
    final vitalInsight = buildNotificationVitalInsight(item);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Chi tiết thông báo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 10),
            ],
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppStateColors.criticalBg,
                  borderRadius: BorderRadius.circular(AppRadii.radiusSm),
                  border: Border.all(color: const Color(0xFFF0C7C7)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.wifi_tethering_error_rounded,
                      size: 18,
                      color: AppColors.critical,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.critical,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadDetail,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(AppRadii.radiusMd),
                border: Border.all(color: AppColors.strokeSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: severityColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message.isEmpty ? 'Không có nội dung mô tả.' : message,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      NotificationInfoChip(
                        label: alertTypeLabel,
                        color: AppStateColors.infoBg,
                      ),
                      NotificationInfoChip(
                        label: severityLabel,
                        color: severityColor.withValues(alpha: 0.14),
                      ),
                      NotificationInfoChip(
                        label: readStatusText,
                        color: readStatusText == 'Đã đọc'
                            ? AppStateColors.successBg
                            : AppStateColors.warningBg,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (vitalInsight != null) ...[
              NotificationDetailSection(
                title: 'Diễn biến chỉ số',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NotificationVitalInsightCard(insight: vitalInsight),
                    if ((vitalInsight.trendText ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgPrimary,
                          borderRadius: BorderRadius.circular(
                            AppRadii.radiusSm,
                          ),
                          border: Border.all(color: AppColors.strokeSoft),
                        ),
                        child: Text(
                          vitalInsight.trendText!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (relatedFields.isNotEmpty) ...[
              NotificationDetailSection(
                title: 'Chỉ số và thông tin liên quan',
                child: Column(
                  children: relatedFields
                      .map(
                        (e) => NotificationDetailRow(
                          label: e.key,
                          value: e.value,
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            NotificationDetailSection(
              title: 'Thông tin chi tiết',
              child: Column(
                children: [
                  NotificationDetailRow(
                    label: 'Mã thông báo',
                    value: notificationId,
                  ),
                  NotificationDetailRow(label: 'Loại', value: alertTypeLabel),
                  NotificationDetailRow(label: 'Mức độ', value: severityLabel),
                  NotificationDetailRow(
                    label: 'Trạng thái',
                    value: readStatusText,
                  ),
                  NotificationDetailRow(
                    label: 'Thời gian tạo',
                    value: createdAtText,
                  ),
                  NotificationDetailRow(
                    label: 'Khoảng thời gian',
                    value: createdAgoText,
                  ),
                  if (readAtText != null)
                    NotificationDetailRow(
                      label: 'Đọc lúc',
                      value: readAtText,
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
