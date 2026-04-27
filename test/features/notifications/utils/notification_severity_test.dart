import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/notifications/utils/notification_severity.dart';

Map<String, dynamic> _item(String alertType) => {'alert_type': alertType};

void main() {
  group('notificationTypeBucket', () {
    test('SOS / manual / fall_* → sos bucket', () {
      expect(notificationTypeBucket(_item('sos')), NotificationTypeFilter.sos);
      expect(
        notificationTypeBucket(_item('manual')),
        NotificationTypeFilter.sos,
      );
      expect(
        notificationTypeBucket(_item('fall_detected')),
        NotificationTypeFilter.sos,
      );
    });

    test('medication_* → medication bucket', () {
      expect(
        notificationTypeBucket(_item('medication_missed')),
        NotificationTypeFilter.medication,
      );
      expect(
        notificationTypeBucket(_item('medication_reminder')),
        NotificationTypeFilter.medication,
      );
    });

    test('risk_* and *_critical → health bucket', () {
      expect(
        notificationTypeBucket(_item('risk_high')),
        NotificationTypeFilter.health,
      );
      expect(
        notificationTypeBucket(_item('risk_critical')),
        NotificationTypeFilter.health,
      );
      expect(
        notificationTypeBucket(_item('heart_rate_critical')),
        NotificationTypeFilter.health,
      );
      expect(
        notificationTypeBucket(_item('spo2_critical')),
        NotificationTypeFilter.health,
      );
    });

    test('unknown / general → system bucket', () {
      expect(
        notificationTypeBucket(_item('general')),
        NotificationTypeFilter.system,
      );
      expect(
        notificationTypeBucket(_item('')),
        NotificationTypeFilter.system,
      );
      expect(
        notificationTypeBucket(<String, dynamic>{}),
        NotificationTypeFilter.system,
      );
    });
  });

  group('notificationLeadingIcon', () {
    test('returns dedicated icons per bucket', () {
      expect(notificationLeadingIcon('sos'), Icons.emergency_share_rounded);
      expect(
        notificationLeadingIcon('fall_detected'),
        Icons.warning_amber_rounded,
      );
      expect(
        notificationLeadingIcon('medication_missed'),
        Icons.medication_rounded,
      );
      expect(
        notificationLeadingIcon('risk_high'),
        Icons.monitor_heart_rounded,
      );
      expect(
        notificationLeadingIcon('heart_rate_critical'),
        Icons.monitor_heart_rounded,
      );
      expect(
        notificationLeadingIcon('general'),
        Icons.notifications_active_rounded,
      );
    });
  });

  group('notificationLeadingIconBg', () {
    test('SOS / fall / risk_critical share the critical color', () {
      final critical = notificationLeadingIconBg('sos');
      expect(notificationLeadingIconBg('manual'), critical);
      expect(notificationLeadingIconBg('fall_detected'), critical);
      expect(notificationLeadingIconBg('risk_critical'), critical);
    });

    test('non-critical risks fall back to the warning color', () {
      final warning = notificationLeadingIconBg('risk_high');
      expect(notificationLeadingIconBg('heart_rate_critical'), warning);
      expect(notificationLeadingIconBg('spo2_critical'), warning);
      // sanity: warning is distinct from sos color
      expect(warning != notificationLeadingIconBg('sos'), isTrue);
    });
  });

  group('notificationDateBucketOf', () {
    test('today (midnight to now) is in the today bucket', () {
      final now = DateTime.now();
      final earlierToday = DateTime(
        now.year,
        now.month,
        now.day,
        1,
        0,
      );
      expect(
        notificationDateBucketOf(earlierToday),
        NotificationDateBucket.today,
      );
    });

    test('one day ago is yesterday', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(
        notificationDateBucketOf(yesterday),
        NotificationDateBucket.yesterday,
      );
    });

    test('2..6 days ago is thisWeek', () {
      for (final days in [2, 4, 6]) {
        final ts = DateTime.now().subtract(Duration(days: days));
        expect(
          notificationDateBucketOf(ts),
          NotificationDateBucket.thisWeek,
          reason: '$days days ago should be thisWeek',
        );
      }
    });

    test('7+ days ago is older', () {
      final old = DateTime.now().subtract(const Duration(days: 30));
      expect(
        notificationDateBucketOf(old),
        NotificationDateBucket.older,
      );
    });
  });

  group('notificationDateBucketLabel / notificationTypeFilterLabel', () {
    test('returns Vietnamese labels', () {
      expect(
        notificationDateBucketLabel(NotificationDateBucket.today),
        'Hôm nay',
      );
      expect(
        notificationDateBucketLabel(NotificationDateBucket.yesterday),
        'Hôm qua',
      );
      expect(
        notificationDateBucketLabel(NotificationDateBucket.thisWeek),
        'Tuần này',
      );
      expect(
        notificationDateBucketLabel(NotificationDateBucket.older),
        'Trước đó',
      );

      expect(
        notificationTypeFilterLabel(NotificationTypeFilter.all),
        'Tất cả',
      );
      expect(
        notificationTypeFilterLabel(NotificationTypeFilter.sos),
        'Khẩn cấp',
      );
      expect(
        notificationTypeFilterLabel(NotificationTypeFilter.health),
        'Sức khoẻ',
      );
      expect(
        notificationTypeFilterLabel(NotificationTypeFilter.medication),
        'Thuốc',
      );
      expect(
        notificationTypeFilterLabel(NotificationTypeFilter.system),
        'Hệ thống',
      );
    });
  });
}
