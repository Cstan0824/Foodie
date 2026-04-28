class AppTime {
  AppTime._();

  static const Duration gmt8Offset = Duration(hours: 8);
  static final RegExp _timezoneSuffixPattern = RegExp(r'(Z|[+-]\d{2}:\d{2})$');
  static const List<String> _shortMonths = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static DateTime nowUtc() => DateTime.now().toUtc();

  static DateTime nowGmt8() => toGmt8(nowUtc());

  static DateTime ensureUtc(DateTime value) =>
      value.isUtc ? value : value.toUtc();

  static DateTime toGmt8(DateTime value) => ensureUtc(value).add(gmt8Offset);

  /// Parses a server timestamp as UTC.
  ///
  /// If the raw string omits a timezone suffix, it is still treated as UTC so
  /// relative time calculations remain consistent across devices.
  static DateTime? parseUtc(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return ensureUtc(raw);

    final text = raw.toString().trim();
    if (text.isEmpty) return null;

    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;

    if (_timezoneSuffixPattern.hasMatch(text)) {
      return parsed.toUtc();
    }

    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }

  static Duration differenceFromNowGmt8(DateTime value) {
    final difference = nowGmt8().difference(toGmt8(value));
    return difference.isNegative ? Duration.zero : difference;
  }

  static int dayDifferenceFromNowGmt8(DateTime value) {
    return differenceFromNowGmt8(value).inDays;
  }

  static String formatNumericDayMonth(DateTime value) {
    final gmt8 = toGmt8(value);
    return '${gmt8.day}/${gmt8.month}';
  }

  static String formatShortMonthDay(DateTime value) {
    final gmt8 = toGmt8(value);
    return '${gmt8.day} ${_shortMonths[gmt8.month - 1]}';
  }
}
