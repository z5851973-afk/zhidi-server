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
import '../services/business_event_api_client.dart';
import '../services/daily_report_api_client.dart';
import '../services/owner_address_api_client.dart';
import '../services/owner_booking_api_client.dart';
import '../services/owner_profile_api_client.dart';
import '../services/inspection_api_client.dart';
import '../services/payment_api_client.dart';
import '../services/service_request_api_client.dart';
import '../models/payment_models.dart';
import '../models/house_info.dart';

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

String _ownerVisitTimeLabel(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

bool _sameRemoteServiceRequests(
  List<RemoteServiceRequest> left,
  List<RemoteServiceRequest> right,
) => listEquals(
  left.map((request) => jsonEncode(request.toJson())).toList(),
  right.map((request) => jsonEncode(request.toJson())).toList(),
);

/// App-wide owner data, serialized as one document after every mutation.
class OwnerAppState extends ChangeNotifier {
  OwnerAppState._({
    required OwnerKeyValueStore store,
    required this._sessionStore,
    required this._profileApi,
    required this._addressApi,
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
    required Map<String, String> notificationFacts,
    required int businessEventCursor,
    required Set<String> remoteServiceRequestIds,
    required List<RemoteServiceRequest> remoteServiceRequests,
    required this._isLoggedIn,
    required this._sessionUserId,
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
       _savedQuotes = savedQuotes,
       // ignore: prefer_initializing_formals
       _notificationFacts = notificationFacts,
       // ignore: prefer_initializing_formals
       _businessEventCursor = businessEventCursor,
       // ignore: prefer_initializing_formals
       _remoteServiceRequestIds = remoteServiceRequestIds,
       // ignore: prefer_initializing_formals
       _remoteServiceRequests = remoteServiceRequests;

  static const String documentKey = 'owner.appState';
  final OwnerKeyValueStore _store;
  final AuthSessionStore _sessionStore;
  final OwnerProfileApi _profileApi;
  final OwnerAddressApi _addressApi;
  final OwnerBookingApi _bookingApi;
  DailyReportApiClient? _reportApi;
  BusinessEventApi _businessEventApi = BusinessEventApiClient();
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
  Map<String, String> _notificationFacts;
  int _businessEventCursor;
  Set<String> _remoteServiceRequestIds;
  List<RemoteServiceRequest> _remoteServiceRequests;
  bool _isLoggedIn;
  String? _sessionUserId;
  Future<void> _mutationQueue = Future<void>.value();

  OwnerProfile get profile => _profile;
  String get profileName => _profile.name;
  List<OwnerAddress> get addresses => List.unmodifiable(_addresses);
  OwnerAddress? get defaultAddress {
    if (_addresses.isEmpty) return null;
    return _addresses.firstWhere(
      (address) => address.isDefault,
      orElse: () => _addresses.first,
    );
  }

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
  List<RemoteServiceRequest> get remoteServiceRequests =>
      List.unmodifiable(_remoteServiceRequests);
  int get remoteProjectCount => _remoteServiceRequests.isNotEmpty
      ? _remoteServiceRequests.map((request) => request.id).toSet().length
      : _remoteServiceRequestIds.length;
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
  String? get sessionUserId => _sessionUserId;
  bool _isFetchingRemoteBookings = false;
  String? _remoteBookingError;
  int _sessionGeneration = 0;
  Future<void>? _remoteBookingFetchInFlight;
  Future<void>? _remoteBusinessFetchInFlight;
  Future<void>? _remoteBusinessEventFetchInFlight;
  Future<void>? _remoteServiceRequestFetchInFlight;
  int _remoteServiceRequestSnapshotVersion = 0;
  bool _isFetchingRemoteServiceRequests = false;
  String? _remoteServiceRequestError;
  bool get isFetchingRemoteBookings => _isFetchingRemoteBookings;
  String? get remoteBookingError => _remoteBookingError;
  bool get isFetchingRemoteServiceRequests => _isFetchingRemoteServiceRequests;
  String? get remoteServiceRequestError => _remoteServiceRequestError;
  int get unreadMessageCount =>
      _messages.where((message) => !message.isRead).length;
  int get businessEventCursor => _businessEventCursor;

  static Future<OwnerAppState> memory({
    OwnerKeyValueStore? store,
    AuthSessionStore? sessionStore,
    OwnerProfileApi? profileApi,
    OwnerAddressApi? addressApi,
    OwnerBookingApi? bookingApi,
  }) async {
    final targetStore = store ?? MemoryOwnerStore();
    return _fromStored(
      targetStore,
      sessionStore ?? MemoryAuthSessionStore(),
      profileApi ?? OwnerProfileApiClient(),
      addressApi ?? const _EmptyOwnerAddressApi(),
      bookingApi ?? OwnerBookingApiClient(),
    );
  }

  static Future<OwnerAppState> load({
    AuthSessionStore? sessionStore,
    OwnerProfileApi? profileApi,
    OwnerAddressApi? addressApi,
    OwnerBookingApi? bookingApi,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    return _fromStored(
      SharedPreferencesOwnerStore(preferences),
      sessionStore ?? SecureAuthSessionStore(),
      profileApi ?? OwnerProfileApiClient(),
      addressApi ?? OwnerAddressApiClient(),
      bookingApi ?? OwnerBookingApiClient(),
    );
  }

  factory OwnerAppState.fromJson(Map<String, dynamic> json) => _fromMap(
    json,
    MemoryOwnerStore(),
    MemoryAuthSessionStore(),
    OwnerProfileApiClient(),
    const _EmptyOwnerAddressApi(),
    OwnerBookingApiClient(),
  );

  static Future<OwnerAppState> _fromStored(
    OwnerKeyValueStore store,
    AuthSessionStore sessionStore,
    OwnerProfileApi profileApi,
    OwnerAddressApi addressApi,
    OwnerBookingApi bookingApi,
  ) async {
    final encoded = store.getString(documentKey);
    final state = encoded != null
        ? _tryDecode(
            encoded,
            store,
            sessionStore,
            profileApi,
            addressApi,
            bookingApi,
          )
        : _seeded(store, sessionStore, profileApi, addressApi, bookingApi);
    final session = await sessionStore.read();
    if (session == null || session.isExpiredAt(DateTime.now())) {
      await state._clearAuthenticatedState();
    } else {
      if (!state._belongsToSession(session)) {
        await state._mutate(() => state._emptyUserDocument(session: session));
      } else if (state._sessionUserId != session.userId || !state._isLoggedIn) {
        await state._mutate(
          () => {
            ...state.toJson(),
            'profile': state._profile.copyWith(phone: session.phone).toJson(),
            'isLoggedIn': true,
            'sessionUserId': session.userId,
          },
        );
      }
    }
    if (state._isLoggedIn) {
      try {
        await state.refreshOwnerProfile();
        await state.refreshOwnerAddresses();
        await state.fetchRemoteBookings();
      } on AuthApiException {
        // Restoring local state must remain usable while profile sync is
        // unavailable. refreshOwnerProfile already clears an invalid session.
      }
    }
    return state;
  }

  OwnerSettings _deviceSettings() =>
      OwnerSettings(darkMode: _settings.darkMode);

  Map<String, dynamic> _emptyUserDocument({AuthSession? session}) {
    final next =
        _seeded(
            _store,
            _sessionStore,
            _profileApi,
            _addressApi,
            _bookingApi,
          ).toJson()
          ..['settings'] = _deviceSettings().toJson()
          ..['isLoggedIn'] = session != null
          ..['sessionUserId'] = session?.userId;
    if (session != null) {
      next['profile'] = const OwnerProfile(
        name: '',
        city: '',
        phone: '',
      ).copyWith(phone: session.phone).toJson();
    }
    return next;
  }

  bool _belongsToSession(AuthSession session) =>
      _sessionUserId == session.userId ||
      (_sessionUserId == null &&
          _isLoggedIn &&
          _profile.phone == session.phone);

  static OwnerAppState _tryDecode(
    String encoded,
    OwnerKeyValueStore store,
    AuthSessionStore sessionStore,
    OwnerProfileApi profileApi,
    OwnerAddressApi addressApi,
    OwnerBookingApi bookingApi,
  ) {
    try {
      return _fromMap(
        jsonDecode(encoded) as Map<String, dynamic>,
        store,
        sessionStore,
        profileApi,
        addressApi,
        bookingApi,
      );
    } on FormatException {
      return _seeded(store, sessionStore, profileApi, addressApi, bookingApi);
    } on TypeError {
      return _seeded(store, sessionStore, profileApi, addressApi, bookingApi);
    }
  }

  static OwnerAppState _fromMap(
    Map<String, dynamic> json,
    OwnerKeyValueStore store,
    AuthSessionStore sessionStore,
    OwnerProfileApi profileApi,
    OwnerAddressApi addressApi,
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
      addressApi: addressApi,
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
          : _seeded(
              store,
              sessionStore,
              profileApi,
              addressApi,
              bookingApi,
            ).bookedWorkers,
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
              addressApi,
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
              addressApi,
              bookingApi,
            ).phaseCompletedAt,
      dailyReports: json.containsKey('dailyReports')
          ? read('dailyReports', DailyReport.fromJson)
          : _seeded(
              store,
              sessionStore,
              profileApi,
              addressApi,
              bookingApi,
            ).dailyReports,
      inspections: json.containsKey('inspections')
          ? read('inspections', InspectionRequest.fromJson)
          : _seeded(
              store,
              sessionStore,
              profileApi,
              addressApi,
              bookingApi,
            ).inspections,
      archives: json['archives'] is List
          ? read('archives', RenovationArchive.fromJson)
          : _seeded(
              store,
              sessionStore,
              profileApi,
              addressApi,
              bookingApi,
            ).archives,
      materialEstimates: (() {
        if (json['materialEstimates'] is List) {
          return read('materialEstimates', MaterialEstimate.fromJson);
        }
        return _seeded(
          store,
          sessionStore,
          profileApi,
          addressApi,
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
      notificationFacts: Map<String, String>.from(
        json['notificationFacts'] as Map? ?? const <String, String>{},
      ),
      businessEventCursor:
          ((json['_businessEventCursor'] as num?)?.toInt() ?? 0)
              .clamp(0, 1 << 62)
              .toInt(),
      remoteServiceRequestIds: Set<String>.from(
        (json['remoteServiceRequestIds'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .where((id) => id.isNotEmpty),
      ),
      remoteServiceRequests: read(
        'remoteServiceRequests',
        RemoteServiceRequest.fromJson,
      ),
      isLoggedIn: json['isLoggedIn'] as bool? ?? false,
      sessionUserId: json['sessionUserId'] as String?,
    );
  }

  static OwnerAppState _seeded(
    OwnerKeyValueStore store,
    AuthSessionStore sessionStore,
    OwnerProfileApi profileApi,
    OwnerAddressApi addressApi,
    OwnerBookingApi bookingApi,
  ) => OwnerAppState._(
    store: store,
    sessionStore: sessionStore,
    profileApi: profileApi,
    addressApi: addressApi,
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
    sessionUserId: null,
    chatMessages: const {},
    savedQuotes: const [],
    notificationFacts: const {},
    businessEventCursor: 0,
    remoteServiceRequestIds: const {},
    remoteServiceRequests: const [],
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
    'notificationFacts': _notificationFacts,
    '_businessEventCursor': _businessEventCursor,
    'remoteServiceRequestIds': _remoteServiceRequestIds.toList(),
    'remoteServiceRequests': _remoteServiceRequests
        .map((request) => request.toJson())
        .toList(),
    'isLoggedIn': _isLoggedIn,
    'sessionUserId': _sessionUserId,
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
          _addressApi,
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
        _notificationFacts = restored._notificationFacts;
        _businessEventCursor = restored._businessEventCursor;
        _remoteServiceRequestIds = restored._remoteServiceRequestIds;
        _remoteServiceRequests = restored._remoteServiceRequests;
        _isLoggedIn = restored._isLoggedIn;
        _sessionUserId = restored._sessionUserId;
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

  Future<AuthSession> _requireOwnerSession() async {
    final session = await _validSession();
    if (session != null) return session;
    throw const AuthApiException(
      code: 'NOT_AUTHENTICATED',
      message: '登录已过期，请重新登录',
    );
  }

  OwnerProfile _localProfile(RemoteOwnerProfile remote) => OwnerProfile(
    name: remote.name ?? '',
    city: remote.city,
    phone: remote.phone,
    avatarUrl: remote.avatarUrl,
    gender: remote.gender,
    decorationType: remote.decorationType,
    address: remote.address,
    area: remote.area,
  );

  OwnerAddress _localAddress(RemoteOwnerAddress remote) => OwnerAddress(
    id: remote.id,
    recipient: remote.recipient,
    phone: remote.phone,
    province: remote.province,
    city: remote.city,
    district: remote.district,
    detail: remote.detail,
    isDefault: remote.isDefault,
    createdAt: remote.createdAt,
    updatedAt: remote.updatedAt,
  );

  OwnerAddressDraft _addressDraft(OwnerAddress address) => OwnerAddressDraft(
    recipient: address.recipient,
    phone: address.phone,
    province: address.province,
    city: address.city,
    district: address.district,
    detail: address.detail,
    isDefault: address.isDefault,
  );

  /// 获取当前有效 accessToken，若过期或未登录返回 null。
  Future<String?> getAccessToken() async {
    final session = await _sessionStore.read();
    if (session == null || session.isExpiredAt(DateTime.now())) return null;
    return session.accessToken;
  }

  Future<void> _clearAuthenticatedState() async {
    _sessionGeneration += 1;
    _remoteServiceRequestSnapshotVersion += 1;
    _remoteBookingFetchInFlight = null;
    _remoteBusinessFetchInFlight = null;
    _remoteBusinessEventFetchInFlight = null;
    _remoteServiceRequestFetchInFlight = null;
    _isFetchingRemoteBookings = false;
    _isFetchingRemoteServiceRequests = false;
    _remoteBookingError = null;
    _remoteServiceRequestError = null;
    await _sessionStore.clear();
    await _mutate(() => _emptyUserDocument());
  }

  bool _isCurrentSession(int generation) => generation == _sessionGeneration;

  Future<void> _handleProfileError(Object error) async {
    if (error is AuthApiException && error.statusCode == 401) {
      await _clearAuthenticatedState();
    }
  }

  Future<void> refreshOwnerProfile() async {
    final generation = _sessionGeneration;
    final session = await _validSession();
    if (session == null || !_isCurrentSession(generation)) return;
    try {
      final remote = await _profileApi.getCurrent(session.accessToken);
      if (!_isCurrentSession(generation)) return;
      await _mutate(
        () => !_isCurrentSession(generation)
            ? null
            : {
                ...toJson(),
                'profile': _localProfile(remote).toJson(),
                'isLoggedIn': true,
              },
      );
    } catch (error) {
      if (!_isCurrentSession(generation)) return;
      await _handleProfileError(error);
      rethrow;
    }
  }

  Future<void> refreshOwnerAddresses() async {
    final generation = _sessionGeneration;
    final session = await _validSession();
    if (session == null || !_isCurrentSession(generation)) return;
    try {
      final remote = await _addressApi.list(session.accessToken);
      if (!_isCurrentSession(generation)) return;
      await _replaceRemoteAddresses(remote, sessionGeneration: generation);
    } catch (error) {
      if (!_isCurrentSession(generation)) return;
      await _handleProfileError(error);
      rethrow;
    }
  }

  Future<void> _replaceRemoteAddresses(
    Iterable<RemoteOwnerAddress> remote, {
    int? sessionGeneration,
  }) async {
    final next = remote.map(_localAddress).toList();
    await _mutate(() {
      if (sessionGeneration != null && !_isCurrentSession(sessionGeneration)) {
        return null;
      }
      return {
        ...toJson(),
        'addresses': next.map((address) => address.toJson()).toList(),
      };
    });
  }

  Future<void> fetchRemoteBookings() {
    final inFlight = _remoteBookingFetchInFlight;
    if (inFlight != null) return inFlight;
    final operation = _doFetchRemoteBookings();
    _remoteBookingFetchInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_remoteBookingFetchInFlight, operation)) {
        _remoteBookingFetchInFlight = null;
      }
    });
  }

  Future<void> fetchRemoteServiceRequests({
    ServiceRequestApi? serviceRequestApi,
  }) {
    final inFlight = _remoteServiceRequestFetchInFlight;
    if (inFlight != null) return inFlight;
    final snapshotVersion = ++_remoteServiceRequestSnapshotVersion;
    final operation = _doFetchRemoteServiceRequests(
      serviceRequestApi: serviceRequestApi,
      snapshotVersion: snapshotVersion,
    );
    _remoteServiceRequestFetchInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_remoteServiceRequestFetchInFlight, operation)) {
        _remoteServiceRequestFetchInFlight = null;
        // A business-notification refresh can supersede this request's
        // snapshot while it is still pending. In that case the operation's
        // own finally intentionally does not change the flag, but there is
        // no newer explicit request using this in-flight slot. Clear it here
        // so callers are never left in a permanent loading state.
        if (_isFetchingRemoteServiceRequests) {
          _isFetchingRemoteServiceRequests = false;
          notifyListeners();
        }
      }
    });
  }

  Future<void> _doFetchRemoteServiceRequests({
    ServiceRequestApi? serviceRequestApi,
    required int snapshotVersion,
  }) async {
    final generation = _sessionGeneration;
    final session = await _validSession();
    if (session == null || !_isCurrentSession(generation)) return;
    _isFetchingRemoteServiceRequests = true;
    _remoteServiceRequestError = null;
    notifyListeners();
    try {
      final api = serviceRequestApi ?? ServiceRequestApiClient();
      final remote = await api.listOwnerRequests(session.accessToken);
      if (!_isCurrentSession(generation) ||
          snapshotVersion != _remoteServiceRequestSnapshotVersion) {
        return;
      }
      final requestIds = remote.map((request) => request.id).toSet();
      await _mutate(() {
        if (!_isCurrentSession(generation) ||
            snapshotVersion != _remoteServiceRequestSnapshotVersion) {
          return null;
        }
        if (_sameRemoteServiceRequests(remote, _remoteServiceRequests) &&
            setEquals(requestIds, _remoteServiceRequestIds)) {
          return null;
        }
        return {
          ...toJson(),
          'remoteServiceRequests': remote
              .map((request) => request.toJson())
              .toList(),
          'remoteServiceRequestIds': requestIds.toList(),
        };
      });
    } catch (error) {
      if (!_isCurrentSession(generation) ||
          snapshotVersion != _remoteServiceRequestSnapshotVersion) {
        return;
      }
      await _handleProfileError(error);
      if (!_isCurrentSession(generation)) return;
      _remoteServiceRequestError = error is AuthApiException
          ? error.message
          : '暂时无法加载项目，请重试';
    } finally {
      if (_isCurrentSession(generation) &&
          snapshotVersion == _remoteServiceRequestSnapshotVersion) {
        _isFetchingRemoteServiceRequests = false;
        notifyListeners();
      }
    }
  }

  Future<void> _doFetchRemoteBookings() async {
    final generation = _sessionGeneration;
    final session = await _validSession();
    if (session == null || !_isCurrentSession(generation)) return;
    _isFetchingRemoteBookings = true;
    _remoteBookingError = null;
    notifyListeners();
    try {
      final remote = await _bookingApi.listOwnerBookings(session.accessToken);
      if (!_isCurrentSession(generation)) return;
      final remoteOrders = remote
          .map(
            (r) => OrderItem(
              id: 'rm-${r.id}',
              bookingId: r.id,
              serviceRequestId: r.serviceRequestId,
              workerName: r.workerName,
              customerName: _profile.name,
              phone: _profile.phone,
              address: r.serviceAddress ?? '',
              area: '',
              description: r.remark ?? '',
              visitTime: _ownerVisitTimeLabel(r.scheduledVisitAt),
              scheduledVisitAt: r.scheduledVisitAt,
              actualOnSiteAt: r.actualOnSiteAt ?? r.onSiteAt,
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
                'COMPLETED' => '已完成',
                'REJECTED' => '已拒绝',
                'CANCELLED' => '已取消',
                'NOT_SELECTED' => '未选中',
                _ => '状态异常',
              },
              createdAt: r.createdAt,
            ),
          )
          .toList();
      final inferredRequestIds = {
        ..._remoteServiceRequestIds,
        ...remote.map((booking) => booking.serviceRequestId),
      };
      await _mutate(() {
        if (!_isCurrentSession(generation)) return null;
        final facts = Map<String, String>.of(_notificationFacts);
        final currentIds = _messages.map((message) => message.id).toSet();
        final newMessages = <OwnerMessage>[];
        for (final booking in remote) {
          final factKey = 'booking:${booking.id}';
          final previous = facts[factKey];
          final current = booking.status;
          if (previous != current) {
            final shouldNotify = previous != null || current == 'PENDING';
            final message = shouldNotify ? _bookingMessage(booking) : null;
            if (message != null &&
                !currentIds.contains(message.id) &&
                !_hasLegacyBookingMessage(message.eventType!, booking.id)) {
              currentIds.add(message.id);
              newMessages.add(message);
            }
            facts[factKey] = current;
          }
        }
        return {
          ...toJson(),
          'appointments': remoteOrders.map((e) => e.toJson()).toList(),
          'notificationFacts': facts,
          'remoteServiceRequestIds': inferredRequestIds.toList(),
          if (newMessages.isNotEmpty)
            'messages': [
              ...newMessages.reversed,
              ..._messages,
            ].map((e) => e.toJson()).toList(),
        };
      });
    } catch (error) {
      if (!_isCurrentSession(generation)) return;
      await _handleProfileError(error);
      if (!_isCurrentSession(generation)) return;
      _remoteBookingError = error is AuthApiException
          ? error.message
          : '预约同步失败，请稍后重试';
    } finally {
      if (_isCurrentSession(generation)) {
        _isFetchingRemoteBookings = false;
        notifyListeners();
      }
    }
  }

  bool _hasLegacyBookingMessage(String eventType, String bookingId) {
    final legacyId = switch (eventType) {
      'PENDING' => 'msg-remote-booking-pending-$bookingId',
      'ACCEPTED' => 'msg-remote-booking-accepted-$bookingId',
      'VISIT_PROPOSED' => 'msg-remote-booking-visit-proposed-$bookingId',
      _ => null,
    };
    return legacyId != null &&
        _messages.any((message) => message.id == legacyId);
  }

  OwnerMessage? _bookingMessage(RemoteOwnerBooking booking) {
    final event = switch (booking.status) {
      'PENDING' => (
        'PENDING',
        '预约已提交',
        '您已预约${booking.workerName}（${_tradeLabel(booking.trade)}），正在等待师傅接单。',
        'OWNER_BOOKING',
      ),
      'ACCEPTED' => (
        'ACCEPTED',
        '工人已接单',
        '您预约的${booking.workerName}（${_tradeLabel(booking.trade)}）已接单，师傅将与您联系确认上门时间。',
        'OWNER_BOOKING',
      ),
      'VISIT_PROPOSED' => (
        'VISIT_PROPOSED',
        '待确认上门时间',
        '${booking.workerName}（${_tradeLabel(booking.trade)}）已提交上门时间，请前往订单确认上门时间。',
        'OWNER_BOOKING',
      ),
      'VISIT_SCHEDULED' => (
        'VISIT_SCHEDULED',
        '上门时间已确认',
        '您与${booking.workerName}的上门时间已确认。',
        'OWNER_BOOKING',
      ),
      'ARRIVAL_PENDING' => (
        'ARRIVAL_PENDING',
        '待确认到场',
        '该订单已进入到场确认阶段，请查看候选工人详情。',
        'OWNER_BOOKING',
      ),
      'QUOTE_PENDING' => (
        'QUOTE_SUBMITTED',
        '报价已提交',
        '${booking.workerName}已提交报价，请前往报价比较。',
        'OWNER_QUOTE_COMPARISON',
      ),
      'READY_TO_START' || 'HIRED' => (
        'HIRED',
        '已选定施工师傅',
        '您已选定${booking.workerName}，请查看订单进度。',
        'OWNER_BOOKING',
      ),
      'NOT_SELECTED' => (
        'NOT_SELECTED',
        '候选工人已更新',
        '${booking.workerName}未被选为本次施工师傅。',
        'OWNER_BOOKING',
      ),
      _ => null,
    };
    if (event == null) return null;
    final address = booking.serviceAddress?.trim();
    final addressText = address == null || address.isEmpty
        ? ''
        : '服务地址：$address。';
    return OwnerMessage(
      id: 'owner:${event.$1}:${booking.id}',
      title: event.$2,
      content: '${event.$3}$addressText',
      category: '预约',
      createdAt:
          (booking.status == 'PENDING' ? booking.createdAt : booking.updatedAt)
              .toLocal(),
      eventType: event.$1,
      bookingId: booking.id,
      serviceRequestId: booking.serviceRequestId,
      targetAction: event.$4,
    );
  }

  void initBusinessEventApi(BusinessEventApi api) {
    _businessEventApi = api;
  }

  Future<void> fetchRemoteBusinessEvents({int pageSize = 100}) {
    if (pageSize < 1 || pageSize > 100) {
      throw RangeError.range(pageSize, 1, 100, 'pageSize');
    }
    final inFlight = _remoteBusinessEventFetchInFlight;
    if (inFlight != null) return inFlight;
    final operation = _doFetchRemoteBusinessEvents(pageSize);
    _remoteBusinessEventFetchInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_remoteBusinessEventFetchInFlight, operation)) {
        _remoteBusinessEventFetchInFlight = null;
      }
    });
  }

  Future<void> _doFetchRemoteBusinessEvents(int pageSize) async {
    final generation = _sessionGeneration;
    final session = await _validSession();
    if (session == null || !_isCurrentSession(generation)) return;
    var after = _businessEventCursor;
    while (true) {
      final page = await _businessEventApi.list(
        session.accessToken,
        after: after,
        size: pageSize,
      );
      if (!_isCurrentSession(generation)) return;
      if (page.items.isEmpty) return;
      final messages = page.items.map(_ownerBusinessEventMessage).toList();
      await _mutate(() {
        if (!_isCurrentSession(generation) || _businessEventCursor != after) {
          return null;
        }
        final knownEventIds = _messages
            .map((message) => message.serverEventId)
            .whereType<String>()
            .toSet();
        final additions = messages
            .where((message) => knownEventIds.add(message.serverEventId!))
            .toList();
        return {
          ...toJson(),
          '_businessEventCursor': page.nextCursor,
          if (additions.isNotEmpty)
            'messages': [
              ...additions.reversed,
              ..._messages,
            ].map((message) => message.toJson()).toList(),
        };
      });
      if (!_isCurrentSession(generation) ||
          _businessEventCursor != page.nextCursor) {
        return;
      }
      after = page.nextCursor;
      if (page.items.length < pageSize) return;
    }
  }

  OwnerMessage _ownerBusinessEventMessage(RemoteBusinessEvent event) {
    final round = event.payload?['round'];
    final revision = event.payload?['revision'];
    final reportDate = event.payload?['reportDate'];
    final presentation = switch (event.eventType) {
      'DAILY_REPORT_SUBMITTED' => (
        '施工日报已提交',
        reportDate == null
            ? '工人已提交施工日报${revision == null ? '' : '（第 $revision 版）'}。'
            : '工人已提交 $reportDate 施工日报${revision == null ? '' : '（第 $revision 版）'}。',
        '日报',
        'OWNER_DAILY_REPORT',
      ),
      'INSPECTION_REQUESTED' => (
        '待验收节点',
        '工人已发起${round == null ? '' : '第 $round 轮'}验收，请及时查看。',
        '验收',
        'OWNER_INSPECTION',
      ),
      'AFTER_SALE_CREATED' => (
        '售后工单已创建',
        '本单售后工单已创建，可进入工单查看最新进展。',
        '售后',
        'OWNER_AFTER_SALE',
      ),
      'AFTER_SALE_PARTICIPANT_MESSAGE' => (
        '售后有新回复',
        '工人已在售后工单中追加回复。',
        '售后',
        'OWNER_AFTER_SALE',
      ),
      'AFTER_SALE_PLATFORM_ACCEPTED' => (
        '平台已受理售后',
        '平台已受理本单售后，请查看处理进展。',
        '售后',
        'OWNER_AFTER_SALE',
      ),
      'AFTER_SALE_PLATFORM_REPLIED' => (
        '平台回复了售后',
        '平台已更新售后处理意见。',
        '售后',
        'OWNER_AFTER_SALE',
      ),
      'AFTER_SALE_RESOLVED' => (
        '售后已解决',
        '本单售后已有解决结果。',
        '售后',
        'OWNER_AFTER_SALE',
      ),
      'AFTER_SALE_CLOSED' => ('售后已关闭', '本单售后工单已关闭。', '售后', 'OWNER_AFTER_SALE'),
      _ => ('业务进度已更新', '本单有新的业务进展。', '系统', null),
    };
    return OwnerMessage(
      id: 'business:${event.eventId}',
      title: presentation.$1,
      content: presentation.$2,
      category: presentation.$3,
      createdAt: event.occurredAt.toLocal(),
      isRead: event.readAt != null,
      eventType: event.eventType,
      bookingId: event.bookingId,
      serviceRequestId: event.serviceRequestId,
      targetAction: presentation.$4,
      serverEventId: event.eventId,
      aggregateType: event.aggregateType,
      aggregateId: event.aggregateId,
    );
  }

  Future<void> fetchRemoteBusinessNotifications({
    ServiceRequestApi? serviceRequestApi,
    InspectionApi? inspectionApi,
    PaymentApiClient? paymentApi,
  }) {
    final inFlight = _remoteBusinessFetchInFlight;
    if (inFlight != null) return inFlight;
    final snapshotVersion = ++_remoteServiceRequestSnapshotVersion;
    final operation = _doFetchRemoteBusinessNotifications(
      serviceRequestApi: serviceRequestApi,
      inspectionApi: inspectionApi,
      paymentApi: paymentApi,
      snapshotVersion: snapshotVersion,
    );
    _remoteBusinessFetchInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_remoteBusinessFetchInFlight, operation)) {
        _remoteBusinessFetchInFlight = null;
      }
    });
  }

  Future<void> _doFetchRemoteBusinessNotifications({
    ServiceRequestApi? serviceRequestApi,
    InspectionApi? inspectionApi,
    PaymentApiClient? paymentApi,
    required int snapshotVersion,
  }) async {
    final generation = _sessionGeneration;
    final session = await _validSession();
    if (session == null || !_isCurrentSession(generation)) return;
    final requestsApi = serviceRequestApi ?? ServiceRequestApiClient();
    final paymentsApi = paymentApi ?? PaymentApiClient();

    List<RemoteServiceRequest> requests = const [];
    var requestsLoaded = false;
    try {
      requests = await requestsApi.listOwnerRequests(session.accessToken);
      requestsLoaded = true;
    } catch (_) {
      // A failed source must not fabricate a transition from missing data.
    }
    if (!_isCurrentSession(generation) ||
        snapshotVersion != _remoteServiceRequestSnapshotVersion) {
      return;
    }

    final serviceRequestByBooking = <String, String>{};
    for (final request in requests) {
      for (final booking in request.candidates) {
        serviceRequestByBooking[booking.id] = request.id;
      }
    }
    if (!_isCurrentSession(generation) ||
        snapshotVersion != _remoteServiceRequestSnapshotVersion) {
      return;
    }

    List<PaymentOrderModel> paymentOrders = const [];
    try {
      paymentOrders = await _listAllOwnerPaymentOrders(
        paymentsApi,
        session.accessToken,
        generation,
      );
    } catch (_) {
      // Payment failures are isolated from inspection and after-sale sync.
    }
    if (!_isCurrentSession(generation)) return;

    await _mutate(() {
      if (!_isCurrentSession(generation) ||
          snapshotVersion != _remoteServiceRequestSnapshotVersion) {
        return null;
      }
      final facts = Map<String, String>.of(_notificationFacts);
      final existingIds = _messages.map((message) => message.id).toSet();
      final newMessages = <OwnerMessage>[];

      void record({
        required String factKey,
        required String current,
        required String bookingId,
        required String? serviceRequestId,
        required DateTime occurredAt,
        required bool notifyWhenFirstSeen,
        required OwnerMessage? Function(String eventType) build,
      }) {
        final previous = facts[factKey];
        if (previous == current) return;
        facts[factKey] = current;
        if (previous == null && !notifyWhenFirstSeen) return;
        final message = build(current);
        if (message == null || !existingIds.add(message.id)) return;
        newMessages.add(message);
      }

      for (final order in paymentOrders) {
        final stage = _paymentSnapshot(order);
        record(
          factKey: 'payment:${order.id}',
          current: stage,
          bookingId: order.bookingId,
          serviceRequestId: serviceRequestByBooking[order.bookingId],
          occurredAt:
              DateTime.tryParse(order.updatedAt)?.toUtc() ??
              DateTime.tryParse(order.createdAt)?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          notifyWhenFirstSeen: stage == 'PAYMENT_REPORTED',
          build: (status) => _ownerPaymentMessage(
            status,
            order,
            serviceRequestByBooking[order.bookingId],
          ),
        );
      }

      final remoteRequestIds = requestsLoaded
          ? requests.map((request) => request.id).toSet()
          : _remoteServiceRequestIds;
      final requestsChanged =
          requestsLoaded &&
          !_sameRemoteServiceRequests(requests, _remoteServiceRequests);
      if (mapEquals(facts, _notificationFacts) &&
          newMessages.isEmpty &&
          setEquals(remoteRequestIds, _remoteServiceRequestIds) &&
          !requestsChanged) {
        return null;
      }
      return {
        ...toJson(),
        'notificationFacts': facts,
        'remoteServiceRequestIds': remoteRequestIds.toList(),
        if (requestsLoaded)
          'remoteServiceRequests': requests
              .map((request) => request.toJson())
              .toList(),
        if (newMessages.isNotEmpty)
          'messages': [
            ...newMessages.reversed,
            ..._messages,
          ].map((message) => message.toJson()).toList(),
      };
    });
    if (requestsLoaded &&
        _isCurrentSession(generation) &&
        snapshotVersion == _remoteServiceRequestSnapshotVersion) {
      _remoteServiceRequestError = null;
      notifyListeners();
    }
  }

  Future<List<PaymentOrderModel>> _listAllOwnerPaymentOrders(
    PaymentApiClient api,
    String accessToken,
    int generation,
  ) async {
    const pageSize = 100;
    final result = <PaymentOrderModel>[];
    final seen = <String>{};
    for (var page = 0; ; page += 1) {
      final batch = await api.listOrders(
        accessToken,
        page: page,
        size: pageSize,
      );
      if (!_isCurrentSession(generation)) return const [];
      var added = false;
      for (final order in batch) {
        if (seen.add(order.id)) {
          result.add(order);
          added = true;
        }
      }
      if (batch.length < pageSize || !added) return result;
    }
  }

  String _paymentSnapshot(PaymentOrderModel order) {
    if (order.constructionPaymentStatus == 'CONFIRMED' ||
        order.constructionConfirmedAt != null ||
        order.workerConfirmedReceivedAt != null ||
        (!order.isSplitOfflineV2 && order.status == 'PAID')) {
      return 'RECEIPT_CONFIRMED';
    }
    if (order.constructionPaymentStatus == 'REPORTED' ||
        order.constructionReportedAt != null ||
        order.ownerReportedPaidAt != null ||
        order.status == 'OWNER_REPORTED_PAID') {
      return 'PAYMENT_REPORTED';
    }
    return 'PENDING';
  }

  OwnerMessage? _ownerPaymentMessage(
    String status,
    PaymentOrderModel order,
    String? serviceRequestId,
  ) {
    final event = switch (status) {
      'PAYMENT_REPORTED' => (
        'PAYMENT_REPORTED',
        '付款申报已提交',
        '服务器已记录本单工程款申报，等待工人确认收款。',
      ),
      'RECEIPT_CONFIRMED' => ('RECEIPT_CONFIRMED', '工人已确认收款', '本单工程款已由工人确认收到。'),
      _ => null,
    };
    if (event == null) return null;
    final occurredAt =
        DateTime.tryParse(order.updatedAt)?.toUtc() ??
        DateTime.tryParse(order.createdAt)?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return OwnerMessage(
      id: 'owner:${event.$1}:${order.bookingId}',
      title: event.$2,
      content: event.$3,
      category: '付款',
      createdAt: occurredAt.toLocal(),
      eventType: event.$1,
      bookingId: order.bookingId,
      serviceRequestId: serviceRequestId,
      paymentOrderId: order.id,
      targetAction: 'OWNER_PAYMENT',
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
    final generation = _sessionGeneration;
    final session = await _validSession();
    if (session == null ||
        _reportApi == null ||
        !_isCurrentSession(generation)) {
      return [];
    }

    try {
      final remote = await _reportApi!.getReportsByBooking(
        session.accessToken,
        bookingId,
      );
      if (!_isCurrentSession(generation)) return [];
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
        if (!_isCurrentSession(generation)) return null;
        return {
          ...toJson(),
          'dailyReports': syncedReports.map((e) => e.toJson()).toList(),
        };
      });
      return remote;
    } catch (error) {
      if (!_isCurrentSession(generation)) return [];
      await _handleProfileError(error);
      rethrow;
    }
  }

  Future<void> updateProfile(OwnerProfile value) async {
    final generation = _sessionGeneration;
    final session = await _validSession();
    if (session != null && _isCurrentSession(generation)) {
      try {
        final remote = await _profileApi.updateCurrent(
          session.accessToken,
          OwnerProfileUpdate(
            name: value.name,
            city: value.city,
            avatarUrl: value.avatarUrl,
            gender: value.gender,
            decorationType: value.decorationType,
            address: value.address,
            area: value.area,
          ),
        );
        if (!_isCurrentSession(generation)) return;
        await _mutate(
          () => !_isCurrentSession(generation)
              ? null
              : {...toJson(), 'profile': _localProfile(remote).toJson()},
        );
        return;
      } catch (error) {
        if (!_isCurrentSession(generation)) return;
        await _handleProfileError(error);
        rethrow;
      }
    }
    if (!_isCurrentSession(generation) || !_isLoggedIn) return;
    await _mutate(() {
      if (!_isCurrentSession(generation)) return null;
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

  Future<void> addAddress(OwnerAddress value) async {
    final generation = _sessionGeneration;
    final session = await _requireOwnerSession();
    if (!_isCurrentSession(generation)) return;
    try {
      final remote = await _addressApi.create(
        session.accessToken,
        _addressDraft(value),
      );
      if (!_isCurrentSession(generation)) return;
      final created = _localAddress(remote);
      final next = _normalizeAddresses([
        ..._addresses.where((item) => item.id != created.id),
        created,
      ], preferredDefaultId: created.isDefault ? created.id : null);
      await _mutate(
        () => !_isCurrentSession(generation)
            ? null
            : {
                ...toJson(),
                'addresses': next.map((address) => address.toJson()).toList(),
              },
      );
    } catch (error) {
      if (!_isCurrentSession(generation)) return;
      await _handleProfileError(error);
      rethrow;
    }
  }

  Future<void> updateAddress(OwnerAddress value) async {
    final generation = _sessionGeneration;
    final session = await _requireOwnerSession();
    if (!_isCurrentSession(generation)) return;
    try {
      final remote = await _addressApi.update(
        session.accessToken,
        value.id,
        _addressDraft(value),
      );
      if (!_isCurrentSession(generation)) return;
      final updated = _localAddress(remote);
      final index = _addresses.indexWhere((item) => item.id == updated.id);
      final replaced = [..._addresses];
      if (index < 0) {
        replaced.add(updated);
      } else {
        replaced[index] = updated;
      }
      final next = _normalizeAddresses(
        replaced,
        preferredDefaultId: updated.isDefault ? updated.id : null,
      );
      await _mutate(
        () => !_isCurrentSession(generation)
            ? null
            : {
                ...toJson(),
                'addresses': next.map((address) => address.toJson()).toList(),
              },
      );
    } catch (error) {
      if (!_isCurrentSession(generation)) return;
      await _handleProfileError(error);
      rethrow;
    }
  }

  Future<void> setDefaultAddress(String id) async {
    final generation = _sessionGeneration;
    final session = await _requireOwnerSession();
    if (!_isCurrentSession(generation)) return;
    try {
      final remote = await _addressApi.setDefault(session.accessToken, id);
      if (!_isCurrentSession(generation)) return;
      final selected = _localAddress(remote);
      final next = _normalizeAddresses(
        _addresses.map(
          (address) => address.id == selected.id ? selected : address,
        ),
        preferredDefaultId: selected.id,
      );
      await _mutate(
        () => !_isCurrentSession(generation)
            ? null
            : {
                ...toJson(),
                'addresses': next.map((address) => address.toJson()).toList(),
              },
      );
    } catch (error) {
      if (!_isCurrentSession(generation)) return;
      await _handleProfileError(error);
      rethrow;
    }
  }

  Future<void> deleteAddress(String id) async {
    final generation = _sessionGeneration;
    final session = await _requireOwnerSession();
    if (!_isCurrentSession(generation)) return;
    try {
      await _addressApi.delete(session.accessToken, id);
      if (!_isCurrentSession(generation)) return;
      final remote = await _addressApi.list(session.accessToken);
      if (!_isCurrentSession(generation)) return;
      await _replaceRemoteAddresses(remote, sessionGeneration: generation);
    } catch (error) {
      if (!_isCurrentSession(generation)) return;
      await _handleProfileError(error);
      rethrow;
    }
  }

  Future<void> markMessageRead(String id) async {
    final currentIndex = _messages.indexWhere((item) => item.id == id);
    if (currentIndex < 0 || _messages[currentIndex].isRead) return;
    final message = _messages[currentIndex];
    final serverEventId = message.serverEventId;
    if (serverEventId != null) {
      final generation = _sessionGeneration;
      final session = await _requireOwnerSession();
      if (!_isCurrentSession(generation)) return;
      await _businessEventApi.markRead(session.accessToken, serverEventId);
      if (!_isCurrentSession(generation)) return;
    }
    await _mutate(() {
      final index = _messages.indexWhere(
        (item) => item.id == id && !item.isRead,
      );
      if (index < 0) return null;
      final next = [..._messages]
        ..[index] = _messages[index].copyWith(isRead: true);
      return {...toJson(), 'messages': next.map((e) => e.toJson()).toList()};
    });
  }

  Future<void> markAllMessagesRead() async {
    if (_messages.every((item) => item.isRead)) return;
    final serverEventIds = _messages
        .where((item) => !item.isRead)
        .map((item) => item.serverEventId)
        .whereType<String>()
        .toList();
    if (serverEventIds.isNotEmpty) {
      final generation = _sessionGeneration;
      final session = await _requireOwnerSession();
      if (!_isCurrentSession(generation)) return;
      for (final eventId in serverEventIds) {
        await _businessEventApi.markRead(session.accessToken, eventId);
        if (!_isCurrentSession(generation)) return;
      }
    }
    await _mutate(() {
      if (_messages.every((item) => item.isRead)) return null;
      final next = _messages
          .map((item) => item.copyWith(isRead: true))
          .toList();
      return {...toJson(), 'messages': next.map((e) => e.toJson()).toList()};
    });
  }

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
    final generation = _sessionGeneration;
    final session = await _validSession();
    if (session == null || !_isCurrentSession(generation)) return;
    // localId 格式 "rm-{uuid}"
    final remoteId = localId.startsWith('rm-') ? localId.substring(3) : localId;
    try {
      await _bookingApi.cancelBooking(session.accessToken, remoteId, '业主主动取消');
    } catch (error) {
      if (!_isCurrentSession(generation)) return;
      await _handleProfileError(error);
      rethrow;
    }
    if (!_isCurrentSession(generation)) return;
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
    HouseInfo? houseInfo,
  }) async {
    final generation = _sessionGeneration;
    if (remoteWorkerUserId == null || remoteWorkerUserId.trim().isEmpty) {
      throw const AuthApiException(
        code: 'SERVER_WORKER_REQUIRED',
        message: '该师傅没有服务器资料，暂时不能预约',
        statusCode: 409,
      );
    }
    if (remoteWorkerUserId.isNotEmpty) {
      final session = await _validSession();
      if (!_isCurrentSession(generation)) return;
      if (session == null) {
        throw const AuthApiException(
          code: 'AUTHENTICATION_REQUIRED',
          message: '请先登录后再预约师傅',
          statusCode: 401,
        );
      }
      final serviceAddress = defaultAddress;
      if (serviceAddress == null) {
        throw const AuthApiException(
          code: 'OWNER_ADDRESS_REQUIRED',
          message: '请先添加上门地址',
          statusCode: 409,
        );
      }
      if (houseInfo == null) {
        throw const AuthApiException(
          code: 'HOUSE_INFO_REQUIRED',
          message: '请先填写房屋面积与户型',
          statusCode: 400,
        );
      }
      try {
        await _bookingApi.createBooking(
          session.accessToken,
          OwnerBookingCreateRequest(
            workerUserId: remoteWorkerUserId,
            houseInfo: houseInfo,
            trade: worker.trade,
            serviceCity: serviceAddress.city,
            serviceAddress: serviceAddress.fullAddress,
            remark: '来自安卓业主端',
          ),
        );
        if (!_isCurrentSession(generation)) return;
      } catch (error) {
        if (!_isCurrentSession(generation)) return;
        await _handleProfileError(error);
        rethrow;
      }
    }
    await _mutate(() {
      if (!_isCurrentSession(generation)) return null;
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
    if (!_isCurrentSession(generation)) return;
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
    _sessionGeneration += 1;
    _remoteServiceRequestSnapshotVersion += 1;
    _remoteBookingFetchInFlight = null;
    _remoteBusinessFetchInFlight = null;
    _remoteBusinessEventFetchInFlight = null;
    _remoteServiceRequestFetchInFlight = null;
    _isFetchingRemoteBookings = false;
    _isFetchingRemoteServiceRequests = false;
    _remoteBookingError = null;
    _remoteServiceRequestError = null;
    final generation = _sessionGeneration;
    final session = AuthSession.fromLogin(response);
    try {
      final previousSession = await _sessionStore.read();
      if (!_isCurrentSession(generation)) return;
      final switchingAccounts =
          previousSession?.userId != session.userId ||
          (_sessionUserId != null && _sessionUserId != session.userId);
      final baseDocument = switchingAccounts
          ? _emptyUserDocument(session: session)
          : toJson();
      final baseProfile = OwnerProfile.fromJson(
        Map<String, dynamic>.from(baseDocument['profile'] as Map),
      );
      await _sessionStore.save(session);
      if (!_isCurrentSession(generation)) return;
      await _mutate(() {
        if (!_isCurrentSession(generation)) return null;
        return {
          ...baseDocument,
          'profile': baseProfile.copyWith(phone: response.user.phone).toJson(),
          'isLoggedIn': true,
          'sessionUserId': session.userId,
        };
      });
    } catch (_) {
      await _sessionStore.clear();
      rethrow;
    }
    if (!_isCurrentSession(generation)) return;
    try {
      await refreshOwnerProfile();
    } on AuthApiException {
      // Login remains successful for retryable profile-fetch failures. A 401 is
      // handled by refreshOwnerProfile and has already cleared login state.
    }
    if (_isLoggedIn) {
      try {
        await refreshOwnerAddresses();
      } on AuthApiException {
        // Address sync is retryable. A 401 has already cleared login state.
      }
    }
  }

  /// 首次登录完成资料填写
  Future<void> completeOnboarding({
    String? name,
    String? city,
    String? avatarUrl,
    String? gender,
    String? decorationType,
    String? address,
    double? area,
  }) async {
    final generation = _sessionGeneration;
    final session = await _requireOwnerSession();
    if (!_isCurrentSession(generation)) return;
    final nextProfile = _profile.copyWith(
      name: name?.trim().isNotEmpty == true ? name!.trim() : _profile.name,
      city: city?.trim().isNotEmpty == true ? city!.trim() : _profile.city,
      avatarUrl: avatarUrl ?? _profile.avatarUrl,
      gender: gender ?? _profile.gender,
      decorationType: decorationType ?? _profile.decorationType,
      address: address ?? _profile.address,
      area: area ?? _profile.area,
    );
    if (!nextProfile.isProfileComplete) return;
    try {
      final remote = await _profileApi.updateCurrent(
        session.accessToken,
        OwnerProfileUpdate(
          name: nextProfile.name,
          city: nextProfile.city,
          avatarUrl: nextProfile.avatarUrl,
          gender: nextProfile.gender,
          decorationType: nextProfile.decorationType,
          address: nextProfile.address,
          area: nextProfile.area,
        ),
      );
      if (!_isCurrentSession(generation)) return;
      await _mutate(
        () => !_isCurrentSession(generation)
            ? null
            : {
                ...toJson(),
                'profile': _localProfile(remote).toJson(),
                'isLoggedIn': true,
              },
      );
    } catch (error) {
      if (!_isCurrentSession(generation)) return;
      await _handleProfileError(error);
      rethrow;
    }
  }

  /// 退出登录：先删除安全令牌，再清理本地登录状态。
  Future<void> logout() => _clearAuthenticatedState();
}

final class _EmptyOwnerAddressApi implements OwnerAddressApi {
  const _EmptyOwnerAddressApi();

  @override
  Future<List<RemoteOwnerAddress>> list(String accessToken) async => const [];

  @override
  Future<RemoteOwnerAddress> create(
    String accessToken,
    OwnerAddressDraft draft,
  ) => throw const AuthApiException(
    code: 'ADDRESS_API_NOT_CONFIGURED',
    message: '地址服务暂不可用',
  );

  @override
  Future<RemoteOwnerAddress> update(
    String accessToken,
    String addressId,
    OwnerAddressDraft draft,
  ) => throw const AuthApiException(
    code: 'ADDRESS_API_NOT_CONFIGURED',
    message: '地址服务暂不可用',
  );

  @override
  Future<RemoteOwnerAddress> setDefault(String accessToken, String addressId) =>
      throw const AuthApiException(
        code: 'ADDRESS_API_NOT_CONFIGURED',
        message: '地址服务暂不可用',
      );

  @override
  Future<void> delete(String accessToken, String addressId) =>
      throw const AuthApiException(
        code: 'ADDRESS_API_NOT_CONFIGURED',
        message: '地址服务暂不可用',
      );
}
