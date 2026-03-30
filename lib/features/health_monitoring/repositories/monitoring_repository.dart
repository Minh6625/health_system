import 'package:healthguard/core/constants/api_endpoints.dart';
import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/health_monitoring/models/vital_signs.dart';

class MonitoringRepository {
  final ApiClient _client;

  MonitoringRepository({ApiClient? client}) : _client = client ?? ApiClient();

  /// Lấy vitals mới nhất của user hiện tại từ backend API.
  Future<VitalSigns> getLatestVitals() async {
    final response = await _client.get(ApiEndpoints.vitalsLatest);
    return VitalSigns.fromJson(response as Map<String, dynamic>);
  }
}
