class Relationship {
  final int id;
  final int patientId;
  final String patientName;
  final String patientEmail;
  final int caregiverId;
  final String caregiverName;
  final String caregiverEmail;
  final String relationshipType;
  final String status;

  Relationship({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientEmail,
    required this.caregiverId,
    required this.caregiverName,
    required this.caregiverEmail,
    required this.relationshipType,
    required this.status,
  });

  factory Relationship.fromJson(Map<String, dynamic> json) {
    return Relationship(
      id: json['id'],
      patientId: json['patient_id'],
      patientName: json['patient_name'],
      patientEmail: json['patient_email'],
      caregiverId: json['caregiver_id'],
      caregiverName: json['caregiver_name'],
      caregiverEmail: json['caregiver_email'],
      relationshipType: json['relationship_type'],
      status: json['status'],
    );
  }
}
