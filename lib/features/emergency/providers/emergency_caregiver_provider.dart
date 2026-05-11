import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:healthguard/features/emergency/models/sos_event_model.dart';
import 'package:healthguard/features/emergency/repositories/emergency_caregiver_repository.dart';

/// Provider for Emergency Caregiver features
class EmergencyCaregiverProvider extends ChangeNotifier {
  final EmergencyCaregiverRepository repository;

  EmergencyCaregiverProvider(this.repository);

  // State for SOS Alerts List
  List<SOSEventModel> sosList = [];
  final Map<String, List<SOSEventModel>> _alertsCacheByStatus = {};
  int _activeAlertsCount = 0;
  String currentFilter = 'all';
  bool isLoadingList = false;
  bool isRefreshing = false;
  String? listErrorMessage;

  // State for SOS Detail
  SOSEventModel? sosDetail;
  bool isLoadingDetail = false;
  String? detailErrorMessage;

  // WebSocket subscription for real-time updates
  StreamSubscription? _sosUpdateSubscription;

  /// Get count of active SOS alerts
  int get activeCount => _activeAlertsCount;

  /// Fetch SOS alerts with status filter
  Future<void> fetchSOSAlerts(String status, {bool silent = false}) async {
    final cachedAlerts = _alertsCacheByStatus[status];
    final hasCachedAlerts = cachedAlerts != null;

    if (!silent) {
      currentFilter = status;
      if (hasCachedAlerts) {
        sosList = List<SOSEventModel>.from(cachedAlerts);
      }
      isLoadingList = !hasCachedAlerts && sosList.isEmpty;
      listErrorMessage = null;
      notifyListeners();
    } else if (hasCachedAlerts && status == currentFilter) {
      sosList = List<SOSEventModel>.from(cachedAlerts);
      notifyListeners();
    }

    try {
      final result = await repository.getSOSAlerts(status: status);
      _activeAlertsCount = result.activeCount;
      _alertsCacheByStatus[status] = result.sosAlerts;

      if (status == 'all') {
        _alertsCacheByStatus['active'] = result.sosAlerts
            .where((alert) => alert.status == 'active')
            .toList();
        _alertsCacheByStatus['resolved'] = result.sosAlerts
            .where((alert) => alert.status == 'resolved')
            .toList();
      }

      // Silent badge polling (e.g. status='all') should not clobber
      // an actively filtered SOS list in the tab view.
      if (!silent || status == currentFilter) {
        sosList = result.sosAlerts;
      }
    } catch (e) {
      listErrorMessage = _getErrorMessage(e);
    } finally {
      if (!silent) {
        isLoadingList = false;
      }
      notifyListeners();
    }
  }

  /// Refresh SOS alerts (pull-to-refresh)
  Future<void> refreshSOSAlerts(String status) async {
    isRefreshing = true;
    listErrorMessage = null;
    notifyListeners();

    try {
      final result = await repository.getSOSAlerts(status: status);
      _alertsCacheByStatus[status] = result.sosAlerts;
      sosList = result.sosAlerts;
      _activeAlertsCount = result.activeCount;
    } catch (e) {
      listErrorMessage = _getErrorMessage(e);
    } finally {
      isRefreshing = false;
      notifyListeners();
    }
  }

  /// Fetch detailed information for specific SOS
  Future<void> fetchSOSDetail(String sosId) async {
    isLoadingDetail = true;
    detailErrorMessage = null;
    notifyListeners();

    try {
      sosDetail = await repository.getSOSDetail(sosId: sosId);
    } catch (e) {
      detailErrorMessage = _getErrorMessage(e);
    } finally {
      isLoadingDetail = false;
      notifyListeners();
    }
  }

  /// Resolve SOS by caregiver
  Future<bool> resolveSOSByCaregiver({
    required String sosId,
    required String resolutionStatus,
    String? notes,
  }) async {
    try {
      await repository.resolveSOSByCaregiver(
        sosId: sosId,
        resolutionStatus: resolutionStatus,
        notes: notes,
      );

      // Refresh detail after resolving
      await fetchSOSDetail(sosId);
      return true;
    } catch (e) {
      detailErrorMessage = _getErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// Make phone call to patient
  Future<void> makePhoneCall(String phoneNumber) async {
    final normalizedPhone = _normalizePhoneNumber(phoneNumber);
    if (normalizedPhone.isEmpty) {
      listErrorMessage = 'So dien thoai khong hop le';
      notifyListeners();
      return;
    }

    try {
      var didLaunchDirectCall = false;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        didLaunchDirectCall =
            await FlutterPhoneDirectCaller.callNumber(normalizedPhone) ?? false;
      }

      if (!didLaunchDirectCall) {
        final uri = Uri.parse('tel:$normalizedPhone');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Khong the goi dien thoai');
        }
      }
    } catch (e) {
      listErrorMessage = 'Khong the mo ung dung dien thoai';
      notifyListeners();
    }
  }

  String _normalizePhoneNumber(String phoneNumber) {
    final value = phoneNumber.trim();
    if (value.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final char = value[i];
      final isDigit = char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;
      final isLeadingPlus = char == '+' && buffer.isEmpty;
      if (isDigit || isLeadingPlus) {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  /// Open map navigation to patient location
  Future<void> openMapNavigation(double latitude, double longitude) async {
    try {
      final String googleMapsUrl =
          'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
      final Uri uri = Uri.parse(googleMapsUrl);

      // On Android simulators, canLaunchUrl for 'https://' sometimes evaluates to false
      // even if the browser works, so we launch directly and let the OS handle it
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      listErrorMessage = 'Không thể mở ứng dụng bản đồ';
      notifyListeners();
    }
  }

  /// Subscribe to real-time SOS updates (WebSocket)
  /// Note: WebSocket implementation would require a WebSocket service
  /// For now, this is a placeholder that uses polling as fallback
  void subscribeToSOSUpdates(
    String sosId, {
    Duration interval = const Duration(seconds: 30),
    bool enabled = true,
  }) {
    // Cancel existing subscription
    _sosUpdateSubscription?.cancel();

    if (!enabled) {
      return;
    }

    // TODO: Implement WebSocket connection here
    // For MVP, we'll use polling every 30 seconds
    _sosUpdateSubscription =
        Stream.periodic(interval, (_) => sosId)
            .asyncMap((id) async {
              try {
                return await repository.getSOSDetail(sosId: id);
              } catch (e) {
                return null;
              }
            })
            .listen((updatedSOS) {
              if (updatedSOS != null) {
                sosDetail = updatedSOS;
                notifyListeners();
              }
            });
  }

  /// Unsubscribe from real-time updates
  void unsubscribeFromSOSUpdates() {
    _sosUpdateSubscription?.cancel();
    _sosUpdateSubscription = null;
  }

  /// Convert exception to user-friendly message
  String _getErrorMessage(dynamic error) {
    final errorString = error.toString();

    if (errorString.contains('Network error')) {
      return 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối internet.';
    } else if (errorString.contains('401')) {
      return 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.';
    } else if (errorString.contains('403')) {
      return 'Bạn không có quyền truy cập chức năng này.';
    } else if (errorString.contains('404')) {
      return 'Không tìm thấy thông tin SOS.';
    } else if (errorString.contains('500')) {
      return 'Lỗi server. Vui lòng thử lại sau.';
    } else {
      return 'Có lỗi xảy ra. Vui lòng thử lại.';
    }
  }

  @override
  void dispose() {
    unsubscribeFromSOSUpdates();
    super.dispose();
  }
}
