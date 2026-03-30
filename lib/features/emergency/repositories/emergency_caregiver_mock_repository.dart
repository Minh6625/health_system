import 'package:healthguard/features/emergency/models/sos_event_model.dart';
import 'package:healthguard/features/emergency/repositories/emergency_caregiver_repository.dart';

/// Mock repository cho Emergency Caregiver — dùng khi API chưa sẵn sàng.
///
/// Hoàn toàn in-memory, không gọi network.
/// Hỗ trợ:
///   - Lọc theo status (all / active / resolved)
///   - Resolve SOS (cập nhật in-memory → Detail polling sẽ thấy thay đổi)
///   - sosId convention: "sos-mock-{profileId}-{seq}" đồng bộ với FamilyProfileSnapshot
///
/// Để switch sang mock: thay EmergencyCaregiverRepository() trong app.dart bằng
///   EmergencyCaregiverMockRepository()
/// Hoặc dùng kDebugMode guard như ví dụ bên dưới.
class EmergencyCaregiverMockRepository extends EmergencyCaregiverRepository {
  // In-memory store — cho phép resolve cập nhật trực tiếp
  final List<Map<String, dynamic>> _store;

  EmergencyCaregiverMockRepository() : _store = _buildInitialStore();

  // ---------------------------------------------------------------------------
  // API 1: Danh sách SOS
  // ---------------------------------------------------------------------------
  @override
  Future<List<SOSEventModel>> getSOSAlerts({required String status}) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final filtered = status == 'all'
        ? _store
        : _store.where((m) => m['status'] == status).toList();

    return filtered
        .map((m) => SOSEventModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // API 2: Chi tiết SOS
  // ---------------------------------------------------------------------------
  @override
  Future<SOSEventModel> getSOSDetail({required String sosId}) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final item = _store.firstWhere(
      (m) => m['sos_id'] == sosId,
      orElse: () => throw Exception('404: SOS $sosId không tìm thấy'),
    );

    return SOSEventModel.fromJson(Map<String, dynamic>.from(item));
  }

  // ---------------------------------------------------------------------------
  // API 3: Gửi SOS thủ công — không cần thay đổi logic, chỉ fake response
  // ---------------------------------------------------------------------------
  @override
  Future<void> triggerSOS({
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    // Mock luôn thành công — recipientCount = 1 (fixed trong SosConfirmScreen)
  }

  // ---------------------------------------------------------------------------
  // API 4: Resolve SOS — cập nhật in-memory để polling trên Detail thấy thay đổi
  // ---------------------------------------------------------------------------
  @override
  Future<void> resolveSOSByCaregiver({
    required String sosId,
    required String resolutionStatus,
    String? notes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final idx = _store.indexWhere((m) => m['sos_id'] == sosId);
    if (idx == -1) throw Exception('404: SOS $sosId không tìm thấy');

    _store[idx] = {
      ..._store[idx],
      'status': 'resolved',
      'resolution': {
        'resolved_by_name': 'Người dùng (mock)',
        'resolved_at': DateTime.now().toIso8601String(),
        'notes': notes ?? resolutionStatus,
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Build initial data — đúng spec EMERGENCY_SOS_Mock_Data_Spec.md
  // ---------------------------------------------------------------------------
  static List<Map<String, dynamic>> _buildInitialStore() {
    final now = DateTime.now();
    final today = now.toUtc();

    return [
      // SOS-001: Trần Thị B — manual, ACTIVE — đồng bộ với FamilyProfileSnapshot.sosId
      {
        'sos_id': 'sos-mock-2-001',
        'patient': {
          'user_id': 2,
          'full_name': 'Trần Thị B',
          'avatar_url': null,
          'phone': '0901234567',
        },
        'trigger_type': 'manual',
        'trigger_time': today
            .subtract(const Duration(minutes: 18))
            .toIso8601String(),
        'status': 'active',
        'location': {
          'latitude': 10.762622,
          'longitude': 106.660172,
          'accuracy': 15.5,
          'address': '123 Nguyễn Huệ, Quận 1, TP.HCM',
          'last_updated': today
              .subtract(const Duration(minutes: 17, seconds: 55))
              .toIso8601String(),
        },
        'fall_detection_xai': null,
        'resolution': null,
      },

      // SOS-002: Nguyễn Văn A — manual, ACTIVE — xuất hiện khi có nhiều SOS cùng lúc
      {
        'sos_id': 'sos-mock-1-002',
        'patient': {
          'user_id': 1,
          'full_name': 'Nguyễn Văn A',
          'avatar_url': null,
          'phone': '0912345678',
        },
        'trigger_type': 'manual',
        'trigger_time': today
            .subtract(const Duration(hours: 1, minutes: 3))
            .toIso8601String(),
        'status': 'active',
        'location': {
          'latitude': 10.775689,
          'longitude': 106.701234,
          'accuracy': 20.0,
          'address': '456 Lê Lợi, Quận 3, TP.HCM',
          'last_updated': today
              .subtract(const Duration(hours: 1, minutes: 2, seconds: 50))
              .toIso8601String(),
        },
        'fall_detection_xai': null,
        'resolution': null,
      },

      // SOS-003: Phạm Văn C — fall_detected, RESOLVED — dùng để test tab "Đã xử lý"
      {
        'sos_id': 'sos-mock-3-003',
        'patient': {
          'user_id': 3,
          'full_name': 'Phạm Văn C',
          'avatar_url': null,
          'phone': '0987654321',
        },
        'trigger_type': 'fall_detected',
        'trigger_time': today
            .subtract(const Duration(hours: 33, minutes: 58))
            .toIso8601String(),
        'status': 'resolved',
        'location': {
          'latitude': 10.801234,
          'longitude': 106.712345,
          'accuracy': 12.0,
          'address': '789 Hai Bà Trưng, Quận 3, TP.HCM',
          'last_updated': today
              .subtract(const Duration(hours: 33, minutes: 57, seconds: 50))
              .toIso8601String(),
        },
        'fall_detection_xai': {
          'confidence': 92.5,
          'timeline': [
            {
              'time': _formatTime(
                today.subtract(const Duration(hours: 34, minutes: 2)),
              ),
              'description': 'Phát hiện chuyển động bất thường',
            },
            {
              'time': _formatTime(
                today.subtract(const Duration(hours: 34)),
              ),
              'description': 'Xác nhận té ngã',
            },
          ],
        },
        'resolution': {
          'resolved_by_name': 'Chị Lan',
          'resolved_at': today
              .subtract(const Duration(hours: 33, minutes: 43))
              .toIso8601String(),
          'notes': 'Đã đến hiện trường, bệnh nhân ổn định',
        },
      },

      // SOS-004: Trần Thị B — vital_critical, RESOLVED — test trigger_type khác
      {
        'sos_id': 'sos-mock-2-004',
        'patient': {
          'user_id': 2,
          'full_name': 'Trần Thị B',
          'avatar_url': null,
          'phone': '0901234567',
        },
        'trigger_type': 'vital_critical',
        'trigger_time': today
            .subtract(const Duration(days: 2, hours: 5))
            .toIso8601String(),
        'status': 'resolved',
        'location': {
          'latitude': 10.762622,
          'longitude': 106.660172,
          'accuracy': 18.0,
          'address': '123 Nguyễn Huệ, Quận 1, TP.HCM',
          'last_updated': today
              .subtract(const Duration(days: 2, hours: 4, minutes: 59))
              .toIso8601String(),
        },
        'fall_detection_xai': null,
        'resolution': {
          'resolved_by_name': 'Bác sĩ Phạm Văn D',
          'resolved_at': today
              .subtract(const Duration(days: 2, hours: 4, minutes: 30))
              .toIso8601String(),
          'notes': 'Nhịp tim trở về bình thường sau 20 phút',
        },
      },

      // SOS-005: Nguyễn Văn A — fall_detected, RESOLVED (không có GPS) — test empty map
      {
        'sos_id': 'sos-mock-1-005',
        'patient': {
          'user_id': 1,
          'full_name': 'Nguyễn Văn A',
          'avatar_url': null,
          'phone': '0912345678',
        },
        'trigger_type': 'fall_detected',
        'trigger_time': today
            .subtract(const Duration(days: 5, hours: 2))
            .toIso8601String(),
        'status': 'resolved',
        'location': {
          'latitude': null,
          'longitude': null,
          'accuracy': null,
          'address': null,
          'last_updated': today
              .subtract(const Duration(days: 5, hours: 2))
              .toIso8601String(),
        },
        'fall_detection_xai': {
          'confidence': 78.3,
          'timeline': [
            {
              'time': _formatTime(
                today.subtract(const Duration(days: 5, hours: 2, minutes: 1)),
              ),
              'description': 'Cảm biến gia tốc tăng đột biến',
            },
            {
              'time': _formatTime(
                today.subtract(const Duration(days: 5, hours: 2)),
              ),
              'description': 'Phân tích tư thế: nằm bất động',
            },
            {
              'time': _formatTime(
                today.subtract(
                  const Duration(days: 5, hours: 1, minutes: 59),
                ),
              ),
              'description': 'Xác nhận té ngã',
            },
          ],
        },
        'resolution': {
          'resolved_by_name': 'Người dùng',
          'resolved_at': today
              .subtract(const Duration(days: 4, hours: 23))
              .toIso8601String(),
          'notes': null,
        },
      },
    ];
  }

  static String _formatTime(DateTime dt) {
    final h = dt.toLocal().hour.toString().padLeft(2, '0');
    final m = dt.toLocal().minute.toString().padLeft(2, '0');
    final s = dt.toLocal().second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
