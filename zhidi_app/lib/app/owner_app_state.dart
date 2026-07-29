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
import '../services/daily_report_api_client.dart';
import '../services/owner_booking_api_client.dart';
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
    required this._bookingApi,
    required this.ready,
    required OwnerProfile profile,
    required List<OwnerAddress> addresses,
    required List<OwnerProject> projects,
    required String? selectedProjectId,
    required List<OwnerReminder> reminders,
    required List<OwnerMessage> messages,
    required List<FavoriteWorker> favoriteWorkers,
    required List<OrderItem> appointments,
    required OwnerSettings settings,
    required List<AfterSalesRequest> afterSalesRequests,
    required List<FeedbackEntry> feedbackEntries,
    required List<BookedWorker> bookedWorkers,
    required Set<int> completedPhases,
    required Map<int, DateTime> phaseCompletedAt,
    required this._dailyReports,
    required this._inspections,
    required this._archives,
    required List<MaterialEstimate> materialEstimates,
    required Map<String, List<ChatMessage>> chatMessages,
    required List<SavedQuote> savedQuotes,
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
       _completedPhases = completedPhases,
       // ignore: prefer_initializing_formals
       _phaseCompletedAt = phaseCompletedAt,
       // ignore: prefer_initializing_formals
       _materialEstimates = materialEstimates,
       // ignore: prefer_initializing_formals
       _chatMessages = chatMessages,
       // ignore: prefer_initializing_formals
       _savedQuotes = savedQuotes;

  static const String documentKey = 'owner.appState';
  final OwnerKeyValueStore _store;
  final AuthSessionStore _sessionStore;
  final OwnerProfileApi _profileApi;
  final OwnerBookingApi _bookingApi;
  DailyReportApiClient? _reportApi;
  final bool ready;

  OwnerProfile _profile;
  List<OwnerAddress> _addresses;
  List<OwnerProject> _projects;
  String? _selectedProjectId;
  List<OwnerReminder> _reminders;
  List<OwnerMessage> _messages;
  List<FavoriteWorker> _favoriteWorkers;
  List<OrderItem> _appointments;
  OwnerSettings _settings;
  List<AfterSalesRequest> _afterSalesRequests;
  List<FeedbackEntry> _feedbackEntries;
  List<BookedWorker> _bookedWorkers;
  Set<int> _completedPhases;
  Map<int, DateTime> _phaseCompletedAt;
  List<DailyReport> _dailyReports;
  List<InspectionRequest> _inspections;
  List<RenovationArchive> _archives;
  List<MaterialEstimate> _materialEstimates;
  Map<String, List<ChatMessage>> _chatMessages = {};
  List<SavedQuote> _savedQuotes = [];
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
  Map<int, DateTime> get phaseCompletedAt =>
      Map.unmodifiable(_phaseCompletedAt);
  List<DailyReport> get dailyReports => List.unmodifiable(_dailyReports);
  List<InspectionRequest> get inspections => List.unmodifiable(_inspections);
  List<RenovationArchive> get archives => List.unmodifiable(_archives);
  List<MaterialEstimate> get materialEstimates =>
      List.unmodifiable(_materialEstimates);
  Map<String, List<ChatMessage>> get chatMessages =>
      Map.unmodifiable(_chatMessages);
  bool get isLoggedIn => _isLoggedIn;
  bool _isFetchingRemoteBookings = false;
  String? _remoteBookingError;
  bool get isFetchingRemoteBookings => _isFetchingRemoteBookings;
  String? get remoteBookingError => _remoteBookingError;
  int get unreadMessageCount =>
      _messages.where((message) => !message.isRead).length;

  static Future<OwnerAppState> memory({
    OwnerKeyValueStore? store,
    AuthSessionStore? sessionStore,
    OwnerProfileApi? profileApi,
    OwnerBookingApi? bookingApi,
  }) async {
    final targetStore = store ?? MemoryOwnerStore();
    return _fromStored(
      targetStore,
      sessionStore ?? MemoryAuthSessionStore(),
      profileApi ?? OwnerProfileApiClient(),
      bookingApi ?? OwnerBookingApiClient(),
    );
  }

  static Future<OwnerAppState> load({
    AuthSessionStore? sessionStore,
    OwnerProfileApi? profileApi,
    OwnerBookingApi? bookingApi,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    return _fromStored(
      SharedPreferencesOwnerStore(preferences),
      sessionStore ?? SecureAuthSessionStore(),
      profileApi ?? OwnerProfileApiClient(),
      bookingApi ?? OwnerBookingApiClient(),
    );
  }

  factory OwnerAppState.fromJson(Map<String, dynamic> json) => _fromMap(
    json,
    MemoryOwnerStore(),
    MemoryAuthSessionStore(),
    OwnerProfileApiClient(),
    OwnerBookingApiClient(),
  );

  static Future<OwnerAppState> _fromStored(
    OwnerKeyValueStore store,
    AuthSessionStore sessionStore,
    OwnerProfileApi profileApi,
    OwnerBookingApi bookingApi,
  ) async {
    final encoded = store.getString(documentKey);
    final state = encoded != null
        ? _tryDecode(encoded, store, sessionStore, profileApi, bookingApi)
        : _seeded(store, sessionStore, profileApi, bookingApi);
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
        await state.fetchRemoteBookings();
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
    OwnerBookingApi bookingApi,
  ) {
    try {
      return _fromMap(
        jsonDecode(encoded) as Map<String, dynamic>,
        store,
        sessionStore,
        profileApi,
        bookingApi,
      );
    } on FormatException {
      return _seeded(store, sessionStore, profileApi, bookingApi);
    } on TypeError {
      return _seeded(store, sessionStore, profileApi, bookingApi);
    }
  }

  static OwnerAppState _fromMap(
    Map<String, dynamic> json,
    OwnerKeyValueStore store,
    AuthSessionStore sessionStore,
    OwnerProfileApi profileApi,
    OwnerBookingApi bookingApi,
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
      bookingApi: bookingApi,
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
      appointments: read('appointments', OrderItem.fromJson),
      settings: OwnerSettings.fromJson(
        Map<String, dynamic>.from(json['settings'] as Map? ?? const {}),
      ),
      afterSalesRequests: read(
        'afterSalesRequests',
        AfterSalesRequest.fromJson,
      ),
      feedbackEntries: read('feedbackEntries', FeedbackEntry.fromJson),
      bookedWorkers: json.containsKey('bookedWorkers')
          ? read('bookedWorkers', BookedWorker.fromJson)
          : _seeded(store, sessionStore, profileApi, bookingApi).bookedWorkers,
      completedPhases: json.containsKey('completedPhases')
          ? Set<int>.from(
              (json['completedPhases'] as List<dynamic>? ?? const []).map(
                (e) => e as int,
              ),
            )
          : _seeded(
              store,
              sessionStore,
              profileApi,
              bookingApi,
            ).completedPhases,
      phaseCompletedAt: json.containsKey('phaseCompletedAt')
          ? (json['phaseCompletedAt'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(int.parse(k), DateTime.parse(v as String)),
            )
          : _seeded(
              store,
              sessionStore,
              profileApi,
              bookingApi,
            ).phaseCompletedAt,
      dailyReports: json.containsKey('dailyReports')
          ? read('dailyReports', DailyReport.fromJson)
          : _seeded(store, sessionStore, profileApi, bookingApi).dailyReports,
      inspections: json.containsKey('inspections')
          ? read('inspections', InspectionRequest.fromJson)
          : _seeded(store, sessionStore, profileApi, bookingApi).inspections,
      archives: json['archives'] is List
          ? read('archives', RenovationArchive.fromJson)
          : _seeded(store, sessionStore, profileApi, bookingApi).archives,
      materialEstimates: (() {
        if (json['materialEstimates'] is List) {
          return read('materialEstimates', MaterialEstimate.fromJson);
        }
        return _seeded(
          store,
          sessionStore,
          profileApi,
          bookingApi,
        ).materialEstimates;
      })(),
      chatMessages: (() {
        if (json['chatMessages'] is Map) {
          final raw = json['chatMessages'] as Map<String, dynamic>;
          return raw.map((key, msgs) {
            final list = (msgs as List<dynamic>)
                .map(
                  (e) =>
                      ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)),
                )
                .toList();
            return MapEntry(key, list);
          });
        }
        return <String, List<ChatMessage>>{};
      })(),
      savedQuotes: json.containsKey('savedQuotes')
          ? read('savedQuotes', SavedQuote.fromJson)
          : const [],
      isLoggedIn: json['isLoggedIn'] as bool? ?? false,
    );
  }

  static OwnerAppState _seeded(
    OwnerKeyValueStore store,
    AuthSessionStore sessionStore,
    OwnerProfileApi profileApi,
    OwnerBookingApi bookingApi,
  ) => OwnerAppState._(
    store: store,
    sessionStore: sessionStore,
    profileApi: profileApi,
    bookingApi: bookingApi,
    ready: true,
    profile: const OwnerProfile(name: '', city: '', phone: ''),
    addresses: const [],
    projects: const [],
    selectedProjectId: null,
    reminders: const [],
    messages: const [],
    favoriteWorkers: const [],
    appointments: const [],
    settings: const OwnerSettings(),
    afterSalesRequests: const [],
    feedbackEntries: const [],
    bookedWorkers: const [],
    completedPhases: const {},
    phaseCompletedAt: const {},
    inspections: const [],
    archives: const [],
    dailyReports: const [],
    materialEstimates: const [],
    isLoggedIn: false,
    chatMessages: const {},
    savedQuotes: const [],
  );

  Map<String, dynamic> toJson() => {
    'profile': _profile.toJson(),
    'addresses': _addresses.map((item) => item.toJson()).toList(),
    'projects': _projects.map((item) => item.toJson()).toList(),
    'selectedProjectId': _selectedProjectId,
    'reminders': _reminders.map((item) => item.toJson()).toList(),
    'messages': _messages.map((item) => item.toJson()).toList(),
    'favoriteWorkers': _favoriteWorkers.map((item) => item.toJson()).toList(),
    'appointments': _appointments.map((item) => item.toJson()).toList(),
    'settings': _settings.toJson(),
    'afterSalesRequests': _afterSalesRequests
        .map((item) => item.toJson())
        .toList(),
    'feedbackEntries': _feedbackEntries.map((item) => item.toJson()).toList(),
    'bookedWorkers': _bookedWorkers.map((item) => item.toJson()).toList(),
    'completedPhases': _completedPhases.toList(),
    'phaseCompletedAt': Map<String, String>.fromEntries(
      _phaseCompletedAt.entries.map(
        (e) => MapEntry(e.key.toString(), e.value.toIso8601String()),
      ),
    ),
    'dailyReports': _dailyReports.map((item) => item.toJson()).toList(),
    'inspections': _inspections.map((item) => item.toJson()).toList(),
    'archives': _archives.map((item) => item.toJson()).toList(),
    'materialEstimates': _materialEstimates
        .map((item) => item.toJson())
        .toList(),
    'chatMessages': _chatMessages.map(
      (key, msgs) => MapEntry(key, msgs.map((m) => m.toJson()).toList()),
    ),
    'savedQuotes': _savedQuotes.map((e) => e.toJson()).toList(),
    'isLoggedIn': _isLoggedIn,
  };

  Future<void> _mutate(
    Map<String, dynamic>? Function() buildNext, {
    void Function()? directUpdate,
  }) {
    final operation = _mutationQueue.then((_) async {
      final next = buildNext();
      if (next == null) return;
      await _store.setString(documentKey, jsonEncode(next));
      if (directUpdate != null) {
        directUpdate();
      } else {
        final restored = _fromMap(
          next,
          _store,
          _sessionStore,
          _profileApi,
          _bookingApi,
        );
        _profile = restored._profile;
        _addresses = restored._addresses;
        _projects = restored._projects;
        _selectedProjectId = restored._selectedProjectId;
        _reminders = restored._reminders;
        _messages = restored._messages;
        _favoriteWorkers = restored._favoriteWorkers;
        _appointments = restored._appointments;
        _settings = restored._settings;
        _afterSalesRequests = restored._afterSalesRequests;
        _feedbackEntries = restored._feedbackEntries;
        _bookedWorkers = restored._bookedWorkers;
        _completedPhases = restored._completedPhases;
        _phaseCompletedAt = restored._phaseCompletedAt;
        _dailyReports = restored._dailyReports;
        _inspections = restored._inspections;
        _archives = restored._archives;
        _materialEstimates = restored._materialEstimates;
        _chatMessages = restored._chatMessages;
        _savedQuotes = restored._savedQuotes;
        _isLoggedIn = restored._isLoggedIn;
      }
      notifyListeners();
    });
    _mutationQueue = operation.then<void>(
      (_) {},
      onError: (e, st) {
        debugPrint('[OwnerAppState] _mutate queue error: $e\n$st');
      },
    );
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

  /// 获取当前有效 accessToken，若过期或未登录返回 null。
  Future<String?> getAccessToken() async {
    final session = await _sessionStore.read();
    if (session == null || session.isExpiredAt(DateTime.now())) return null;
    return session.accessToken;
  }

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

  Future<void> fetchRemoteBookings() async {
    final session = await _validSession();
    if (session == null) return;
    _isFetchingRemoteBookings = true;
    _remoteBookingError = null;
    notifyListeners();
    try {
      final remote = await _bookingApi.listOwnerBookings(session.accessToken);
      final remoteOrders = remote
          .map(
            (r) => OrderItem(
              id: 'rm-${r.id}',
              workerName: r.workerName,
              customerName: _profile.name,
              phone: _profile.phone,
              address: r.serviceAddress ?? '',
              area: '',
              description: r.remark ?? '',
              visitTime: '',
              status: switch (r.status) {
                'PENDING' => '待接单',
                'ACCEPTED' => '已确认',
                'VISIT_PROPOSED' => '待确认上门时间',
                'VISIT_SCHEDULED' => '已约定上门',
                'ARRIVAL_PENDING' => '待确认到场',
                'ON_SITE' => '已到场',
                'QUOTE_PENDING' => '待确认报价',
                'READY_TO_START' => '待开工',
                'HIRED' => '施工中',
                'REJECTED' => '已拒绝',
                'CANCELLED' => '已取消',
                'NOT_SELECTED' => '未选中',
                _ => '状态异常',
              },
              createdAt: r.createdAt,
            ),
          )
          .toList();
      final existingMessageIds = _messages.map((m) => m.id).toSet();
      final acceptedMessages = remote
          .where((r) => r.status == 'ACCEPTED')
          .map(_acceptedBookingMessage)
          .where((message) => !existingMessageIds.contains(message.id))
          .toList();
      final pendingMessages = remote
          .where((r) => r.status == 'PENDING')
          .map(_pendingBookingMessage)
          .where((message) => !existingMessageIds.contains(message.id))
          .toList();
      final nextMessages = [
        ...acceptedMessages,
        ...pendingMessages,
        ..._messages,
      ];
      await _mutate(() {
        return {
          ...toJson(),
          'appointments': remoteOrders.map((e) => e.toJson()).toList(),
          if (acceptedMessages.isNotEmpty || pendingMessages.isNotEmpty)
            'messages': nextMessages.map((e) => e.toJson()).toList(),
        };
      });
    } catch (error) {
      await _handleProfileError(error);
      _remoteBookingError = error is AuthApiException
          ? error.message
          : '预约同步失败，请稍后重试';
    } finally {
      _isFetchingRemoteBookings = false;
      notifyListeners();
    }
  }

  OwnerMessage _pendingBookingMessage(RemoteOwnerBooking booking) {
    final address = booking.serviceAddress?.trim();
    final addressText = address == null || address.isEmpty
        ? ''
        : '服务地址：$address。';
    return OwnerMessage(
      id: 'msg-remote-booking-pending-${booking.id}',
      title: '预约已提交',
      content:
          '您已预约${booking.workerName}（${_tradeLabel(booking.trade)}），'
          '正在等待师傅接单。$addressText',
      category: '预约',
      createdAt: booking.createdAt.toLocal(),
    );
  }

  OwnerMessage _acceptedBookingMessage(RemoteOwnerBooking booking) {
    final address = booking.serviceAddress?.trim();
    final addressText = address == null || address.isEmpty
        ? ''
        : '服务地址：$address。';
    return OwnerMessage(
      id: 'msg-remote-booking-accepted-${booking.id}',
      title: '工人已接单',
      content:
          '您预约的${booking.workerName}（${_tradeLabel(booking.trade)}）已接单，'
          '师傅将与您联系确认上门时间。$addressText',
      category: '预约',
      createdAt: booking.updatedAt.toLocal(),
    );
  }

  String _tradeLabel(String apiTrade) {
    return switch (apiTrade.trim()) {
      'demolition' => '拆除',
      'plumbing' => '水电',
      'masonry' => '泥瓦',
      'waterproof' => '防水',
      'carpentry' => '木工',
      'painting' => '油漆',
      'installation' => '安装',
      'cleaning' => '保洁',
      final value => value,
    };
  }

  void initReportApi(DailyReportApiClient api) {
    _reportApi = api;
  }

  Future<List<RemoteDailyReport>> fetchDailyReports(String bookingId) async {
    final session = await _validSession();
    if (session == null || _reportApi == null) return [];

    try {
      final remote = await _reportApi!.getReportsByBooking(
        session.accessToken,
        bookingId,
      );
      final syncedReports = remote
          .map(
            (r) => DailyReport(
              id: r.id,
              workerId: r.workerUserId,
              date: r.createdAt,
              imagePaths: r.photos,
              note: r.content,
              phaseIndex: 0,
            ),
          )
          .toList();
      await _mutate(() {
        return {
          ...toJson(),
          'dailyReports': syncedReports.map((e) => e.toJson()).toList(),
        };
      });
      return remote;
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
          value.phone == _profile.phone) {
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
    // 避免重复：同工种+同师傅只保留最新
    final filtered = _savedQuotes
        .where(
          (q) =>
              !(q.workerName == quote.workerName &&
                  q.tradeName == quote.tradeName),
        )
        .toList();
    final next = [quote, ...filtered];
    return {...toJson(), 'savedQuotes': next.map((e) => e.toJson()).toList()};
  });

  Future<void> removeSavedQuote(String id) => _mutate(() {
    final next = _savedQuotes.where((q) => q.id != id).toList();
    if (next.length == _savedQuotes.length) return null;
    return {...toJson(), 'savedQuotes': next.map((e) => e.toJson()).toList()};
  });

  Future<void> removeAppointment(String id) => _mutate(() {
    final next = _appointments.where((a) => a.id != id).toList();
    if (next.length == _appointments.length) return null;
    return {...toJson(), 'appointments': next.map((e) => e.toJson()).toList()};
  });

  /// 取消远端预约（远程订单）
  Future<void> cancelRemoteBooking(String localId) async {
    final session = await _validSession();
    if (session == null) return;
    // localId 格式 "rm-{uuid}"
    final remoteId = localId.startsWith('rm-') ? localId.substring(3) : localId;
    try {
      await _bookingApi.cancelBooking(session.accessToken, remoteId, '业主主动取消');
    } catch (error) {
      await _handleProfileError(error);
      rethrow;
    }
    await removeAppointment(localId);
  }

  Future<void> addAppointment(
    OrderItem appointment, {
    String? trade,
    int? phaseIndex,
    String? phaseName,
    String? workerId,
  }) async {
    final next = [appointment, ..._appointments];
    await _mutate(
      () {
        final json = toJson();
        json['appointments'] = next.map((item) => item.toJson()).toList();
        return json;
      },
      directUpdate: () {
        _appointments = next;
      },
    );
  }

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

  /// 预约师傅：服务端工人先创建真实预约，再写入本地 bookedWorkers 列表并生成消息通知。
  Future<void> bookWorker(
    BookedWorker worker, {
    String? remoteWorkerUserId,
    String? serviceCity,
  }) async {
    if (remoteWorkerUserId == null || remoteWorkerUserId.trim().isEmpty) {
      throw const AuthApiException(
        code: 'SERVER_WORKER_REQUIRED',
        message: '该师傅没有服务器资料，暂时不能预约',
        statusCode: 409,
      );
    }
    if (remoteWorkerUserId.isNotEmpty) {
      final session = await _validSession();
      if (session == null) {
        throw const AuthApiException(
          code: 'AUTHENTICATION_REQUIRED',
          message: '请先登录后再预约师傅',
          statusCode: 401,
        );
      }
      try {
        await _bookingApi.createBooking(
          session.accessToken,
          OwnerBookingCreateRequest(
            workerUserId: remoteWorkerUserId,
            trade: worker.trade,
            serviceCity: serviceCity ?? _profile.city,
            serviceAddress: _profile.address,
            remark: '来自安卓业主端',
          ),
        );
      } catch (error) {
        await _handleProfileError(error);
        rethrow;
      }
    }
    await _mutate(() {
      final existingIndex = _bookedWorkers.indexWhere(
        (w) => w.id == worker.id || _sameServicePhase(w, worker),
      );
      if (existingIndex >= 0) {
        // 同一个工种/工序已经预约过：更新为最新师傅，避免“我的服务”重复展示同工种
        final previous = _bookedWorkers[existingIndex];
        final updated = [..._bookedWorkers]
          ..[existingIndex] = worker.copyWith(
            bookedAt: worker.bookedAt ?? previous.bookedAt ?? DateTime.now(),
          );
        return {
          ...toJson(),
          'bookedWorkers': updated.map((e) => e.toJson()).toList(),
        };
      }
      final now = DateTime.now();
      final next = [worker.copyWith(bookedAt: now), ..._bookedWorkers];
      return {
        ...toJson(),
        'bookedWorkers': next.map((e) => e.toJson()).toList(),
      };
    });
    await fetchRemoteBookings();
  }

  bool _sameServicePhase(BookedWorker a, BookedWorker b) {
    if (a.phaseIndex >= 0 && b.phaseIndex >= 0) {
      return a.phaseIndex == b.phaseIndex;
    }
    final aKey = '${a.phaseName}-${a.trade}'.trim();
    final bKey = '${b.phaseName}-${b.trade}'.trim();
    return aKey.isNotEmpty && aKey == bKey;
  }

  /// 取消预约
  Future<void> cancelBookedWorker(String id) => _mutate(() {
    final target = _bookedWorkers.firstWhere(
      (w) => w.id == id,
      orElse: () => const BookedWorker(
        id: '',
        name: '',
        trade: '',
        phaseName: '',
        phaseIndex: -1,
        rating: 0,
        completedOrders: 0,
        years: 0,
        avatarEmoji: '',
        skills: [],
      ),
    );
    if (target.id.isEmpty) return null;
    final now = DateTime.now();
    final next = _bookedWorkers.where((w) => w.id != id).toList();
    final message = OwnerMessage(
      id: 'msg-cancel-${now.millisecondsSinceEpoch}',
      title: '预约已取消',
      content: '已取消${target.name}（${target.phaseName}·${target.trade}）的预约。',
      category: '预约',
      createdAt: now,
    );
    final nextMessages = [message, ..._messages];
    return {
      ...toJson(),
      'bookedWorkers': next.map((e) => e.toJson()).toList(),
      'messages': nextMessages.map((e) => e.toJson()).toList(),
    };
  });

  /// 确认某道工序完成
  Future<void> confirmPhaseComplete(int phaseIndex) => _mutate(() {
    if (_completedPhases.contains(phaseIndex)) return null;
    final phaseNames = const [
      '打拆',
      '水电',
      '防水',
      '泥工',
      '木工',
      '瓦工',
      '美缝',
      '安装',
      '清洁',
    ];
    final phaseLabel = phaseIndex < phaseNames.length
        ? phaseNames[phaseIndex]
        : '未知工序';
    final newPhases = {..._completedPhases, phaseIndex};
    // 标记该工序师傅为「已完成」
    final updatedWorkers = _bookedWorkers.map((w) {
      if (w.phaseIndex == phaseIndex && !w.isCompleted) {
        return w.copyWith(status: '已完成');
      }
      return w;
    }).toList();
    final now = DateTime.now();
    final newCompletedAt = {..._phaseCompletedAt, phaseIndex: now};
    final message = OwnerMessage(
      id: 'msg-phase-done-${now.millisecondsSinceEpoch}',
      title: '工序完成通知',
      content:
          '$phaseLabel 施工已完成，'
          '${phaseIndex + 1 < phaseNames.length ? '下一道工序「${phaseNames[phaseIndex + 1]}」可以进场。' : '全部工序结束！'}',
      category: '项目',
      createdAt: now,
    );
    final nextMessages = [message, ..._messages];
    return {
      ...toJson(),
      'completedPhases': newPhases.toList(),
      'phaseCompletedAt': Map<String, String>.fromEntries(
        newCompletedAt.entries.map(
          (e) => MapEntry(e.key.toString(), e.value.toIso8601String()),
        ),
      ),
      'bookedWorkers': updatedWorkers.map((e) => e.toJson()).toList(),
      'messages': nextMessages.map((e) => e.toJson()).toList(),
    };
  });

  /// 撤销工序完成 — 移除已完成标记、恢复师傅状态
  Future<void> undoPhaseComplete(int phaseIndex) => _mutate(() {
    if (!_completedPhases.contains(phaseIndex)) return null;
    final newPhases = {..._completedPhases};
    newPhases.remove(phaseIndex);
    final newCompletedAt = {..._phaseCompletedAt};
    newCompletedAt.remove(phaseIndex);
    final updatedWorkers = _bookedWorkers.map((w) {
      if (w.phaseIndex == phaseIndex && w.status == '已完成') {
        return w.copyWith(status: '已预约');
      }
      return w;
    }).toList();
    return {
      ...toJson(),
      'completedPhases': newPhases.toList(),
      'phaseCompletedAt': Map<String, String>.fromEntries(
        newCompletedAt.entries.map(
          (e) => MapEntry(e.key.toString(), e.value.toIso8601String()),
        ),
      ),
      'bookedWorkers': updatedWorkers.map((e) => e.toJson()).toList(),
    };
  });

  /// 申请验收 — 为指定工序创建验收请求
  Future<void> requestInspection(String workerId) => _mutate(() {
    final worker = _bookedWorkers.firstWhere(
      (w) => w.id == workerId,
      orElse: () => const BookedWorker(
        id: '',
        name: '',
        trade: '',
        phaseName: '',
        phaseIndex: -1,
        rating: 0,
        completedOrders: 0,
        years: 0,
        avatarEmoji: '',
        skills: [],
      ),
    );
    if (worker.id.isEmpty) return null;
    final now = DateTime.now();
    final inspection = InspectionRequest(
      id: 'insp-${now.millisecondsSinceEpoch}',
      workerId: worker.id,
      workerName: worker.name,
      phaseName: worker.phaseName,
      phaseIndex: worker.phaseIndex,
      requestedAt: now,
    );
    final newInspections = [..._inspections, inspection];
    return {
      ...toJson(),
      'inspections': newInspections.map((e) => e.toJson()).toList(),
    };
  });

  /// 验收合格 — 标记工序完成、通知下个工种
  Future<void> acceptInspection(String inspectionId) => _mutate(() {
    final idx = _inspections.indexWhere((i) => i.id == inspectionId);
    if (idx == -1 || _inspections[idx].status != InspectionStatus.pending) {
      return null;
    }
    final insp = _inspections[idx];
    final phaseNames = const ['打拆', '水电', '防水', '泥工', '木工', '美缝', '安装', '清洁'];
    final nextPhase = insp.phaseIndex + 1;
    final nextPhaseLabel = nextPhase < phaseNames.length
        ? phaseNames[nextPhase]
        : null;
    final now = DateTime.now();
    // 标记验收为已通过 + 标记该工序为已完成
    final newInspections = _inspections.toList()
      ..[idx] = insp.copyWith(status: InspectionStatus.accepted);
    final newPhases = {..._completedPhases, insp.phaseIndex};
    final newCompletedAt = {..._phaseCompletedAt, insp.phaseIndex: now};
    final updatedWorkers = _bookedWorkers.map((w) {
      if (w.phaseIndex == insp.phaseIndex) {
        return w.copyWith(status: '已完成');
      }
      if (w.phaseIndex == nextPhase && w.status == '已接单待进场') {
        return w.copyWith(status: '已接单待上门');
      }
      return w;
    }).toList();
    final messages = [
      OwnerMessage(
        id: 'msg-insp-pass-${now.millisecondsSinceEpoch}',
        title: '验收合格',
        content: '${insp.phaseName} 验收通过，工序完工。',
        category: '验收',
        createdAt: now,
      ),
      if (nextPhaseLabel != null)
        OwnerMessage(
          id: 'msg-next-phase-${now.millisecondsSinceEpoch + 1}',
          title: '下道工序通知',
          content: '下一道工序「$nextPhaseLabel」已就绪，师傅将联系您确认进场时间。',
          category: '项目',
          createdAt: now,
        ),
      ..._messages,
    ];
    // 生成装修档案
    final worker = _bookedWorkers.firstWhere(
      (w) => w.phaseIndex == insp.phaseIndex,
      orElse: () => BookedWorker(
        id: '',
        name: insp.workerName,
        trade: insp.phaseName,
        phaseName: insp.phaseName,
        phaseIndex: insp.phaseIndex,
        rating: 0,
        completedOrders: 0,
        years: 0,
        avatarEmoji: '',
        skills: [],
      ),
    );
    final reports = _dailyReports
        .where((r) => r.workerId == insp.workerId)
        .toList();
    final archive = RenovationArchive(
      id: 'arch-${insp.phaseIndex}-${now.millisecondsSinceEpoch}',
      phaseName: insp.phaseName,
      phaseIndex: insp.phaseIndex,
      workerName: insp.workerName,
      trade: worker.trade.isNotEmpty ? worker.trade : insp.phaseName,
      completedAt: now,
      startedAt: (() {
        if (reports.isEmpty) return null;
        final dates = reports.map((r) => r.date).whereType<DateTime>().toList();
        return dates.isNotEmpty
            ? dates.reduce((a, b) => a.isBefore(b) ? a : b)
            : null;
      })(),
      rating: worker.rating > 0 ? worker.rating : null,
      skills: worker.skills,
      photoUrls: reports.expand((r) => r.imagePaths).toList(),
      dailyNotes: reports.map((r) => r.note).toList(),
      avatarEmoji: worker.avatarEmoji.isNotEmpty ? worker.avatarEmoji : null,
    );
    final newArchives = [..._archives, archive];
    return {
      ...toJson(),
      'inspections': newInspections.map((e) => e.toJson()).toList(),
      'completedPhases': newPhases.toList(),
      'phaseCompletedAt': Map<String, String>.fromEntries(
        newCompletedAt.entries.map(
          (e) => MapEntry(e.key.toString(), e.value.toIso8601String()),
        ),
      ),
      'bookedWorkers': updatedWorkers.map((e) => e.toJson()).toList(),
      'messages': messages.map((e) => e.toJson()).toList(),
      'archives': newArchives.map((e) => e.toJson()).toList(),
    };
  });

  /// 验收通过（别名，兼容旧 API）
  Future<void> approveInspection(String inspectionId) =>
      acceptInspection(inspectionId);

  /// 验收不合格 — 通知工人整改
  Future<void> rejectInspection(String inspectionId, {String? note}) =>
      _mutate(() {
        final idx = _inspections.indexWhere((i) => i.id == inspectionId);
        if (idx == -1 || _inspections[idx].status != InspectionStatus.pending) {
          return null;
        }
        final insp = _inspections[idx];
        final now = DateTime.now();
        final newInspections = _inspections.toList()
          ..[idx] = insp.copyWith(
            status: InspectionStatus.rejected,
            inspectorNote: note,
          );
        final message = OwnerMessage(
          id: 'msg-insp-reject-${now.millisecondsSinceEpoch}',
          title: '验收不合格',
          content:
              '${insp.phaseName} 验收不通过，已通知${insp.workerName}整改。'
              '${note != null ? ' 整改意见：$note' : ''}',
          category: '验收',
          createdAt: now,
        );
        final nextMessages = [message, ..._messages];
        return {
          ...toJson(),
          'inspections': newInspections.map((e) => e.toJson()).toList(),
          'messages': nextMessages.map((e) => e.toJson()).toList(),
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

  /// 添加材料估算
  Future<void> addMaterialEstimate(MaterialEstimate estimate) => _mutate(() {
    final updated = [..._materialEstimates, estimate];
    return {
      ...toJson(),
      'materialEstimates': updated.map((e) => e.toJson()).toList(),
    };
  });

  /// 勾选/取消勾选材料项
  Future<void> toggleMaterialItem(String estimateId, String itemId) =>
      _mutate(() {
        final idx = _materialEstimates.indexWhere((e) => e.id == estimateId);
        if (idx == -1) return null;
        final estimate = _materialEstimates[idx];
        if (estimate.status != EstimateStatus.pending) return null;
        final selected = Set<String>.from(estimate.selectedItemIds);
        if (selected.contains(itemId)) {
          selected.remove(itemId);
        } else {
          selected.add(itemId);
        }
        final updated = _materialEstimates.toList()
          ..[idx] = estimate.copyWith(selectedItemIds: selected);
        return {
          ...toJson(),
          'materialEstimates': updated.map((e) => e.toJson()).toList(),
        };
      });

  /// 确认下单
  Future<void> confirmMaterialOrder(String estimateId) => _mutate(() {
    final idx = _materialEstimates.indexWhere((e) => e.id == estimateId);
    if (idx == -1) return null;
    final estimate = _materialEstimates[idx];
    if (estimate.status != EstimateStatus.pending) return null;
    if (estimate.selectedItemIds.isEmpty) return null;
    final now = DateTime.now();
    final delivery = now.add(const Duration(hours: 48));
    final updated = _materialEstimates.toList()
      ..[idx] = estimate.copyWith(
        status: EstimateStatus.ordered,
        orderedAt: now,
        estimatedDelivery: delivery,
      );
    final deliveryDesc = '预计 ${delivery.month}月${delivery.day}日送达';
    final message = OwnerMessage(
      id: 'msg-material-${now.millisecondsSinceEpoch}',
      title: '材料已下单',
      content:
          '${estimate.workerName}（${estimate.phaseName}）材料清单已确认下单，'
          '共 ${estimate.selectedCount} 项，合计 ¥${estimate.selectedTotal.toStringAsFixed(2)}，'
          '$deliveryDesc。',
      category: '材料',
      createdAt: now,
    );
    final nextMessages = [message, ..._messages];
    return {
      ...toJson(),
      'materialEstimates': updated.map((e) => e.toJson()).toList(),
      'messages': nextMessages.map((e) => e.toJson()).toList(),
    };
  });

  /// 确认材料采购（别名，兼容旧 API）
  Future<void> confirmMaterialEstimate(String estimateId) =>
      confirmMaterialOrder(estimateId);

  /// 获取某师傅的聊天记录
  List<ChatMessage> getChatMessages(String workerId) =>
      List.unmodifiable(_chatMessages[workerId] ?? const []);

  /// 追加聊天消息并持久化
  Future<void> addChatMessage(String workerId, ChatMessage msg) => _mutate(() {
    final next = Map<String, List<ChatMessage>>.from(_chatMessages);
    next.putIfAbsent(workerId, () => []);
    next[workerId] = [...next[workerId]!, msg];
    return {
      ...toJson(),
      'chatMessages': next.map(
        (key, msgs) => MapEntry(key, msgs.map((m) => m.toJson()).toList()),
      ),
    };
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

  /// 首次登录完成资料填写
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
    if (session == null) {
      throw const AuthApiException(
        code: 'NOT_AUTHENTICATED',
        message: '登录已过期，请重新登录',
      );
    }
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
    } catch (error) {
      await _handleProfileError(error);
      rethrow;
    }
  }

  /// 退出登录：先删除安全令牌，再清理本地登录状态。
  Future<void> logout() async {
    await _sessionStore.clear();
    await _mutate(() {
      if (!_isLoggedIn) return null;
      return {...toJson(), 'isLoggedIn': false};
    });
  }
}
