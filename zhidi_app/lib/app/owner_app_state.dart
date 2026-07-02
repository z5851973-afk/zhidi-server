import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'owner_key_value_store.dart';

import 'owner_key_value_store.dart';

/// App-wide owner data and the persistence boundary for owner-facing features.
class OwnerAppState extends ChangeNotifier {
  OwnerAppState._({
    required this.ready,
    required this._profileName,
    required this._store,
  });

  static const _profileNameKey = 'owner.profileName';
  static const _defaultProfileName = '王先生';

  final OwnerKeyValueStore _store;
  String _profileName;

  final bool ready;

  String get profileName => _profileName;

  /// Creates an immediately ready state over a replaceable in-memory store.
  factory OwnerAppState.memory({OwnerKeyValueStore? store}) {
    final memoryStore = store ?? MemoryOwnerStore();
    return OwnerAppState._(
      ready: true,
      profileName:
          memoryStore.getString(_profileNameKey) ?? _defaultProfileName,
      store: memoryStore,
    );
  }

  /// Loads the persistent state used by the application bootstrap.
  static Future<OwnerAppState> load() async {
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesOwnerStore(preferences);
    return OwnerAppState._(
      ready: true,
      profileName: store.getString(_profileNameKey) ?? _defaultProfileName,
      store: store,
    );
  }

  Future<void> updateProfileName(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || normalizedName == _profileName) return;

    await _store.setString(_profileNameKey, normalizedName);
    _profileName = normalizedName;
    notifyListeners();
  }
}
