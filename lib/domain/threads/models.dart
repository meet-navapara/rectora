class ThreadPair {
  const ThreadPair({required this.label, required this.a, required this.b});

  final String label;
  final int a;
  final int b;

  @override
  bool operator ==(Object other) =>
      other is ThreadPair &&
      other.label == label &&
      other.a == a &&
      other.b == b;

  @override
  int get hashCode => Object.hash(label, a, b);
}

class ThreadPuzzle {
  const ThreadPuzzle({
    required this.rows,
    required this.cols,
    required this.pairs,
    required this.blocked,
  });

  final int rows;
  final int cols;
  final List<ThreadPair> pairs;
  final List<int> blocked;

  int get cellCount => rows * cols;

  int index(int row, int col) => row * cols + col;

  (int, int) cellOf(int index) => (index ~/ cols, index % cols);
}

enum ThreadIssue {
  ok,
  malformed,
  tooShort,
  notOrthogonal,
  blocked,
  revisit,
  overlap,
  foreignTerminal,
  endsMismatch,
}

class ThreadPath {
  const ThreadPath({required this.pairIndex, required this.cells});

  final int pairIndex;
  final List<int> cells;
}

class ThreadAssessment {
  const ThreadAssessment({required this.issue, this.path});

  final ThreadIssue issue;
  final ThreadPath? path;

  bool get accepted => issue == ThreadIssue.ok;
}

class ThreadSolveResult {
  const ThreadSolveResult({
    required this.solutions,
    required this.budgetExhausted,
    this.solution,
    this.nodes = 0,
  });

  final int solutions;
  final int nodes;
  final bool budgetExhausted;
  final List<ThreadPath>? solution;

  static const none = ThreadSolveResult(solutions: 0, budgetExhausted: false);
}

class ThreadHint {
  const ThreadHint({required this.kind, this.pairIndex, this.cells = const []});

  final ThreadHintKind kind;
  final int? pairIndex;
  final List<int> cells;

  bool get placesAPath => kind == ThreadHintKind.required && cells.length >= 2;
}

enum ThreadHintKind { required, ambiguous, deadEnd, alreadyDone }
