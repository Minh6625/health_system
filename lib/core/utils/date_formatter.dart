class DateFormatter {
  static DateTime toVietnamTime(DateTime date) {
    final utcDate = date.isUtc ? date : date.toUtc();
    return utcDate.add(const Duration(hours: 7));
  }

  static String formatDdMmYyyy(DateTime date) {
    final vietnamDate = toVietnamTime(date);
    final day = vietnamDate.day.toString().padLeft(2, '0');
    final month = vietnamDate.month.toString().padLeft(2, '0');
    final year = vietnamDate.year.toString();
    return '$day/$month/$year';
  }

  const DateFormatter._();
}
