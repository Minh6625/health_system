import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Loại cảnh báo — quyết định file âm thanh phát ra.
enum AudioAlertType {
  /// Màn hình SOS bấm tay (`ManualSOSScreen`).
  /// → `res/raw/emergency_alert.wav`
  manualSos,

  /// Overlay cảnh báo chỉ số sức khỏe (`RiskAlertFullScreenOverlay`).
  /// → `res/raw/health_emergency.wav`
  healthEmergency,

  /// Màn hình phát hiện té ngã (`FallAlertScreen`).
  /// → `res/raw/fall_alert.wav`
  fallAlert,
}

extension _AudioAlertTypeExt on AudioAlertType {
  /// Tên file trong `android/app/src/main/res/raw/` (không kèm đuôi).
  String get rawAsset {
    switch (this) {
      case AudioAlertType.manualSos:
        return 'emergency_alert';
      case AudioAlertType.healthEmergency:
        return 'health_emergency';
      case AudioAlertType.fallAlert:
        return 'fall_alert';
    }
  }
}

/// Phát âm thanh + rung cảnh báo cho các màn hình SOS / risk alert / fall.
///
/// Mỗi màn hình chỉ cần gọi [start] khi mount và [stop] khi dispose:
///
/// ```dart
/// final _sosAudio = SosAudioService(AudioAlertType.manualSos);
/// @override
/// void initState() {
///   super.initState();
///   _sosAudio.start();
/// }
/// @override
/// void dispose() {
///   _sosAudio.stop();
///   super.dispose();
/// }
/// ```
class SosAudioService {
  SosAudioService(
    this.alertType, {
    Duration interval = const Duration(seconds: 4),
  }) : _interval = interval;

  final AudioAlertType alertType;
  final Duration _interval;
  Timer? _timer;
  bool _isRunning = false;
  AudioPlayer? _player;

  bool get isRunning => _isRunning;

  /// Bắt đầu phát loop âm thanh + rung. An toàn khi gọi nhiều lần.
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _player = AudioPlayer();
    _playOnce();
    _timer = Timer.periodic(_interval, (_) => _playOnce());
  }

  /// Dừng loop. Idempotent.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    await _player?.stop();
    await _player?.dispose();
    _player = null;
  }

  Future<void> _playOnce() async {
    HapticFeedback.heavyImpact();
    try {
      await _player?.play(AssetSource('audio/${alertType.rawAsset}.wav'));
    } catch (_) {
      // Fallback nếu audioplayers không load được file native.
      SystemSound.play(SystemSoundType.alert);
    }
  }
}
