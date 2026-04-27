import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/notifications/utils/notification_severity.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';

void main() {
  group('notification risk severity helpers', () {
    test('normalize risk severities to low medium critical', () {
      expect(normalizeNotificationSeverityLabel('low'), 'low');
      expect(normalizeNotificationSeverityLabel('moderate'), 'medium');
      expect(normalizeNotificationSeverityLabel('high'), 'medium');
      expect(normalizeNotificationSeverityLabel('critical'), 'critical');
      expect(normalizeNotificationSeverityLabel('unknown'), isNull);
    });

    test('severity label and color are normalized for user-facing UI', () {
      expect(notificationSeverityLabel('low'), 'Nhẹ');
      expect(notificationSeverityLabel('medium'), 'Cảnh báo');
      expect(notificationSeverityLabel('high'), 'Cảnh báo');
      expect(notificationSeverityLabel('critical'), 'Nguy hiểm');
      expect(notificationSeverityLabel(null), 'Nhẹ');
      expect(notificationSeverityColor('low'), AppColors.success);
      expect(notificationSeverityColor('medium'), AppColors.warning);
      expect(notificationSeverityColor('critical'), AppColors.critical);
      expect(notificationSeverityColor('high'), AppColors.warning);
    });
  });
}
