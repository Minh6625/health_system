import 'dart:async';
import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:geolocator/geolocator.dart';
import 'package:healthguard/features/emergency/repositories/emergency_caregiver_repository.dart';

class ManualSOSScreen extends StatefulWidget {
  const ManualSOSScreen({super.key});

  @override
  State<ManualSOSScreen> createState() => _ManualSOSScreenState();
}

class _ManualSOSScreenState extends State<ManualSOSScreen>
    with SingleTickerProviderStateMixin {
  final EmergencyCaregiverRepository _repository =
      EmergencyCaregiverRepository();
  int _countdown = 5;
  Timer? _timer;
  bool _isSending = false;
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
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
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

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 5),
        ),
      );
      debugPrint(
        "Grabbed position: ${position.latitude}, ${position.longitude}",
      );
      return position;
    } catch (e) {
      debugPrint("Exception determining position: $e");
      return null;
    }
  }

  Future<void> _triggerSOS() async {
    if (_isCancelled) return;

    setState(() {
      _isSending = true;
      _networkError = false;
    });

    try {
      Position? position = await _determinePosition();

      if (_isCancelled) return;

      // Call actual API
      await _repository.triggerSOS(
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      // Navigate or show success overlay
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Đã gửi tín hiệu khẩn cấp thành công!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context); // Go back after sent
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _networkError = true;
        });
      }
    }
  }

  void _cancelSOS() {
    setState(() {
      _isCancelled = true;
    });
    _timer?.cancel();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade900,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 32),
          onPressed: _isSending ? null : _cancelSOS,
          tooltip: 'Hủy khẩn cấp',
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: double.infinity,
              ), // Đảm bảo tự động căn giữa toàn bộ khi không còn SlideAction
              if (_networkError)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi_off, color: Colors.black87),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Đang thử kết nối... Sẽ tự động gửi lại.",
                          style: TextStyle(
                            color: Colors.black87,
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
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                "Sẽ gửi SOS trong:",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              if (_isSending)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48.0),
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 4,
                  ),
                )
              else
                Text(
                  "$_countdown",
                  style: const TextStyle(
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),

              if (_isSending)
                const Text(
                  "Đang báo động...",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),

              const Spacer(),

              if (!_isSending) ...[
                SlideAction(
                  height: 64,
                  outerColor: Colors.white,
                  innerColor: Colors.red.shade900,
                  textColor: Colors.red.shade900,
                  text: "Trượt để GỬI NGAY",
                  textStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                  ),
                  sliderButtonIcon: const Icon(
                    Icons.double_arrow,
                    color: Colors.white,
                  ),
                  onSubmit: () async {
                    _timer?.cancel();
                    await _triggerSOS();
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white24,
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
                        color: Colors.white,
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
  }
}
