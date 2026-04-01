import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:healthguard/features/emergency/models/sos_event_model.dart';
import 'package:healthguard/features/emergency/providers/emergency_caregiver_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// SOS Detail screen for Caregiver
class EmergencySOSDetailScreen extends StatefulWidget {
  final String sosId;

  const EmergencySOSDetailScreen({super.key, required this.sosId});

  @override
  State<EmergencySOSDetailScreen> createState() =>
      _EmergencySOSDetailScreenState();
}

class _EmergencySOSDetailScreenState extends State<EmergencySOSDetailScreen>
    with TickerProviderStateMixin {
  late EmergencyCaregiverProvider _provider;
  bool _isInitialized = false;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _shadowOpacity = ValueNotifier<double>(1.0);
  late AnimationController _arrowAnimationController;
  late AnimationController _warningAnimationController;
  late Animation<double> _arrowAnimation;
  bool _isWarningAnimating = false;

  @override
  void initState() {
    super.initState();
    // Add listener in initState
    _scrollController.addListener(_onScroll);

    // Setup arrow animation
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

    // Bounce arrow 3 times then stop to save battery
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      for (int i = 0; i < 3; i++) {
        if (!mounted) break;
        await _arrowAnimationController.forward();
        if (!mounted) break;
        await _arrowAnimationController.reverse();
      }
    });

    // Setup warning icon shake animation (translate + rotate)
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
      _provider.fetchSOSDetail(widget.sosId);
      _provider.subscribeToSOSUpdates(widget.sosId);
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;

      // Calculate how close to bottom (0 = at top, 1 = at bottom)
      final scrollProgress = maxScroll > 0
          ? (currentScroll / maxScroll).clamp(0.0, 1.0)
          : 0.0;

      // Fade out shadow as we scroll down (inverse of progress)
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
      backgroundColor: const Color(0xFFEBEBEB),
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

          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (error != null) return _buildErrorState(error);
          if (hasDetail) return _buildDetailContent(context);

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildDetailContent(BuildContext context) {
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
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: sos.isActive
                        ? const Color(0xFFFFABAF)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: sos.isActive
                            ? const Color(0xFFE53935).withValues(alpha: 0.25)
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
                            backgroundColor: Colors.grey[400],
                            child: sos.patient.photoUrl == null
                                ? const Icon(
                                    Icons.person,
                                    size: 32,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              sos.patient.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: sos.isActive
                                    ? const Color(0xFF1A1A1A)
                                    : Colors.black87,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48), // Space for warning icon
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getTriggerIcon(sos.triggerType),
                              size: 18,
                              color: Colors.grey[800],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getTriggerLabel(sos.triggerType),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Animated warning icon for active SOS
                if (sos.isActive)
                  Positioned(
                    top:
                        28, // Thay đổi số này để điều chỉnh khoảng cách từ trên xuống
                    right:
                        28, // Thay đổi số này để điều chỉnh khoảng cách từ phải sang trái
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _warningAnimationController,
                        builder: (context, child) {
                          final wave = math.sin(
                            _warningAnimationController.value * math.pi * 2 * 4,
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
                          color: Color(0xFFE53935),
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
              height: 220,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.grey[300],
                  child:
                      (sos.location.latitude != null &&
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
                              userAgentPackageName: 'com.example.healthguard',
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
                                    color: Colors.red,
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
                            Icon(Icons.map, size: 64, color: Colors.grey[600]),
                            const SizedBox(height: 8),
                            Text(
                              'Map view',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              'Vị trí không xác định',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
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
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLocationInfo(sos),
                        const SizedBox(height: 16),
                        _buildTimeInfo(sos),
                        if (sos.fallDetectionXAI != null) ...[
                          const SizedBox(height: 16),
                          _buildXAITimeline(sos.fallDetectionXAI!),
                        ],
                        if (sos.resolution != null) ...[
                          const SizedBox(height: 16),
                          _buildResolutionInfo(sos.resolution!),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                },
              ),
              // Gradient shadow at bottom to indicate more content below
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
              // Animated arrow icon
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
                              color: Colors.grey[700],
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
  }

  Widget _buildLocationInfo(dynamic sos) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, size: 20, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Text(
                'Vị trí',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sos.location?.latitude != null && sos.location?.longitude != null)
            Text(
              'GPS: ${sos.location!.latitude!.toStringAsFixed(6)}, '
              '${sos.location!.longitude!.toStringAsFixed(6)}',
              style: TextStyle(color: Colors.grey[700]),
            )
          else
            Text(
              'GPS: Không có dữ liệu',
              style: TextStyle(color: Colors.grey[700]),
            ),
          const SizedBox(height: 4),
          if (sos.location?.accuracy != null)
            Text(
              'Độ chính xác: ${sos.location!.accuracy!.toStringAsFixed(1)} mét',
              style: TextStyle(color: Colors.grey[700]),
            ),
          const SizedBox(height: 4),
          if (sos.location?.lastUpdated != null)
            Text(
              'Cập nhật: ${DateFormat('HH:mm:ss - dd/MM/yyyy').format(sos.location!.lastUpdated!)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(dynamic sos) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, size: 20, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Text(
                'Thời gian',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Kích hoạt: ${DateFormat('HH:mm:ss - dd/MM/yyyy').format(sos.triggerTime)}',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Text(
            'Đã trôi qua: ${_formatElapsedTime(sos.elapsedTime)}',
            style: TextStyle(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildTriggerInfo(dynamic sos) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Text(
                'Nguyên nhân',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                _getTriggerIcon(sos.triggerType),
                size: 20,
                color: Colors.grey[700],
              ),
              const SizedBox(width: 8),
              Text(
                _getTriggerLabel(sos.triggerType),
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[300]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, size: 20, color: Colors.amber[700]),
              const SizedBox(width: 8),
              const Text(
                'Chi tiết phát hiện té ngã',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Độ tin cậy: ${xai.confidence.toStringAsFixed(1)}%',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 12),
          Text(
            'Timeline:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          ...xai.timeline.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  Expanded(
                    child: Text(
                      '${event.time} - ${event.description}',
                      style: TextStyle(color: Colors.grey[700]),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[300]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, size: 20, color: Colors.green[700]),
              const SizedBox(width: 8),
              const Text(
                'Thông tin xử lý',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Đã xử lý bởi: ${resolution.resolvedBy}',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Text(
            'Thời gian: ${DateFormat('HH:mm:ss - dd/MM/yyyy').format(resolution.resolvedTime)}',
            style: TextStyle(color: Colors.grey[700]),
          ),
          if (resolution.notes != null) ...[
            const SizedBox(height: 8),
            Text(
              'Ghi chú: ${resolution.notes}',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(EmergencyCaregiverProvider provider, dynamic sos) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => provider.makePhoneCall(sos.patient.phone),
                    icon: const Icon(Icons.phone),
                    label: const Text('Gọi điện'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size(0, 56),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ElevatedButton.icon(
                    onPressed:
                        (sos.location?.latitude == null ||
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
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size(0, 56),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (sos.isActive) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmSafety(provider, sos.id),
                icon: const Icon(Icons.check_circle),
                label: const Text('Xác nhận'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              style: const TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              context.read<EmergencyCaregiverProvider>().fetchSOSDetail(
                widget.sosId,
              );
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
        title: const Text('Xác nhận xử lý'),
        content: const Text(
          'Bạn có chắc chắn muốn xác nhận đã xử lý sự kiện này?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await provider.resolveSOSByCaregiver(
        sosId: sosId,
        resolutionStatus: 'safe',
        notes: 'Người chăm sóc xác nhận đã xử lý',
      );

      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã xác nhận xử lý')));
      }
    }
  }
}
