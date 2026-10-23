import 'dart:async';

import 'package:flutter/material.dart';

/// Draws the puzzle clock without rebuilding the board every second.
class PlayClock extends StatefulWidget {
  const PlayClock({
    super.key,
    required this.bankedMs,
    required this.runningSince,
    this.style,
  });

  final int bankedMs;
  final DateTime? runningSince;
  final TextStyle? style;

  @override
  State<PlayClock> createState() => _PlayClockState();
}

class _PlayClockState extends State<PlayClock> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.runningSince != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running = widget.runningSince == null
        ? 0
        : DateTime.now().difference(widget.runningSince!).inMilliseconds;
    final total = (widget.bankedMs + running) ~/ 1000;
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return Text(
      '$minutes:$seconds',
      style:
          widget.style ??
          Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}

/// Shows [onSlow] only when [future] is still running after [wait].
Future<T> showWhenSlow<T>({
  required Future<T> future,
  required bool Function() mounted,
  required void Function() onSlow,
  required void Function() onDone,
  Duration wait = const Duration(milliseconds: 140),
}) async {
  final done = Completer<void>();
  future.whenComplete(() {
    if (!done.isCompleted) done.complete();
  });
  await Future.any([done.future, Future<void>.delayed(wait)]);
  final slow = !done.isCompleted;
  if (slow && mounted()) onSlow();
  try {
    return await future;
  } finally {
    if (slow && mounted()) onDone();
  }
}
