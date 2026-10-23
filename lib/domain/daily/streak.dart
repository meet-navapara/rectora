import '../common/date_key.dart';

/// Consecutive local dates ending today, or ending yesterday when today is
/// still open. A gap of two or more days ends the streak. Completing an older
/// date extends the streak only when that date connects to today or yesterday.
int currentStreak(Set<String> completed, DateTime today) {
  if (completed.isEmpty) return 0;
  final todayKey = dateKey(today);
  final yesterdayKey = dateKey(
    DateTime(today.year, today.month, today.day - 1),
  );
  if (!completed.contains(todayKey) && !completed.contains(yesterdayKey)) {
    return 0;
  }
  var cursor = completed.contains(todayKey)
      ? DateTime(today.year, today.month, today.day)
      : DateTime(today.year, today.month, today.day - 1);
  var count = 0;
  while (completed.contains(dateKey(cursor))) {
    count++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return count;
}

int longestStreak(Set<String> completed) {
  if (completed.isEmpty) return 0;
  final keys = completed.toList()..sort();
  var best = 1;
  var run = 1;
  for (var i = 1; i < keys.length; i++) {
    if (isNextCivilDay(keys[i - 1], keys[i])) {
      run++;
      if (run > best) best = run;
    } else {
      run = 1;
    }
  }
  return best;
}

enum DailyDayState { completed, todayOpen, earlierOpen, future, outside }

DailyDayState dailyState({
  required DateTime day,
  required DateTime today,
  required Set<String> completed,
}) {
  final dayNumber = civilDayNumber(day);
  final todayNumber = civilDayNumber(today);
  if (completed.contains(dateKey(day))) return DailyDayState.completed;
  if (dayNumber > todayNumber) return DailyDayState.future;
  if (dayNumber == todayNumber) return DailyDayState.todayOpen;
  return DailyDayState.earlierOpen;
}
