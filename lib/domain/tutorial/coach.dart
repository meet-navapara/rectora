import '../parcels/models.dart';
import 'progress.dart';

enum GuideKind { intro, demonstrate, perform, practice }

enum CoachPhase {
  intro,
  demonstrating,
  waitingForPlayer,
  successFeedback,
  correctiveHint,
  practice,
  completed,
  skipped,
}

/// One beat of a gameplay lesson. [cells] are board indexes, row-major.
class GuideStep {
  const GuideStep({
    required this.kind,
    required this.title,
    required this.body,
    this.cells = const [],
    this.orderedPrefix = false,
  });

  final GuideKind kind;
  final String title;
  final String body;
  final List<int> cells;

  /// Trace keeps every cell that is still a prefix of [cells].
  /// The step finishes only when the path equals [cells].
  final bool orderedPrefix;
}

class PlayCoach {
  PlayCoach(this.steps, {required this.hintCopy})
    : assert(steps.isNotEmpty),
      assert(hintCopy.length == 3);

  final List<GuideStep> steps;
  final List<String> hintCopy;
  var index = 0;
  var phase = CoachPhase.intro;
  var correction = '';
  var hintTier = 0;
  var pointerVisible = true;

  GuideStep get step => steps[index];

  /// The lesson is over, by finishing or skipping, and the board is free.
  bool get finished =>
      phase == CoachPhase.completed || phase == CoachPhase.skipped;

  /// True while the board waits for the player to read or watch. A finished
  /// or skipped lesson never locks the board.
  bool get locksInput =>
      phase == CoachPhase.intro ||
      phase == CoachPhase.demonstrating ||
      phase == CoachPhase.successFeedback;

  /// True while a lesson step limits what may be erased or redrawn.
  bool get restrictsEditing => !finished && phase != CoachPhase.practice;

  bool get expectsMove =>
      phase == CoachPhase.waitingForPlayer ||
      phase == CoachPhase.correctiveHint;

  String get hintText => hintTier == 0 ? '' : hintCopy[hintTier - 1];

  void hidePointer() => pointerVisible = false;

  void continuePressed() {
    if (phase == CoachPhase.intro || phase == CoachPhase.successFeedback) {
      _activate(index + 1);
      return;
    }
    if (phase == CoachPhase.correctiveHint) {
      phase = CoachPhase.waitingForPlayer;
      pointerVisible = true;
    }
  }

  /// The guide light has finished. The same squares stay empty for the player.
  void demonstrationFinished() {
    if (phase != CoachPhase.demonstrating) return;
    phase = CoachPhase.waitingForPlayer;
    pointerVisible = false;
    correction = '';
  }

  /// True when [cells] may stay on the board.
  bool judge(List<int> cells) {
    if (phase == CoachPhase.practice || phase == CoachPhase.completed) {
      return true;
    }
    final guided =
        step.kind == GuideKind.perform || step.kind == GuideKind.demonstrate;
    if (!expectsMove || !guided) return false;
    if (step.orderedPrefix) {
      if (_same(cells, step.cells)) {
        phase = CoachPhase.successFeedback;
        pointerVisible = false;
        return true;
      }
      if (_isPrefix(step.cells, cells)) return true;
      correction = 'Stay on the glowing squares, in order.';
      phase = CoachPhase.correctiveHint;
      pointerVisible = true;
      return false;
    }
    final got = cells.toSet();
    final want = step.cells.toSet();
    if (got.length == want.length && want.containsAll(got)) {
      phase = CoachPhase.successFeedback;
      pointerVisible = false;
      return true;
    }
    correction = 'That is not the glowing move.';
    phase = CoachPhase.correctiveHint;
    pointerVisible = true;
    return false;
  }

  void skip() => phase = CoachPhase.skipped;

  void replay() {
    index = 0;
    phase = CoachPhase.intro;
    correction = '';
    hintTier = 0;
    pointerVisible = true;
  }

  void bumpHint() {
    if (hintTier < 3) hintTier++;
  }

  void markSolved() {
    if (phase == CoachPhase.skipped) return;
    phase = CoachPhase.completed;
    pointerVisible = false;
  }

  void _activate(int next) {
    if (next >= steps.length) {
      phase = CoachPhase.completed;
      pointerVisible = false;
      return;
    }
    index = next;
    correction = '';
    hintTier = 0;
    pointerVisible = true;
    phase = switch (steps[index].kind) {
      GuideKind.intro => CoachPhase.intro,
      GuideKind.demonstrate => CoachPhase.demonstrating,
      GuideKind.perform => CoachPhase.waitingForPlayer,
      GuideKind.practice => CoachPhase.practice,
    };
  }
}

bool _same(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

bool _isPrefix(List<int> full, List<int> prefix) {
  if (prefix.length > full.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (prefix[i] != full[i]) return false;
  }
  return true;
}

bool shouldGuideLevel({
  required int number,
  required bool campaignLevel,
  required Set<String> seen,
  required String modeId,
}) {
  return campaignLevel && number <= 2 && !tutorialSettled(seen, modeId);
}

List<int> rectCells(GridRect rect, int cols) {
  final cells = <int>[];
  for (var row = rect.r1; row <= rect.r2; row++) {
    for (var col = rect.c1; col <= rect.c2; col++) {
      cells.add(row * cols + col);
    }
  }
  return cells;
}

GridRect rectFromCells(List<int> cells, int cols) {
  var r1 = 1 << 30;
  var c1 = 1 << 30;
  var r2 = 0;
  var c2 = 0;
  for (final cell in cells) {
    final row = cell ~/ cols;
    final col = cell % cols;
    if (row < r1) r1 = row;
    if (col < c1) c1 = col;
    if (row > r2) r2 = row;
    if (col > c2) c2 = col;
  }
  return GridRect(r1, c1, r2, c2);
}

const parcelHintCopy = [
  'The number is how many squares its rectangle needs.',
  'The glow is one rectangle that fits that number.',
  'Drag from one end of the glow to the other.',
];

const traceHintCopy = [
  'The path starts on 1 and steps to a touching square.',
  'The glow is the next square on a valid path.',
  'Draw onto the glowing square. Diagonals do not count.',
];

const inkHintCopy = [
  'A number owns that many touching squares. The shape may bend.',
  'The glow is one group that matches its number.',
  'Drag through the glowing squares, then let go.',
];

const threadHintCopy = [
  'Each letter has one match. The line stays on open squares.',
  'The glow joins that pair without crossing.',
  'Drag from one glowing letter to the other.',
];

List<GuideStep> parcelGuide({
  required int number,
  required List<GridRect> solution,
  required int cols,
}) {
  final pieces = [for (final rect in solution) rectCells(rect, cols)];
  return _pieceGuide(
    number: number,
    pieces: pieces,
    introTitle: 'Cover the grid',
    introBody: 'Each number is the size of its rectangle. A light will show the first one.',
    demoTitle: 'Watch the guide',
    demoBody: 'The light shows the drag. It does not place the rectangle.',
    performTitle: 'Your turn',
    performBody: 'Drag the glowing squares into one rectangle.',
    practiceBody:
        'Place the glowing rectangle, then finish the board yourself.',
  );
}

List<GuideStep> traceGuide({required int number, required List<int> solution}) {
  if (solution.length < 2) {
    return const [
      GuideStep(
        kind: GuideKind.practice,
        title: 'Draw the path',
        body: 'Start on 1 and cover every open square.',
      ),
    ];
  }
  if (number <= 1) {
    final cut = solution.length <= 4 ? 2 : 3;
    return [
      const GuideStep(
        kind: GuideKind.intro,
        title: 'Start at 1',
        body: 'Trace is one path. It steps up, down, left, or right.',
      ),
      GuideStep(
        kind: GuideKind.demonstrate,
        title: 'Watch the guide',
        body: 'The light follows the path. The squares stay empty.',
        cells: solution.sublist(0, cut),
        orderedPrefix: true,
      ),
      GuideStep(
        kind: GuideKind.perform,
        title: 'Continue the path',
        body: 'Draw through the glowing squares, one step at a time.',
        cells: solution,
        orderedPrefix: true,
      ),
    ];
  }
  final first = solution.sublist(0, solution.length < 2 ? 1 : 2);
  return [
    const GuideStep(
      kind: GuideKind.intro,
      title: 'Start at 1',
      body: 'The glow shows the first step. You draw it.',
    ),
    GuideStep(
      kind: GuideKind.perform,
      title: 'Take the first step',
      body: 'Start on 1 and move onto the glowing square.',
      cells: first,
      orderedPrefix: true,
    ),
    const GuideStep(
      kind: GuideKind.practice,
      title: 'Finish the path',
      body: 'Cover every open square. A hint can show the next step.',
    ),
  ];
}

List<GuideStep> inkGuide({
  required int number,
  required List<List<int>> solution,
}) {
  return _pieceGuide(
    number: number,
    pieces: solution,
    introTitle: 'Each number owns a group',
    introBody: 'A group is touching squares. It may bend. A light will show the first one.',
    demoTitle: 'Watch the guide',
    demoBody: 'The light traces the group. It does not paint it.',
    performTitle: 'Your turn',
    performBody: 'Drag through the glowing squares, then let go.',
    practiceBody: 'Paint the glowing group, then finish the board yourself.',
  );
}

List<GuideStep> threadGuide({
  required int number,
  required List<List<int>> solution,
}) {
  return _pieceGuide(
    number: number,
    pieces: solution,
    introTitle: 'Find the matching letters',
    introBody: 'Join each letter to its twin. Lines do not cross. A light will show the first one.',
    demoTitle: 'Watch the guide',
    demoBody: 'The light joins the pair. It does not draw the line.',
    performTitle: 'Your turn',
    performBody: 'Drag from one glowing letter to its match.',
    practiceBody: 'Join the glowing pair, then connect the rest yourself.',
  );
}

List<GuideStep> _pieceGuide({
  required int number,
  required List<List<int>> pieces,
  required String introTitle,
  required String introBody,
  required String demoTitle,
  required String demoBody,
  required String performTitle,
  required String performBody,
  required String practiceBody,
}) {
  if (pieces.isEmpty) {
    return [
      GuideStep(kind: GuideKind.practice, title: introTitle, body: introBody),
    ];
  }
  if (number <= 1 && pieces.length >= 2) {
    return [
      GuideStep(kind: GuideKind.intro, title: introTitle, body: introBody),
      GuideStep(
        kind: GuideKind.demonstrate,
        title: demoTitle,
        body: demoBody,
        cells: pieces.first,
      ),
      for (final piece in pieces.skip(1))
        GuideStep(
          kind: GuideKind.perform,
          title: performTitle,
          body: performBody,
          cells: piece,
        ),
    ];
  }
  return [
    GuideStep(kind: GuideKind.intro, title: introTitle, body: introBody),
    GuideStep(
      kind: GuideKind.perform,
      title: performTitle,
      body: practiceBody,
      cells: pieces.first,
    ),
    const GuideStep(
      kind: GuideKind.practice,
      title: 'Finish the puzzle',
      body: 'The rest is yours. A hint never plays an ad during this lesson.',
    ),
  ];
}
