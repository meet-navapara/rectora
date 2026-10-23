import 'package:shared_preferences/shared_preferences.dart';

abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class MemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

class PrefsStore implements KeyValueStore {
  PrefsStore(this.preferences);

  final SharedPreferences preferences;

  @override
  Future<String?> read(String key) async => preferences.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await preferences.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await preferences.remove(key);
  }
}
