import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/emergency/models/sos_event_model.dart';

class SOSAlertsResult {
  final List<SOSEventModel> sosAlerts;
  final int totalCount;
  final int activeCount;
  final int resolvedCount;

  const SOSAlertsResult({
    required this.sosAlerts,
    required this.totalCount,
    required this.activeCount,
    required this.resolvedCount,
  });
}

class EmergencyCaregiverRepository {
  final ApiClient _apiClient = ApiClient();

  /// Get list of SOS alerts with optional status filter
  Future<SOSAlertsResult> getSOSAlerts({required String status}) async {
    try {
      final result = await _apiClient.get(
        '/emergency/caregiver/sos-alerts?status=$status',
      );

      final List<dynamic> sosAlertsJson = result['sos_alerts'] as List;
      final alerts = sosAlertsJson
          .map((json) => SOSEventModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return SOSAlertsResult(
        sosAlerts: alerts,
        totalCount: (result['total_count'] as num?)?.toInt() ?? alerts.length,
        activeCount: (result['active_count'] as num?)?.toInt() ?? 0,
        resolvedCount: (result['resolved_count'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      throw Exception('Không thể tải danh sách SOS: ${e.toString()}');
    }
  }

  /// Get detailed information for a specific SOS
  Future<SOSEventModel> getSOSDetail({required String sosId}) async {
    try {
      final result = await _apiClient.get('/emergency/sos/$sosId');
      return SOSEventModel.fromJson(result as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Không thể tải chi tiết SOS: ${e.toString()}');
    }
  }

  /// Trigger manual SOS event
  Future<void> triggerSOS({
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    try {
      await _apiClient.post(
        '/emergency/sos/trigger',
        body: {
          'trigger_type': 'manual',
          // ignore: use_null_aware_elements
          if (latitude != null) 'latitude': latitude,
          // ignore: use_null_aware_elements
          if (longitude != null) 'longitude': longitude,
          // ignore: use_null_aware_elements
          if (address != null) 'address': address,
        },
      );
    } catch (e) {
      throw Exception('Không thể gửi cảnh báo khẩn cấp: ${e.toString()}');
    }
  }

  /// Resolve SOS by caregiver
  Future<void> resolveSOSByCaregiver({
    required String sosId,
    required String resolutionStatus,
    String? notes,
  }) async {
    try {
      await _apiClient.post(
        '/emergency/sos/$sosId/resolve',
        body: {
          'resolution_status': resolutionStatus,
          // ignore: use_null_aware_elements
          if (notes != null) 'notes': notes,
        },
      );
    } catch (e) {
      throw Exception('Không thể xác nhận xử lý SOS: ${e.toString()}');
    }
  }
}
