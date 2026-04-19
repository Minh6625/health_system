import 'package:healthguard/core/constants/api_endpoints.dart';
import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/health_monitoring/models/vital_signs.dart';

class MonitoringRepository {
  final ApiClient _client;

  MonitoringRepository({ApiClient? client}) : _client = client ?? ApiClient();

  int? _resolveTargetProfileId(String? profileId) {
    if (profileId == null || profileId.isEmpty || profileId == 'self') {
      return null;
    }
    return int.tryParse(profileId);
  }

  /// Lấy vitals mới nhất của user hiện tại từ backend API.
  Future<VitalSigns> getLatestVitals({String? profileId}) async {
    final response = await _client.get(
      ApiEndpoints.vitalsLatest,
      targetProfileId: _resolveTargetProfileId(profileId),
    );
    return VitalSigns.fromJson(response as Map<String, dynamic>);
  }
}
