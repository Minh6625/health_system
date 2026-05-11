import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/emergency/models/sos_event_model.dart';

class TriggerSOSResult {
  final String sosId;
  final int recipientCount;
  final String? message;

  const TriggerSOSResult({
    required this.sosId,
    required this.recipientCount,
    this.message,
  });

  factory TriggerSOSResult.fromJson(Map<String, dynamic> json) {
    return TriggerSOSResult(
      sosId: json['sos_id'].toString(),
      recipientCount: (json['recipient_count'] as num?)?.toInt() ?? 0,
      message: json['message'] as String?,
    );
  }
}

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
  EmergencyCaregiverRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

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
  Future<TriggerSOSResult> triggerSOS({
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    try {
      final result = await _apiClient.post(
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
      return TriggerSOSResult.fromJson(result as Map<String, dynamic>);
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

  /// Submit a risk response for a notification.
  ///
  /// The backend uses this to record the user's outcome for the alert.
  Future<Map<String, dynamic>> respondToRiskNotification({
    required String notificationId,
    required String responseType,
    required String source,
    int? riskScoreId,
  }) async {
    try {
      final result = await _apiClient.post(
        '/risk/alerts/$notificationId/respond',
        body: {
          'risk_score_id': ?riskScoreId,
          'action': responseType,
          'source': source,
        },
      );

      if (result is Map<String, dynamic>) {
        return result;
      }

      if (result is Map) {
        return result.map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        );
      }

      return <String, dynamic>{};
    } catch (e) {
      throw Exception('Không thể gửi phản hồi rủi ro: ${e.toString()}');
    }
  }
}
