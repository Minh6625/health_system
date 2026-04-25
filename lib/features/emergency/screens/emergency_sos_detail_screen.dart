import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:healthguard/features/emergency/models/sos_event_model.dart';
import 'package:healthguard/features/emergency/providers/emergency_caregiver_provider.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// SOS Detail screen for Caregiver
class EmergencySOSDetailScreen extends StatefulWidget {
  final String sosId;
  final bool enableAutoRefresh;
  final Duration detailPollInterval;

  const EmergencySOSDetailScreen({
    super.key,
    required this.sosId,
    this.enableAutoRefresh = true,
    this.detailPollInterval = const Duration(seconds: 30),
  });

  @override
  State<EmergencySOSDetailScreen> createState() =>
      _EmergencySOSDetailScreenState();
}

class _EmergencySOSDetailScreenState extends State<EmergencySOSDetailScreen>
    with TickerProviderStateMixin {
  late EmergencyCaregiverProvider _provider;
  bool _isInitialized = false;
  bool _isResolving = false;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _shadowOpacity = ValueNotifier<double>(1.0);
  late AnimationController _arrowAnimationController;
  late AnimationController _warningAnimationController;
  late Animation<double> _arrowAnimation;
  bool _isWarningAnimating = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    _arrowAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _arrowAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(
        parent: _arrowAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      for (int i = 0; i < 3; i++) {
        if (!mounted) break;
        await _arrowAnimationController.forward();
        if (!mounted) break;
        await _arrowAnimationController.reverse();
      }
    });

    _warningAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _provider = context.read<EmergencyCaregiverProvider>();
      Future.microtask(() {
        if (!mounted) {
          return;
        }
        _provider.fetchSOSDetail(widget.sosId);
        _provider.subscribeToSOSUpdates(
          widget.sosId,
          enabled: widget.enableAutoRefresh,
          interval: widget.detailPollInterval,
        );
      });
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      final scrollProgress =
          maxScroll > 0 ? (currentScroll / maxScroll).clamp(0.0, 1.0) : 0.0;
      final newOpacity = (1.0 - scrollProgress).clamp(0.0, 1.0);
      if ((newOpacity - _shadowOpacity.value).abs() > 0.01) {
        _shadowOpacity.value = newOpacity;
      }
    }
  }

  void _syncWarningAnimation(bool shouldAnimate) {
    if (shouldAnimate && !_isWarningAnimating) {
      _warningAnimationController.repeat();
      _isWarningAnimating = true;
      return;
    }
    if (!shouldAnimate && _isWarningAnimating) {
      _warningAnimationController.stop();
      _warningAnimationController.value = 0;
      _isWarningAnimating = false;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _shadowOpacity.dispose();
    _arrowAnimationController.dispose();
    _warningAnimationController.dispose();
    _provider.unsubscribeFromSOSUpdates();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('emergency-sos-detail-screen'),
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Chi tiết SOS'), elevation: 0),
      body: Builder(
        builder: (context) {
          final isLoading = context.select<EmergencyCaregiverProvider, bool>(
            (p) => p.isLoadingDetail,
          );
          final error = context.select<EmergencyCaregiverProvider, String?>(
            (p) => p.detailErrorMessage,
          );
          final hasDetail = context.select<EmergencyCaregiverProvider, bool>(
            (p) => p.sosDetail != null,
          );

          final showLoadingOverlay = isLoading || _isResolving;

          Widget content;
          if (hasDetail) {
            content = _buildDetailContent(context);
          } else if (error != null) {
            content = _buildErrorState(error);
          } else {
            content = const SizedBox.expand();
          }

          return Stack(
            children: [
              Positioned.fill(child: content),
              if (showLoadingOverlay) _buildUnifiedLoadingOverlay(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUnifiedLoadingOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.2),
        child: const Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailContent(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapHeight = math.max(
          160.0,
          math.min(220.0, constraints.maxHeight * 0.3),
        );
        return Column(
          children: [
        // Patient Header
        Selector<EmergencyCaregiverProvider, SOSEventModel?>(
          selector: (context, provider) => provider.sosDetail,
          builder: (context, sos, child) {
            if (sos == null) return const SizedBox.shrink();
            _syncWarningAnimation(sos.isActive);
            return Stack(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(AppSpacing.gapLg),
                  padding: const EdgeInsets.all(AppSpacing.gapLg),
                  decoration: BoxDecoration(
                    color: sos.isActive
                        ? AppColors.critical.withValues(alpha: 0.15)
                        : AppColors.bgSurface,
                    borderRadius:
                        BorderRadius.circular(AppRadii.radiusMd),
                    boxShadow: [
                      BoxShadow(
                        color: sos.isActive
                            ? AppColors.critical.withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundImage: sos.patient.photoUrl != null
                                ? CachedNetworkImageProvider(
                                    sos.patient.photoUrl!,
                                  )
                                : null,
                            backgroundColor: AppColors.strokeSoft,
                            child: sos.patient.photoUrl == null
                                ? const Icon(
                                    Icons.person,
                                    size: 32,
                                    color: AppColors.bgSurface,
                                  )
                                : null,
                          ),
                          const SizedBox(width: AppSpacing.gapMd),
                          Expanded(
                            child: Text(
                              sos.patient.name,
                              style: AppTextStyles.sectionTitle.copyWith(
                                color: sos.isActive
                                    ? AppColors.textPrimary
                                    : AppColors.textPrimary,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.gapMd),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.gapMd,
                          vertical: AppSpacing.gapSm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface.withValues(alpha: 0.7),
                          borderRadius:
                              BorderRadius.circular(AppRadii.radiusSm),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getTriggerIcon(sos.triggerType),
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.gapSm),
                            Text(
                              _getTriggerLabel(sos.triggerType),
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (sos.isActive)
                  Positioned(
                    top: 28,
                    right: 28,
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _warningAnimationController,
                        builder: (context, child) {
                          final wave = math.sin(
                            _warningAnimationController.value *
                                math.pi *
                                2 *
                                4,
                          );
                          return Transform.translate(
                            offset: Offset(wave * 4, 0),
                            child: Transform.rotate(
                              angle: wave * 0.10,
                              child: child,
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.critical,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        // Map Placeholder
        Selector<EmergencyCaregiverProvider, String>(
          selector: (context, provider) =>
              '${provider.sosDetail?.location.latitude},${provider.sosDetail?.location.longitude}',
          builder: (context, locStr, child) {
            final sos = context.read<EmergencyCaregiverProvider>().sosDetail!;
            return Container(
              height: mapHeight,
              margin:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.gapLg),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(AppRadii.radiusMd),
                boxShadow: AppShadows.softShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.radiusMd),
                child: Container(
                  color: AppColors.strokeSoft,
                  child: (sos.location.latitude != null &&
                          sos.location.longitude != null)
                      ? FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(
                              sos.location.latitude!,
                              sos.location.longitude!,
                            ),
                            initialZoom: 15.0,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName:
                                  'com.example.healthguard',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(
                                    sos.location.latitude!,
                                    sos.location.longitude!,
                                  ),
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: AppColors.critical,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map,
                              size: 64,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: AppSpacing.gapSm),
                            Text(
                              'Map view',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              'Vị trí không xác định',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        ),

        // Details Section
        Expanded(
          child: Stack(
            children: [
              Selector<EmergencyCaregiverProvider, SOSEventModel?>(
                selector: (context, provider) => provider.sosDetail,
                builder: (context, sos, child) {
                  if (sos == null) return const SizedBox.shrink();
                  return SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.gapLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLocationInfo(sos),
                        const SizedBox(height: AppSpacing.gapLg),
                        _buildTimeInfo(sos),
                        if (sos.fallDetectionXAI != null) ...[
                          const SizedBox(height: AppSpacing.gapLg),
                          _buildXAITimeline(sos.fallDetectionXAI!),
                        ],
                        if (sos.resolution != null) ...[
                          const SizedBox(height: AppSpacing.gapLg),
                          _buildResolutionInfo(sos.resolution!),
                        ],
                        const SizedBox(height: AppSpacing.gapLg),
                      ],
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _shadowOpacity,
                    builder: (context, opacity, child) {
                      return AnimatedOpacity(
                        opacity: opacity,
                        duration: const Duration(milliseconds: 150),
                        child: RepaintBoundary(
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.15),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _shadowOpacity,
                    builder: (context, opacity, child) {
                      return AnimatedOpacity(
                        opacity: opacity,
                        duration: const Duration(milliseconds: 150),
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _arrowAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _arrowAnimation.value),
                                child: child,
                              );
                            },
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              size: 32,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // Action Buttons
        Selector<EmergencyCaregiverProvider, SOSEventModel?>(
          selector: (context, provider) => provider.sosDetail,
          builder: (context, sos, child) {
            if (sos == null) return const SizedBox.shrink();
            final provider = context.read<EmergencyCaregiverProvider>();
            return _buildActionButtons(provider, sos);
          },
        ),
          ],
        );
      },
    );
  }

  Widget _buildLocationInfo(dynamic sos) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gapLg),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        boxShadow: AppShadows.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, size: 20, color: AppColors.info),
              const SizedBox(width: AppSpacing.gapSm),
              Text(
                'Vị trí',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapMd),
          if (sos.location?.latitude != null &&
              sos.location?.longitude != null)
            Text(
              'GPS: ${sos.location!.latitude!.toStringAsFixed(6)}, '
              '${sos.location!.longitude!.toStringAsFixed(6)}',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            Text(
              'GPS: Không có dữ liệu',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: AppSpacing.gapXs),
          if (sos.location?.accuracy != null)
            Text(
              'Độ chính xác: ${sos.location!.accuracy!.toStringAsFixed(1)} mét',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: AppSpacing.gapXs),
          if (sos.location?.lastUpdated != null)
            Text(
              'Cập nhật: ${DateFormat('HH:mm:ss - dd/MM/yyyy').format(sos.location!.lastUpdated!)}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(dynamic sos) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gapLg),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        boxShadow: AppShadows.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, size: 20, color: AppColors.info),
              const SizedBox(width: AppSpacing.gapSm),
              Text(
                'Thời gian',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapMd),
          Text(
            'Kích hoạt: ${DateFormat('HH:mm:ss - dd/MM/yyyy').format(sos.triggerTime)}',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.gapXs),
          Text(
            'Đã trôi qua: ${_formatElapsedTime(sos.elapsedTime)}',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildTriggerInfo(dynamic sos) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gapLg),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        boxShadow: AppShadows.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: AppColors.info),
              const SizedBox(width: AppSpacing.gapSm),
              Text(
                'Nguyên nhân',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapMd),
          Row(
            children: [
              Icon(
                _getTriggerIcon(sos.triggerType),
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.gapSm),
              Text(
                _getTriggerLabel(sos.triggerType),
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getTriggerIcon(String triggerType) {
    switch (triggerType) {
      case 'fall_detected':
        return Icons.arrow_downward;
      case 'manual':
        return Icons.touch_app;
      case 'vital_critical':
        return Icons.error;
      default:
        return Icons.emergency;
    }
  }

  String _getTriggerLabel(String triggerType) {
    switch (triggerType) {
      case 'fall_detected':
        return 'Phát hiện té ngã';
      case 'manual':
        return 'Kích hoạt thủ công';
      case 'vital_critical':
        return 'Chỉ số sinh tồn tới hạn';
      default:
        return 'SOS khẩn cấp';
    }
  }

  Widget _buildXAITimeline(dynamic xai) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gapLg),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        border: Border.all(color: AppColors.warning, width: 2),
        boxShadow: AppShadows.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, size: 20, color: AppColors.warning),
              const SizedBox(width: AppSpacing.gapSm),
              Text(
                'Chi tiết phát hiện té ngã',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapMd),
          Text(
            // Backend stores confidence as 0.0-1.0; multiply for human display.
            'Độ tin cậy: ${(xai.confidence * 100).toStringAsFixed(0)}%',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (xai.triggerReason != null &&
              (xai.triggerReason as String).trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.gapXs),
            Text(
              xai.triggerReason as String,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.gapMd),
          Text(
            'Timeline:',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.gapSm),
          ...xai.timeline.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.gapXs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${event.time} - ${event.description}',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionInfo(dynamic resolution) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gapLg),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        border: Border.all(color: AppColors.success, width: 2),
        boxShadow: AppShadows.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, size: 20, color: AppColors.success),
              const SizedBox(width: AppSpacing.gapSm),
              Text(
                'Thông tin xử lý',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapMd),
          Text(
            'Đã xử lý bởi: ${resolution.resolvedBy}',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.gapXs),
          Text(
            'Thời gian: ${DateFormat('HH:mm:ss - dd/MM/yyyy').format(resolution.resolvedTime)}',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.gapXs),
          Text(
            'Trạng thái xử lý: ${resolution.resolutionStatus}',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (resolution.notes != null) ...[
            const SizedBox(height: AppSpacing.gapSm),
            Text(
              'Ghi chú: ${resolution.notes}',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(EmergencyCaregiverProvider provider, dynamic sos) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gapLg),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.success,
                        AppColors.success.withValues(alpha: 0.85),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.circular(AppRadii.radiusSm),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => provider.makePhoneCall(sos.patient.phone),
                    icon: const Icon(Icons.phone),
                    label: const Text('Gọi điện'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppColors.bgSurface,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size(0, 56),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.gapLg),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.brandPrimary,
                        AppColors.brandPrimary.withValues(alpha: 0.85),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.circular(AppRadii.radiusSm),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: (sos.location?.latitude == null ||
                            sos.location?.longitude == null)
                        ? null
                        : () => provider.openMapNavigation(
                              sos.location!.latitude,
                              sos.location!.longitude,
                            ),
                    icon: const Icon(Icons.map),
                    label: const Text('Chỉ đường'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppColors.bgSurface,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size(0, 56),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (sos.isActive) ...[
            const SizedBox(height: AppSpacing.gapMd),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('emergency-sos-detail-resolve-button'),
                onPressed: _isResolving
                    ? null
                    : () => _confirmSafety(provider, sos.id),
                icon: _isResolving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(_isResolving ? 'Đang xác nhận...' : 'Xác nhận'),
                style:
                    OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      key: const ValueKey('emergency-sos-detail-error'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.critical),
          const SizedBox(height: AppSpacing.gapLg),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              style: AppTextStyles.body.copyWith(color: AppColors.critical),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.gapLg),
          ElevatedButton.icon(
            key: const ValueKey('emergency-sos-detail-retry'),
            onPressed: () {
              context
                  .read<EmergencyCaregiverProvider>()
                  .fetchSOSDetail(widget.sosId);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  String _formatElapsedTime(Duration duration) {
    if (duration.inMinutes < 1) {
      return 'Vừa xong';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes} phút';
    } else if (duration.inHours < 24) {
      return '${duration.inHours} giờ';
    } else {
      return '${duration.inDays} ngày';
    }
  }

  Future<void> _confirmSafety(
    EmergencyCaregiverProvider provider,
    String sosId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('emergency-sos-detail-resolve-dialog'),
        title: const Text('Xác nhận xử lý'),
        content: const Text(
          'Bạn có chắc chắn muốn xác nhận đã xử lý sự kiện này?',
        ),
        actions: [
          TextButton(
            key: const ValueKey('emergency-sos-detail-resolve-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            key: const ValueKey('emergency-sos-detail-resolve-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isResolving = true;
      });

      final success = await provider.resolveSOSByCaregiver(
        sosId: sosId,
        resolutionStatus: 'safe',
        notes: 'Người chăm sóc xác nhận đã xử lý',
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xác nhận xử lý')),
        );
      }

      if (mounted) {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }
}
