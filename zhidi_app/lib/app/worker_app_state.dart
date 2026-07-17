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
import '../models/renovation.dart';
import '../services/order_bridge.dart' as bridge;
import '../services/shared_worker_bridge.dart' as shared_workers;
import '../services/daily_report_api_client.dart';
import '../services/worker_booking_api_client.dart';
import '../services/worker_quote_api_client.dart';
import '../services/auth_api_client.dart';
import '../services/auth_session_store.dart';

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
    required this._profile,
    required this._orders,
    required this._dailyReports,
    required this._inspectionRequests,
    required this._earnings,
    required this._messages,
    required this._settings,
    required this._quotations,
    required this._isLoggedIn,
    List<RemoteWorkerBooking>? remoteBookings,
  }) : _remoteBookings = remoteBookings ?? [];

  static const documentKey = 'worker.appState';
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

  // ── 远程预约 ──
  WorkerBookingApiClient? _bookingApi;
  DailyReportApiClient? _reportApi;
  String? _accessToken;
  List<RemoteWorkerBooking> _remoteBookings = [];

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

  List<RemoteWorkerBooking> get remoteBookings =>
      List.unmodifiable(_remoteBookings);

  int get unreadMessageCount => _messages.where((m) => !m.isRead).length;

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
    await _mergeSharedOrders(state);
    await state._publishCurrentWorker();
    return state;
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

  /// 合并共享订单到本地列表（不重复追加）
  static Future<void> _mergeSharedOrders(WorkerAppState state) async {
    final shared = await bridge.readAll();
    if (shared.isEmpty) return;
    final existingIds = state._orders.map((o) => o.id).toSet();
    var changed = false;
    for (final so in shared) {
      if (!existingIds.contains(so.id)) {
        state._orders.insert(0, bridge.sharedToWorkerOrder(so));
        changed = true;
      }
    }
    if (changed) state.notifyListeners();
  }

  /// 将单条订单同步到共享存储
  void _syncOrderToShared(String orderId) {
    final wo = _orders.firstWhere((o) => o.id == orderId);
    final so = bridge.workerOrderToShared(wo);
    bridge.upsert(so);
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
      remoteBookings: read('remoteBookings', RemoteWorkerBooking.fromJson),
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
    'remoteBookings': _remoteBookings.map((e) => e.toJson()).toList(),
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
      _remoteBookings = restored._remoteBookings;
      _accessToken = restored._accessToken;
      notifyListeners();
    });
    _writeQueue = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  // ── 业务操作 ──

  /// 更新个人信息
  Future<void> updateProfile(WorkerProfile value, {OwnerAuthApi? api}) async {
    var savedValue = value;
    if (_accessToken != null) {
      final profileApi = api ?? AuthApiClient();
      await profileApi.updateWorkerProfile(_accessToken!, {
        'name': value.name.trim(),
        'serviceCity': value.serviceCity.trim(),
        'primaryTrade': value.trade.name,
        'experienceYears': value.experienceYears,
        'dailyRate': value.dailyRate,
        'bio': value.bio.trim(),
      });
      final remote = await profileApi.getWorkerProfile(_accessToken!);
      savedValue = _profileFromRemote(remote, fallbackPhone: value.phone);
    }
    await _mutate(() {
      if (jsonEncode(savedValue.toJson()) == jsonEncode(_profile.toJson())) {
        return null;
      }
      return {...toJson(), 'profile': savedValue.toJson()};
    });
    await _publishCurrentWorker();
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
    _syncOrderToShared(orderId);
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
    _syncOrderToShared(orderId);
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
    _syncOrderToShared(orderId);
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
    _syncOrderToShared(orderId);
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

  /// 提交施工日报
  Future<void> submitDailyReport(WorkerDailyReport report) async {
    // 尝试远端提交
    if (_reportApi != null && _accessToken != null) {
      try {
        await _reportApi!.submitReport(
          _accessToken!,
          report.orderId,
          report.title,
          report.content,
          report.images,
        );
      } catch (_) {
        // 远端提交失败时继续走本地持久化
      }
    }

    await _mutate(() {
      if (_dailyReports.any((r) => r.id == report.id)) return null;
      final next = [report, ..._dailyReports];
      final now = DateTime.now();
      final order = _orders.firstWhere(
        (o) => o.id == report.orderId,
        orElse: () => _orders.first,
      );
      List<WorkerOrder> updatedOrders;
      if (order.status == WorkerOrderStatus.accepted) {
        updatedOrders = _orders.map((o) {
          if (o.id == report.orderId) {
            return o.copyWith(status: WorkerOrderStatus.inProgress);
          }
          return o;
        }).toList();
      } else {
        updatedOrders = _orders;
      }
      final message = WorkerMessage(
        id: 'wmsg-report-${now.millisecondsSinceEpoch}',
        title: '日报已提交',
        content: '「${report.title}」已提交至平台，业主将收到通知。',
        category: '系统',
        createdAt: now,
        orderId: report.orderId,
      );
      return {
        ...toJson(),
        'dailyReports': next.map((e) => e.toJson()).toList(),
        'orders': updatedOrders.map((e) => e.toJson()).toList(),
        'messages': [message.toJson(), ..._messages.map((e) => e.toJson())],
      };
    });
    _syncOrderToShared(report.orderId);
  }

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
    _syncOrderToShared(request.orderId);
  }

  /// 标记消息已读
  Future<void> markMessageRead(String id) => _mutate(() {
    final idx = _messages.indexWhere((m) => m.id == id && !m.isRead);
    if (idx < 0) return null;
    final next = [..._messages]..[idx] = _messages[idx].copyWith(isRead: true);
    return {...toJson(), 'messages': next.map((e) => e.toJson()).toList()};
  });

  /// 全部标记已读
  Future<void> markAllMessagesRead() => _mutate(() {
    if (_messages.every((m) => m.isRead)) return null;
    final next = _messages.map((m) => m.copyWith(isRead: true)).toList();
    return {...toJson(), 'messages': next.map((e) => e.toJson()).toList()};
  });

  /// 更新设置
  Future<void> updateSettings(WorkerSettings value) async {
    await _mutate(() {
      if (jsonEncode(value.toJson()) == jsonEncode(_settings.toJson())) {
        return null;
      }
      return {...toJson(), 'settings': value.toJson()};
    });
    await _publishCurrentWorker();
  }

  /// 使用预颁发 Token 登录（跳过手机号验证流程，用于联调/CI 等场景）
  void loginWithToken(String token) {
    if (_isLoggedIn) return;
    _isLoggedIn = true;
    _accessToken = token;
    notifyListeners();
  }

  Future<void> loginOnline(
    OwnerLoginResponse response, {
    RemoteWorkerProfile? remoteProfile,
  }) async {
    final session = AuthSession.fromLogin(response);
    final nextProfile = remoteProfile != null
        ? _profileFromRemote(remoteProfile, fallbackPhone: response.user.phone)
        : _profile.copyWith(phone: response.user.phone);
    await _sessionStore.save(session);
    await _mutate(
      () => {...toJson(), 'profile': nextProfile.toJson(), 'isLoggedIn': true},
    );
    _accessToken = session.accessToken;
    notifyListeners();
  }

  WorkerProfile _profileFromRemote(
    RemoteWorkerProfile remote, {
    required String fallbackPhone,
  }) {
    final remoteName = remote.name?.trim();
    final remoteBio = remote.bio?.trim();
    final remoteTrade = _tradeFromRemote(remote.primaryTrade) ?? _profile.trade;
    final remoteTradeSelected = remote.primaryTrade?.trim().isNotEmpty == true;
    return _profile.copyWith(
      name: remoteName?.isNotEmpty == true ? remoteName : _profile.name,
      phone: remote.phone.isNotEmpty ? remote.phone : fallbackPhone,
      trade: remoteTrade,
      tradeSelected: remoteTradeSelected || _profile.tradeSelected,
      serviceCity: remote.serviceCity?.trim() ?? _profile.serviceCity,
      experienceYears: remote.experienceYears ?? _profile.experienceYears,
      dailyRate: remote.dailyRate ?? _profile.dailyRate,
      bio: remoteBio?.isNotEmpty == true ? remoteBio : _profile.bio,
      isVerified: remote.profileComplete || _profile.isVerified,
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

  Future<bool> restoreOnlineSession() async {
    final session = await _sessionStore.read();
    if (session == null || session.isExpiredAt(DateTime.now())) {
      await _sessionStore.clear();
      return false;
    }
    _accessToken = session.accessToken;
    _isLoggedIn = true;
    _profile = _profile.copyWith(phone: session.phone);
    notifyListeners();
    return true;
  }

  /// 登录
  Future<void> login(String phone) async {
    await _mutate(() {
      if (_isLoggedIn) return null;
      return {
        ...toJson(),
        'profile': _profile.copyWith(phone: phone).toJson(),
        'isLoggedIn': true,
      };
    });
    // 保障：即便持久化失败，内存状态也必须更新为已登录
    if (!_isLoggedIn) {
      _isLoggedIn = true;
      _profile = _profile.copyWith(phone: phone);
      notifyListeners();
    }
    await _publishCurrentWorker();
  }

  /// 退出登录
  Future<void> logout() async {
    await _sessionStore.clear();
    _accessToken = null;
    await _mutate(() => {...toJson(), 'isLoggedIn': false});
  }

  Future<void> _publishCurrentWorker() async {
    if (!_isLoggedIn) return;
    await shared_workers.publishWorkerProfile(
      profile: _profile,
      settings: _settings,
    );
  }

  /// 提交报价单
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
    _syncOrderToShared(quotation.orderId);

    // 同步报价到后端
    if (_accessToken != null) {
      try {
        final quoteApi = WorkerQuoteApiClient();
        await quoteApi.submitQuote(
          _accessToken!,
          quotation.orderId,
          quotation.items
              .map(
                (i) => RemoteQuoteItem(
                  tradeName: i.name,
                  laborFee: i.total,
                  auxiliaryFee: 0,
                  mainMaterialFee: 0,
                ),
              )
              .toList(),
        );
      } catch (_) {
        // 后端同步失败不阻断
      }
    }
  }

  // ── 远程预约操作 ──

  void initBookingApi({
    required WorkerBookingApiClient api,
    required String accessToken,
  }) {
    _bookingApi = api;
    _accessToken = accessToken;
    fetchRemoteBookings();
  }

  /// 自动连接后端：获取验证码 → 登录 → 初始化 API → 拉取预约
  Future<void> connectBackend(AuthApiClient authApi) async {
    if (_accessToken != null && _bookingApi != null) {
      await fetchRemoteBookings();
      return;
    }
    final phone = _profile.phone;
    if (phone.isEmpty) return;
    try {
      final smsResp = await authApi.requestSmsCode(phone);
      if (smsResp.simulatedCode == null) return;
      final loginResp = await authApi.loginWorker(
        phone,
        smsResp.simulatedCode!,
      );
      _accessToken = loginResp.accessToken;
      _bookingApi = WorkerBookingApiClient();
      await fetchRemoteBookings();
    } catch (_) {
      // 静默失败，下次首页加载时重试
    }
  }

  void initReportApi({
    required DailyReportApiClient api,
    required String accessToken,
  }) {
    _reportApi = api;
    _accessToken = accessToken;
  }

  Future<void> fetchRemoteBookings() async {
    if (_bookingApi == null || _accessToken == null) return;
    try {
      final remote = await _bookingApi!.listWorkerBookings(_accessToken!);
      _remoteBookings = remote;
      final existingIds = _orders.map((o) => o.id).toSet();
      for (final rb in remote) {
        if (!existingIds.contains(rb.id)) {
          _orders.insert(0, _remoteBookingToOrder(rb));
        }
      }
    } catch (_) {
      // 远端获取失败时不阻塞本地
    }
    notifyListeners();
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
      case 'REJECTED':
        status = WorkerOrderStatus.cancelled;
        break;
      default:
        status = WorkerOrderStatus.pending;
    }
    return WorkerOrder(
      id: rb.id,
      ownerName: rb.ownerName,
      ownerPhone: rb.ownerPhone,
      ownerAddress: rb.serviceAddress ?? '',
      area: '',
      requirement: rb.trade,
      description: rb.remark ?? '',
      trade: rb.trade,
      status: status,
      createdAt: rb.createdAt,
    );
  }

  Future<bool> acceptRemoteBooking(String bookingId) async {
    if (_bookingApi == null || _accessToken == null) return false;
    try {
      await _bookingApi!.acceptBooking(_accessToken!, bookingId);
    } catch (_) {
      return false;
    }
    final orderIdx = _orders.indexWhere((o) => o.id == bookingId);
    if (orderIdx >= 0) {
      _orders[orderIdx] = _orders[orderIdx].copyWith(
        status: WorkerOrderStatus.accepted,
      );
    }
    final rbIdx = _remoteBookings.indexWhere((b) => b.id == bookingId);
    if (rbIdx >= 0) {
      _remoteBookings[rbIdx] = _remoteBookings[rbIdx].copyWith(
        status: 'ACCEPTED',
      );
    }
    notifyListeners();
    return true;
  }

  Future<bool> rejectRemoteBooking(String bookingId) async {
    if (_bookingApi == null || _accessToken == null) return false;
    try {
      await _bookingApi!.rejectBooking(_accessToken!, bookingId);
    } catch (_) {
      return false;
    }
    final orderIdx = _orders.indexWhere((o) => o.id == bookingId);
    if (orderIdx >= 0) {
      _orders[orderIdx] = _orders[orderIdx].copyWith(
        status: WorkerOrderStatus.cancelled,
      );
    }
    final rbIdx = _remoteBookings.indexWhere((b) => b.id == bookingId);
    if (rbIdx >= 0) {
      _remoteBookings[rbIdx] = _remoteBookings[rbIdx].copyWith(
        status: 'REJECTED',
      );
    }
    notifyListeners();
    return true;
  }

  bool isRemoteOrder(String orderId) {
    return _remoteBookings.any((b) => b.id == orderId);
  }

  /// 提交报价单
}
