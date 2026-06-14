import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/routes/app_router.dart';
import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';
import '../../../shared/presentation/theme/app_spacing.dart';
import '../../../shared/presentation/theme/app_text_styles.dart';
import '../models/vital_signs.dart';
import '../providers/vital_signs_provider.dart';
import '../widgets/animated_vital_value.dart';
import '../widgets/mini_line_chart.dart';
import '../widgets/vital_detail_skeleton.dart';
import '../widgets/empty_chart_placeholder.dart';
import '../widgets/error_view.dart';
import '../widgets/vital_education_card.dart';
import '../widgets/vital_safe_range.dart';
import '../widgets/vital_safe_range_bar.dart';

class VitalDetailScreen extends StatefulWidget {
  final String vitalType;
  final String? profileId;

  const VitalDetailScreen({
    super.key,
    required this.vitalType,
    this.profileId,
  });

  @override
  State<VitalDetailScreen> createState() => _VitalDetailScreenState();
}

class _VitalDetailScreenState extends State<VitalDetailScreen> {
  late final VitalSignsProvider _vitalsProvider;
  String _selectedRange = '1h';

  // 12 entries each — matches the 12 time-bucket points the backend returns.
  // Empty strings skip labeling that position so only 4 ticks are visible.
  static const Map<String, List<String>> _rangeLabels = {
    '1h': ['60p', '', '', '', '40p', '', '', '', '20p', '', '', 'Bây giờ'],
    '6h': ['6h',  '', '', '', '4h',  '', '', '', '2h',  '', '', 'Bây giờ'],
  };

  @override
  void initState() {
    super.initState();
    _vitalsProvider = VitalSignsProvider(
      vitalType: widget.vitalType,
      profileId: widget.profileId,
    )..startPolling();
  }

  @override
  void dispose() {
    _vitalsProvider.dispose();
    super.dispose();
  }

  Color _getStatusColor(VitalStatus status) => switch (status) {
        VitalStatus.normal => AppColors.success,
        VitalStatus.warning => AppColors.warning,
        VitalStatus.critical => AppColors.critical,
        VitalStatus.unknown => AppColors.textSecondary,
      };

  String _getStatusText(VitalStatus status) => switch (status) {
        VitalStatus.normal => 'Bình thường',
        VitalStatus.warning => 'Cảnh báo',
        VitalStatus.critical => 'Nguy hiểm',
        VitalStatus.unknown => 'Không rõ',
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vitalsProvider,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: _buildAppBar(_vitalsProvider),
          body: SafeArea(
            child: _buildBody(_vitalsProvider),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(VitalSignsProvider provider) {
    return AppBar(
      title: Column(
        children: [
          Text(
            provider.title.isNotEmpty ? provider.title : 'Chi tiết chỉ số',
            style: AppTextStyles.sectionTitle,
          ),
          if (provider.linkedProfileName.isNotEmpty)
            Text(
              provider.linkedProfileName,
              style: AppTextStyles.caption,
            ),
        ],
      ),
      backgroundColor: AppColors.bgSurface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
    );
  }

  Widget _buildBody(VitalSignsProvider provider) {
    switch (provider.state) {
      case VitalsUIState.initial:
      case VitalsUIState.loading:
        return const VitalDetailSkeleton();
      case VitalsUIState.error:
        return ErrorView(
          message: 'Không thể tải dữ liệu.\nVui lòng kiểm tra kết nối mạng.',
          onRetry: () {
            provider.refresh();
          },
        );
      case VitalsUIState.empty:
      case VitalsUIState.success:
        return _buildContent(provider);
    }
  }

  Widget _buildContent(VitalSignsProvider provider) {
    final statusColor = _getStatusColor(provider.vitalStatus);
    final isCritical = provider.vitalStatus == VitalStatus.critical;
    final isEmpty = provider.state == VitalsUIState.empty;

    final safeRange = vitalSafeRangeFor(widget.vitalType);
    final gaugeValue = safeRange != null
        ? extractGaugeValue(widget.vitalType, provider.value)
        : null;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Nổi bật hiện tại (Huge latest value)
                _buildVitalValueCard(provider, statusColor),

                if (safeRange != null) ...[
                  SizedBox(height: AppSpacing.sectionGapLg),
                  // 1b. Khoảng an toàn (5-zone gauge — W3.1)
                  VitalSafeRangeBar(
                    range: safeRange,
                    currentValue: gaugeValue,
                  ),
                ],

                SizedBox(height: AppSpacing.sectionGapXl),

                // 2. Biểu đồ chuyên biệt (Mini chart - 24h trend).
                // The previous header rendered a "Xem xu hướng" TextButton
                // whose onPressed body was just `// TODO: navigate to history`
                // — there is no per-vital history screen wired into AppRouter
                // today (only sleep-history and health-report exist). The
                // mini chart underneath already shows the 24h trend the
                // section title promises, so we drop the dead CTA instead of
                // hiding the lie behind a disabled state.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Biến động $_selectedRange qua',
                      style: AppTextStyles.sectionTitle.copyWith(
                        fontSize: 18,
                      ),
                    ),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: '1h', label: Text('1h')),
                        ButtonSegment(value: '6h', label: Text('6h')),
                      ],
                      selected: {_selectedRange},
                      onSelectionChanged: (selected) {
                        final range = selected.first;
                        setState(() => _selectedRange = range);
                        _vitalsProvider.loadTimeseries(
                          force: true,
                          range: range,
                        );
                      },
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.gapSm),

                if (isEmpty || provider.chartData.isEmpty)
                  const EmptyChartPlaceholder(message: 'Chưa có dữ liệu xu hướng')
                else
                  Container(
                    height: 180,
                    padding: AppSpacing.cardPadding,
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: AppRadii.cardRadius,
                      border: Border.all(color: AppColors.strokeSoft),
                    ),
                    child: MiniLineChart(
                      linesData: provider.chartData,
                      lineColors: provider.chartColors,
                      height: 140,
                      xLabels: _rangeLabels[_selectedRange] ??
                          _rangeLabels['1h']!,
                    ),
                  ),

                SizedBox(height: AppSpacing.sectionGapXl),

                // 3. Kiến thức y khoa (collapsible — W3.2)
                VitalEducationCard(text: provider.educationText),
              ],
            ),
          ),
        ),
        
        // 4. Cảnh báo hoặc SOS (Contextual actions)
        if (isCritical) 
          _buildCriticalAction(provider),
      ],
    );
  }

  Widget _buildVitalValueCard(VitalSignsProvider provider, Color statusColor) {
    final updatedAt = provider.vitals?.timestamp;
    // F-8 (M-9): when the backend marks the snapshot stale (no ingest in
    // 5+ minutes), the value is forced to "--" by the provider and we want
    // the user to see *why* — not just an unexplained dash. Without this
    // banner QA reported users mistaking a dead watch for a healthy one
    // because the previous reading was still painted on screen.
    //
    // Phase 2 (Health Connect): rephrase the sub-message based on
    // [DataFreshness] so a normal HC delay (5-15 min) reads as "đang
    // chờ đồng bộ" instead of the alarmist "mất kết nối", which would
    // otherwise fire every cycle just because Mi Fitness hasn't pushed
    // yet. Only the >15 min bucket keeps the disconnect copy.
    final freshness = provider.dataFreshness;
    final isStale = provider.isStale || freshness == DataFreshness.stale;
    final isDelayed = freshness == DataFreshness.delayed;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusXxl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: AppRadii.pillRadius,
            ),
            child: Text(
              _getStatusText(provider.vitalStatus),
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
          SizedBox(height: AppSpacing.sectionGapXl),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                AnimatedVitalValue(
                  value: provider.value,
                  fontSize: 84, // 84sp for elderly view
                  color: statusColor,
                ),
                SizedBox(width: AppSpacing.gapSm),
                Text(
                  provider.unit,
                  style: AppTextStyles.displayCompact.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (updatedAt != null) ...[
            SizedBox(height: AppSpacing.gapLg),
            Text(
              isStale
                  // F-8 (M-9): rephrase the timestamp when stale so it reads
                  // "last update was at HH:mm:ss" instead of pretending the
                  // device just refreshed.
                  ? 'Cập nhật cuối lúc ${DateFormat('HH:mm:ss').format(updatedAt.toLocal())}'
                  : 'Cập nhật lúc ${DateFormat('HH:mm:ss').format(updatedAt.toLocal())}',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: isStale ? AppColors.warning : null,
              ),
            ),
          ],
          if (isStale) ...[
            SizedBox(height: AppSpacing.gapSm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.signal_wifi_off_rounded,
                  size: 16,
                  color: AppColors.warning,
                ),
                SizedBox(width: AppSpacing.gapXs),
                Text(
                  'Đã hơn 15 phút chưa cập nhật',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ] else if (isDelayed) ...[
            SizedBox(height: AppSpacing.gapSm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.sync_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: AppSpacing.gapXs),
                Text(
                  'Đang chờ đồng bộ từ đồng hồ',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCriticalAction(VitalSignsProvider provider) {
    if (provider.isSelf) {
      // Self + Critical -> SOS Button
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          boxShadow: [
            BoxShadow(
              color: AppColors.critical.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Semantics(
          button: true,
          label: 'Gọi bác sĩ hoặc người thân ngay lập tức',
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, AppRouter.manualSos);
            },
            icon: const Icon(Icons.emergency, size: 28),
            label: Text(
              'GỌI CẤP CỨU',
              style: AppTextStyles.sectionTitle.copyWith(
                color: AppColors.bgSurface,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.critical,
              foregroundColor: AppColors.bgSurface,
              minimumSize: const Size(double.infinity, 64),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadii.cardRadius,
              ),
              elevation: 4,
            ),
          ),
        ),
      );
    } else {
      // Linked + Critical -> Warning Banner, No SOS per UC007 / Requirement
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        color: AppStateColors.criticalBg,
        child: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.critical, size: 28),
            SizedBox(width: AppSpacing.gapMd),
            Expanded(
              child: Text(
                'Chỉ số nguy hiểm! Vui lòng liên hệ ${provider.linkedProfileName.isNotEmpty ? provider.linkedProfileName : 'người thân'} ngay.',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.critical,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}
