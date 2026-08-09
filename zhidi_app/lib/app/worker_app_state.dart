// ============================================================
// 工匠端全局状态管理
// 严格对齐 owner_app_state.dart 的 ChangeNotifier + SharedPreferences 持久化模式
// ============================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'worker_models.dart';

import 'owner_key_value_store.dart';
import 'worker_models.dart';
import '../models/payment_models.dart';
import '../models/renovation.dart';
import '../services/worker_booking_api_client.dart';
import '../services/worker_quote_api_client.dart'
    show CatalogSubmitItem, RemoteQuote, WorkerQuoteApiClient;
import '../services/auth_api_client.dart';
import '../services/auth_session_store.dart';
import '../services/business_event_api_client.dart';
import '../services/payment_api_client.dart';
import '../services/inspection_api_client.dart';

// ── 抽象持久化存储（复用 OwnerKeyValueStore 抽象）──
typedef WorkerKeyValueStore = OwnerKeyValueStore;
typedef MemoryWorkerStore = MemoryOwnerStore;
typedef SharedPreferencesWorkerStore = SharedPreferencesOwnerStore;

/// 工匠端全局应用状态
/// 继承 ChangeNotifier，通过 InheritedNotifier 注入到 widget 树
class WorkerAppState extends ChangeNotifier {
  WorkerAppState._({
    required this._store,
    required this._sessionStore,
    required this.ready,
    required WorkerProfile profile,
    required List<WorkerOrder> orders,
    required List<WorkerDailyReport> dailyReports,
    required List<WorkerInspectionRequest> inspectionRequests,
    required List<EarningRecord> earnings,
    required List<WorkerMessage> messages,
    required WorkerSettings settings,
    required List<Quotation> quotations,
    required bool isLoggedIn,
    required this._sessionUserId,
    List<RemoteWorkerBooking>? remoteBookings,
    Map<String, String>? notificationFacts,
    int businessEventCursor = 0,
    // Named public-looking parameters keep seeded-data construction readable.
    // ignore: prefer_initializing_formals
  }) : _profile = profile,
       _orders = List.of(orders),
       _dailyReports = List.of(dailyReports),
       _inspectionRequests = List.of(inspectionRequests),
       _earnings = List.of(earnings),
       _messages = List.of(messages),
       // ignore: prefer_initializing_formals
       _settings = settings,
       _quotations = List.of(quotations),
       // ignore: prefer_initializing_formals
       _isLoggedIn = isLoggedIn,
       _remoteBookings = List.of(remoteBookings ?? const []),
       _notificationFacts = Map.of(notificationFacts ?? const {}),
       // ignore: prefer_initializing_formals
       _businessEventCursor = businessEventCursor;

  static const documentKey = 'worker.appState';
  static final RegExp _legacySplitReceiptBodyPattern = RegExp(
    r'^本单工程款 ¥([0-9]+(?:\.[0-9]+)?)，请核对实际到账后确认。'
    '\u5e73\u53f0\u670d\u52a1\u8d39\u7531\u4e1a\u4e3b\u53e6\u884c\u652f\u4ed8\u3002\$',
  );
  final WorkerKeyValueStore _store;
  final AuthSessionStore _sessionStore;
  final bool ready;

  // ── 私有字段 ──
  WorkerProfile _profile;
  List<WorkerOrder> _orders;
  List<WorkerDailyReport> _dailyReports;
  List<WorkerInspectionRequest> _inspectionRequests;
  List<EarningRecord> _earnings;
  List<WorkerMessage> _messages;
  WorkerSettings _settings;
  List<Quotation> _quotations;
  bool _isLoggedIn;
  String? _sessionUserId;

  // ── 远程预约 ──
  WorkerBookingApi? _bookingApi;
  String? _accessToken;
  List<RemoteWorkerBooking> _remoteBookings = [];
  Map<String, String> _notificationFacts;
  int _businessEventCursor;
  Future<void>? _remoteBookingFetchInFlight;
  String? _remoteBookingError;
  PaymentApiClient? _paymentApi;
  Future<void>? _remotePaymentFetchInFlight;
  BusinessEventApi _businessEventApi = BusinessEventApiClient();
  Future<void>? _remoteBusinessEventFetchInFlight;
  int _sessionGeneration = 0;
  List<PaymentOrderModel> _remotePaymentOrders = [];
  List<SettlementModel> _remoteSettlements = [];
  List<WarrantyRetentionModel> _remoteWarrantyRetentions = [];
  WorkerWarrantyAccountModel? _remoteWorkerWarrantyAccount;
  List<WorkerWarrantyContributionModel> _remoteWorkerWarrantyContributions = [];

  // ── 写操作队列：保证写操作原子性 ──
  Future<void> _writeQueue = Future<void>.value();

  // ── 公开 getters ──
  WorkerProfile get profile => _profile;
  String get profileName => _profile.name;
  List<WorkerOrder> get orders => List.unmodifiable(_orders);
  List<WorkerDailyReport> get dailyReports => List.unmodifiable(_dailyReports);
  List<WorkerInspectionRequest> get inspectionRequests =>
      List.unmodifiable(_inspectionRequests);
  List<EarningRecord> get earnings => List.unmodifiable(_earnings);
  List<WorkerMessage> get messages => List.unmodifiable(_messages);
  WorkerSettings get settings => _settings;
  List<Quotation> get quotations => List.unmodifiable(_quotations);
  bool get isLoggedIn => _isLoggedIn;
  String? get accessToken => _accessToken;
  String? get sessionUserId => _sessionUserId;
  String? get remoteBookingError => _remoteBookingError;

  /// 获取当前用户 ID（从会话中读取）。
  Future<String?> getUserId() async {
    final session = await _sessionStore.read();
    return session?.userId;
  }

  List<RemoteWorkerBooking> get remoteBookings =>
      List.unmodifiable(_remoteBookings);

  int get unreadMessageCount => _messages.where((m) => !m.isRead).length;
  int get businessEventCursor => _businessEventCursor;

  Quotation? getOrderQuotation(String orderId) {
    try {
      return _quotations.lastWhere((q) => q.orderId == orderId);
    } catch (_) {
      return null;
    }
  }

  // ── 便捷分组 ──
  List<WorkerOrder> get pendingOrders =>
      _orders.where((o) => o.status == WorkerOrderStatus.pending).toList();

  List<WorkerOrder> get activeOrders => _orders
      .where(
        (o) =>
            o.status == WorkerOrderStatus.accepted ||
            o.status == WorkerOrderStatus.visitProposed ||
            o.status == WorkerOrderStatus.visitScheduled ||
            o.status == WorkerOrderStatus.arrivalPending ||
            o.status == WorkerOrderStatus.onSite ||
            o.status == WorkerOrderStatus.quotePending ||
            o.status == WorkerOrderStatus.hired ||
            o.status == WorkerOrderStatus.inProgress,
      )
      .toList();

  List<WorkerOrder> get completedOrders =>
      _orders.where((o) => o.status == WorkerOrderStatus.completed).toList();

  double get totalEarnings {
    double total = 0;
    for (final e in _earnings) {
      if (e.status == EarningSettlementStatus.settled) {
        total += e.amount;
      }
    }
    return total;
  }

  double get remoteSettleableAmount => _remoteSettlements
      .where((item) => item.status == 'SETTLEABLE')
      .fold<double>(0, (total, item) => total + item.amount);

  double get remoteWarrantyRetentionAmount =>
      _remoteWorkerWarrantyAccount?.effectiveBalance ??
      _remoteWarrantyRetentions.fold<double>(
        0,
        (total, item) => total + item.remainingAmount,
      );

  WorkerWarrantyAccountModel? get remoteWorkerWarrantyAccount =>
      _remoteWorkerWarrantyAccount;

  List<WorkerWarrantyContributionModel> get remoteWorkerWarrantyContributions =>
      List.unmodifiable(_remoteWorkerWarrantyContributions);

  bool get hasRemoteWorkerWarrantyAccount =>
      _remoteWorkerWarrantyAccount != null;

  double remoteSettleableAmountForBooking(String bookingId) =>
      _remoteSettlements
          .where(
            (item) =>
                item.bookingId == bookingId && item.status == 'SETTLEABLE',
          )
          .fold<double>(0, (total, item) => total + item.amount);

  double remoteWarrantyRetentionAmountForBooking(String bookingId) =>
      _remoteWarrantyRetentions
          .where((item) => item.bookingId == bookingId)
          .fold<double>(0, (total, item) => total + item.remainingAmount);

  PaymentOrderModel? remotePaymentOrderForBooking(String bookingId) {
    final matches =
        _remotePaymentOrders
            .where((item) => item.bookingId == bookingId)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return matches.firstOrNull;
  }

  // ── 工厂构造 ──

  /// 内存存储（不持久化），用于测试或兜底
  static Future<WorkerAppState> memory({
    WorkerKeyValueStore? store,
    AuthSessionStore? sessionStore,
  }) async {
    final targetStore = store ?? MemoryWorkerStore();
    return _fromStored(targetStore, sessionStore ?? MemoryAuthSessionStore());
  }

  /// 从 SharedPreferences 加载状态
  static Future<WorkerAppState> load({AuthSessionStore? sessionStore}) async {
    final preferences = await SharedPreferences.getInstance();
    return _fromStored(
      SharedPreferencesWorkerStore(preferences),
      sessionStore ?? MemoryAuthSessionStore(),
    );
  }

  /// 从 JSON Map 反序列化
  factory WorkerAppState.fromJson(Map<String, dynamic> json) =>
      _fromMap(json, MemoryWorkerStore(), MemoryAuthSessionStore());

  // ── 内部：从存储恢复 ──
  static Future<WorkerAppState> _fromStored(
    WorkerKeyValueStore store,
    AuthSessionStore sessionStore,
  ) async {
    final encoded = store.getString(documentKey);
    final state = encoded != null
        ? _tryDecode(encoded, store, sessionStore)
        : _seeded(store, sessionStore);
    final session = await sessionStore.read();
    if (session == null || session.isExpiredAt(DateTime.now())) {
      if (session != null) await sessionStore.clear();
      await state._mutate(() => state._emptyUserDocument());
      return state;
    }
    state._accessToken = session.accessToken;
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
    var sanitized = false;
    state._messages = state._messages.map((message) {
      final next = _sanitizeRestoredPaymentMessage(message);
      sanitized = sanitized || !identical(next, message);
      return next;
    }).toList();
    if (sanitized) {
      await store.setString(documentKey, jsonEncode(state.toJson()));
    }
    return state;
  }

  WorkerSettings _deviceSettings() => WorkerSettings(
    pushNotifications: _settings.pushNotifications,
    orderNotifications: _settings.orderNotifications,
    inspectionNotifications: _settings.inspectionNotifications,
  );

  Map<String, dynamic> _emptyUserDocument({AuthSession? session}) {
    final next = _seeded(_store, _sessionStore).toJson()
      ..['settings'] = _deviceSettings().toJson()
      ..['isLoggedIn'] = session != null
      ..['sessionUserId'] = session?.userId;
    if (session != null) {
      final profile = _seeded(
        _store,
        _sessionStore,
      ).profile.copyWith(phone: session.phone);
      next['profile'] = profile.toJson();
    }
    return next;
  }

  bool _belongsToSession(AuthSession session) =>
      _sessionUserId == session.userId ||
      (_sessionUserId == null &&
          _isLoggedIn &&
          _profile.phone == session.phone);

  static WorkerMessage _sanitizeRestoredPaymentMessage(WorkerMessage message) {
    final paymentOrderId = message.paymentOrderId;
    if (paymentOrderId == null ||
        message.id != 'wmsg-payment-awaiting-$paymentOrderId' ||
        message.title != '业主已付工程款，待确认到账' ||
        message.category != '收入') {
      return message;
    }
    final match = _legacySplitReceiptBodyPattern.firstMatch(message.content);
    if (match == null) return message;
    return message.copyWith(content: '本单工程款 ¥${match.group(1)}，请核对实际到账后确认。');
  }

  static WorkerAppState _tryDecode(
    String encoded,
    WorkerKeyValueStore store,
    AuthSessionStore sessionStore,
  ) {
    try {
      return _fromMap(
        jsonDecode(encoded) as Map<String, dynamic>,
        store,
        sessionStore,
      );
    } on FormatException {
      return _seeded(store, sessionStore);
    } on TypeError {
      return _seeded(store, sessionStore);
    }
  }

  // ── 内部：从 Map 反序列化 ──
  static WorkerAppState _fromMap(
    Map<String, dynamic> json,
    WorkerKeyValueStore store,
    AuthSessionStore sessionStore,
  ) {
    List<T> read<T>(String key, T Function(Map<String, dynamic>) decode) =>
        (json[key] as List<dynamic>? ?? const [])
            .map((v) => decode(Map<String, dynamic>.from(v as Map)))
            .toList();

    return WorkerAppState._(
      store: store,
      sessionStore: sessionStore,
      ready: true,
      profile: WorkerProfile.fromJson(
        Map<String, dynamic>.from(json['profile'] as Map),
      ),
      orders: read('orders', WorkerOrder.fromJson),
      dailyReports: read('dailyReports', WorkerDailyReport.fromJson),
      inspectionRequests: read(
        'inspectionRequests',
        WorkerInspectionRequest.fromJson,
      ),
      earnings: read('earnings', EarningRecord.fromJson),
      messages: read('messages', WorkerMessage.fromJson),
      settings: WorkerSettings.fromJson(
        Map<String, dynamic>.from(json['settings'] as Map? ?? const {}),
      ),
      quotations: read('quotations', Quotation.fromJson),
      isLoggedIn: json['isLoggedIn'] as bool? ?? false,
      sessionUserId: json['sessionUserId'] as String?,
      remoteBookings: read('remoteBookings', RemoteWorkerBooking.fromJson),
      notificationFacts: Map<String, String>.from(
        json['notificationFacts'] as Map? ?? const <String, String>{},
      ),
      businessEventCursor:
          ((json['_businessEventCursor'] as num?)?.toInt() ?? 0)
              .clamp(0, 1 << 62)
              .toInt(),
    );
  }

  // ── 内部：种子数据 ──
  static WorkerAppState _seeded(
    WorkerKeyValueStore store,
    AuthSessionStore sessionStore,
  ) {
    return WorkerAppState._(
      store: store,
      sessionStore: sessionStore,
      ready: true,
      profile: const WorkerProfile(
        name: '',
        phone: '',
        trade: Trade.demolition,
      ),
      orders: const [],
      dailyReports: const [],
      inspectionRequests: const [],
      earnings: const [],
      messages: const [],
      settings: const WorkerSettings(),
      quotations: const [],
      isLoggedIn: false,
      sessionUserId: null,
      businessEventCursor: 0,
    );
  }

  // ── 序列化 ──
  Map<String, dynamic> toJson() => {
    'profile': _profile.toJson(),
    'orders': _orders.map((e) => e.toJson()).toList(),
    'dailyReports': _dailyReports.map((e) => e.toJson()).toList(),
    'inspectionRequests': _inspectionRequests.map((e) => e.toJson()).toList(),
    'earnings': _earnings.map((e) => e.toJson()).toList(),
    'messages': _messages.map((e) => e.toJson()).toList(),
    'settings': _settings.toJson(),
    'quotations': _quotations.map((e) => e.toJson()).toList(),
    'isLoggedIn': _isLoggedIn,
    'sessionUserId': _sessionUserId,
    'remoteBookings': _remoteBookings.map((e) => e.toJson()).toList(),
    'notificationFacts': _notificationFacts,
    '_businessEventCursor': _businessEventCursor,
  };

  // ── 核心：原子性写入操作 ──
  Future<void> _mutate(Map<String, dynamic>? Function() buildNext) {
    final operation = _writeQueue.then((_) async {
      final next = buildNext();
      if (next == null) return;
      await _store.setString(documentKey, jsonEncode(next));
      final restored = _fromMap(next, _store, _sessionStore);
      _profile = restored._profile;
      _orders = restored._orders;
      _dailyReports = restored._dailyReports;
      _inspectionRequests = restored._inspectionRequests;
      _earnings = restored._earnings;
      _messages = restored._messages;
      _settings = restored._settings;
      _quotations = restored._quotations;
      _isLoggedIn = restored._isLoggedIn;
      _sessionUserId = restored._sessionUserId;
      _remoteBookings = restored._remoteBookings;
      _notificationFacts = restored._notificationFacts;
      _businessEventCursor = restored._businessEventCursor;
      notifyListeners();
    });
    _writeQueue = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  // ── 业务操作 ──

  /// 更新个人信息
  Future<void> updateProfile(WorkerProfile value, {OwnerAuthApi? api}) async {
    var savedValue = value;
    final accessToken = _accessToken;
    final generation = _sessionGeneration;
    if (accessToken != null) {
      final profileApi = api ?? AuthApiClient();
      await profileApi.updateWorkerProfile(accessToken, {
        'name': value.name.trim(),
        'serviceCity': value.serviceCity.trim(),
        'primaryTrade': value.trade.name,
        'experienceYears': value.experienceYears,
        'dailyRate': value.dailyRate,
        'bio': value.bio.trim(),
      });
      if (!_isCurrentRemoteSession(generation, accessToken)) return;
      final remote = await profileApi.getWorkerProfile(accessToken);
      if (!_isCurrentRemoteSession(generation, accessToken)) return;
      savedValue = _profileFromRemote(remote, fallbackPhone: value.phone);
    }
    await _mutate(() {
      if (accessToken != null &&
          !_isCurrentRemoteSession(generation, accessToken)) {
        return null;
      }
      if (jsonEncode(savedValue.toJson()) == jsonEncode(_profile.toJson())) {
        return null;
      }
      return {...toJson(), 'profile': savedValue.toJson()};
    });
  }

  /// 更新姓名
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

  /// 接单：从待接单转为已接单
  Future<void> acceptOrder(
    String orderId, {
    double? quotedPrice,
    DateTime? visitTime,
  }) async {
    await _mutate(() {
      final idx = _orders.indexWhere(
        (o) => o.id == orderId && o.status == WorkerOrderStatus.pending,
      );
      if (idx < 0) return null;
      final updated = _orders.toList()
        ..[idx] = _orders[idx].copyWith(
          status: WorkerOrderStatus.accepted,
          quotedPrice: quotedPrice ?? _orders[idx].quotedPrice,
          visitTime: visitTime ?? _orders[idx].visitTime,
        );
      final now = DateTime.now();
      final message = WorkerMessage(
        id: 'wmsg-accept-${now.millisecondsSinceEpoch}',
        title: '接单成功',
        content:
            '您已接单「${_orders[idx].ownerName} - ${_orders[idx].requirement}」'
            '${quotedPrice != null ? '，报价 ¥${quotedPrice.toStringAsFixed(0)}' : ''}。',
        category: '订单',
        createdAt: now,
        orderId: orderId,
      );
      return {
        ...toJson(),
        'orders': updated.map((e) => e.toJson()).toList(),
        'messages': [message.toJson(), ..._messages.map((e) => e.toJson())],
      };
    });
  }

  /// 开始施工
  Future<void> startOrder(String orderId) async {
    await _mutate(() {
      final idx = _orders.indexWhere(
        (o) => o.id == orderId && o.status == WorkerOrderStatus.accepted,
      );
      if (idx < 0) return null;
      final updated = _orders.toList()
        ..[idx] = _orders[idx].copyWith(status: WorkerOrderStatus.inProgress);
      final now = DateTime.now();
      final message = WorkerMessage(
        id: 'wmsg-start-${now.millisecondsSinceEpoch}',
        title: '开始施工',
        content:
            '「${_orders[idx].ownerName} - ${_orders[idx].requirement}」已开始施工。',
        category: '订单',
        createdAt: now,
        orderId: orderId,
      );
      return {
        ...toJson(),
        'orders': updated.map((e) => e.toJson()).toList(),
        'messages': [message.toJson(), ..._messages.map((e) => e.toJson())],
      };
    });
  }

  /// 完成订单
  Future<void> completeOrder(String orderId) async {
    await _mutate(() {
      final idx = _orders.indexWhere(
        (o) => o.id == orderId && o.status == WorkerOrderStatus.inProgress,
      );
      if (idx < 0) return null;
      final updated = _orders.toList()
        ..[idx] = _orders[idx].copyWith(status: WorkerOrderStatus.completed);
      final now = DateTime.now();
      final message = WorkerMessage(
        id: 'wmsg-done-${now.millisecondsSinceEpoch}',
        title: '施工完成',
        content:
            '「${_orders[idx].ownerName} - ${_orders[idx].requirement}」已完工，请等待业主验收。',
        category: '订单',
        createdAt: now,
        orderId: orderId,
      );
      return {
        ...toJson(),
        'orders': updated.map((e) => e.toJson()).toList(),
        'messages': [message.toJson(), ..._messages.map((e) => e.toJson())],
      };
    });
  }

  /// 拒绝订单
  Future<void> rejectOrder(String orderId) async {
    await _mutate(() {
      final idx = _orders.indexWhere(
        (o) => o.id == orderId && o.status == WorkerOrderStatus.pending,
      );
      if (idx < 0) return null;
      final updated = _orders.toList()
        ..[idx] = _orders[idx].copyWith(status: WorkerOrderStatus.cancelled);
      return {...toJson(), 'orders': updated.map((e) => e.toJson()).toList()};
    });
  }

  /// 修改订单上门时间
  Future<void> updateOrderVisitTime(String orderId, DateTime visitTime) =>
      _mutate(() {
        final idx = _orders.indexWhere((o) => o.id == orderId);
        if (idx < 0) return null;
        final updated = _orders.toList()
          ..[idx] = _orders[idx].copyWith(visitTime: visitTime);
        return {...toJson(), 'orders': updated.map((e) => e.toJson()).toList()};
      });

  /// 标记已上门
  Future<void> markOrderVisited(String orderId) => _mutate(() {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx < 0) return null;
    final updated = _orders.toList()
      ..[idx] = _orders[idx].copyWith(hasVisited: true);
    return {...toJson(), 'orders': updated.map((e) => e.toJson()).toList()};
  });

  /// 发起验收请求
  Future<void> requestInspection(WorkerInspectionRequest request) async {
    await _mutate(() {
      if (_inspectionRequests.any((r) => r.id == request.id)) return null;
      final next = [request, ..._inspectionRequests];
      final now = DateTime.now();
      final message = WorkerMessage(
        id: 'wmsg-insp-${now.millisecondsSinceEpoch}',
        title: '验收请求已发起',
        content: '「${request.phaseName}」验收请求已发出，等待业主确认。',
        category: '验收',
        createdAt: now,
        orderId: request.orderId,
      );
      return {
        ...toJson(),
        'inspectionRequests': next.map((e) => e.toJson()).toList(),
        'messages': [message.toJson(), ..._messages.map((e) => e.toJson())],
      };
    });
  }

  /// 标记消息已读
  Future<void> markMessageRead(String id) async {
    final currentIndex = _messages.indexWhere((item) => item.id == id);
    if (currentIndex < 0 || _messages[currentIndex].isRead) return;
    final message = _messages[currentIndex];
    final serverEventId = message.serverEventId;
    if (serverEventId != null) {
      final accessToken = _accessToken;
      if (accessToken == null) {
        throw const AuthApiException(
          code: 'NOT_AUTHENTICATED',
          message: '未登录，请先登录',
        );
      }
      final generation = _sessionGeneration;
      await _businessEventApi.markRead(accessToken, serverEventId);
      if (!_isCurrentRemoteSession(generation, accessToken)) return;
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

  /// 全部标记已读
  Future<void> markAllMessagesRead() async {
    if (_messages.every((item) => item.isRead)) return;
    final serverEventIds = _messages
        .where((item) => !item.isRead)
        .map((item) => item.serverEventId)
        .whereType<String>()
        .toSet();
    if (serverEventIds.isNotEmpty) {
      final accessToken = _accessToken;
      if (accessToken == null) {
        throw const AuthApiException(
          code: 'NOT_AUTHENTICATED',
          message: '未登录，请先登录',
        );
      }
      final generation = _sessionGeneration;
      for (final eventId in serverEventIds) {
        await _businessEventApi.markRead(accessToken, eventId);
        if (!_isCurrentRemoteSession(generation, accessToken)) return;
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

  /// 更新设置
  Future<void> updateSettings(WorkerSettings value) async {
    await _mutate(() {
      if (jsonEncode(value.toJson()) == jsonEncode(_settings.toJson())) {
        return null;
      }
      return {...toJson(), 'settings': value.toJson()};
    });
  }

  /// 使用预颁发 Token 登录（跳过手机号验证流程，用于联调/CI 等场景）
  void loginWithToken(String token) {
    if (_isLoggedIn) return;
    _advanceSessionGeneration();
    _isLoggedIn = true;
    _accessToken = token;
    notifyListeners();
  }

  Future<void> loginOnline(
    OwnerLoginResponse response, {
    RemoteWorkerProfile? remoteProfile,
  }) async {
    final session = AuthSession.fromLogin(response);
    final generation = _advanceSessionGeneration();
    final previousSession = await _sessionStore.read();
    if (generation != _sessionGeneration) return;
    final switchingAccounts =
        previousSession?.userId != session.userId ||
        (_sessionUserId != null && _sessionUserId != session.userId);
    final baseDocument = switchingAccounts
        ? _emptyUserDocument(session: session)
        : toJson();
    final baseProfile = switchingAccounts
        ? WorkerProfile.fromJson(
            Map<String, dynamic>.from(baseDocument['profile'] as Map),
          )
        : _profile;
    final nextProfile = remoteProfile != null
        ? _profileFromRemote(
            remoteProfile,
            fallbackPhone: response.user.phone,
            baseProfile: baseProfile,
          )
        : baseProfile.copyWith(phone: response.user.phone);
    await _sessionStore.save(session);
    if (generation != _sessionGeneration) return;
    _accessToken = session.accessToken;
    await _mutate(
      () => !_isCurrentRemoteSession(generation, session.accessToken)
          ? null
          : {
              ...baseDocument,
              'profile': nextProfile.toJson(),
              'isLoggedIn': true,
              'sessionUserId': session.userId,
            },
    );
    if (_isCurrentRemoteSession(generation, session.accessToken)) {
      notifyListeners();
    }
  }

  WorkerProfile _profileFromRemote(
    RemoteWorkerProfile remote, {
    required String fallbackPhone,
    WorkerProfile? baseProfile,
  }) {
    final base = baseProfile ?? _profile;
    final remoteName = remote.name?.trim();
    final remoteBio = remote.bio?.trim();
    final remoteTrade = _tradeFromRemote(remote.primaryTrade) ?? base.trade;
    final remoteTradeSelected = remote.primaryTrade?.trim().isNotEmpty == true;
    return base.copyWith(
      name: remoteName?.isNotEmpty == true ? remoteName : base.name,
      phone: remote.phone.isNotEmpty ? remote.phone : fallbackPhone,
      trade: remoteTrade,
      tradeSelected: remoteTradeSelected || base.tradeSelected,
      serviceCity: remote.serviceCity?.trim() ?? base.serviceCity,
      experienceYears: remote.experienceYears ?? base.experienceYears,
      dailyRate: remote.dailyRate ?? base.dailyRate,
      bio: remoteBio?.isNotEmpty == true ? remoteBio : base.bio,
      isVerified: remote.profileComplete || base.isVerified,
    );
  }

  Trade? _tradeFromRemote(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    for (final trade in Trade.values) {
      if (trade.name == normalized || trade.label == normalized) {
        return trade;
      }
    }
    return null;
  }

  Future<bool> restoreOnlineSession({OwnerAuthApi? api}) async {
    final session = await _sessionStore.read();
    if (session == null || session.isExpiredAt(DateTime.now())) {
      await logout();
      return false;
    }
    final generation = _advanceSessionGeneration();
    _accessToken = session.accessToken;
    if (!_belongsToSession(session)) {
      await _mutate(
        () => _isCurrentRemoteSession(generation, session.accessToken)
            ? _emptyUserDocument(session: session)
            : null,
      );
    }
    if (!_isCurrentRemoteSession(generation, session.accessToken)) return false;
    var nextProfile = _profile.copyWith(phone: session.phone);
    try {
      final remote = await (api ?? AuthApiClient()).getWorkerProfile(
        session.accessToken,
      );
      nextProfile = _profileFromRemote(remote, fallbackPhone: session.phone);
    } catch (_) {
      // 保留登录态，远程资料下次启动或进入首页时继续同步。
    }
    if (!_isCurrentRemoteSession(generation, session.accessToken)) return false;
    await _mutate(
      () => !_isCurrentRemoteSession(generation, session.accessToken)
          ? null
          : {
              ...toJson(),
              'profile': nextProfile.toJson(),
              'isLoggedIn': true,
              'sessionUserId': session.userId,
            },
    );
    if (!_isCurrentRemoteSession(generation, session.accessToken)) return false;
    notifyListeners();
    return true;
  }

  /// 登录
  Future<void> login(String phone) async {
    if (_isLoggedIn) return;
    _advanceSessionGeneration();
    _accessToken = null;
    await _mutate(() {
      final next = _emptyUserDocument();
      return {
        ...next,
        'profile': WorkerProfile.fromJson(
          Map<String, dynamic>.from(next['profile'] as Map),
        ).copyWith(phone: phone).toJson(),
        'isLoggedIn': true,
      };
    });
    // 保障：即便持久化失败，内存状态也必须更新为已登录
    if (!_isLoggedIn) {
      _isLoggedIn = true;
      _profile = _profile.copyWith(phone: phone);
      notifyListeners();
    }
  }

  /// 退出登录
  Future<void> logout() async {
    _advanceSessionGeneration();
    _accessToken = null;
    await _sessionStore.clear();
    await _mutate(_emptyUserDocument);
  }

  int _advanceSessionGeneration() {
    _sessionGeneration += 1;
    _accessToken = null;
    _remoteBookingFetchInFlight = null;
    _remotePaymentFetchInFlight = null;
    _remoteBusinessEventFetchInFlight = null;
    _clearRemoteSessionCaches();
    return _sessionGeneration;
  }

  void _clearRemoteSessionCaches() {
    _remoteBookingError = null;
    _remotePaymentOrders = [];
    _remoteSettlements = [];
    _remoteWarrantyRetentions = [];
    _remoteWorkerWarrantyAccount = null;
    _remoteWorkerWarrantyContributions = [];
  }

  bool _isCurrentRemoteSession(int generation, String accessToken) =>
      generation == _sessionGeneration && _accessToken == accessToken;

  /// 提交报价单（阶段 3：服务端固定价格，仅传 name + quantity）
  Future<RemoteQuote> submitQuote(
    String bookingId,
    List<CatalogSubmitItem> items,
  ) async {
    final accessToken = _accessToken;
    if (accessToken == null) {
      throw const AuthApiException(
        code: 'NOT_AUTHENTICATED',
        message: '未登录，请先登录',
      );
    }
    final generation = _sessionGeneration;
    final quoteApi = WorkerQuoteApiClient();
    final remote = await quoteApi.submitQuote(accessToken, bookingId, items);
    if (!_isCurrentRemoteSession(generation, accessToken)) return remote;

    // 刷新远程预约：报价提交后状态变为 QUOTE_PENDING
    await fetchRemoteBookings();
    if (!_isCurrentRemoteSession(generation, accessToken)) return remote;

    // 添加本地消息
    final now = DateTime.now();
    final ownerName =
        _orders
            .where((o) => o.id == bookingId)
            .map((o) => o.ownerName)
            .firstOrNull ??
        '';
    await _mutate(() {
      if (!_isCurrentRemoteSession(generation, accessToken)) return null;
      final message = WorkerMessage(
        id: 'wmsg-quotation-${now.millisecondsSinceEpoch}',
        title: '报价单已提交',
        content: '「$ownerName」的报价单已提交，等待业主确认。',
        category: '报价',
        createdAt: now,
        orderId: bookingId,
      );
      return {
        ...toJson(),
        'messages': [message.toJson(), ..._messages.map((e) => e.toJson())],
      };
    });

    return remote;
  }

  /// 提交报价单（旧版 local-first，保留兼容）
  Future<void> submitQuotation(Quotation quotation) async {
    await _mutate(() {
      final next = [quotation, ..._quotations];
      final now = DateTime.now();
      final message = WorkerMessage(
        id: 'wmsg-quotation-${now.millisecondsSinceEpoch}',
        title: '报价单已提交',
        content:
            '「${_orders.where((o) => o.id == quotation.orderId).map((o) => o.ownerName).firstOrNull ?? ''}」的报价单已提交'
            '（人工 ¥${quotation.laborTotal.toStringAsFixed(0)} + 辅料 ¥${quotation.auxiliaryTotal.toStringAsFixed(0)} + 主材 ¥${quotation.mainMaterialTotal.toStringAsFixed(0)}）'
            '，合计 ¥${quotation.grandTotal.toStringAsFixed(0)}。',
        category: '报价',
        createdAt: now,
        orderId: quotation.orderId,
      );
      return {
        ...toJson(),
        'quotations': next.map((e) => e.toJson()).toList(),
        'messages': [message.toJson(), ..._messages.map((e) => e.toJson())],
      };
    });
  }

  // ── 远程预约操作 ──

  void initBookingApi({
    required WorkerBookingApi api,
    required String accessToken,
  }) {
    _bookingApi = api;
    _accessToken = accessToken;
    fetchRemoteBookings();
  }

  /// 使用已登录会话刷新后端数据。绝不在后台自动获取验证码或代替用户登录。
  Future<void> connectBackend() async {
    await refreshRemoteData();
  }

  Future<void> refreshRemoteData() async {
    await fetchRemoteBookings();
    await fetchRemotePayments();
    try {
      await fetchRemoteBusinessEvents();
    } catch (_) {
      // 事件流下次前台轮询继续追赶，不阻断订单/付款快照刷新。
    }
  }

  void initBusinessEventApi(BusinessEventApi api) {
    _businessEventApi = api;
  }

  Future<void> fetchRemoteBusinessEvents({int pageSize = 100}) {
    if (pageSize < 1 || pageSize > 100) {
      throw RangeError.range(pageSize, 1, 100, 'pageSize');
    }
    final accessToken = _accessToken;
    if (accessToken == null) return Future<void>.value();
    final inFlight = _remoteBusinessEventFetchInFlight;
    if (inFlight != null) return inFlight;
    final generation = _sessionGeneration;
    final operation = _doFetchRemoteBusinessEvents(
      accessToken,
      generation,
      pageSize,
    );
    _remoteBusinessEventFetchInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_remoteBusinessEventFetchInFlight, operation)) {
        _remoteBusinessEventFetchInFlight = null;
      }
    });
  }

  Future<void> _doFetchRemoteBusinessEvents(
    String accessToken,
    int generation,
    int pageSize,
  ) async {
    var after = _businessEventCursor;
    while (true) {
      final page = await _businessEventApi.list(
        accessToken,
        after: after,
        size: pageSize,
      );
      if (!_isCurrentRemoteSession(generation, accessToken)) return;
      if (page.items.isEmpty) return;
      final messages = page.items.map(_workerBusinessEventMessage).toList();
      await _mutate(() {
        if (!_isCurrentRemoteSession(generation, accessToken) ||
            _businessEventCursor != after) {
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
      if (!_isCurrentRemoteSession(generation, accessToken) ||
          _businessEventCursor != page.nextCursor) {
        return;
      }
      after = page.nextCursor;
      if (page.items.length < pageSize) return;
    }
  }

  WorkerMessage _workerBusinessEventMessage(RemoteBusinessEvent event) {
    final round = event.payload?['round'];
    final presentation = switch (event.eventType) {
      'INSPECTION_RECTIFICATION_REQUIRED' => (
        '验收需整改',
        '第${round ?? ''}轮验收未通过，请查看结果并完成整改。',
        '验收',
        'WORKER_INSPECTION',
      ),
      'INSPECTION_PASSED' => (
        '验收已通过',
        '第${round ?? ''}轮验收已通过。',
        '验收',
        'WORKER_INSPECTION',
      ),
      'AFTER_SALE_CREATED' => (
        '收到新的售后工单',
        '业主已创建售后工单，请及时查看。',
        '售后',
        'WORKER_AFTER_SALE',
      ),
      'AFTER_SALE_PARTICIPANT_MESSAGE' => (
        '售后有新回复',
        '业主已在售后工单中追加回复。',
        '售后',
        'WORKER_AFTER_SALE',
      ),
      'AFTER_SALE_PLATFORM_ACCEPTED' => (
        '平台已受理售后',
        '平台已受理本单售后，请查看处理进展。',
        '售后',
        'WORKER_AFTER_SALE',
      ),
      'AFTER_SALE_PLATFORM_REPLIED' => (
        '平台回复了售后',
        '平台已更新售后处理意见。',
        '售后',
        'WORKER_AFTER_SALE',
      ),
      'AFTER_SALE_RESOLVED' => (
        '售后已解决',
        '本单售后已有解决结果。',
        '售后',
        'WORKER_AFTER_SALE',
      ),
      'AFTER_SALE_CLOSED' => ('售后已关闭', '本单售后工单已关闭。', '售后', 'WORKER_AFTER_SALE'),
      _ => ('业务进度已更新', '本单有新的业务进展。', '系统', null),
    };
    return WorkerMessage(
      id: 'business:${event.eventId}',
      title: presentation.$1,
      content: presentation.$2,
      category: presentation.$3,
      createdAt: event.occurredAt.toLocal(),
      isRead: event.readAt != null,
      orderId: event.bookingId,
      eventType: event.eventType,
      bookingId: event.bookingId,
      serviceRequestId: event.serviceRequestId,
      targetAction: presentation.$4,
      serverEventId: event.eventId,
      aggregateType: event.aggregateType,
      aggregateId: event.aggregateId,
    );
  }

  Future<void> fetchRemoteBookings() async {
    final bookingApi = _bookingApi;
    final accessToken = _accessToken;
    if (bookingApi == null || accessToken == null) return;
    final inFlight = _remoteBookingFetchInFlight;
    if (inFlight != null) return inFlight;
    final generation = _sessionGeneration;
    final operation = _doFetchRemoteBookings(
      bookingApi,
      accessToken,
      generation,
    );
    _remoteBookingFetchInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_remoteBookingFetchInFlight, operation)) {
        _remoteBookingFetchInFlight = null;
      }
    }
  }

  Future<void> _doFetchRemoteBookings(
    WorkerBookingApi bookingApi,
    String accessToken,
    int generation,
  ) async {
    _remoteBookingError = null;
    try {
      final remote = await bookingApi.listWorkerBookings(accessToken);
      if (!_isCurrentRemoteSession(generation, accessToken)) return;
      final remoteOrders = remote.map(_remoteBookingToOrder).toList();
      await _mutate(() {
        if (!_isCurrentRemoteSession(generation, accessToken)) return null;
        final facts = Map<String, String>.of(_notificationFacts);
        final previousBookings = {
          for (final booking in _remoteBookings) booking.id: booking,
        };
        final ids = _messages.map((message) => message.id).toSet();
        final newMessages = <WorkerMessage>[];
        for (final booking in remote) {
          final factKey = 'booking:${booking.id}';
          final previous =
              facts[factKey] ?? previousBookings[booking.id]?.status;
          if (previous == booking.status) {
            facts[factKey] = booking.status;
            continue;
          }
          final shouldNotify = previous != null || booking.status == 'PENDING';
          final message = shouldNotify ? _workerBookingMessage(booking) : null;
          if (message != null &&
              ids.add(message.id) &&
              !_hasLegacyWorkerBookingMessage(message.eventType!, booking.id)) {
            newMessages.add(message);
          }
          facts[factKey] = booking.status;
        }
        return {
          ...toJson(),
          'remoteBookings': remote.map((booking) => booking.toJson()).toList(),
          'orders': remoteOrders.map((order) => order.toJson()).toList(),
          'notificationFacts': facts,
          if (newMessages.isNotEmpty)
            'messages': [
              ...newMessages.reversed,
              ..._messages,
            ].map((message) => message.toJson()).toList(),
        };
      });
    } catch (error) {
      if (!_isCurrentRemoteSession(generation, accessToken)) return;
      _remoteBookingError = error is AuthApiException
          ? error.message
          : '订单同步失败，请检查网络后重试';
      notifyListeners();
    }
  }

  bool _hasLegacyWorkerBookingMessage(String eventType, String bookingId) {
    if (eventType != 'PENDING') return false;
    return _messages.any(
      (message) => message.id == 'wmsg-remote-pending-$bookingId',
    );
  }

  WorkerMessage? _workerBookingMessage(RemoteWorkerBooking booking) {
    final event = switch (booking.status) {
      'PENDING' => (
        'PENDING',
        '新的预约待接单',
        '业主「${booking.ownerName}」预约了您的${_tradeLabel(booking.trade)}服务，请及时处理。',
      ),
      'VISIT_SCHEDULED' => ('VISIT_CONFIRMED', '上门时间已确认', '业主已确认本单上门时间，请按约到场。'),
      'ARRIVAL_PENDING' => ('ARRIVAL_PENDING', '待完成到场确认', '本单已进入双方到场确认阶段。'),
      'ON_SITE' => ('ARRIVAL_CONFIRMED', '双方已确认到场', '本单双方到场已由服务器确认。'),
      'READY_TO_START' || 'HIRED' => ('SELECTED', '您已被选中', '业主已选定您为本单施工师傅。'),
      'NOT_SELECTED' => ('NOT_SELECTED', '本次未被选中', '业主已选择其他施工师傅。'),
      _ => null,
    };
    if (event == null) return null;
    return WorkerMessage(
      id: 'worker:${event.$1}:${booking.id}',
      title: event.$2,
      content: event.$3,
      category: '订单',
      createdAt:
          (booking.status == 'PENDING' ? booking.createdAt : booking.updatedAt)
              .toLocal(),
      orderId: booking.id,
      eventType: event.$1,
      bookingId: booking.id,
      serviceRequestId: booking.serviceRequestId,
      targetAction: 'WORKER_ORDER',
    );
  }

  void initInspectionApi(InspectionApi _) {}

  /// 旧入口保留给已有页面/测试调用；验收消息已唯一改由 business event 流投递。
  Future<void> fetchRemoteInspections() => Future<void>.value();

  void initPaymentApi({
    required PaymentApiClient api,
    required String accessToken,
  }) {
    _paymentApi = api;
    _accessToken = accessToken;
  }

  Future<void> fetchRemotePayments() async {
    final paymentApi = _paymentApi;
    final accessToken = _accessToken;
    if (paymentApi == null || accessToken == null) return;
    final inFlight = _remotePaymentFetchInFlight;
    if (inFlight != null) return inFlight;
    final generation = _sessionGeneration;
    final operation = _doFetchRemotePayments(
      paymentApi,
      accessToken,
      generation,
    );
    _remotePaymentFetchInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_remotePaymentFetchInFlight, operation)) {
        _remotePaymentFetchInFlight = null;
      }
    }
  }

  Future<void> _doFetchRemotePayments(
    PaymentApiClient paymentApi,
    String accessToken,
    int generation,
  ) async {
    try {
      final results = await Future.wait<Object>([
        _listAllWorkerPaymentOrders(paymentApi, accessToken, generation),
        paymentApi.listSettlements(accessToken),
        paymentApi.listWarrantyRetentions(accessToken),
      ]);
      if (!_isCurrentRemoteSession(generation, accessToken)) return;
      final orders = results[0] as List<PaymentOrderModel>;
      final settlements = results[1] as List<SettlementModel>;
      final warrantyRetentions = results[2] as List<WarrantyRetentionModel>;
      WorkerWarrantyAccountModel? warrantyAccount;
      try {
        warrantyAccount = await paymentApi.getWorkerWarrantyAccount(
          accessToken,
        );
      } catch (_) {
        warrantyAccount = null;
      }
      if (!_isCurrentRemoteSession(generation, accessToken)) return;
      List<WorkerWarrantyContributionModel> warrantyContributions;
      try {
        warrantyContributions = await paymentApi
            .listWorkerWarrantyContributions(accessToken);
      } catch (_) {
        warrantyContributions = [];
      }
      if (!_isCurrentRemoteSession(generation, accessToken)) return;
      _remotePaymentOrders = orders;
      _remoteSettlements = settlements;
      _remoteWarrantyRetentions = warrantyRetentions;
      _remoteWorkerWarrantyAccount = warrantyAccount;
      _remoteWorkerWarrantyContributions = warrantyContributions;
      await _mutate(() {
        if (!_isCurrentRemoteSession(generation, accessToken)) return null;
        final facts = Map<String, String>.of(_notificationFacts);
        final currentMessages = [..._messages];
        final ids = currentMessages.map((message) => message.id).toSet();
        final newMessages = <WorkerMessage>[];
        for (final order in orders) {
          final stage = _workerPaymentSnapshot(order);
          final factKey = 'payment:${order.id}';
          final previous = facts[factKey];
          if (previous == stage) continue;
          facts[factKey] = stage;
          final shouldNotify = previous != null || stage == 'PAYMENT_REPORTED';
          if (!shouldNotify) continue;
          final message = _workerPaymentMessage(stage, order);
          if (message == null) continue;
          final legacyIndex = currentMessages.indexWhere(
            (existing) => existing.id == 'wmsg-payment-awaiting-${order.id}',
          );
          if (stage == 'PAYMENT_REPORTED' && legacyIndex >= 0) {
            final legacy = currentMessages[legacyIndex];
            currentMessages[legacyIndex] = legacy.copyWith(
              content: message.content,
              eventType: message.eventType,
              bookingId: message.bookingId,
              serviceRequestId: message.serviceRequestId,
              targetAction: message.targetAction,
            );
            continue;
          }
          if (ids.add(message.id)) newMessages.add(message);
        }
        if (mapEquals(facts, _notificationFacts) && newMessages.isEmpty) {
          return null;
        }
        return {
          ...toJson(),
          'notificationFacts': facts,
          'messages': _deduplicateMessagesById([
            ...newMessages.reversed,
            ...currentMessages,
          ]).map((message) => message.toJson()).toList(),
        };
      });
      if (_isCurrentRemoteSession(generation, accessToken)) notifyListeners();
    } catch (_) {
      // 支付状态同步失败不阻断接单中心；下次轮询或手动刷新会继续重试。
    }
  }

  Future<List<PaymentOrderModel>> _listAllWorkerPaymentOrders(
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
      if (!_isCurrentRemoteSession(generation, accessToken)) return const [];
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

  String _workerPaymentSnapshot(PaymentOrderModel order) {
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

  WorkerMessage? _workerPaymentMessage(String stage, PaymentOrderModel order) {
    final serviceRequestId = _remoteBookings
        .where((booking) => booking.id == order.bookingId)
        .map((booking) => booking.serviceRequestId)
        .firstOrNull;
    final event = switch (stage) {
      'PAYMENT_REPORTED' => (
        'PAYMENT_REPORTED',
        order.isSplitOfflineV2 ? '业主已付工程款，待确认到账' : '业主已付款，待确认收款',
        order.isSplitOfflineV2
            ? '本单工程款 ¥${order.quoteAmount.toStringAsFixed(0)}，请核对实际到账后确认。'
            : '请查看费用明细并核对实际到账，确认无误后点击确认收款。',
      ),
      'RECEIPT_CONFIRMED' => (
        'RECEIPT_CONFIRMED',
        '收款确认已完成',
        '本单工程款收款状态已由服务器确认。',
      ),
      _ => null,
    };
    if (event == null) return null;
    return WorkerMessage(
      id: 'worker:${event.$1}:${order.bookingId}',
      title: event.$2,
      content: event.$3,
      category: '收入',
      createdAt:
          (DateTime.tryParse(order.updatedAt) ??
                  DateTime.tryParse(order.createdAt) ??
                  DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
              .toLocal(),
      orderId: order.bookingId,
      paymentOrderId: order.id,
      eventType: event.$1,
      bookingId: order.bookingId,
      serviceRequestId: serviceRequestId,
      targetAction: 'WORKER_PAYMENT',
    );
  }

  List<WorkerMessage> _deduplicateMessagesById(List<WorkerMessage> messages) {
    final seen = <String>{};
    return [
      for (final message in messages)
        if (seen.add(message.id)) message,
    ];
  }

  WorkerOrder _remoteBookingToOrder(RemoteWorkerBooking rb) {
    WorkerOrderStatus status;
    switch (rb.status) {
      case 'PENDING':
        status = WorkerOrderStatus.pending;
        break;
      case 'ACCEPTED':
        status = WorkerOrderStatus.accepted;
        break;
      case 'VISIT_PROPOSED':
        status = WorkerOrderStatus.visitProposed;
        break;
      case 'VISIT_SCHEDULED':
        status = WorkerOrderStatus.visitScheduled;
        break;
      case 'ARRIVAL_PENDING':
        status = WorkerOrderStatus.arrivalPending;
        break;
      case 'ON_SITE':
        status = WorkerOrderStatus.onSite;
        break;
      case 'QUOTE_PENDING':
        status = WorkerOrderStatus.quotePending;
        break;
      case 'HIRED':
      case 'READY_TO_START':
        status = WorkerOrderStatus.hired;
        break;
      case 'COMPLETED':
        status = WorkerOrderStatus.completed;
        break;
      case 'REJECTED':
      case 'CANCELLED':
      case 'NOT_SELECTED':
        status = WorkerOrderStatus.cancelled;
        break;
      default:
        status = WorkerOrderStatus.pending;
    }
    final tradeLabel = _tradeLabel(rb.trade);
    return WorkerOrder(
      id: rb.id,
      ownerName: rb.ownerName,
      ownerPhone: rb.ownerPhone,
      ownerAddress: rb.serviceAddress ?? '',
      area: rb.houseInfo?.areaLabel ?? '',
      houseInfo: rb.houseInfo,
      requirement: '$tradeLabel师傅',
      description: rb.remark ?? '',
      trade: tradeLabel,
      status: status,
      proposedTime: rb.proposedTime,
      scheduledVisitAt: rb.scheduledVisitAt,
      arrivalConfirmedByOwner: rb.arrivalConfirmedByOwner,
      arrivalConfirmedByWorker: rb.arrivalConfirmedByWorker,
      onSiteAt: rb.onSiteAt,
      actualOnSiteAt: rb.actualOnSiteAt,
      createdAt: rb.createdAt,
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

  Future<bool> acceptRemoteBooking(String bookingId) async {
    final bookingApi = _bookingApi;
    final accessToken = _accessToken;
    if (bookingApi == null || accessToken == null) return false;
    final generation = _sessionGeneration;
    try {
      await bookingApi.acceptBooking(accessToken, bookingId);
    } catch (error) {
      if (!_isCurrentRemoteSession(generation, accessToken)) return false;
      _remoteBookingError = error is AuthApiException
          ? error.code == 'WORKER_WARRANTY_TOP_UP_REQUIRED'
                ? '履约质保金待补足，完成核验后可继续接单'
                : error.message
          : '接单失败，请检查网络后重试';
      notifyListeners();
      return false;
    }
    if (!_isCurrentRemoteSession(generation, accessToken)) return false;
    await fetchRemoteBookings();
    return _isCurrentRemoteSession(generation, accessToken);
  }

  Future<bool> rejectRemoteBooking(String bookingId) async {
    final bookingApi = _bookingApi;
    final accessToken = _accessToken;
    if (bookingApi == null || accessToken == null) return false;
    final generation = _sessionGeneration;
    try {
      await bookingApi.rejectBooking(accessToken, bookingId);
    } catch (error) {
      if (!_isCurrentRemoteSession(generation, accessToken)) return false;
      _remoteBookingError = error is AuthApiException
          ? error.message
          : '拒单失败，请检查网络后重试';
      notifyListeners();
      return false;
    }
    if (!_isCurrentRemoteSession(generation, accessToken)) return false;
    await fetchRemoteBookings();
    return _isCurrentRemoteSession(generation, accessToken);
  }

  bool isRemoteOrder(String orderId) {
    return _remoteBookings.any((b) => b.id == orderId);
  }

  /// 获取当前 access token，供 visit flow API 使用
  String? getAccessToken() => _accessToken;

  /// 用 API 返回的 booking 对象更新本地订单状态
  void updateOrderFromApi(String bookingId, RemoteWorkerBooking updated) {
    // 更新本地 orders 列表
    final orderIdx = _orders.indexWhere((o) => o.id == bookingId);
    if (orderIdx >= 0) {
      _orders[orderIdx] = _remoteBookingToOrder(updated);
    }
    // 更新 remoteBookings 缓存
    final rbIdx = _remoteBookings.indexWhere((b) => b.id == bookingId);
    if (rbIdx >= 0) {
      _remoteBookings[rbIdx] = updated;
    }
    notifyListeners();
  }

  /// 提交报价单
}
