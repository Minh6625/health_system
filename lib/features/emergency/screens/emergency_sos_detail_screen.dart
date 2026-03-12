import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:healthguard/features/emergency/providers/emergency_caregiver_provider.dart';
import 'package:healthguard/features/emergency/widgets/status_badge.dart';
import 'package:intl/intl.dart';

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
  double _shadowOpacity = 1.0;
  late AnimationController _arrowAnimationController;
  late AnimationController _warningAnimationController;
  late Animation<double> _arrowAnimation;
  late Animation<double> _warningAnimation;

  @override
  void initState() {
    super.initState();
    // Add listener in initState
    _scrollController.addListener(_onScroll);
    
    // Setup arrow animation
    _arrowAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _arrowAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(
        parent: _arrowAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Setup warning icon shake animation (rotate)
    _warningAnimationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    )..repeat(reverse: true);
    
    _warningAnimation = Tween<double>(begin: -0.1, end: 0.1).animate(
      CurvedAnimation(
        parent: _warningAnimationController,
        curve: Curves.linear,
      ),
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
      final scrollProgress = maxScroll > 0 ? (currentScroll / maxScroll).clamp(0.0, 1.0) : 0.0;
      
      // Fade out shadow as we scroll down (inverse of progress)
      final newOpacity = (1.0 - scrollProgress).clamp(0.0, 1.0);
      
      if ((newOpacity - _shadowOpacity).abs() > 0.01) {
        setState(() {
          _shadowOpacity = newOpacity;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _arrowAnimationController.dispose();
    _warningAnimationController.dispose();
    _provider.unsubscribeFromSOSUpdates();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBEBEB),
      appBar: AppBar(
        title: const Text('Chi tiết SOS'),
        elevation: 0,
      ),
      body: Consumer<EmergencyCaregiverProvider>(
        builder: (context, provider, child) {
          // Loading state
          if (provider.isLoadingDetail) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (provider.detailErrorMessage != null) {
            return _buildErrorState(provider.detailErrorMessage!);
          }

          // Success state
          if (provider.sosDetail != null) {
            return _buildDetailContent(provider);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildDetailContent(EmergencyCaregiverProvider provider) {
    final sos = provider.sosDetail!;

    return Column(
      children: [
        // Patient Header
        Stack(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sos.isActive ? const Color(0xFFFFABAF) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: sos.isActive
                        ? const Color(0xFFE53935).withOpacity(0.25)
                        : Colors.black.withOpacity(0.08),
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
                            ? CachedNetworkImageProvider(sos.patient.photoUrl!)
                            : null,
                        backgroundColor: Colors.grey[400],
                        child: sos.patient.photoUrl == null
                            ? const Icon(Icons.person, size: 32, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          sos.patient.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: sos.isActive ? const Color(0xFF1A1A1A) : Colors.black87,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Space for warning icon
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
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
                top: 28,    // Thay đổi số này để điều chỉnh khoảng cách từ trên xuống
                right: 28,  // Thay đổi số này để điều chỉnh khoảng cách từ phải sang trái
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _warningAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _warningAnimation.value,
                        child: child,
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
        ),

        // Map Placeholder
        Container(
          height: 220,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.grey[300],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 8),
                  Text(
                    'Map view',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  if (sos.location.latitude != null)
                    Text(
                      'Lat: ${sos.location.latitude!.toStringAsFixed(6)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  if (sos.location.longitude != null)
                    Text(
                      'Lng: ${sos.location.longitude!.toStringAsFixed(6)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Details Section
        Expanded(
          child: Stack(
            children: [
              SingleChildScrollView(
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
              ),
              // Gradient shadow at bottom to indicate more content below
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _shadowOpacity,
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
                              Colors.black.withOpacity(0.15),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Animated arrow icon
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _shadowOpacity,
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
                  ),
                ),
              ),
            ],
          ),
        ),

        // Action Buttons
        _buildActionButtons(provider, sos),
      ],
    );
  }

  Widget _buildLocationInfo(sos) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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
          Text(
            'GPS: ${sos.location.latitude.toStringAsFixed(6)}, '
            '${sos.location.longitude.toStringAsFixed(6)}',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Text(
            'Độ chính xác: ${sos.location.accuracy.toStringAsFixed(1)} mét',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Text(
            'Cập nhật: ${DateFormat('HH:mm:ss - dd/MM/yyyy').format(sos.location.lastUpdated)}',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(sos) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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

  Widget _buildTriggerInfo(sos) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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
              Icon(_getTriggerIcon(sos.triggerType), size: 20, color: Colors.grey[700]),
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

  Widget _buildXAITimeline(xai) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[300]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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

  Widget _buildResolutionInfo(resolution) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[300]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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

  Widget _buildActionButtons(EmergencyCaregiverProvider provider, sos) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
                    onPressed: () => provider.openMapNavigation(
                      sos.location.latitude,
                      sos.location.longitude,
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
