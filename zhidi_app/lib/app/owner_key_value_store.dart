import 'package:shared_preferences/shared_preferences.dart';

abstract interface class OwnerKeyValueStore {
  String? getString(String key);

  Future<void> setString(String key, String value);
}

class MemoryOwnerStore implements OwnerKeyValueStore {
  MemoryOwnerStore([Map<String, String>? values])
    : _values = values ?? <String, String>{};

  final Map<String, String> _values;

  @override
  String? getString(String key) => _values[key];

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }
}

class SharedPreferencesOwnerStore implements OwnerKeyValueStore {
  const SharedPreferencesOwnerStore(this._preferences);

  final SharedPreferences _preferences;

  @override
  String? getString(String key) => _preferences.getString(key);

  @override
  Future<void> setString(String key, String value) async {
    final saved = await _preferences.setString(key, value);
    if (!saved) {
      throw StateError('Unable to persist owner state.');
    }
  }
}
