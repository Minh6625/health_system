// ignore_for_file: avoid_print
import 'lib/features/family/models/linked_contact_model.dart'; import 'dart:convert'; void main() { var json = jsonDecode('''{"id": "7", "displayName": "Mih", "email": "tran", "tags": [{"id": "doctor", "name": "Bác sĩ"}]}'''); var m = LinkedContactModel.fromJson(json); print(m.tags); }
