import 'dart:async';

import 'package:flutter/services.dart';

/// Phát âm thanh + rung cảnh báo cho các màn hình SOS / risk alert.
///
/// Sử dụng built-in `SystemSound.play(SystemSoundType.alert)` và
/// `HapticFeedback.heavyImpact()` để không cần asset hay package thứ ba.
///
/// Mỗi màn hình chỉ cần gọi [start] khi mount và [stop] khi dispose:
///
/// ```dart
/// final _sosAudio = SosAudioService();
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
  SosAudioService({
    Duration interval = const Duration(seconds: 1),
  }) : _interval = interval;

  final Duration _interval;
  Timer? _timer;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// Bắt đầu phát loop âm thanh + rung. An toàn khi gọi nhiều lần.
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    // Phát ngay lập tức ở lần đầu để user cảm nhận tức thì.
    _playOnce();
    _timer = Timer.periodic(_interval, (_) => _playOnce());
  }

  /// Dừng loop. Idempotent.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }

  void _playOnce() {
    // SystemSound.alert: tiếng "ting" hệ thống — nghe rõ trên cả Android/iOS.
    SystemSound.play(SystemSoundType.alert);
    // HapticFeedback.heavyImpact: rung mạnh để user cảm nhận khi điện thoại ở
    // chế độ im lặng (ringer off).
    HapticFeedback.heavyImpact();
  }
}
