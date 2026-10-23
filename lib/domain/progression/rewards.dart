import '../parcels/models.dart';

/// Points for a first real solve. Replays and skips award nothing.
int masteryXp(Difficulty difficulty, {required bool perfect}) {
  final base = switch (difficulty) {
    Difficulty.beginner => 8,
    Difficulty.easy => 12,
    Difficulty.medium => 20,
    Difficulty.hard => 36,
    Difficulty.expert => 55,
    Difficulty.master => 80,
    Difficulty.grandmaster => 120,
  };
  return perfect ? base + (base ~/ 2) : base;
}

const weeklyClearBonus = 50;
const chapterClearBonus = 40;

String chapterKey(String mode, String packId) => '$mode:$packId';

class BoardStyle {
  const BoardStyle(this.id, this.title, this.xpRequired);

  final String id;
  final String title;
  final int xpRequired;
}

const boardStyles = <BoardStyle>[
  BoardStyle('midnight', 'Midnight grid', 0),
  BoardStyle('ivory', 'Ivory ink', 30),
  BoardStyle('pine', 'Pine line', 80),
  BoardStyle('archive', 'Archive gold', 160),
];

bool styleUnlocked(int xp, String id) {
  for (final style in boardStyles) {
    if (style.id == id) return xp >= style.xpRequired;
  }
  return false;
}

/// Monday of the local week, so the same week key is stable inside that week.
String weekKey(DateTime local) {
  final day = DateTime(local.year, local.month, local.day);
  final monday = day.subtract(Duration(days: day.weekday - 1));
  final month = monday.month.toString().padLeft(2, '0');
  final date = monday.day.toString().padLeft(2, '0');
  return '${monday.year}-$month-$date';
}

/// Three campaign ids for this week. The same week and catalog always agree.
List<String> weeklyLevelIds(String week, List<String> ids) {
  if (ids.isEmpty) return const [];
  var hash = 0;
  for (final code in week.codeUnits) {
    hash = (hash * 33 + code) & 0x7fffffff;
  }
  final picked = <String>[];
  var cursor = hash % ids.length;
  while (picked.length < 3 && picked.length < ids.length) {
    final id = ids[cursor % ids.length];
    if (!picked.contains(id)) picked.add(id);
    cursor += 17;
  }
  return picked;
}

String completionBody({
  required String time,
  required int hints,
  required Difficulty difficulty,
  required int xpGained,
  int? bestMs,
}) {
  final perfect = hints == 0;
  final best = bestMs == null ? '' : ' Best ${_clock(bestMs)}.';
  final award = xpGained == 0
      ? ' Replaying does not award more points.'
      : ' $xpGained mastery points for a ${difficulty.label} solve.';
  final hintLine = perfect
      ? 'No hints used.'
      : 'Hints used: $hints. This solve is not perfect.';
  return 'Time $time. $hintLine$award$best';
}

String _clock(int ms) {
  final total = ms ~/ 1000;
  final minutes = (total ~/ 60).toString().padLeft(2, '0');
  final seconds = (total % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
