import 'package:flutter/foundation.dart';

import '../models/linked_contact_medical_info_model.dart';
import '../repositories/family_repository.dart';

/// P-4: provider for the caregiver-facing medical-info screen. Owns the
/// fetch/loading/error lifecycle and translates repository exceptions into
/// a single ``status`` enum the UI can switch on.
///
/// Why an enum + nullable model instead of sealed states: keeps the API
/// surface tiny (one ``status`` field, one ``contact`` field) and matches
/// the existing pattern used by ``LinkedContactDetailProvider``. A sealed
/// hierarchy would be overkill for four states that share the same data
/// shape.
enum MedicalInfoStatus {
  initial,
  loading,
  ready,

  /// 403 path — the patient has not granted ``can_view_medical_info``
  /// to the current user. UI shows the "ask the patient to enable
  /// sharing" empty state.
  permissionDenied,

  /// 404 path — no accepted relationship exists. Most commonly happens
  /// when the link was removed between dashboard refresh and tap.
  notFound,

  /// Any other failure (network, parse, etc.).
  error,
}

class LinkedContactMedicalInfoProvider extends ChangeNotifier {
  LinkedContactMedicalInfoProvider({FamilyRepository? repository})
    : _repository = repository ?? FamilyRepository();

  final FamilyRepository _repository;

  MedicalInfoStatus _status = MedicalInfoStatus.initial;
  LinkedContactMedicalInfoModel? _info;
  String? _errorMessage;

  MedicalInfoStatus get status => _status;
  LinkedContactMedicalInfoModel? get info => _info;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _status == MedicalInfoStatus.loading;

  /// Reload from the server. Idempotent — calling while a load is in
  /// flight is a no-op so a double tap on the entry button doesn't fire
  /// two requests.
  Future<void> load(String contactId) async {
    if (_status == MedicalInfoStatus.loading) {
      return;
    }
    _status = MedicalInfoStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.getLinkedContactMedicalInfo(contactId);
      _info = result;
      _status = MedicalInfoStatus.ready;
    } on MedicalInfoPermissionDeniedException catch (e) {
      _info = null;
      _errorMessage = e.message;
      _status = MedicalInfoStatus.permissionDenied;
    } on MedicalInfoNotFoundException catch (e) {
      _info = null;
      _errorMessage = e.message;
      _status = MedicalInfoStatus.notFound;
    } catch (e) {
      _info = null;
      _errorMessage = e.toString();
      _status = MedicalInfoStatus.error;
    }

    notifyListeners();
  }
}
