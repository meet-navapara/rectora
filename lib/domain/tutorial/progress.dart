/// Tutorial ids stay in the existing `tutorialsSeen` set.
///
/// A completed lesson is stored as the mode id, for example `parcels`.
/// A skipped lesson is stored as `parcels:skipped`. Campaign records are not
/// part of either value.
bool tutorialSettled(Set<String> seen, String mode) {
  return seen.contains(mode) || seen.contains('$mode:skipped');
}

bool tutorialCompleted(Set<String> seen, String mode) {
  return seen.contains(mode);
}
