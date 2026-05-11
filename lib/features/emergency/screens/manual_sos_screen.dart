import 'dart:async' show Timer, unawaited;
import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:geolocator/geolocator.dart';
import 'package:healthguard/core/services/sos_audio_service.dart';
import 'package:healthguard/features/emergency/repositories/emergency_caregiver_repository.dart';
import 'package:healthguard/features/emergency/screens/sos_confirm_screen.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';

typedef ManualSosLocationPermissionRequester = Future<void> Function();
typedef ManualSosPositionResolver = Future<Position?> Function();

class ManualSOSScreen extends StatefulWidget {
  ManualSOSScreen({
    super.key,
    EmergencyCaregiverRepository? repository,
    this.initialCountdown = 3,
    this.countdownInterval = const Duration(seconds: 1),
    this.requestLocationPermission,
    this.positionResolver,
  }) : repository = repository ?? EmergencyCaregiverRepository();

  final EmergencyCaregiverRepository repository;
  final int initialCountdown;
  final Duration countdownInterval;
  final ManualSosLocationPermissionRequester? requestLocationPermission;
  final ManualSosPositionResolver? positionResolver;

  @override
  State<ManualSOSScreen> createState() => _ManualSOSScreenState();
}

class _ManualSOSScreenState extends State<ManualSOSScreen>
    with SingleTickerProviderStateMixin {
  late final ValueNotifier<int> _countdownNotifier;
  Timer? _timer;
  final ValueNotifier<bool> _isSendingNotifier = ValueNotifier<bool>(false);
  bool _isCancelled = false;
  bool _networkError = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final SosAudioService _audio = SosAudioService(AudioAlertType.manualSos);

  @override
  void initState() {
    super.initState();
    _countdownNotifier = ValueNotifier<int>(
      widget.initialCountdown > 0 ? widget.initialCountdown : 1,
    );
    Future.microtask(_requestLocationPermission);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _audio.start();
    _startCountdown();
  }

  Future<void> _requestLocationPermission() async {
    if (widget.requestLocationPermission != null) {
      await widget.requestLocationPermission!.call();
      return;
    }
    await _requestLocationPermissionOnce();
  }

  Future<void> _requestLocationPermissionOnce() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {}
  }

  void _startCountdown() {
    _timer = Timer.periodic(widget.countdownInterval, (timer) {
      if (!mounted) return;
      if (_countdownNotifier.value > 1) {
        _countdownNotifier.value--;
      } else {
        _timer?.cancel();
        _triggerSOS();
      }
    });
  }

  Future<Position?> _determinePosition() async {
    if (widget.positionResolver != null) {
      return widget.positionResolver!.call();
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("Location service is disabled");
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint("Location permission denied");
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint("Location permission denied forever");
        return null;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (e) {
        debugPrint("Current position failed, trying last known: $e");
      }

      position ??= await Geolocator.getLastKnownPosition();

      if (position != null) {
        debugPrint(
          "Grabbed position: ${position.latitude}, ${position.longitude}",
        );
      }

      return position;
    } catch (e) {
      debugPrint("Exception determining position: $e");
      return null;
    }
  }

  Future<void> _triggerSOS() async {
    if (_isCancelled) return;

    _isSendingNotifier.value = true;
    setState(() {
      _networkError = false;
    });

    try {
      Position? position = await _determinePosition();

      if (_isCancelled) return;

      final result = await widget.repository.triggerSOS(
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      await _audio.stop();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SosConfirmScreen(
              recipientCount: result.recipientCount,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _isSendingNotifier.value = false;
        setState(() {
          _networkError = true;
        });
      }
    }
  }

  void _cancelSOS() {
    _isCancelled = true;
    _timer?.cancel();
    unawaited(_audio.stop());
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_audio.stop());
    _countdownNotifier.dispose();
    _isSendingNotifier.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isSendingNotifier,
      builder: (context, isSending, child) {
        return Scaffold(
          key: const ValueKey('manual-sos-screen'),
          backgroundColor: AppColors.critical,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              key: const ValueKey('manual-sos-close-button'),
              icon: const Icon(
                Icons.close,
                color: AppColors.bgSurface,
                size: 32,
              ),
              onPressed: isSending ? null : _cancelSOS,
              tooltip: 'Hủy khẩn cấp',
            ),
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sectionGapXl,
                    vertical: AppSpacing.gapLg,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: double.infinity),
                          if (_networkError)
                            Container(
                              key: const ValueKey('manual-sos-network-error'),
                              padding: const EdgeInsets.all(AppSpacing.gapMd),
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.sectionGapXl,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warning,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.radiusSm),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.wifi_off,
                                    color: AppColors.textPrimary,
                                  ),
                                  SizedBox(width: AppSpacing.gapMd),
                                  Expanded(
                                    child: Text(
                                      "Đang thử kết nối... Sẽ tự động gửi lại.",
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: AppSpacing.sectionGapXl),
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              size: 100,
                              color: AppColors.bgSurface,
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            "Sẽ gửi SOS trong:",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.bgSurface,
                            ),
                          ),
                          if (isSending)
                            const Padding(
                              key: ValueKey('manual-sos-sending-indicator'),
                              padding: EdgeInsets.symmetric(vertical: 48.0),
                              child: CircularProgressIndicator(
                                color: AppColors.bgSurface,
                                strokeWidth: 4,
                              ),
                            )
                          else
                            ValueListenableBuilder<int>(
                              valueListenable: _countdownNotifier,
                              builder: (context, countdown, child) {
                                return Text(
                                  key: const ValueKey('manual-sos-countdown'),
                                  "$countdown",
                                  style: const TextStyle(
                                    fontSize: 120,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.bgSurface,
                                    height: 1.2,
                                  ),
                                );
                              },
                            ),
                          if (isSending)
                            Text(
                              "Đang báo động...",
                              style: TextStyle(
                                fontSize: 20,
                                color: AppColors.bgSurface.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          const SizedBox(height: AppSpacing.sectionGapXl),
                          if (!isSending) ...[
                            SlideAction(
                              key: const ValueKey('manual-sos-submit-slider'),
                              height: 64,
                              outerColor: AppColors.bgSurface,
                              innerColor: AppColors.critical,
                              textColor: AppColors.critical,
                              text: "Trượt để GỬI NGAY",
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.critical,
                              ),
                              sliderButtonIcon: const Icon(
                                Icons.double_arrow,
                                color: AppColors.bgSurface,
                              ),
                              onSubmit: () async {
                                _timer?.cancel();
                                await _triggerSOS();
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.gapLg),
                            SizedBox(
                              width: double.infinity,
                              height: 64,
                              child: TextButton(
                                key: const ValueKey('manual-sos-cancel-button'),
                                style: TextButton.styleFrom(
                                  backgroundColor:
                                      AppColors.bgSurface.withValues(alpha: 0.24),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(32),
                                  ),
                                ),
                                onPressed: _cancelSOS,
                                child: const Text(
                                  "Hủy báo động",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.bgSurface,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
