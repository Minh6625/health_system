import 'package:flutter/material.dart';
import '../domain/entities/risk_report_entity.dart';
import '../domain/entities/risk_report_detail_entity.dart';

class RiskReportProvider extends ChangeNotifier {
  bool _isLoading = false;
  RiskReportEntity? _report;
  RiskReportDetailEntity? _reportDetail;
  String? _error;

  bool get isLoading => _isLoading;
  RiskReportEntity? get report => _report;
  RiskReportDetailEntity? get reportDetail => _reportDetail;
  String? get error => _error;

  Future<void> fetchLatestReport(String? profileId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      // Mock data based on plan
      _report = RiskReportEntity(
        reportId: "risk_20260320_0842",
        profileId: profileId ?? "self",
        score: 32, // Lower is better or worse? If 'Risk Score', lower might be better or worse according to plan.
        level: RiskLevel.low,
        displayStatus: "Ổn định",
        summary: "Sức khoẻ hôm nay đang ở mức ổn định.",
        analyzedAt: DateTime.now().subtract(const Duration(minutes: 15)),
        previousScore: 38,
        trend7d: [42, 39, 44, 36, 35, 38, 32],
        topFactors: [
          TopFactor(key: "heart_rate", label: "Nhịp tim lúc nghỉ ổn định"),
          TopFactor(key: "spo2", label: "SpO2 bình thường"),
        ],
        recommendationPreview: [
          "Duy trì chế độ ăn và sinh hoạt hiện tại",
          "Theo dõi giấc ngủ hàng ngày thay vì thỉnh thoảng"
        ],
        confidence: 0.87,
        isStale: false,
      );
    } catch (e) {
      _error = "Không thể tải dữ liệu: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchReportDetail(String reportId, String? profileId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      _reportDetail = RiskReportDetailEntity(
        reportId: reportId,
        profileId: profileId ?? "self",
        score: 32,
        level: RiskLevel.low,
        summary: "Sức khoẻ hôm nay đang ở mức ổn định.",
        analyzedAt: DateTime.now().subtract(const Duration(minutes: 15)),
        breakdown: [
          FactorBreakdown(
            key: "heart_rate",
            label: "Nhịp tim lúc nghỉ cao",
            contributionScore: 18,
            impactLevel: "high",
            value: "108",
            unit: "bpm",
            routeTarget: "vital_hr",
          ),
          FactorBreakdown(
            key: "spo2",
            label: "SpO2 giảm nhẹ",
            contributionScore: 12,
            impactLevel: "medium",
            value: "93",
            unit: "%",
            routeTarget: "vital_spo2",
          ),
        ],
        xaiExplanation: "Điểm tăng chủ yếu do nhịp tim lúc nghỉ cao và SpO2 giảm nhẹ trong buổi sáng. Đây là dấu hiệu cần theo dõi thêm nhưng chưa ở mức nguy hiểm.",
        recommendations: [
          "Nghỉ ngơi 15 phút rồi đo lại nhịp tim.",
          "Theo dõi SpO2 trong ngày hôm nay."
        ],
        snapshot: SnapshotMetrics(
          heartRate: 108,
          spO2: 93,
          sysBp: 138,
          diaBp: 86,
          bodyTemp: 36.9,
          hrv: 28,
          mapVal: 103,
        ),
      );
    } catch (e) {
      _error = "Không thể tải chi tiết: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
