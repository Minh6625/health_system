import 'package:healthguard/core/constants/api_endpoints.dart';
import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/health_monitoring/models/health_report.dart';
import 'package:healthguard/features/health_monitoring/models/vital_signs.dart';
import 'package:healthguard/features/health_monitoring/models/vitals_timeseries.dart';

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

  /// Lấy báo cáo sức khoẻ tổng hợp 24h (vitals avg + risk + health score).
  Future<HealthReport> getHealthReport({String? profileId}) async {
    final response = await _client.get(
      ApiEndpoints.healthReport,
      targetProfileId: _resolveTargetProfileId(profileId),
    );
    return HealthReport.fromJson(response as Map<String, dynamic>);
  }

  /// F-12 (M-6): Lấy time-series 24h cho biểu đồ vital_detail_screen.
  ///
  /// Trước fix `VitalSignsProvider.chartData` cứng `const []` nên section
  /// "Biến động 24h qua" luôn trống. Hàm này gọi endpoint mới
  /// `/metrics/vitals/timeseries`, trả về danh sách bucket đã downsample
  /// (mặc định 15 phút × 24 h ≈ 96 điểm) — đủ mượt cho fl_chart, đủ chi
  /// tiết để thấy biến động trong ngày.
  ///
  /// [range] hôm nay chỉ chấp nhận `"24h"` ở phía UI; `"7d"` / `"30d"` đã
  /// được backend ngầm coerce về `"24h"` đến khi tab range mới ship.
  Future<VitalsTimeseries> getVitalsTimeseries({
    String? profileId,
    String range = '24h',
  }) async {
    final response = await _client.get(
      ApiEndpoints.vitalsTimeseries,
      queryParams: {'range': range},
      targetProfileId: _resolveTargetProfileId(profileId),
    );
    return VitalsTimeseries.fromJson(response as Map<String, dynamic>);
  }
}
