import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide owner data and the persistence boundary for owner-facing features.
class OwnerAppState extends ChangeNotifier {
  OwnerAppState._({
    required this.ready,
    required this._profileName,
    this._preferences,
  });

  static const _profileNameKey = 'owner.profileName';
  static const _defaultProfileName = '王先生';

  final SharedPreferences? _preferences;
  String _profileName;

  final bool ready;

  String get profileName => _profileName;

  /// Creates an immediately ready, non-persistent state for tests/previews.
  factory OwnerAppState.memory() =>
      OwnerAppState._(ready: true, profileName: _defaultProfileName);

  /// Loads the persistent state used by the application bootstrap.
  static Future<OwnerAppState> load() async {
    final preferences = await SharedPreferences.getInstance();
    return OwnerAppState._(
      ready: true,
      profileName:
          preferences.getString(_profileNameKey) ?? _defaultProfileName,
      preferences: preferences,
    );
  }

  Future<void> updateProfileName(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || normalizedName == _profileName) return;

    _profileName = normalizedName;
    await _preferences?.setString(_profileNameKey, normalizedName);
    notifyListeners();
  }
}
