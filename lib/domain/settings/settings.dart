import 'package:flutter/material.dart';

enum ThemeChoice { system, light, dark }

extension ThemeChoiceMode on ThemeChoice {
  ThemeMode get themeMode {
    switch (this) {
      case ThemeChoice.system:
        return ThemeMode.system;
      case ThemeChoice.light:
        return ThemeMode.light;
      case ThemeChoice.dark:
        return ThemeMode.dark;
    }
  }
}

class Settings {
  const Settings({
    this.theme = ThemeChoice.system,
    this.haptics = true,
    this.sound = true,
    this.showTimer = true,
    this.showSize = false,
    this.cornerPlacement = false,
    this.animations = true,
    this.boardStyle = 'midnight',
    this.reminders = false,
  });

  final ThemeChoice theme;
  final bool haptics;
  final bool sound;
  final bool showTimer;
  final bool showSize;
  final bool cornerPlacement;
  final bool animations;
  final String boardStyle;
  final bool reminders;

  Settings copyWith({
    ThemeChoice? theme,
    bool? haptics,
    bool? sound,
    bool? showTimer,
    bool? showSize,
    bool? cornerPlacement,
    bool? animations,
    String? boardStyle,
    bool? reminders,
  }) {
    return Settings(
      theme: theme ?? this.theme,
      haptics: haptics ?? this.haptics,
      sound: sound ?? this.sound,
      showTimer: showTimer ?? this.showTimer,
      showSize: showSize ?? this.showSize,
      cornerPlacement: cornerPlacement ?? this.cornerPlacement,
      animations: animations ?? this.animations,
      boardStyle: boardStyle ?? this.boardStyle,
      reminders: reminders ?? this.reminders,
    );
  }

  Map<String, Object?> toJson() => {
    'theme': theme.name,
    'haptics': haptics,
    'sound': sound,
    'showTimer': showTimer,
    'showSize': showSize,
    'cornerPlacement': cornerPlacement,
    'animations': animations,
    'boardStyle': boardStyle,
    'reminders': reminders,
  };

  factory Settings.fromJson(Map<String, Object?> json) {
    return Settings(
      theme:
          ThemeChoice.values.asNameMap()[json['theme']] ?? ThemeChoice.system,
      haptics: json['haptics'] != false,
      sound: json['sound'] != false,
      showTimer: json['showTimer'] != false,
      showSize: json['showSize'] == true,
      cornerPlacement: json['cornerPlacement'] == true,
      animations: json['animations'] != false,
      boardStyle: json['boardStyle'] is String
          ? json['boardStyle'] as String
          : 'midnight',
      reminders: json['reminders'] == true,
    );
  }
}
