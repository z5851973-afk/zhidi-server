import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'owner_key_value_store.dart';
export 'owner_models.dart';

import 'owner_key_value_store.dart';
import 'owner_models.dart';
import 'owner_appointment.dart';
import '../services/auth_api_client.dart';
import '../services/auth_session_store.dart';
import '../services/owner_profile_api_client.dart';

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
    required this._sessionStore,
    required this._profileApi,
    required this.ready,
    required OwnerProfile profile,
    required List<OwnerAddress> addresses,
    required List<OwnerProject> projects,
    required String? selectedProjectId,
    required List<OwnerReminder> reminders,
    required List<OwnerMessage> messages,
    required List<FavoriteWorker> favoriteWorkers,
    required List<SavedQuote> savedQuotes,
    required List<OrderItem> appointments,
    required OwnerSettings settings,
    required List<AfterSalesRequest> afterSalesRequests,
    required List<FeedbackEntry> feedbackEntries,
    required List<BookedWorker> bookedWorkers,
    required Set<int> completedPhases,
    required this._isLoggedIn,
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
       _selectedProjectId = selectedProjectId,
       // ignore: prefer_initializing_formals
       _reminders = reminders,
       // ignore: prefer_initializing_formals
       _messages = messages,
       // ignore: prefer_initializing_formals
       _favoriteWorkers = favoriteWorkers,
       // ignore: prefer_initializing_formals
       _savedQuotes = savedQuotes,
       // ignore: prefer_initializing_formals
       _appointments = appointments,
       // ignore: prefer_initializing_formals
       _settings = settings,
       // ignore: prefer_initializing_formals
       _afterSalesRequests = afterSalesRequests,
       // ignore: prefer_initializing_formals
       _feedbackEntries = feedbackEntries,
       // ignore: prefer_initializing_formals
       _bookedWorkers = bookedWorkers,
       // ignore: prefer_initializing_formals
       _completedPhases = completedPhases;

  static const documentKey = 'owner.appState';
  final OwnerKeyValueStore _store;
  final AuthSessionStore _sessionStore;
  final OwnerProfileApi _profileApi;
  final bool ready;

  OwnerProfile _profile;
  List<OwnerAddress> _addresses;
  List<OwnerProject> _projects;
  String? _selectedProjectId;
  List<OwnerReminder> _reminders;
  List<OwnerMessage> _messages;
  List<FavoriteWorker> _favoriteWorkers;
  List<SavedQuote> _savedQuotes;
  List<OrderItem> _appointments;
  OwnerSettings _settings;
  List<AfterSalesRequest> _afterSalesRequests;
  List<FeedbackEntry> _feedbackEntries;
  List<BookedWorker> _bookedWorkers;
  Set<int> _completedPhases;
  bool _isLoggedIn;
  Future<void> _mutationQueue = Future<void>.value();

  OwnerProfile get profile => _profile;
  String get profileName => _profile.name;
  List<OwnerAddress> get addresses => List.unmodifiable(_addresses);
  List<OwnerProject> get projects => List.unmodifiable(_projects);
  String? get selectedProjectId => _selectedProjectId;
  OwnerProject? get selectedProject {
    if (_projects.isEmpty) return null;
    return _projects.firstWhere(
      (project) => project.id == _selectedProjectId,
      orElse: () => _projects.first,
    );
  }

  List<OwnerReminder> get reminders => List.unmodifiable(_reminders);
  List<OwnerMessage> get messages => List.unmodifiable(_messages);
  List<FavoriteWorker> get favoriteWorkers =>
      List.unmodifiable(_favoriteWorkers);
  List<SavedQuote> get savedQuotes => List.unmodifiable(_savedQuotes);
  List<OrderItem> get appointments => List.unmodifiable(_appointments);
  OwnerSettings get settings => _settings;
  List<AfterSalesRequest> get afterSalesRequests =>
      List.unmodifiable(_afterSalesRequests);
  List<FeedbackEntry> get feedbackEntries =>
      List.unmodifiable(_feedbackEntries);
  List<BookedWorker> get bookedWorkers => List.unmodifiable(_bookedWorkers);
  Set<int> get completedPhases => Set.unmodifiable(_completedPhases);
  bool get isLoggedIn => _isLoggedIn;
  int get unreadMessageCount =>
      _messages.where((message) => !message.isRead).length;

  static Future<OwnerAppState> memory({
    OwnerKeyValueStore? store,
    AuthSessionStore? sessionStore,
    OwnerProfileApi? profileApi,
  }) async {
    final targetStore = store ?? MemoryOwnerStore();
    return _fromStored(
      targetStore,
      sessionStore ?? MemoryAuthSessionStore(),
      profileApi ?? OwnerProfileApiClient(),
    );
  }

  static Future<OwnerAppState> load({
    AuthSessionStore? sessionStore,
    OwnerProfileApi? profileApi,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    return _fromStored(
      SharedPreferencesOwnerStore(preferences),
      sessionStore ?? SecureAuthSessionStore(),
      profileApi ?? OwnerProfileApiClient(),
    );
  }

  factory OwnerAppState.fromJson(Map<String, dynamic> json) => _fromMap(
    json,
    MemoryOwnerStore(),
    MemoryAuthSessionStore(),
    OwnerProfileApiClient(),
  );

  static Future<OwnerAppState> _fromStored(
    OwnerKeyValueStore store,
    AuthSessionStore sessionStore,
    OwnerProfileApi profileApi,
  ) async {
    final encoded = store.getString(documentKey);
    final state = encoded != null
        ? _tryDecode(encoded, store, sessionStore, profileApi)
        : _seeded(store, sessionStore, profileApi);
    final session = await sessionStore.read();
    if (session == null || session.isExpiredAt(DateTime.now())) {
      state._isLoggedIn = false;
      if (session != null) await sessionStore.clear();
    } else {
      state._isLoggedIn = true;
      state._profile = state._profile.copyWith(phone: session.phone);
    }
    if (state._isLoggedIn) {
      try {
        await state.refreshOwnerProfile();
      } on AuthApiException {
        // Restoring local state must remain usable while profile sync is
        // unavailable. refreshOwnerProfile already clears an invalid session.
      }
    }
    return state;
  }

  static OwnerAppState _tryDecode(
    String encoded,
    OwnerKeyValueStore store,
    AuthSessionStore sessionStore,
    OwnerProfileApi profileApi,
  ) {
    try {
      return _fromMap(
        jsonDecode(encoded) as Map<String, dynamic>,
        store,
        sessionStore,
        profileApi,
      );
    } on FormatException {
      return _seeded(store, sessionStore, profileApi);
    } on TypeError {
      return _seeded(store, sessionStore, profileApi);
    }
  }

  static OwnerAppState _fromMap(
    Map<String, dynamic> json,
    OwnerKeyValueStore store,
    AuthSessionStore sessionStore,
    OwnerProfileApi profileApi,
  ) {
    List<T> read<T>(String key, T Function(Map<String, dynamic>) decode) =>
        (json[key] as List<dynamic>? ?? const [])
            .map((value) => decode(Map<String, dynamic>.from(value as Map)))
            .toList();
    final projects = read('projects', OwnerProject.fromJson);
    final storedSelectedProjectId = json['selectedProjectId'] as String?;
    return OwnerAppState._(
      store: store,
      sessionStore: sessionStore,
      profileApi: profileApi,
      ready: true,
      profile: OwnerProfile.fromJson(
        Map<String, dynamic>.from(json['profile'] as Map),
      ),
      addresses: _normalizeAddresses(read('addresses', OwnerAddress.fromJson)),
      projects: projects,
      selectedProjectId:
          projects.any((project) => project.id == storedSelectedProjectId)
          ? storedSelectedProjectId
          : (projects.isEmpty ? null : projects.first.id),
      reminders: read('reminders', OwnerReminder.fromJson),
      messages: read('messages', OwnerMessage.fromJson),
      favoriteWorkers: read('favoriteWorkers', FavoriteWorker.fromJson),
      savedQuotes: read('savedQuotes', SavedQuote.fromJson),
      appointments: read('appointments', OrderItem.fromJson),
      settings: OwnerSettings.fromJson(
        Map<String, dynamic>.from(json['settings'] as Map? ?? const {}),
      ),
      afterSalesRequests: read(
        'afterSalesRequests',
        AfterSalesRequest.fromJson,
      ),
      feedbackEntries: read('feedbackEntries', FeedbackEntry.fromJson),
      bookedWorkers: read('bookedWorkers', BookedWorker.fromJson),
      completedPhases: Set<int>.from(
        (json['completedPhases'] as List<dynamic>? ?? const []).map(
          (value) => value as int,
        ),
      ),
      isLoggedIn: json['isLoggedIn'] as bool? ?? false,
    );
  }

  static OwnerAppState _seeded(
    OwnerKeyValueStore store,
    AuthSessionStore sessionStore,
    OwnerProfileApi profileApi,
  ) => OwnerAppState._(
    store: store,
    sessionStore: sessionStore,
    profileApi: profileApi,
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
    selectedProjectId: 'project-1',
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
    savedQuotes: const [],
    appointments: const [],
    settings: const OwnerSettings(),
    afterSalesRequests: const [],
    feedbackEntries: const [],
    bookedWorkers: const [],
    completedPhases: const {},
    isLoggedIn: false,
  );

  Map<String, dynamic> toJson() => {
    'profile': _profile.toJson(),
    'addresses': _addresses.map((item) => item.toJson()).toList(),
    'projects': _projects.map((item) => item.toJson()).toList(),
    'selectedProjectId': _selectedProjectId,
    'reminders': _reminders.map((item) => item.toJson()).toList(),
    'messages': _messages.map((item) => item.toJson()).toList(),
    'favoriteWorkers': _favoriteWorkers.map((item) => item.toJson()).toList(),
    'savedQuotes': _savedQuotes.map((item) => item.toJson()).toList(),
    'appointments': _appointments.map((item) => item.toJson()).toList(),
    'settings': _settings.toJson(),
    'afterSalesRequests': _afterSalesRequests
        .map((item) => item.toJson())
        .toList(),
    'feedbackEntries': _feedbackEntries.map((item) => item.toJson()).toList(),
    'bookedWorkers': _bookedWorkers.map((item) => item.toJson()).toList(),
    'completedPhases': _completedPhases.toList(),
    'isLoggedIn': _isLoggedIn,
  };

  Future<void> _mutate(Map<String, dynamic>? Function() buildNext) {
    final operation = _mutationQueue.then((_) async {
      final next = buildNext();
      if (next == null) return;
      await _store.setString(documentKey, jsonEncode(next));
      final restored = _fromMap(next, _store, _sessionStore, _profileApi);
      _profile = restored._profile;
      _addresses = restored._addresses;
      _projects = restored._projects;
      _selectedProjectId = restored._selectedProjectId;
      _reminders = restored._reminders;
      _messages = restored._messages;
      _favoriteWorkers = restored._favoriteWorkers;
      _savedQuotes = restored._savedQuotes;
      _appointments = restored._appointments;
      _settings = restored._settings;
      _afterSalesRequests = restored._afterSalesRequests;
      _feedbackEntries = restored._feedbackEntries;
      _bookedWorkers = restored._bookedWorkers;
      _completedPhases = restored._completedPhases;
      _isLoggedIn = restored._isLoggedIn;
      notifyListeners();
    });
    _mutationQueue = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  Future<AuthSession?> _validSession() async {
    final session = await _sessionStore.read();
    if (session == null) return null;
    if (!session.isExpiredAt(DateTime.now())) return session;
    await _clearAuthenticatedState();
    return null;
  }

  OwnerProfile _localProfile(RemoteOwnerProfile remote) => OwnerProfile(
    name: remote.name ?? '',
    city: remote.city,
    phone: remote.phone,
    decorationType: remote.decorationType,
    address: remote.address,
    area: remote.area,
  );

  Future<void> _clearAuthenticatedState() async {
    await _sessionStore.clear();
    await _mutate(() {
      if (!_isLoggedIn) return null;
      return {...toJson(), 'isLoggedIn': false};
    });
  }

  Future<void> _handleProfileError(Object error) async {
    if (error is AuthApiException && error.statusCode == 401) {
      await _clearAuthenticatedState();
    }
  }

  Future<void> refreshOwnerProfile() async {
    final session = await _validSession();
    if (session == null) return;
    try {
      final remote = await _profileApi.getCurrent(session.accessToken);
      await _mutate(
        () => {
          ...toJson(),
          'profile': _localProfile(remote).toJson(),
          'isLoggedIn': true,
        },
      );
    } catch (error) {
      await _handleProfileError(error);
      rethrow;
    }
  }

  Future<void> updateProfile(OwnerProfile value) async {
    final session = await _validSession();
    if (session != null) {
      try {
        final remote = await _profileApi.updateCurrent(
          session.accessToken,
          OwnerProfileUpdate(
            name: value.name,
            city: value.city,
            decorationType: value.decorationType,
            address: value.address,
            area: value.area,
          ),
        );
        await _mutate(
          () => {...toJson(), 'profile': _localProfile(remote).toJson()},
        );
        return;
      } catch (error) {
        await _handleProfileError(error);
        rethrow;
      }
    }
    await _mutate(() {
      if (value.name == _profile.name &&
          value.city == _profile.city &&
          value.phone == _profile.phone &&
          value.decorationType == _profile.decorationType &&
          value.address == _profile.address &&
          value.area == _profile.area) {
        return null;
      }
      return {...toJson(), 'profile': value.toJson()};
    });
  }

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

  Future<void> addSavedQuote(SavedQuote quote) => _mutate(() {
    final filtered = _savedQuotes
        .where(
          (item) =>
              !(item.workerName == quote.workerName &&
                  item.tradeName == quote.tradeName),
        )
        .toList();
    final next = [quote, ...filtered];
    return {
      ...toJson(),
      'savedQuotes': next.map((item) => item.toJson()).toList(),
    };
  });

  Future<void> removeSavedQuote(String id) => _mutate(() {
    final next = _savedQuotes.where((item) => item.id != id).toList();
    if (next.length == _savedQuotes.length) return null;
    return {
      ...toJson(),
      'savedQuotes': next.map((item) => item.toJson()).toList(),
    };
  });

  Future<void> addAppointment(OrderItem appointment) => _mutate(() {
    final next = [appointment, ..._appointments];
    return {
      ...toJson(),
      'appointments': next.map((item) => item.toJson()).toList(),
    };
  });

  String _phaseLabel(int phaseIndex) {
    const phaseNames = ['拆除', '水电', '防水', '泥瓦', '木工', '油漆', '安装', '清洁'];
    if (phaseIndex >= 0 && phaseIndex < phaseNames.length) {
      return phaseNames[phaseIndex];
    }
    return '待确认工序';
  }

  bool _sameServicePhase(BookedWorker a, BookedWorker b) {
    if (a.phaseIndex >= 0 && b.phaseIndex >= 0) {
      return a.phaseIndex == b.phaseIndex;
    }
    final aKey = '${a.phaseName}-${a.trade}'.trim();
    final bKey = '${b.phaseName}-${b.trade}'.trim();
    return aKey.isNotEmpty && aKey == bKey;
  }

  Future<void> bookWorker(BookedWorker worker) => _mutate(() {
    final existingIndex = _bookedWorkers.indexWhere(
      (item) => item.id == worker.id || _sameServicePhase(item, worker),
    );
    final now = DateTime.now();
    final booked = worker.copyWith(bookedAt: worker.bookedAt ?? now);
    final nextWorkers = _bookedWorkers.toList();
    if (existingIndex >= 0) {
      nextWorkers[existingIndex] = booked;
    } else {
      nextWorkers.insert(0, booked);
    }
    final message = OwnerMessage(
      id: 'msg-booking-${now.millisecondsSinceEpoch}',
      title: '预约已确认',
      content:
          '您已成功预约${booked.name}（${_phaseLabel(booked.phaseIndex)}·${booked.trade}）。',
      category: '预约',
      createdAt: now,
    );
    return {
      ...toJson(),
      'bookedWorkers': nextWorkers.map((item) => item.toJson()).toList(),
      'messages': [message, ..._messages].map((item) => item.toJson()).toList(),
    };
  });

  Future<void> cancelBookedWorker(String id) => _mutate(() {
    final existing = _bookedWorkers.where((item) => item.id == id).toList();
    if (existing.isEmpty) return null;
    final target = existing.first;
    final now = DateTime.now();
    final message = OwnerMessage(
      id: 'msg-cancel-${now.millisecondsSinceEpoch}',
      title: '预约已取消',
      content: '已取消${target.name}（${target.phaseName}·${target.trade}）的预约。',
      category: '预约',
      createdAt: now,
    );
    final nextWorkers = _bookedWorkers.where((item) => item.id != id).toList();
    return {
      ...toJson(),
      'bookedWorkers': nextWorkers.map((item) => item.toJson()).toList(),
      'messages': [message, ..._messages].map((item) => item.toJson()).toList(),
    };
  });

  Future<void> confirmPhaseComplete(int phaseIndex) => _mutate(() {
    if (_completedPhases.contains(phaseIndex)) return null;
    final now = DateTime.now();
    final nextPhases = {..._completedPhases, phaseIndex};
    final nextWorkers = _bookedWorkers
        .map(
          (item) => item.phaseIndex == phaseIndex
              ? item.copyWith(status: '已完成')
              : item,
        )
        .toList();
    final message = OwnerMessage(
      id: 'msg-phase-complete-${now.millisecondsSinceEpoch}',
      title: '${_phaseLabel(phaseIndex)}阶段已完成',
      content: '业主已确认${_phaseLabel(phaseIndex)}阶段完成。',
      category: '项目',
      createdAt: now,
    );
    return {
      ...toJson(),
      'bookedWorkers': nextWorkers.map((item) => item.toJson()).toList(),
      'completedPhases': nextPhases.toList(),
      'messages': [message, ..._messages].map((item) => item.toJson()).toList(),
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

  Future<void> selectProject(String id) => _mutate(() {
    if (id == _selectedProjectId || !_projects.any((item) => item.id == id)) {
      return null;
    }
    return {...toJson(), 'selectedProjectId': id};
  });

  Future<void> updateProject(OwnerProject value) => _mutate(() {
    final index = _projects.indexWhere((item) => item.id == value.id);
    if (index < 0 ||
        jsonEncode(_projects[index].toJson()) == jsonEncode(value.toJson())) {
      return null;
    }
    final next = [..._projects]..[index] = value;
    return {...toJson(), 'projects': next.map((e) => e.toJson()).toList()};
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

  /// 完成后端认证：安全令牌保存成功后才进入登录态。
  Future<void> completeAuthenticatedLogin(OwnerLoginResponse response) async {
    final session = AuthSession.fromLogin(response);
    await _sessionStore.save(session);
    try {
      await _mutate(() {
        return {
          ...toJson(),
          'profile': _profile.copyWith(phone: response.user.phone).toJson(),
          'isLoggedIn': true,
        };
      });
    } catch (_) {
      await _sessionStore.clear();
      rethrow;
    }
    try {
      await refreshOwnerProfile();
    } on AuthApiException {
      // Login remains successful for retryable profile-fetch failures. A 401 is
      // handled by refreshOwnerProfile and has already cleared login state.
    }
  }

  /// 首次登录完成资料填写。
  Future<void> completeOnboarding({
    String? name,
    required String decorationType,
    required String address,
    required double area,
  }) async {
    final nextProfile = _profile.copyWith(
      name: name?.trim().isNotEmpty == true ? name!.trim() : _profile.name,
      decorationType: decorationType,
      address: address,
      area: area,
    );
    if (!nextProfile.isProfileComplete) return;
    final session = await _validSession();
    if (session != null) {
      try {
        final remote = await _profileApi.updateCurrent(
          session.accessToken,
          OwnerProfileUpdate(
            name: nextProfile.name,
            city: nextProfile.city,
            decorationType: nextProfile.decorationType,
            address: nextProfile.address,
            area: nextProfile.area,
          ),
        );
        await _mutate(
          () => {
            ...toJson(),
            'profile': _localProfile(remote).toJson(),
            'isLoggedIn': true,
          },
        );
        return;
      } catch (error) {
        await _handleProfileError(error);
        rethrow;
      }
    }
    await _mutate(
      () => {...toJson(), 'profile': nextProfile.toJson(), 'isLoggedIn': true},
    );
  }

  /// 退出登录：先删除安全令牌，再清理本地登录状态。
  Future<void> logout() async {
    await _sessionStore.clear();
    await _mutate(() {
      if (!_isLoggedIn) return null;
      return {...toJson(), 'isLoggedIn': false};
    });
  }

  /// Restores notification and privacy preferences only.
  /// Owner profile, addresses, projects, and submitted records are preserved.
  Future<void> resetSettings() => updateSettings(const OwnerSettings());
}
