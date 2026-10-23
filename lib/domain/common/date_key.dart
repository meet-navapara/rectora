/// Local calendar dates as `YYYY-MM-DD`, without using [Duration.inDays].
///
/// [DateTime.difference] across a daylight-saving transition is not a whole
/// number of 24-hour periods, so streak and daily-puzzle math uses the
/// year/month/day fields converted to a UTC civil day count.
library;

String dateKey(DateTime local) {
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime parseDateKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) {
    throw FormatException('Expected YYYY-MM-DD, got $key');
  }
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  final day = int.parse(parts[2]);
  final local = DateTime(year, month, day);
  if (local.year != year || local.month != month || local.day != day) {
    throw FormatException('Not a real calendar date: $key');
  }
  return local;
}

/// Days since 1970-01-01 for the civil date, ignoring the clock and timezone.
int civilDayNumber(DateTime local) {
  final utc = DateTime.utc(local.year, local.month, local.day);
  return utc.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
}

int civilDaysBetween(DateTime earlier, DateTime later) {
  return civilDayNumber(later) - civilDayNumber(earlier);
}

bool isNextCivilDay(String earlierKey, String laterKey) {
  return civilDaysBetween(parseDateKey(earlierKey), parseDateKey(laterKey)) ==
      1;
}

/// Index into a daily pool. The same local date always maps to the same index
/// for a given pool length and epoch. This is a shared schedule only for
/// installs that ship the same pool; it is not coordinated by a server.
int dailyPoolIndex(DateTime local, int poolLength, {DateTime? epoch}) {
  if (poolLength <= 0) {
    throw ArgumentError.value(poolLength, 'poolLength');
  }
  final origin = epoch ?? DateTime(2026, 1, 1);
  final delta = civilDaysBetween(origin, local);
  final mod = delta % poolLength;
  return mod < 0 ? mod + poolLength : mod;
}

/// Sunday-first month grid. Leading and trailing blanks are null.
List<DateTime?> monthCells(int year, int month) {
  final first = DateTime(year, month, 1);
  final leading = first.weekday % 7;
  final days = DateTime(year, month + 1, 0).day;
  final cells = <DateTime?>[
    for (var i = 0; i < leading; i++) null,
    for (var day = 1; day <= days; day++) DateTime(year, month, day),
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return cells;
}
