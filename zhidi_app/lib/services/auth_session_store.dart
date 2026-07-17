import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_api_client.dart';

abstract interface class AuthSessionStore {
  Future<AuthSession?> read();

  Future<void> save(AuthSession session);

  Future<void> clear();
}

final class SecureAuthSessionStore implements AuthSessionStore {
  SecureAuthSessionStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage(),
      _sessionKey = _ownerSessionKey;

  SecureAuthSessionStore.worker([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage(),
      _sessionKey = _workerSessionKey;

  static const _ownerSessionKey = 'owner.auth.session';
  static const _workerSessionKey = 'worker.auth.session';
  final FlutterSecureStorage _storage;
  final String _sessionKey;

  @override
  Future<AuthSession?> read() async {
    final encoded = await _storage.read(key: _sessionKey);
    if (encoded == null) return null;
    try {
      return AuthSession.fromJson(
        Map<String, dynamic>.from(jsonDecode(encoded) as Map),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> save(AuthSession session) =>
      _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _sessionKey);
}

final class MemoryAuthSessionStore implements AuthSessionStore {
  MemoryAuthSessionStore([this._session]);

  AuthSession? _session;

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> save(AuthSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}

final class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresAt,
    required this.userId,
    required this.phone,
    required this.roles,
  });

  factory AuthSession.fromLogin(
    OwnerLoginResponse response, {
    DateTime? issuedAt,
  }) {
    final startedAt = issuedAt ?? DateTime.now().toUtc();
    return AuthSession(
      accessToken: response.accessToken,
      tokenType: response.tokenType,
      expiresAt: startedAt.add(Duration(seconds: response.expiresInSeconds)),
      userId: response.user.id,
      phone: response.user.phone,
      roles: List.unmodifiable(response.user.roles),
    );
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'];
    if (rawRoles is! List) {
      throw const FormatException('roles must be a JSON array');
    }
    return AuthSession(
      accessToken: _requiredString(json, 'accessToken'),
      tokenType: _requiredString(json, 'tokenType'),
      expiresAt: DateTime.parse(_requiredString(json, 'expiresAt')).toUtc(),
      userId: _requiredString(json, 'userId'),
      phone: _requiredString(json, 'phone'),
      roles: List.unmodifiable(rawRoles.cast<String>()),
    );
  }

  final String accessToken;
  final String tokenType;
  final DateTime expiresAt;
  final String userId;
  final String phone;
  final List<String> roles;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now.toUtc());

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'tokenType': tokenType,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'userId': userId,
    'phone': phone,
    'roles': roles,
  };
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}
