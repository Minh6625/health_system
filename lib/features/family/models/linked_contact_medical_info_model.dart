/// P-4: read-only view of a patient's self-filled medical profile, surfaced
/// to a caregiver when ``can_view_medical_info`` is granted on the matching
/// relationship row. Mirrors backend ``LinkedContactMedicalInfoResponse``.
///
/// Why a separate model from ``UserProfileModel``: the caregiver only sees a
/// strict subset (no email, phone, password, etc.) and the API returns a
/// flatter shape. Keeping them apart makes the privacy boundary explicit at
/// the type level — you can't accidentally pass a ``UserProfileModel`` (with
/// PII) into a caregiver-facing widget.
class LinkedContactMedicalInfoModel {
  /// Owning user's id (the patient whose data this is).
  final int contactId;
  final String displayName;

  // Optional medical fields. ``null`` means the patient hasn't filled this
  // entry, NOT that we lack permission — gating happens at the route level
  // (403). Distinguishing "not filled" from "denied" matters because the
  // UI shows a friendly empty hint vs. a hard permission lock.
  final String? bloodType;
  final int? heightCm;
  final double? weightKg;

  /// Always non-null lists; the backend coerces legacy NULL columns to ``[]``.
  final List<String> medications;
  final List<String> allergies;
  final List<String> medicalConditions;

  const LinkedContactMedicalInfoModel({
    required this.contactId,
    required this.displayName,
    this.bloodType,
    this.heightCm,
    this.weightKg,
    this.medications = const [],
    this.allergies = const [],
    this.medicalConditions = const [],
  });

  factory LinkedContactMedicalInfoModel.fromJson(Map<String, dynamic> json) {
    return LinkedContactMedicalInfoModel(
      contactId: (json['contact_id'] as num).toInt(),
      displayName: json['display_name'] as String? ?? 'Người dùng',
      bloodType: json['blood_type'] as String?,
      // ``height_cm`` is a smallint server-side; double-coerce defensively
      // so a malformed string doesn't crash the parse.
      heightCm: (json['height_cm'] as num?)?.toInt(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      medications: _toStringList(json['medications']),
      allergies: _toStringList(json['allergies']),
      medicalConditions: _toStringList(json['medical_conditions']),
    );
  }

  /// Defensive list coercion: backend always returns ``List<String>`` after
  /// the ``coerce`` in the service, but a future contract drift (e.g. JSONB
  /// returning ``null``) shouldn't crash deserialisation.
  static List<String> _toStringList(Object? value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList(growable: false);
    }
    return const <String>[];
  }

  /// True when the patient hasn't filled in any medical fields yet. UI
  /// uses this to show a single "Người này chưa cập nhật hồ sơ y tế."
  /// banner instead of multiple empty sections.
  bool get isEmpty =>
      (bloodType == null || bloodType!.isEmpty) &&
      heightCm == null &&
      weightKg == null &&
      medications.isEmpty &&
      allergies.isEmpty &&
      medicalConditions.isEmpty;
}
