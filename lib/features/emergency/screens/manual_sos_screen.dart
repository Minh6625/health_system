import 'dart:async';
import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:geolocator/geolocator.dart';
import 'package:healthguard/features/emergency/repositories/emergency_caregiver_repository.dart';
import 'package:healthguard/features/emergency/screens/sos_confirm_screen.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';

class ManualSOSScreen extends StatefulWidget {
  const ManualSOSScreen({super.key});

  @override
  State<ManualSOSScreen> createState() => _ManualSOSScreenState();
}

class _ManualSOSScreenState extends State<ManualSOSScreen>
    with SingleTickerProviderStateMixin {
  final EmergencyCaregiverRepository _repository =
      EmergencyCaregiverRepository();
  final ValueNotifier<int> _countdownNotifier = ValueNotifier<int>(3);
  Timer? _timer;
  final ValueNotifier<bool> _isSendingNotifier = ValueNotifier<bool>(false);
  bool _isCancelled = false;
  bool _networkError = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _requestLocationPermissionOnce();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startCountdown();
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
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
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

      await _repository.triggerSOS(
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const SosConfirmScreen(recipientCount: 1),
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
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
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
          backgroundColor: AppColors.critical,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
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
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sectionGapXl,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: double.infinity),
                  if (_networkError)
                    Container(
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
                          Icon(Icons.wifi_off, color: AppColors.textPrimary),
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

                  const Spacer(),

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

                  const Spacer(),

                  if (!isSending) ...[
                    SlideAction(
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
    );
  }
}
