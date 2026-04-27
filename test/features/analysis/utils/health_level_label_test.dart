import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/analysis/utils/health_level_label.dart';

void main() {
  group('vietnameseHealthLevel', () {
    test('maps backend stable/good/low/high to "Ổn định"', () {
      expect(vietnameseHealthLevel('stable'), 'Ổn định');
      expect(vietnameseHealthLevel('good'), 'Ổn định');
      expect(vietnameseHealthLevel('low'), 'Ổn định');
      expect(vietnameseHealthLevel('high'), 'Ổn định');
      expect(vietnameseHealthLevel('STABLE'), 'Ổn định');
    });

    test('maps watch/medium/moderate/warning to "Cần theo dõi"', () {
      expect(vietnameseHealthLevel('watch'), 'Cần theo dõi');
      expect(vietnameseHealthLevel('medium'), 'Cần theo dõi');
      expect(vietnameseHealthLevel('moderate'), 'Cần theo dõi');
      expect(vietnameseHealthLevel('warning'), 'Cần theo dõi');
    });

    test('maps critical/poor to "Nguy hiểm"', () {
      expect(vietnameseHealthLevel('critical'), 'Nguy hiểm');
      expect(vietnameseHealthLevel('poor'), 'Nguy hiểm');
    });

    test('returns null for unknown / empty / null inputs so callers can fall back', () {
      expect(vietnameseHealthLevel(null), isNull);
      expect(vietnameseHealthLevel(''), isNull);
      expect(vietnameseHealthLevel('   '), isNull);
      expect(vietnameseHealthLevel('something_unexpected'), isNull);
    });
  });
}
