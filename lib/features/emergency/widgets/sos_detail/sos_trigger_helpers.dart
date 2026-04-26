import 'package:flutter/material.dart';

/// Shared trigger-type helpers used by the SOS-detail widgets.
///
/// Backend stores the SOS trigger type as a free-form string
/// (`fall_detected`, `manual`, `vital_critical`, plus a default fallback).
/// The patient-header widget renders both the icon and the label, and the
/// (currently unused) trigger-info card and any future caregiver surfaces
/// will need the same mapping. Centralising the lookups here keeps the
/// translation table in one place so a new trigger value only has to be
/// added once.
IconData triggerIconFor(String triggerType) {
  switch (triggerType) {
    case 'fall_detected':
      return Icons.arrow_downward;
    case 'manual':
      return Icons.touch_app;
    case 'vital_critical':
      return Icons.error;
    default:
      return Icons.emergency;
  }
}

String triggerLabelFor(String triggerType) {
  switch (triggerType) {
    case 'fall_detected':
      return 'Phát hiện té ngã';
    case 'manual':
      return 'Kích hoạt thủ công';
    case 'vital_critical':
      return 'Chỉ số sinh tồn tới hạn';
    default:
      return 'SOS khẩn cấp';
  }
}
