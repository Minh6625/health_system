import 'package:flutter/services.dart';

/// Shared validation rules for the user-facing "device name" field used by
/// the rename dialog (`device_screen.dart`) and the configure screen
/// (`device_configure_screen.dart`). Both call sites previously validated
/// independently — or not at all — which is how QA caught a rename dialog
/// that silently accepted 500-character names and any special character.
///
/// The numbers here mirror the backend Pydantic schema
/// `DeviceUpdateRequest.device_name`
/// (`backend/app/schemas/device.py:39`). If the backend cap changes,
/// update [kDeviceNameMaxLength] so the client doesn't lag behind and
/// surface 422s from the server instead of inline errors.

/// Maximum number of characters accepted for a device name. Mirrors the
/// backend `Field(min_length=1, max_length=100)`.
const int kDeviceNameMaxLength = 100;

/// Character class allowed inside a device name. Includes any Unicode
/// letter (so Vietnamese diacritics and other locales pass through), any
/// digit, spaces, and a small set of safe punctuation (`_ - . ( )`).
///
/// Special characters QA flagged — `< > { } [ ] \ / | * ? " ' % $ # @ ^ &
/// ~ = + ` ` — are intentionally excluded so they cannot enter the device
/// name in the first place.
final RegExp kDeviceNameAllowedChars = RegExp(
  r'[\p{L}\p{N} _\-.()]',
  unicode: true,
);

/// Formatters that should be attached to every TextField/TextFormField
/// that edits a device name. Combines the allow-list above with a hard
/// length cap so the UI cannot get out of sync with the backend.
List<TextInputFormatter> deviceNameInputFormatters() => [
      FilteringTextInputFormatter.allow(kDeviceNameAllowedChars),
      LengthLimitingTextInputFormatter(kDeviceNameMaxLength),
    ];

/// Returns a Vietnamese error message for [value], or null if it is a
/// valid device name. Centralised so both call sites give the same
/// feedback text for empty / too-long input.
String? validateDeviceName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'Tên thiết bị không được để trống.';
  }
  if (trimmed.length > kDeviceNameMaxLength) {
    return 'Tên thiết bị không được vượt quá '
        '$kDeviceNameMaxLength ký tự.';
  }
  return null;
}
