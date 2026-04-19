import 'package:flutter/material.dart';
import '../domain/entities/risk_report_detail_entity.dart';
import '../domain/entities/risk_report_entity.dart';
import '../repositories/risk_analysis_repository.dart';

class RiskReportProvider extends ChangeNotifier {
  RiskReportProvider({RiskAnalysisRepository? repository})
    : _repository = repository ?? RiskAnalysisRepository();

  final RiskAnalysisRepository _repository;

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

    try {
      _report = await _repository.fetchLatestReport(profileId);
    } catch (e) {
      _error = 'Không thể tải dữ liệu: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchReportDetail(int reportId, String? profileId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _reportDetail = await _repository.fetchReportDetail(reportId, profileId);
    } catch (e) {
      _error = 'Không thể tải chi tiết: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
