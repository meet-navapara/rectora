class Profile {
  const Profile({this.name = 'Traveler', this.avatar = 0});

  static const avatarCount = 8;
  static const maxNameLength = 16;

  final String name;
  final int avatar;

  Profile copyWith({String? name, int? avatar}) {
    return Profile(name: name ?? this.name, avatar: avatar ?? this.avatar);
  }

  Map<String, Object?> toJson() => {'name': name, 'avatar': avatar};

  factory Profile.fromJson(Map<String, Object?> json) {
    final parsed = validateDisplayName(json['name'] as String? ?? '');
    final avatar = json['avatar'];
    return Profile(
      name: parsed ?? 'Traveler',
      avatar: avatar is int && avatar >= 0 && avatar < avatarCount ? avatar : 0,
    );
  }
}

/// Returns a cleaned display name, or null when the text cannot be stored.
String? validateDisplayName(String raw) {
  final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (name.isEmpty || name.length > Profile.maxNameLength) return null;
  if (RegExp(r'[^\p{L}\p{N} _\-]', unicode: true).hasMatch(name)) return null;
  return name;
}
