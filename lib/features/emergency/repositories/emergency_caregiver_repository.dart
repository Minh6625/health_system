import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/emergency/models/sos_event_model.dart';

class EmergencyCaregiverRepository {
  final ApiClient _apiClient = ApiClient();

  /// Get list of SOS alerts with optional status filter
  Future<List<SOSEventModel>> getSOSAlerts({required String status}) async {
    try {
      final result = await _apiClient.get(
        '/mobile/caregiver/sos-alerts?status=$status',
      );

      final List<dynamic> sosAlertsJson = result['sos_alerts'] as List;
      return sosAlertsJson
          .map((json) => SOSEventModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Không thể tải danh sách SOS: ${e.toString()}');
    }
  }

  /// Get detailed information for a specific SOS
  Future<SOSEventModel> getSOSDetail({required String sosId}) async {
    try {
      final result = await _apiClient.get('/mobile/emergency/sos/$sosId');
      return SOSEventModel.fromJson(result as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Không thể tải chi tiết SOS: ${e.toString()}');
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
        '/mobile/emergency/sos/$sosId/resolve',
        body: {
          'resolution_status': resolutionStatus,
          if (notes != null) 'notes': notes,
        },
      );
    } catch (e) {
      throw Exception('Không thể xác nhận xử lý SOS: ${e.toString()}');
    }
  }
}
