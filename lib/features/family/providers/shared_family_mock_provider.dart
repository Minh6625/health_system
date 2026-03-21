import 'package:flutter/foundation.dart';
import 'package:healthguard/features/family/models/contact_tag.dart';
import 'package:healthguard/features/family/models/linked_contact_model.dart';
import 'package:healthguard/features/family/models/family_profile_snapshot.dart';

class SharedFamilyMockProvider extends ChangeNotifier {
  // Singleton instance
  static final SharedFamilyMockProvider _instance = SharedFamilyMockProvider._internal();
  factory SharedFamilyMockProvider() => _instance;
  SharedFamilyMockProvider._internal();

  bool _isLoading = false;
  String? _error;

  List<LinkedContactModel> _contacts = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<LinkedContactModel> get contacts => _contacts;

  List<LinkedContactModel> get pendingRequests => 
      _contacts.where((c) => c.status == ContactStatus.pending).toList();
      
  List<LinkedContactModel> get acceptedContacts => 
      _contacts.where((c) => c.status == ContactStatus.accepted).toList();

  Future<void> loadInitialData() async {
    if (_contacts.isNotEmpty) return; // Already loaded

    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    _contacts = [
      LinkedContactModel(
        id: '1',
        displayName: 'Bố - Nguyễn Văn A',
        email: 'nguyen.a@example.com',
        role: ContactRole.family,
        tags: [ContactTagsConfig.defaultTags[0]], // Gia đình
        primaryRelationshipLabel: 'Gia đình',
        status: ContactStatus.accepted,
        permissions: ['can_view_vitals', 'can_receive_alerts'],
      ),
      LinkedContactModel(
        id: '2',
        displayName: 'Mẹ - Trần Thị B',
        email: 'tran.b@example.com',
        role: ContactRole.family,
        tags: [ContactTagsConfig.defaultTags[0]], // Gia đình
        primaryRelationshipLabel: 'Gia đình',
        status: ContactStatus.accepted,
        permissions: ['can_view_vitals', 'can_receive_alerts', 'can_view_location'],
      ),
      LinkedContactModel(
        id: '3',
        displayName: 'Bác sĩ - Phạm Văn D',
        email: 'doctor.pham@example.com',
        role: ContactRole.doctor,
        tags: [ContactTagsConfig.defaultTags[1]], // Bác sĩ
        primaryRelationshipLabel: 'Bác sĩ',
        status: ContactStatus.accepted,
        permissions: ['can_view_vitals'],
      ),
      LinkedContactModel(
        id: 'req_1',
        displayName: 'Cô - Lê Thị C',
        email: 'le.c@example.com',
        role: ContactRole.unclassified,
        tags: const [], // chưa gắn tag
        primaryRelationshipLabel: 'Chưa phân loại',
        status: ContactStatus.pending,
        isIncomingRequest: true,
      ),
    ];

    _isLoading = false;
    notifyListeners();
  }

  // Phase 3: Accept Pending
  Future<void> acceptRequest(String contactId, List<String> permissions) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 400));
    
    final index = _contacts.indexWhere((c) => c.id == contactId);
    if (index != -1) {
      _contacts[index] = _contacts[index].copyWith(
        status: ContactStatus.accepted,
        permissions: permissions,
      );
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> rejectRequest(String contactId) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 400));
    _contacts.removeWhere((c) => c.id == contactId);
    
    _isLoading = false;
    notifyListeners();
  }

  // Phase 4: Add Contact — nhận tags thay vì role cứng
  Future<void> sendRequest(String email, List<ContactTag> tags) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    final primaryLabel = tags.isNotEmpty ? tags.first.name : 'Chưa phân loại';

    _contacts.add(LinkedContactModel(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      displayName: email.split('@').first,
      email: email,
      tags: tags,
      primaryRelationshipLabel: primaryLabel,
      role: ContactRole.unclassified,
      status: ContactStatus.pending,
      isIncomingRequest: false, // Outgoing
    ));

    _isLoading = false;
    notifyListeners();
  }

  // Phase 5: Detail updates
  Future<void> updateContactPermissions(String contactId, List<String> newPermissions) async {
    final index = _contacts.indexWhere((c) => c.id == contactId);
    if (index != -1) {
      _contacts[index] = _contacts[index].copyWith(permissions: newPermissions);
      notifyListeners();
    }
  }

  Future<void> updateContactTags(String contactId, List<ContactTag> newTags) async {
    final index = _contacts.indexWhere((c) => c.id == contactId);
    if (index != -1) {
      _contacts[index] = _contacts[index].copyWith(
        tags: newTags,
        // Cập nhật luôn primary label nếu tags thay đổi và có ít nhất 1 tag
        primaryRelationshipLabel: newTags.isNotEmpty ? newTags.first.name : null,
      );
      notifyListeners();
    }
  }

  Future<void> updateContactPrimaryLabel(String contactId, String newLabel) async {
    final index = _contacts.indexWhere((c) => c.id == contactId);
    if (index != -1) {
      _contacts[index] = _contacts[index].copyWith(primaryRelationshipLabel: newLabel);
      notifyListeners();
    }
  }

  Future<void> updateContactRole(String contactId, ContactRole newRole) async {
    final index = _contacts.indexWhere((c) => c.id == contactId);
    if (index != -1) {
      _contacts[index] = _contacts[index].copyWith(role: newRole);
      notifyListeners();
    }
  }

  Future<void> unlinkContact(String contactId) async {
    _contacts.removeWhere((c) => c.id == contactId);
    notifyListeners();
  }

  LinkedContactModel? getContactById(String id) {
    try {
      return _contacts.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // Phase 6: Sync to FamilyDashboard
  List<FamilyProfileSnapshot> generateDashboardSnapshots() {
    return acceptedContacts.map((c) {
      // Mock vital variety dựa theo id
      bool isSos = c.id == '2'; // Mock 'Mẹ' có SOS
      String risk = c.id == '3' ? 'high' : 'low';
      if (c.id == '1') risk = 'medium';
      bool pinned = c.id == '1' || c.id == '3'; // Bố và Bác sĩ là ưu tiên

      // Mock BP: Mẹ tăng nhẹ, Bác sĩ cao, còn lại bình thường
      int? sys, dia;
      if (c.id == '2') { sys = 138; dia = 88; }
      else if (c.id == '3') { sys = 145; dia = 92; }
      else { sys = 118; dia = 76; }

      // Mock Temp: Mẹ sốt nhẹ, còn lại bình thường
      double temp = c.id == '2' ? 37.8 : 36.5 + (c.id.hashCode % 3) * 0.1;

      // Mock sleep data
      int sleepMin;
      String sleepQual;
      if (c.id == '1') { sleepMin = 480; sleepQual = 'Tốt'; }
      else if (c.id == '2') { sleepMin = 330; sleepQual = 'Kém'; }
      else { sleepMin = 420; sleepQual = 'Trung bình'; }

      // Mock health score 7 ngày
      int score;
      String scoreLevel;
      if (c.id == '1') { score = 72; scoreLevel = 'Trung bình'; }
      else if (c.id == '2') { score = 48; scoreLevel = 'Thấp'; }
      else { score = 85; scoreLevel = 'Cao'; }

      return FamilyProfileSnapshot(
        id: c.id,
        name: c.displayName.split(' - ').last,
        relation: c.primaryRelationshipLabel.isNotEmpty ? c.primaryRelationshipLabel : c.role.label,
        heartRate: 70 + (c.id.hashCode % 30),
        spo2: 95 + (c.id.hashCode % 5),
        bloodPressureSystolic: sys,
        bloodPressureDiastolic: dia,
        bodyTemperature: temp,
        riskLevel: risk,
        isSosActive: isSos,
        sosId: isSos ? 'sos-mock-${c.id}-001' : null,
        isPinned: pinned,
        hasViewVitalsPermission: c.permissions.contains('can_view_vitals'),
        lastUpdated: DateTime.now().subtract(Duration(minutes: c.hashCode.abs() % 10)),
        specialNote: isSos ? 'Cần hỗ trợ ngay!' : (risk == 'medium' ? 'Huyết áp cần theo dõi' : ''),
        sleepDurationMinutes: sleepMin,
        sleepQuality: sleepQual,
        healthScore7Days: score,
        healthScoreLevel: scoreLevel,
      );
    }).toList();
  }
}
