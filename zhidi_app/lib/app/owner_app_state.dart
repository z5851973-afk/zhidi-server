import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'owner_key_value_store.dart';
export 'owner_models.dart';

import 'owner_key_value_store.dart';
import 'owner_models.dart';

List<OwnerAddress> _normalizeAddresses(
  Iterable<OwnerAddress> addresses, {
  String? preferredDefaultId,
}) {
  final items = addresses.toList();
  if (items.isEmpty) return items;
  var defaultId = preferredDefaultId;
  if (defaultId == null || !items.any((item) => item.id == defaultId)) {
    defaultId = items
        .firstWhere((item) => item.isDefault, orElse: () => items.first)
        .id;
  }
  return items
      .map((item) => item.copyWith(isDefault: item.id == defaultId))
      .toList();
}

/// App-wide owner data, serialized as one document after every mutation.
class OwnerAppState extends ChangeNotifier {
  OwnerAppState._({
    required OwnerKeyValueStore store,
    required this.ready,
    required OwnerProfile profile,
    required List<OwnerAddress> addresses,
    required List<OwnerProject> projects,
    required List<OwnerReminder> reminders,
    required List<OwnerMessage> messages,
    required List<FavoriteWorker> favoriteWorkers,
    required OwnerSettings settings,
    required List<AfterSalesRequest> afterSalesRequests,
    required List<FeedbackEntry> feedbackEntries,
    // Named public-looking parameters keep seeded-data construction readable.
    // ignore: prefer_initializing_formals
  }) : _store = store,
       // ignore: prefer_initializing_formals
       _profile = profile,
       // ignore: prefer_initializing_formals
       _addresses = addresses,
       // ignore: prefer_initializing_formals
       _projects = projects,
       // ignore: prefer_initializing_formals
       _reminders = reminders,
       // ignore: prefer_initializing_formals
       _messages = messages,
       // ignore: prefer_initializing_formals
       _favoriteWorkers = favoriteWorkers,
       // ignore: prefer_initializing_formals
       _settings = settings,
       // ignore: prefer_initializing_formals
       _afterSalesRequests = afterSalesRequests,
       // ignore: prefer_initializing_formals
       _feedbackEntries = feedbackEntries;

  static const documentKey = 'owner.appState';
  final OwnerKeyValueStore _store;
  final bool ready;

  OwnerProfile _profile;
  List<OwnerAddress> _addresses;
  List<OwnerProject> _projects;
  List<OwnerReminder> _reminders;
  List<OwnerMessage> _messages;
  List<FavoriteWorker> _favoriteWorkers;
  OwnerSettings _settings;
  List<AfterSalesRequest> _afterSalesRequests;
  List<FeedbackEntry> _feedbackEntries;
  Future<void> _mutationQueue = Future<void>.value();

  OwnerProfile get profile => _profile;
  String get profileName => _profile.name;
  List<OwnerAddress> get addresses => List.unmodifiable(_addresses);
  List<OwnerProject> get projects => List.unmodifiable(_projects);
  List<OwnerReminder> get reminders => List.unmodifiable(_reminders);
  List<OwnerMessage> get messages => List.unmodifiable(_messages);
  List<FavoriteWorker> get favoriteWorkers =>
      List.unmodifiable(_favoriteWorkers);
  OwnerSettings get settings => _settings;
  List<AfterSalesRequest> get afterSalesRequests =>
      List.unmodifiable(_afterSalesRequests);
  List<FeedbackEntry> get feedbackEntries =>
      List.unmodifiable(_feedbackEntries);
  int get unreadMessageCount =>
      _messages.where((message) => !message.isRead).length;

  factory OwnerAppState.memory({OwnerKeyValueStore? store}) {
    final targetStore = store ?? MemoryOwnerStore();
    return _fromStored(targetStore);
  }

  static Future<OwnerAppState> load() async {
    final preferences = await SharedPreferences.getInstance();
    return _fromStored(SharedPreferencesOwnerStore(preferences));
  }

  factory OwnerAppState.fromJson(Map<String, dynamic> json) =>
      _fromMap(json, MemoryOwnerStore());

  static OwnerAppState _fromStored(OwnerKeyValueStore store) {
    final encoded = store.getString(documentKey);
    if (encoded == null) return _seeded(store);
    try {
      return _fromMap(jsonDecode(encoded) as Map<String, dynamic>, store);
    } on FormatException {
      return _seeded(store);
    } on TypeError {
      return _seeded(store);
    }
  }

  static OwnerAppState _fromMap(
    Map<String, dynamic> json,
    OwnerKeyValueStore store,
  ) {
    List<T> read<T>(String key, T Function(Map<String, dynamic>) decode) =>
        (json[key] as List<dynamic>? ?? const [])
            .map((value) => decode(Map<String, dynamic>.from(value as Map)))
            .toList();
    return OwnerAppState._(
      store: store,
      ready: true,
      profile: OwnerProfile.fromJson(
        Map<String, dynamic>.from(json['profile'] as Map),
      ),
      addresses: _normalizeAddresses(read('addresses', OwnerAddress.fromJson)),
      projects: read('projects', OwnerProject.fromJson),
      reminders: read('reminders', OwnerReminder.fromJson),
      messages: read('messages', OwnerMessage.fromJson),
      favoriteWorkers: read('favoriteWorkers', FavoriteWorker.fromJson),
      settings: OwnerSettings.fromJson(
        Map<String, dynamic>.from(json['settings'] as Map? ?? const {}),
      ),
      afterSalesRequests: read(
        'afterSalesRequests',
        AfterSalesRequest.fromJson,
      ),
      feedbackEntries: read('feedbackEntries', FeedbackEntry.fromJson),
    );
  }

  static OwnerAppState _seeded(OwnerKeyValueStore store) => OwnerAppState._(
    store: store,
    ready: true,
    profile: const OwnerProfile(name: '王先生', city: '成都', phone: '13800000000'),
    addresses: const [
      OwnerAddress(
        id: 'address-1',
        recipient: '王先生',
        phone: '13800000000',
        city: '成都',
        district: '高新区',
        detail: '天府一街 100 号',
        isDefault: true,
      ),
    ],
    projects: [
      OwnerProject(
        id: 'project-1',
        name: '麓湖新居翻新',
        city: '成都',
        address: '天府新区麓湖生态城',
        startDate: DateTime(2026, 6, 18),
      ),
    ],
    reminders: [
      OwnerReminder(
        id: 'reminder-1',
        title: '确认水电点位',
        projectId: 'project-1',
        dueAt: DateTime(2026, 7, 3),
      ),
      OwnerReminder(
        id: 'reminder-2',
        title: '验收防水施工',
        projectId: 'project-1',
        dueAt: DateTime(2026, 7, 8),
      ),
    ],
    messages: [
      OwnerMessage(
        id: 'message-1',
        title: '工长已更新施工进度',
        content: '水电开槽已完成，请查看现场照片。',
        category: '项目',
        createdAt: DateTime(2026, 7, 2, 9, 30),
      ),
      OwnerMessage(
        id: 'message-2',
        title: '预约已确认',
        content: '您预约的成都木工陈师傅已确认时间。',
        category: '预约',
        createdAt: DateTime(2026, 7, 1, 16),
      ),
      OwnerMessage(
        id: 'message-3',
        title: '平台保障提醒',
        content: '请通过平台确认验收结果。',
        category: '系统',
        createdAt: DateTime(2026, 6, 30),
        isRead: true,
      ),
    ],
    favoriteWorkers: const [],
    settings: const OwnerSettings(),
    afterSalesRequests: const [],
    feedbackEntries: const [],
  );

  Map<String, dynamic> toJson() => {
    'profile': _profile.toJson(),
    'addresses': _addresses.map((item) => item.toJson()).toList(),
    'projects': _projects.map((item) => item.toJson()).toList(),
    'reminders': _reminders.map((item) => item.toJson()).toList(),
    'messages': _messages.map((item) => item.toJson()).toList(),
    'favoriteWorkers': _favoriteWorkers.map((item) => item.toJson()).toList(),
    'settings': _settings.toJson(),
    'afterSalesRequests': _afterSalesRequests
        .map((item) => item.toJson())
        .toList(),
    'feedbackEntries': _feedbackEntries.map((item) => item.toJson()).toList(),
  };

  Future<void> _mutate(Map<String, dynamic>? Function() buildNext) {
    final operation = _mutationQueue.then((_) async {
      final next = buildNext();
      if (next == null) return;
      await _store.setString(documentKey, jsonEncode(next));
      final restored = _fromMap(next, _store);
      _profile = restored._profile;
      _addresses = restored._addresses;
      _projects = restored._projects;
      _reminders = restored._reminders;
      _messages = restored._messages;
      _favoriteWorkers = restored._favoriteWorkers;
      _settings = restored._settings;
      _afterSalesRequests = restored._afterSalesRequests;
      _feedbackEntries = restored._feedbackEntries;
      notifyListeners();
    });
    _mutationQueue = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  Future<void> updateProfile(OwnerProfile value) => _mutate(() {
    if (value.name == _profile.name &&
        value.city == _profile.city &&
        value.phone == _profile.phone) {
      return null;
    }
    return {...toJson(), 'profile': value.toJson()};
  });

  Future<void> updateProfileName(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) return Future<void>.value();
    return _mutate(() {
      if (normalized == _profile.name) return null;
      return {
        ...toJson(),
        'profile': _profile.copyWith(name: normalized).toJson(),
      };
    });
  }

  Future<void> addAddress(OwnerAddress value) => _mutate(() {
    if (_addresses.any((item) => item.id == value.id)) return null;
    final next = _normalizeAddresses(
      [..._addresses, value],
      preferredDefaultId: value.isDefault || _addresses.isEmpty
          ? value.id
          : null,
    );
    return {...toJson(), 'addresses': next.map((e) => e.toJson()).toList()};
  });

  Future<void> updateAddress(OwnerAddress value) => _mutate(() {
    final index = _addresses.indexWhere((item) => item.id == value.id);
    if (index < 0 ||
        jsonEncode(_addresses[index].toJson()) == jsonEncode(value.toJson())) {
      return null;
    }
    final replaced = [..._addresses]..[index] = value;
    final next = _normalizeAddresses(
      replaced,
      preferredDefaultId: value.isDefault ? value.id : null,
    );
    return {...toJson(), 'addresses': next.map((e) => e.toJson()).toList()};
  });

  Future<void> deleteAddress(String id) => _mutate(() {
    final next = _normalizeAddresses(_addresses.where((item) => item.id != id));
    if (next.length == _addresses.length) return null;
    return {...toJson(), 'addresses': next.map((e) => e.toJson()).toList()};
  });

  Future<void> markMessageRead(String id) => _mutate(() {
    final index = _messages.indexWhere((item) => item.id == id && !item.isRead);
    if (index < 0) return null;
    final next = [..._messages]
      ..[index] = _messages[index].copyWith(isRead: true);
    return {...toJson(), 'messages': next.map((e) => e.toJson()).toList()};
  });

  Future<void> markAllMessagesRead() => _mutate(() {
    if (_messages.every((item) => item.isRead)) return null;
    final next = _messages.map((item) => item.copyWith(isRead: true)).toList();
    return {...toJson(), 'messages': next.map((e) => e.toJson()).toList()};
  });

  bool isFavorite(String workerId) =>
      _favoriteWorkers.any((item) => item.id == workerId);

  Future<void> toggleFavorite(FavoriteWorker worker) => _mutate(() {
    final next = isFavorite(worker.id)
        ? _favoriteWorkers.where((item) => item.id != worker.id).toList()
        : [..._favoriteWorkers, worker];
    return {
      ...toJson(),
      'favoriteWorkers': next.map((e) => e.toJson()).toList(),
    };
  });

  Future<void> completeReminder(String id) => _mutate(() {
    final index = _reminders.indexWhere(
      (item) => item.id == id && !item.isCompleted,
    );
    if (index < 0) return null;
    final next = [..._reminders]
      ..[index] = _reminders[index].copyWith(isCompleted: true);
    return {...toJson(), 'reminders': next.map((e) => e.toJson()).toList()};
  });

  Future<void> submitFeedback(FeedbackEntry entry) => _mutate(() {
    if (_feedbackEntries.any((item) => item.id == entry.id)) {
      return null;
    }
    return {
      ...toJson(),
      'feedbackEntries': [
        ..._feedbackEntries,
        entry,
      ].map((e) => e.toJson()).toList(),
    };
  });

  Future<void> submitAfterSales(AfterSalesRequest request) => _mutate(() {
    if (_afterSalesRequests.any((item) => item.id == request.id)) return null;
    return {
      ...toJson(),
      'afterSalesRequests': [
        ..._afterSalesRequests,
        request,
      ].map((e) => e.toJson()).toList(),
    };
  });

  Future<void> updateSettings(OwnerSettings value) => _mutate(() {
    if (jsonEncode(value.toJson()) == jsonEncode(_settings.toJson())) {
      return null;
    }
    return {...toJson(), 'settings': value.toJson()};
  });

  /// Restores notification and privacy preferences only.
  /// Owner profile, addresses, projects, and submitted records are preserved.
  Future<void> resetSettings() => updateSettings(const OwnerSettings());
}
