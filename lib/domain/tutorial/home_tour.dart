import '../campaign/catalog.dart';
import '../campaign/save_game.dart';
import 'progress.dart';

/// Home-screen guide. Mode lessons keep their existing ids.
const homeIntroId = 'home_intro';

/// First published home tour. Later tours should use a new id.
const currentOnboardingVersion = 1;

const modeLessonIds = ['parcels', 'trace', 'inks', 'threads'];

bool isModeLesson(String id) => modeLessonIds.contains(id);

/// True when this save already has play data from before the home tour.
bool hasCampaignProgress(SaveGame save) {
  return save.parcelRecords.isNotEmpty ||
      save.threadRecords.isNotEmpty ||
      save.traceRecords.isNotEmpty ||
      save.inkRecords.isNotEmpty ||
      save.parcelsStarted.isNotEmpty ||
      save.threadsStarted.isNotEmpty ||
      save.tracesStarted.isNotEmpty ||
      save.inksStarted.isNotEmpty ||
      save.lastPlayed != null ||
      save.xp > 0 ||
      save.dailyCompleted.isNotEmpty ||
      save.weeklySolved.isNotEmpty ||
      modeLessonIds.any((id) => tutorialSettled(save.tutorialsSeen, id));
}

/// Brand-new guests see the home tour on their own.
bool shouldAutoStartHomeTour(SaveGame save) {
  return !tutorialSettled(save.tutorialsSeen, homeIntroId) &&
      !hasCampaignProgress(save);
}

/// Players who already have progress get a small invitation, not a blocker.
bool shouldOfferHomeTour(SaveGame save) {
  return !tutorialSettled(save.tutorialsSeen, homeIntroId) &&
      hasCampaignProgress(save);
}

ParcelLevel? parcelLesson(GameCatalog catalog) {
  for (final level in catalog.parcels) {
    if (level.tutorial) return level;
  }
  if (catalog.parcels.isEmpty) return null;
  return catalog.parcels.first;
}

TraceLevel? traceLesson(GameCatalog catalog) {
  for (final level in catalog.traces) {
    if (level.tutorial) return level;
  }
  if (catalog.traces.isEmpty) return null;
  return catalog.traces.first;
}

InkLevel? inkLesson(GameCatalog catalog) {
  for (final level in catalog.inks) {
    if (level.tutorial) return level;
  }
  if (catalog.inks.isEmpty) return null;
  return catalog.inks.first;
}

ThreadLevel? threadLesson(GameCatalog catalog) {
  for (final level in catalog.threads) {
    if (level.tutorial) return level;
  }
  if (catalog.threads.isEmpty) return null;
  return catalog.threads.first;
}
