import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:healthguard/features/emergency/models/sos_event_model.dart';
import 'package:healthguard/features/emergency/repositories/emergency_caregiver_repository.dart';

/// Provider for Emergency Caregiver features
class EmergencyCaregiverProvider extends ChangeNotifier {
  final EmergencyCaregiverRepository repository;

  EmergencyCaregiverProvider(this.repository);

  // State for SOS Alerts List
  List<SOSEventModel> sosList = [];
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
  int get activeCount => sosList.where((sos) => sos.isActive).length;

  /// Fetch SOS alerts with status filter
  Future<void> fetchSOSAlerts(String status) async {
    isLoadingList = true;
    listErrorMessage = null;
    currentFilter = status;
    notifyListeners();

    try {
      sosList = await repository.getSOSAlerts(status: status);
    } catch (e) {
      listErrorMessage = _getErrorMessage(e);
    } finally {
      isLoadingList = false;
      notifyListeners();
    }
  }

  /// Refresh SOS alerts (pull-to-refresh)
  Future<void> refreshSOSAlerts(String status) async {
    isRefreshing = true;
    listErrorMessage = null;
    notifyListeners();

    try {
      sosList = await repository.getSOSAlerts(status: status);
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
    try {
      final uri = Uri.parse('tel:$phoneNumber');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw Exception('Không thể gọi điện thoại');
      }
    } catch (e) {
      listErrorMessage = 'Không thể mở ứng dụng điện thoại';
      notifyListeners();
    }
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
  void subscribeToSOSUpdates(String sosId) {
    // Cancel existing subscription
    _sosUpdateSubscription?.cancel();

    // TODO: Implement WebSocket connection here
    // For MVP, we'll use polling every 30 seconds
    _sosUpdateSubscription =
        Stream.periodic(const Duration(seconds: 30), (_) => sosId)
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
