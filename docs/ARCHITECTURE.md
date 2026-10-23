# Rectora architecture

Rectora is a single Flutter app. Puzzle rules do not live in widgets.

## Domain

- `lib/domain/parcels` validates and solves rectangle covers. A placement is accepted only when the rectangle stays on the board, has a positive area, contains exactly one clue, matches that clue, and does not overlap an accepted region. Easy puzzles stop there. Medium puzzles also require every remaining clue to have at least one candidate. Hard, expert, and master puzzles run the solver on commit and refuse a move that leaves zero solutions. A search that hits its node budget does not reject the move and does not invent a hint.
- `lib/domain/trace` is a single ordered path. The path starts on checkpoint 1, visits the numbered checkpoints in order, stays on orthogonal neighbors, and does not revisit a cell or enter a blocked cell. Completion means the path length equals the number of open cells and the path ends on the last checkpoint.
- `lib/domain/ink` fills the board with edge-connected regions. A region contains exactly one clue and has a size equal to that clue. Regions may bend. They cannot overlap, and every cell belongs to one region.
- `lib/domain/threads` is a separate mode. Paths are orthogonal. A diagonal drag is not interpolated into a diagonal step. Paths cannot cross, enter a blocked cell, or use another pair's endpoint. Completion means every open cell belongs to exactly one finished path.
- `lib/domain/campaign` owns the versioned catalog, the versioned save, unlock order, and derived statistics. Unlock is computed from the previous level being finished. It is not a stored "max level" that can drift.
- `lib/domain/daily` and `date_key.dart` use civil year/month/day counts. The daily index is `days since 2026-01-01` modulo the shipped pool. The same local date selects the same puzzle on every install of this schedule. A missed day ends the streak. Completing an older date extends the streak only when it connects to today or yesterday. Completing a date twice does not award it again.
- Daily attempts are stored as `daily@YYYY-MM-DD`. They are not campaign level ids, so they do not change campaign unlocks or the campaign solved count.

## Catalogs

`tool/generate_campaign.dart` builds a complete partition, writes clue values from the regions, removes the borders, and keeps the puzzle only when the solver finds exactly one solution. `tool/generate_modes.dart` does the same for Trace and Inks. The shipped files are `assets/levels/parcels.json`, `traces.json`, `inks.json`, `threads.json`, and `daily.json`, format version 1. `proveCatalogUnique` repeats that check in tests. App startup checks shape and exact cover only.

Save format stays at version 1. Trace and Inks progress are optional maps, so an older save still loads. The first 20 parcel levels stored as easy are shown as beginner. Their rules do not change.

## Application

`RectoraApp` loads the catalogs and a `KeyValueStore`. Production uses `shared_preferences` under `rectora.save.v1`. Tests use `MemoryStore`. A save that cannot be decoded is left in place and is not erased unless the player confirms it.

`RectoraController` is the only writer of the save. Screens read it through `RectoraScope`. Boards paint from session state; they do not decide whether a move is legal.

## What is intentionally absent

There is no account, backend, Firebase, analytics SDK, or advertising SDK. Skip is a free, confirmed action. Sound is local WAV playback. Haptics use the platform vibrator. Neither feature sends data.

Release signing reads `android/key.properties` when that file exists. The repository does not contain a keystore or passwords.
