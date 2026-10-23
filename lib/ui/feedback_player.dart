import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:rectora/domain/settings/settings.dart';

/// Optional clicks and vibration. Failures are ignored so a missing sound
/// asset never blocks a move.
class FeedbackPlayer {
  AudioPlayer? _player;

  Future<void> place(Settings settings) =>
      _cue(settings, 'place', heavy: false);

  Future<void> error(Settings settings) => _cue(settings, 'error', heavy: true);

  Future<void> complete(Settings settings) =>
      _cue(settings, 'complete', heavy: true);

  Future<void> tap(Settings settings) => _cue(settings, 'tap', heavy: false);

  Future<void> _cue(
    Settings settings,
    String name, {
    required bool heavy,
  }) async {
    if (settings.haptics) {
      if (heavy) {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.selectionClick();
      }
    }
    if (!settings.sound) return;
    try {
      final player = _player ??= AudioPlayer()
        ..setPlayerMode(PlayerMode.lowLatency);
      await player.stop();
      await player.play(AssetSource('sfx/$name.wav'));
    } catch (_) {
      _player = null;
    }
  }

  void dispose() {
    final player = _player;
    _player = null;
    player?.dispose();
  }
}
