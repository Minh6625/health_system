import 'package:flutter/material.dart';
import '../domain/entities/risk_report_detail_entity.dart';
import '../domain/entities/risk_report_entity.dart';
import '../repositories/risk_analysis_repository.dart';

class RiskReportProvider extends ChangeNotifier {
  RiskReportProvider({RiskAnalysisRepository? repository})
    : _repository = repository ?? RiskAnalysisRepository();

  final RiskAnalysisRepository _repository;

  bool _isInitialLoading = false;
  bool _isRefreshing = false;
  bool _isRecalculating = false;
  RiskReportEntity? _report;
  RiskReportDetailEntity? _reportDetail;
  String? _error;
  String? _emptyMessage;

  bool get isLoading => _isInitialLoading || _isRefreshing;
  bool get isInitialLoading => _isInitialLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isRecalculating => _isRecalculating;
  RiskReportEntity? get report => _report;
  RiskReportDetailEntity? get reportDetail => _reportDetail;
  String? get error => _error;
  String? get emptyMessage => _emptyMessage;
  bool get isEmpty => _emptyMessage != null;
  bool get isForbidden =>
      (_error ?? '').toLowerCase().contains('không có quyền');
  bool get hasStaleContent =>
      (_report?.isStale ?? false) || (_reportDetail?.isStale ?? false);

  Future<void> fetchLatestReport(String? profileId) async {
    final hasExistingContent = _report != null;
    _isInitialLoading = !hasExistingContent;
    _isRefreshing = hasExistingContent;
    _error = null;
    _emptyMessage = null;
    notifyListeners();

    try {
      _report = await _repository.fetchLatestReport(profileId);
    } catch (e) {
      if (e.toString().contains('Chưa có dữ liệu đánh giá')) {
        _report = null;
        _emptyMessage =
            'Chưa có báo cáo rủi ro. Hãy đeo thiết bị thêm vài giờ để hệ thống tạo báo cáo đầu tiên.';
      } else {
        _error = 'Không thể tải dữ liệu: $e';
      }
    } finally {
      _isInitialLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> recalculateRisk(String? profileId) async {
    _isRecalculating = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.recalculateRisk(profileId);
      await fetchLatestReport(profileId);
    } catch (e) {
      _error = 'Không thể đánh giá lại: $e';
      notifyListeners();
    } finally {
      _isRecalculating = false;
      notifyListeners();
    }
  }

  Future<void> fetchReportDetail(
    int reportId,
    String? profileId, {
    // Phase 8 / slice 4a. Forwarded verbatim to
    // ``RiskAnalysisRepository.fetchReportDetail``. ``null`` keeps
    // the legacy patient flow; ``"clinician"`` (when the user has
    // toggled the setting on AND has a clinician role) flips to the
    // ``RiskReportClinicianResponse`` shape with raw SHAP +
    // model_request_id.
    String? audience,
  }) async {
    final hasExistingContent = _reportDetail != null;
    _isInitialLoading = !hasExistingContent;
    _isRefreshing = hasExistingContent;
    _error = null;
    notifyListeners();

    try {
      _reportDetail = await _repository.fetchReportDetail(
        reportId,
        profileId,
        audience: audience,
      );
    } catch (e) {
      _error = 'Không thể tải chi tiết: $e';
    } finally {
      _isInitialLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }
}
