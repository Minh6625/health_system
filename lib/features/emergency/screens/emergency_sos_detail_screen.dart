import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:healthguard/features/emergency/models/sos_event_model.dart';
import 'package:healthguard/features/emergency/providers/emergency_caregiver_provider.dart';
import 'package:healthguard/features/emergency/widgets/sos_detail/emergency_sos_actions_block.dart';
import 'package:healthguard/features/emergency/widgets/sos_detail/emergency_sos_info_cards.dart';
import 'package:healthguard/features/emergency/widgets/sos_detail/emergency_sos_map_block.dart';
import 'package:healthguard/features/emergency/widgets/sos_detail/emergency_sos_patient_header.dart';
import 'package:healthguard/features/emergency/widgets/sos_detail/emergency_sos_timeline_block.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';
import 'package:provider/provider.dart';

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
  late Animation<double> _arrowAnimation;

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

  @override
  void dispose() {
    _scrollController.dispose();
    _shadowOpacity.dispose();
    _arrowAnimationController.dispose();
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
            // Patient header (avatar + name + trigger chip + warning shake).
            Selector<EmergencyCaregiverProvider, SOSEventModel?>(
              selector: (context, provider) => provider.sosDetail,
              builder: (context, sos, child) {
                if (sos == null) return const SizedBox.shrink();
                return EmergencySOSPatientHeader(sos: sos);
              },
            ),

            // Map block (OSM with marker, fallback when GPS missing).
            // Selector key is the lat/lng string so this only rebuilds when
            // the GPS pin actually moves; otherwise the map keeps its
            // current camera state during silent polling refreshes.
            Selector<EmergencyCaregiverProvider, String>(
              selector: (context, provider) =>
                  '${provider.sosDetail?.location.latitude},${provider.sosDetail?.location.longitude}',
              builder: (context, _, _) {
                final sos =
                    context.read<EmergencyCaregiverProvider>().sosDetail!;
                return EmergencySOSMapBlock(sos: sos, height: mapHeight);
              },
            ),

            // Details Section (scrollable cards + bottom-shadow + arrow hint).
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
                            EmergencySOSLocationInfoCard(sos: sos),
                            const SizedBox(height: AppSpacing.gapLg),
                            EmergencySOSTimeInfoCard(sos: sos),
                            if (sos.fallDetectionXAI != null) ...[
                              const SizedBox(height: AppSpacing.gapLg),
                              EmergencySOSTimelineBlock(
                                xai: sos.fallDetectionXAI!,
                              ),
                            ],
                            if (sos.resolution != null) ...[
                              const SizedBox(height: AppSpacing.gapLg),
                              EmergencySOSResolutionInfoCard(
                                resolution: sos.resolution!,
                              ),
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

            // Sticky action bar (Goi dien / Chi duong / Xac nhan).
            Selector<EmergencyCaregiverProvider, SOSEventModel?>(
              selector: (context, provider) => provider.sosDetail,
              builder: (context, sos, child) {
                if (sos == null) return const SizedBox.shrink();
                final provider = context.read<EmergencyCaregiverProvider>();
                return EmergencySOSActionsBlock(
                  sos: sos,
                  isResolving: _isResolving,
                  onCall: () => provider.makePhoneCall(sos.patient.phone),
                  onNavigate: (sos.location.latitude == null ||
                          sos.location.longitude == null)
                      ? null
                      : () => provider.openMapNavigation(
                            sos.location.latitude!,
                            sos.location.longitude!,
                          ),
                  onConfirmResolve: () => _confirmSafety(provider, sos.id),
                );
              },
            ),
          ],
        );
      },
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
