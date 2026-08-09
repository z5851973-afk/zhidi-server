import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/app/worker_app_state.dart';
import 'package:zhidi_app/models/house_info.dart';
import 'package:zhidi_app/models/renovation.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/payment_api_client.dart';
import 'package:zhidi_app/services/worker_booking_api_client.dart';

void main() {
  test(
    'worker online login stores secure session and logout clears it',
    () async {
      final sessions = MemoryAuthSessionStore();
      final state = await WorkerAppState.memory(sessionStore: sessions);
      const response = OwnerLoginResponse(
        accessToken: 'worker-jwt',
        tokenType: 'Bearer',
        expiresInSeconds: 3600,
        user: AuthUser(
          id: 'worker-id',
          phone: '13800138102',
          status: 'ACTIVE',
          roles: ['WORKER'],
        ),
      );

      await state.loginOnline(response);

      expect(state.isLoggedIn, isTrue);
      expect((await sessions.read())?.accessToken, 'worker-jwt');
      expect(state.toJson(), isNot(contains('accessToken')));

      await state.logout();

      expect(state.isLoggedIn, isFalse);
      expect(await sessions.read(), isNull);
    },
  );

  test(
    'worker logout clears prior account business data in memory and storage',
    () async {
      final store = MemoryWorkerStore();
      final sessions = MemoryAuthSessionStore();
      final state = await WorkerAppState.memory(
        store: store,
        sessionStore: sessions,
      );
      await state.loginOnline(_loginResponse);
      await state.updateSettings(
        state.settings.copyWith(
          acceptOrders: false,
          pushNotifications: false,
          serviceAreas: const ['旧账号服务区域'],
        ),
      );
      state.initBookingApi(
        api: _FakeWorkerBookingApi([_privacyBooking]),
        accessToken: _loginResponse.accessToken,
      );
      await state.fetchRemoteBookings();
      await state.submitQuotation(
        Quotation(
          id: 'quotation-old-account',
          orderId: _privacyBooking.id,
          items: const [
            QuotationItem(
              name: '旧账号木工项目',
              category: QuotationItemCategory.labor,
              unitPrice: 200,
              quantity: 1,
            ),
          ],
          createdAt: DateTime.utc(2026, 8, 8),
        ),
      );
      state.initPaymentApi(
        api: _privacyPaymentApi(),
        accessToken: _loginResponse.accessToken,
      );
      await state.fetchRemotePayments();

      expect(state.orders, isNotEmpty);
      expect(state.quotations, isNotEmpty);
      expect(state.remoteBookings, isNotEmpty);
      expect(state.messages, isNotEmpty);
      expect(state.remotePaymentOrderForBooking(_privacyBooking.id), isNotNull);
      expect(state.remoteSettleableAmount, 180);

      await state.logout();

      expect(state.isLoggedIn, isFalse);
      expect(await sessions.read(), isNull);
      expect(state.orders, isEmpty);
      expect(state.quotations, isEmpty);
      expect(state.remoteBookings, isEmpty);
      expect(state.messages, isEmpty);
      expect(state.remotePaymentOrderForBooking(_privacyBooking.id), isNull);
      expect(state.remoteSettleableAmount, 0);
      expect(state.settings.acceptOrders, isTrue);
      expect(state.settings.pushNotifications, isFalse);
      expect(state.settings.serviceAreas, isEmpty);

      final persisted =
          jsonDecode(store.getString(WorkerAppState.documentKey)!)
              as Map<String, dynamic>;
      expect(persisted['orders'], isEmpty);
      expect(persisted['quotations'], isEmpty);
      expect(persisted['remoteBookings'], isEmpty);
      expect(persisted['messages'], isEmpty);

      final restored = await WorkerAppState.memory(
        store: store,
        sessionStore: sessions,
      );
      expect(restored.orders, isEmpty);
      expect(restored.quotations, isEmpty);
      expect(restored.remoteBookings, isEmpty);
      expect(restored.messages, isEmpty);
      expect(restored.remotePaymentOrderForBooking(_privacyBooking.id), isNull);
      expect(restored.remoteSettleableAmount, 0);
      expect(restored.settings.acceptOrders, isTrue);
      expect(restored.settings.pushNotifications, isFalse);
      expect(restored.settings.serviceAreas, isEmpty);
    },
  );

  test(
    'worker logout rejects in-flight booking and payment responses from old session',
    () async {
      final store = MemoryWorkerStore();
      final sessions = MemoryAuthSessionStore();
      final state = await WorkerAppState.memory(
        store: store,
        sessionStore: sessions,
      );
      await state.loginOnline(_loginResponse);
      final bookingResult = Completer<List<RemoteWorkerBooking>>();
      state.initBookingApi(
        api: _ControlledWorkerBookingApi(bookingResult),
        accessToken: _loginResponse.accessToken,
      );
      final bookingFetch = state.fetchRemoteBookings();
      final paymentResult = Completer<http.Response>();
      state.initPaymentApi(
        api: _ControlledPaymentApi(paymentResult).client,
        accessToken: _loginResponse.accessToken,
      );
      final paymentFetch = state.fetchRemotePayments();
      await Future<void>.delayed(Duration.zero);

      await state.logout();
      bookingResult.complete([_privacyBooking]);
      paymentResult.complete(_privacyPaymentOrdersResponse());
      await Future.wait([bookingFetch, paymentFetch]);

      expect(state.orders, isEmpty);
      expect(state.remoteBookings, isEmpty);
      expect(state.messages, isEmpty);
      expect(state.remotePaymentOrderForBooking(_privacyBooking.id), isNull);
      expect(state.remoteSettleableAmount, 0);

      final restored = await WorkerAppState.memory(
        store: store,
        sessionStore: sessions,
      );
      expect(restored.orders, isEmpty);
      expect(restored.remoteBookings, isEmpty);
      expect(restored.messages, isEmpty);
    },
  );

  test('worker account switch rejects the prior session response', () async {
    final sessions = _DelayedSecondSaveSessionStore();
    final state = await WorkerAppState.memory(sessionStore: sessions);
    await state.loginOnline(
      _loginResponse,
      remoteProfile: const RemoteWorkerProfile(
        phone: '13800138102',
        name: '旧账号工人',
        serviceCity: '成都',
        primaryTrade: 'carpentry',
        experienceYears: 8,
        dailyRate: 500,
        bio: '旧账号资料',
        profileComplete: true,
      ),
    );
    state.initBookingApi(
      api: _FakeWorkerBookingApi([_privacyBooking]),
      accessToken: _loginResponse.accessToken,
    );
    await state.fetchRemoteBookings();
    await state.submitQuotation(
      Quotation(
        id: 'quotation-old-account',
        orderId: _privacyBooking.id,
        items: const [],
        createdAt: DateTime.utc(2026, 8, 8),
      ),
    );
    state.initPaymentApi(
      api: _privacyPaymentApi(),
      accessToken: _loginResponse.accessToken,
    );
    await state.fetchRemotePayments();
    expect(state.remotePaymentOrderForBooking(_privacyBooking.id), isNotNull);
    expect(state.remoteSettleableAmount, 180);
    expect(state.remoteWarrantyRetentionAmount, 3084);
    expect(state.remoteWorkerWarrantyAccount, isNotNull);
    expect(state.remoteWorkerWarrantyContributions, isNotEmpty);
    final bookingResult = Completer<List<RemoteWorkerBooking>>();
    state.initBookingApi(
      api: _ControlledWorkerBookingApi(bookingResult),
      accessToken: _loginResponse.accessToken,
    );
    final oldFetch = state.fetchRemoteBookings();

    final nextLogin = state.loginOnline(_nextLoginResponse);
    await sessions.waitUntilSecondSaveStarted();
    bookingResult.complete([_privacyBooking]);
    await oldFetch;
    await state.refreshRemoteData();
    sessions.completeSecondSave();
    await nextLogin;

    expect(state.profile.name, isEmpty);
    expect(state.orders, isEmpty);
    expect(state.remoteBookings, isEmpty);
    expect(state.messages, isEmpty);
    expect(state.quotations, isEmpty);
    expect(state.remotePaymentOrderForBooking(_privacyBooking.id), isNull);
    expect(state.remoteSettleableAmount, 0);
    expect(state.remoteWarrantyRetentionAmount, 0);
    expect(state.remoteWorkerWarrantyAccount, isNull);
    expect(state.remoteWorkerWarrantyContributions, isEmpty);
  });

  test(
    'worker startup without a valid session clears persisted user data',
    () async {
      final store = MemoryWorkerStore();
      final sessions = MemoryAuthSessionStore();
      final state = await WorkerAppState.memory(
        store: store,
        sessionStore: sessions,
      );
      await state.loginOnline(_loginResponse);
      state.initBookingApi(
        api: _FakeWorkerBookingApi([_privacyBooking]),
        accessToken: _loginResponse.accessToken,
      );
      await state.fetchRemoteBookings();
      await state.submitQuotation(
        Quotation(
          id: 'quotation-old-account',
          orderId: _privacyBooking.id,
          items: const [],
          createdAt: DateTime.utc(2026, 8, 8),
        ),
      );
      await sessions.clear();

      final restored = await WorkerAppState.memory(
        store: store,
        sessionStore: sessions,
      );

      expect(restored.isLoggedIn, isFalse);
      expect(restored.profile.name, isEmpty);
      expect(restored.orders, isEmpty);
      expect(restored.remoteBookings, isEmpty);
      expect(restored.messages, isEmpty);
      expect(restored.quotations, isEmpty);
      final persisted =
          jsonDecode(store.getString(WorkerAppState.documentKey)!)
              as Map<String, dynamic>;
      expect(persisted['orders'], isEmpty);
      expect(persisted['remoteBookings'], isEmpty);
      expect(persisted['messages'], isEmpty);
      expect(persisted['quotations'], isEmpty);
    },
  );

  test('worker logout rejects an in-flight profile write', () async {
    final state = await WorkerAppState.memory(
      sessionStore: MemoryAuthSessionStore(),
    );
    await state.loginOnline(_loginResponse);
    final updateResult = Completer<void>();
    final profileWrite = state.updateProfile(
      state.profile.copyWith(name: '旧账号延迟资料'),
      api: _ControlledWorkerProfileApi(updateResult),
    );
    await Future<void>.delayed(Duration.zero);

    await state.logout();
    updateResult.complete();
    await profileWrite;

    expect(state.profile.name, isEmpty);
    expect(state.orders, isEmpty);
    expect(state.messages, isEmpty);
  });

  test('restoring worker session refreshes complete remote profile', () async {
    final sessions = MemoryAuthSessionStore();
    final state = await WorkerAppState.memory(sessionStore: sessions);
    await state.loginOnline(_loginResponse);
    await state.logout();
    await sessions.save(AuthSession.fromLogin(_loginResponse));

    final restored = await state.restoreOnlineSession(
      api: _RecordingWorkerProfileApi(
        remoteProfile: const RemoteWorkerProfile(
          phone: '13800138102',
          name: '模拟器闭环木工',
          serviceCity: '成都',
          primaryTrade: 'carpentry',
          experienceYears: 8,
          dailyRate: 500,
          bio: '擅长全屋定制和柜体安装',
          profileComplete: true,
        ),
      ),
    );

    expect(restored, isTrue);
    expect(state.isLoggedIn, isTrue);
    expect(state.profile.name, '模拟器闭环木工');
    expect(state.profile.trade, Trade.carpentry);
    expect(state.profile.isProfileComplete, isTrue);
  });

  test(
    'worker profile is persisted remotely before local state changes',
    () async {
      final sessions = MemoryAuthSessionStore();
      final state = await WorkerAppState.memory(sessionStore: sessions);
      final api = _RecordingWorkerProfileApi();
      await state.loginOnline(_loginResponse);
      final next = state.profile.copyWith(
        name: '张师傅',
        serviceCity: '成都',
        trade: Trade.plumbing,
        tradeSelected: true,
        experienceYears: 8,
        dailyRate: 500,
        bio: '擅长旧房水电改造',
      );

      await state.updateProfile(next, api: api);

      expect(api.updatedBody, {
        'name': '张师傅',
        'serviceCity': '成都',
        'primaryTrade': Trade.plumbing.name,
        'experienceYears': 8,
        'dailyRate': 500.0,
        'bio': '擅长旧房水电改造',
      });
      expect(state.profile.isProfileComplete, isTrue);
      expect(state.profile.name, '张师傅');
    },
  );

  test('failed remote profile save leaves local profile unchanged', () async {
    final state = await WorkerAppState.memory();
    await state.loginOnline(_loginResponse);
    final before = state.profile;

    await expectLater(
      state.updateProfile(
        before.copyWith(name: '不应保存'),
        api: _RecordingWorkerProfileApi(failUpdate: true),
      ),
      throwsA(isA<AuthApiException>()),
    );

    expect(state.profile.name, before.name);
  });

  test(
    'local persistence mutations preserve the active server session',
    () async {
      final state = await WorkerAppState.memory();
      await state.loginOnline(_loginResponse);

      await state.updateSettings(
        state.settings.copyWith(acceptOrders: !state.settings.acceptOrders),
      );

      expect(state.accessToken, _loginResponse.accessToken);
      expect(state.isLoggedIn, isTrue);
    },
  );

  test(
    'remote booking trade is displayed as Chinese worker order trade',
    () async {
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-jwt');

      state.initBookingApi(
        api: _FakeWorkerBookingApi([
          RemoteWorkerBooking(
            id: 'booking-1',
            ownerUserId: 'owner-1',
            ownerName: '业主',
            ownerPhone: '13800000000',
            serviceRequestId: 'request-1',
            workerUserId: 'worker-1',
            workerName: '模拟器闭环木工',
            trade: 'carpentry',
            serviceCity: '成都',
            serviceAddress: 'Android Studio 模拟器小区',
            status: 'ACCEPTED',
            createdAt: DateTime.utc(2026, 7, 18),
            updatedAt: DateTime.utc(2026, 7, 18),
          ),
        ]),
        accessToken: 'worker-jwt',
      );
      await state.fetchRemoteBookings();

      expect(state.remoteBookings.single.trade, 'carpentry');
      expect(state.orders.single.trade, '木工');
      expect(state.orders.single.requirement, '木工师傅');
    },
  );

  test(
    'new remote pending booking creates one unread worker message',
    () async {
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-jwt');
      final api = _FakeWorkerBookingApi([]);
      state.initBookingApi(api: api, accessToken: 'worker-jwt');
      await state.fetchRemoteBookings();

      api.bookings = [
        RemoteWorkerBooking(
          id: 'booking-new',
          ownerUserId: 'owner-1',
          ownerName: 'kkkkk',
          ownerPhone: '13555555555',
          serviceRequestId: 'request-1',
          workerUserId: 'worker-gt',
          workerName: 'GT',
          trade: 'plumbing',
          serviceCity: '成都',
          serviceAddress: 'fghfdg',
          status: 'PENDING',
          createdAt: DateTime.utc(2026, 7, 18),
          updatedAt: DateTime.utc(2026, 7, 18),
        ),
      ];

      await state.fetchRemoteBookings();
      await state.fetchRemoteBookings();

      expect(state.pendingOrders.single.id, 'booking-new');
      expect(
        state.messages.where((m) => m.orderId == 'booking-new'),
        hasLength(1),
      );
      expect(state.messages.single.title, '新的预约待接单');
      expect(state.messages.single.isRead, isFalse);
    },
  );

  test(
    'owner reported payment creates one unread receipt confirmation message',
    () async {
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-jwt');
      final api = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          final data = switch (request.url.path) {
            '/api/v1/payment/orders' => {
              'content': [
                {
                  'id': 'payment-1',
                  'bookingId': 'booking-1',
                  'ownerUserId': 'owner-1',
                  'workerUserId': 'worker-1',
                  'quoteId': 'quote-1',
                  'amount': 6380,
                  'platformFee': 580,
                  'workerSettlement': 5220,
                  'warrantyRetention': 580,
                  'status': 'OWNER_REPORTED_PAID',
                  'paymentMethod': 'OFFLINE',
                  'createdAt': '2026-08-01T10:00:00Z',
                  'updatedAt': '2026-08-01T10:01:00Z',
                },
              ],
            },
            '/api/v1/settlements' => <Map<String, dynamic>>[],
            '/api/v1/warranty-retentions' => <Map<String, dynamic>>[],
            _ => <Map<String, dynamic>>[],
          };
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({'code': 'OK', 'message': 'success', 'data': data}),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      state.initPaymentApi(api: api, accessToken: 'worker-jwt');

      await state.fetchRemotePayments();
      await state.fetchRemotePayments();

      final messages = state.messages
          .where((message) => message.paymentOrderId == 'payment-1')
          .toList();
      expect(messages, hasLength(1));
      expect(messages.single.title, '业主已付款，待确认收款');
      expect(messages.single.category, '收入');
      expect(messages.single.isRead, isFalse);
      expect(messages.single.orderId, 'booking-1');
      expect(messages.single.content, '请查看费用明细并核对实际到账，确认无误后点击确认收款。');
    },
  );

  test('split construction payment creates one full receipt message', () async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    final api = PaymentApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        final data = switch (request.url.path) {
          '/api/v1/payment/orders' => {
            'content': [
              {
                'id': 'payment-split-1',
                'bookingId': 'booking-split-1',
                'ownerUserId': 'owner-1',
                'workerUserId': 'worker-1',
                'quoteId': 'quote-split-1',
                'amount': 11924,
                'platformFee': 1084,
                'workerSettlement': 10840,
                'warrantyRetention': 0,
                'fundingModel': 'OFFLINE_SPLIT_V2',
                'quoteAmount': 10840,
                'constructionPaymentStatus': 'REPORTED',
                'platformFeeStatus': 'REPORTED',
                'status': 'UNDER_REVIEW',
                'paymentMethod': 'OFFLINE',
                'createdAt': '2026-08-06T10:00:00Z',
                'updatedAt': '2026-08-06T10:01:00Z',
              },
            ],
          },
          '/api/v1/settlements' => <Map<String, dynamic>>[],
          '/api/v1/warranty-retentions' => <Map<String, dynamic>>[],
          '/api/v1/worker-warranty/account' => {
            'id': 'account-1',
            'workerUserId': 'worker-1',
            'effectiveBalance': 0,
            'deductedTotal': 0,
            'releasedTotal': 0,
            'capAmount': 10000,
            'outstandingAmount': 1084,
            'status': 'ACTIVE',
            'canAcceptNewJobs': false,
          },
          '/api/v1/worker-warranty/contributions' => <Map<String, dynamic>>[],
          _ => <Map<String, dynamic>>[],
        };
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({'code': 'OK', 'message': 'success', 'data': data}),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    state.initPaymentApi(api: api, accessToken: 'worker-jwt');

    await state.fetchRemotePayments();
    await state.fetchRemotePayments();

    final messages = state.messages
        .where((message) => message.paymentOrderId == 'payment-split-1')
        .toList();
    expect(messages, hasLength(1));
    expect(messages.single.title, '业主已付工程款，待确认到账');
    expect(messages.single.content, '本单工程款 ¥10840，请核对实际到账后确认。');
  });

  test(
    'restoring an old split receipt message sanitizes and persists it',
    () async {
      final seed = await WorkerAppState.memory();
      final createdAt = DateTime.utc(2026, 8, 6, 10, 1);
      final sessions = MemoryAuthSessionStore(
        AuthSession.fromLogin(_loginResponse),
      );
      final store = MemoryWorkerStore({
        WorkerAppState.documentKey: jsonEncode({
          ...seed.toJson(),
          'profile': seed.profile
              .copyWith(phone: _loginResponse.user.phone)
              .toJson(),
          'isLoggedIn': true,
          'sessionUserId': _loginResponse.user.id,
          'messages': [
            {
              'id': 'wmsg-payment-awaiting-payment-split-1',
              'title': '业主已付工程款，待确认到账',
              'content': '本单工程款 ¥10840，请核对实际到账后确认。平台服务费由业主另行支付。',
              'category': '收入',
              'createdAt': createdAt.toIso8601String(),
              'isRead': true,
              'orderId': 'booking-split-1',
              'paymentOrderId': 'payment-split-1',
            },
          ],
        }),
      });

      final restored = await WorkerAppState.memory(
        store: store,
        sessionStore: sessions,
      );

      expect(restored.messages, hasLength(1));
      final message = restored.messages.single;
      expect(message.content, '本单工程款 ¥10840，请核对实际到账后确认。');
      expect(message.id, 'wmsg-payment-awaiting-payment-split-1');
      expect(message.paymentOrderId, 'payment-split-1');
      expect(message.orderId, 'booking-split-1');
      expect(message.createdAt, createdAt);
      expect(message.isRead, isTrue);

      final persistedAfterRestore =
          jsonDecode(store.getString(WorkerAppState.documentKey)!)
              as Map<String, dynamic>;
      final persistedMessage = Map<String, dynamic>.from(
        (persistedAfterRestore['messages'] as List<dynamic>).single as Map,
      );
      expect(persistedMessage['content'], '本单工程款 ¥10840，请核对实际到账后确认。');

      final reloaded = await WorkerAppState.memory(
        store: store,
        sessionStore: sessions,
      );
      expect(reloaded.messages, hasLength(1));
      expect(reloaded.messages.single.content, '本单工程款 ¥10840，请核对实际到账后确认。');
    },
  );

  test(
    'remote split payment sync refreshes a known receipt copy in place',
    () async {
      final seed = await WorkerAppState.memory();
      final createdAt = DateTime.utc(2026, 8, 6, 10, 1);
      final sessions = MemoryAuthSessionStore(
        AuthSession.fromLogin(_loginResponse),
      );
      final store = MemoryWorkerStore({
        WorkerAppState.documentKey: jsonEncode({
          ...seed.toJson(),
          'profile': seed.profile
              .copyWith(phone: _loginResponse.user.phone)
              .toJson(),
          'isLoggedIn': true,
          'sessionUserId': _loginResponse.user.id,
          'messages': [
            {
              'id': 'wmsg-payment-awaiting-payment-split-1',
              'title': '业主已付工程款，待确认到账',
              'content': '旧版工程款到账提醒。',
              'category': '收入',
              'createdAt': createdAt.toIso8601String(),
              'isRead': true,
              'orderId': 'booking-split-1',
              'paymentOrderId': 'payment-split-1',
            },
          ],
        }),
      });
      final state = await WorkerAppState.memory(
        store: store,
        sessionStore: sessions,
      );
      final api = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          final data = switch (request.url.path) {
            '/api/v1/payment/orders' => {
              'content': [
                {
                  'id': 'payment-split-1',
                  'bookingId': 'booking-split-1',
                  'ownerUserId': 'owner-1',
                  'workerUserId': 'worker-1',
                  'quoteId': 'quote-split-1',
                  'amount': 11924,
                  'platformFee': 1084,
                  'workerSettlement': 10840,
                  'warrantyRetention': 0,
                  'fundingModel': 'OFFLINE_SPLIT_V2',
                  'quoteAmount': 10840,
                  'constructionPaymentStatus': 'REPORTED',
                  'platformFeeStatus': 'REPORTED',
                  'status': 'UNDER_REVIEW',
                  'paymentMethod': 'OFFLINE',
                  'createdAt': '2026-08-06T10:00:00Z',
                  'updatedAt': '2026-08-06T10:02:00Z',
                },
              ],
            },
            '/api/v1/settlements' => <Map<String, dynamic>>[],
            '/api/v1/warranty-retentions' => <Map<String, dynamic>>[],
            _ => <Map<String, dynamic>>[],
          };
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({'code': 'OK', 'message': 'success', 'data': data}),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      state.initPaymentApi(api: api, accessToken: 'worker-jwt');

      await state.fetchRemotePayments();

      expect(state.messages, hasLength(1));
      final message = state.messages.single;
      expect(message.content, '本单工程款 ¥10840，请核对实际到账后确认。');
      expect(message.id, 'wmsg-payment-awaiting-payment-split-1');
      expect(message.paymentOrderId, 'payment-split-1');
      expect(message.orderId, 'booking-split-1');
      expect(message.createdAt, createdAt);
      expect(message.isRead, isTrue);

      final reloaded = await WorkerAppState.memory(
        store: store,
        sessionStore: sessions,
      );
      expect(reloaded.messages, hasLength(1));
      expect(reloaded.messages.single.content, '本单工程款 ¥10840，请核对实际到账后确认。');
      expect(reloaded.messages.single.id, message.id);
      expect(reloaded.messages.single.createdAt, createdAt);
      expect(reloaded.messages.single.isRead, isTrue);
    },
  );

  test(
    'warranty top-up error is shown as an actionable worker message',
    () async {
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-jwt');
      state.initBookingApi(
        api: _WarrantyBlockedWorkerBookingApi(),
        accessToken: 'worker-jwt',
      );

      final accepted = await state.acceptRemoteBooking('booking-1');

      expect(accepted, isFalse);
      expect(state.remoteBookingError, '履约质保金待补足，完成核验后可继续接单');
    },
  );

  test(
    'concurrent remote booking refresh does not duplicate new order message',
    () async {
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-jwt');
      final api = _FakeWorkerBookingApi([
        RemoteWorkerBooking(
          id: 'booking-race',
          ownerUserId: 'owner-1',
          ownerName: '业主',
          ownerPhone: '13800000000',
          serviceRequestId: 'request-1',
          workerUserId: 'worker-1',
          workerName: 'GT',
          trade: 'plumbing',
          serviceCity: '成都',
          serviceAddress: 'fghfdg',
          status: 'PENDING',
          createdAt: DateTime.utc(2026, 7, 18),
          updatedAt: DateTime.utc(2026, 7, 18),
        ),
      ], delay: const Duration(milliseconds: 10));
      state.initBookingApi(api: api, accessToken: 'worker-jwt');

      await Future.wait([
        state.fetchRemoteBookings(),
        state.fetchRemoteBookings(),
      ]);

      expect(
        state.messages.where((m) => m.orderId == 'booking-race'),
        hasLength(1),
      );
    },
  );

  test('remote booking refresh replaces stale local order state', () async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    final api = _FakeWorkerBookingApi([
      RemoteWorkerBooking(
        id: 'booking-1',
        ownerUserId: 'owner-1',
        ownerName: '业主',
        ownerPhone: '13800000000',
        serviceRequestId: 'request-1',
        workerUserId: 'worker-1',
        workerName: '模拟器闭环木工',
        trade: 'carpentry',
        serviceCity: '成都',
        serviceAddress: 'Android Studio 模拟器小区',
        status: 'ACCEPTED',
        createdAt: DateTime.utc(2026, 7, 18),
        updatedAt: DateTime.utc(2026, 7, 18),
      ),
    ]);
    state.initBookingApi(api: api, accessToken: 'worker-jwt');
    await state.fetchRemoteBookings();

    final proposedTime = DateTime.utc(2026, 7, 19, 1);
    api.bookings = [
      RemoteWorkerBooking(
        id: 'booking-1',
        ownerUserId: 'owner-1',
        ownerName: '业主',
        ownerPhone: '13800000000',
        serviceRequestId: 'request-1',
        workerUserId: 'worker-1',
        workerName: '模拟器闭环木工',
        trade: 'carpentry',
        serviceCity: '成都',
        serviceAddress: 'Android Studio 模拟器小区',
        status: 'VISIT_SCHEDULED',
        proposedTime: proposedTime,
        createdAt: DateTime.utc(2026, 7, 18),
        updatedAt: DateTime.utc(2026, 7, 18, 1),
      ),
    ];

    await state.fetchRemoteBookings();

    expect(state.orders.single.status, WorkerOrderStatus.visitScheduled);
    expect(state.orders.single.proposedTime, proposedTime);
    expect(state.activeOrders.single.status, WorkerOrderStatus.visitScheduled);
  });

  test(
    'remote order keeps scheduled and actual visit timestamps separate',
    () async {
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-jwt');
      final scheduled = DateTime.utc(2026, 8, 10, 1, 30);
      final actual = DateTime.utc(2026, 8, 10, 2, 5);
      state.initBookingApi(
        api: _FakeWorkerBookingApi([
          RemoteWorkerBooking(
            id: 'booking-visit-times',
            ownerUserId: 'owner-1',
            ownerName: '业主',
            ownerPhone: '13800000000',
            serviceRequestId: 'request-1',
            workerUserId: 'worker-1',
            workerName: '模拟器闭环木工',
            trade: 'carpentry',
            serviceCity: '成都',
            status: 'ON_SITE',
            proposedTime: DateTime.utc(2026, 8, 11, 1, 30),
            scheduledVisitAt: scheduled,
            actualOnSiteAt: actual,
            createdAt: DateTime.utc(2026, 8, 9),
            updatedAt: actual,
          ),
        ]),
        accessToken: 'worker-jwt',
      );

      await state.fetchRemoteBookings();

      expect(state.orders.single.scheduledVisitAt, scheduled);
      expect(state.orders.single.actualOnSiteAt, actual);
      expect(
        state.orders.single.proposedTime,
        DateTime.utc(2026, 8, 11, 1, 30),
      );
    },
  );

  test('legacy persisted order restores separate visit timestamp aliases', () {
    final order = WorkerOrder.fromJson({
      'id': 'booking-legacy-visit-times',
      'ownerName': '业主',
      'ownerPhone': '13800000000',
      'ownerAddress': '成都 1 栋 101',
      'area': '80㎡',
      'requirement': '木工师傅',
      'description': '柜体安装',
      'trade': '木工',
      'status': 'onSite',
      'images': <String>[],
      'proposedTime': '2026-08-10T09:30:00+08:00',
      'onSiteAt': '2026-08-10T10:05:00+08:00',
    });

    expect(order.scheduledVisitAt, DateTime.parse('2026-08-10T09:30:00+08:00'));
    expect(order.actualOnSiteAt, DateTime.parse('2026-08-10T10:05:00+08:00'));
    expect(order.houseInfo, isNull);
    expect(order.houseSummary, '房屋信息未填写');
  });

  test(
    'remote booking maps structured house info into persisted order',
    () async {
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-jwt');
      final now = DateTime.utc(2026, 8, 9);
      state.initBookingApi(
        api: _FakeWorkerBookingApi([
          RemoteWorkerBooking(
            id: 'house-booking',
            ownerUserId: 'owner-1',
            ownerName: '业主',
            ownerPhone: '13800000000',
            serviceRequestId: 'request-1',
            workerUserId: 'worker-1',
            workerName: '张师傅',
            trade: 'painting',
            serviceCity: '成都市',
            houseInfo: const HouseInfo(
              areaSqm: 98.5,
              bedroomCount: 3,
              livingRoomCount: 2,
              kitchenCount: 1,
              bathroomCount: 2,
            ),
            status: 'PENDING',
            createdAt: now,
            updatedAt: now,
          ),
        ]),
        accessToken: 'worker-jwt',
      );

      await state.fetchRemoteBookings();

      final order = state.orders.single;
      expect(order.houseSummary, '98.5㎡ · 3室2厅1厨2卫');
      expect(WorkerOrder.fromJson(order.toJson()).houseInfo, order.houseInfo);
    },
  );

  test('arrival pending status label tells worker confirmation is pending', () {
    final order = WorkerOrder(
      id: 'booking-1',
      ownerName: '业主',
      ownerPhone: '13800000000',
      ownerAddress: '成都 1 栋 101',
      area: '80㎡',
      requirement: '木工师傅',
      description: '柜体安装',
      trade: '木工',
      status: WorkerOrderStatus.arrivalPending,
      arrivalConfirmedByWorker: true,
      arrivalConfirmedByOwner: false,
    );

    expect(order.statusLabel, '等待到场确认');
  });

  test(
    'server terminal and ready statuses never become pending orders',
    () async {
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-jwt');
      final now = DateTime.utc(2026, 7, 22);
      state.initBookingApi(
        api: _FakeWorkerBookingApi([
          for (final entry in const {
            'not-selected': 'NOT_SELECTED',
            'rejected': 'REJECTED',
            'cancelled': 'CANCELLED',
            'ready': 'READY_TO_START',
            'completed': 'COMPLETED',
          }.entries)
            RemoteWorkerBooking(
              id: entry.key,
              ownerUserId: 'owner-1',
              ownerName: '业主',
              ownerPhone: '13800000000',
              serviceRequestId: 'request-1',
              workerUserId: 'worker-1',
              workerName: '张师傅',
              trade: 'plumbing',
              serviceCity: '成都',
              status: entry.value,
              createdAt: now,
              updatedAt: now,
            ),
        ]),
        accessToken: 'worker-jwt',
      );

      await state.fetchRemoteBookings();

      expect(state.pendingOrders, isEmpty);
      expect(
        state.orders.firstWhere((order) => order.id == 'not-selected').status,
        WorkerOrderStatus.cancelled,
      );
      expect(
        state.orders.firstWhere((order) => order.id == 'ready').status,
        WorkerOrderStatus.hired,
      );
      expect(
        state.activeOrders.where((order) => order.id == 'completed'),
        isEmpty,
      );
      expect(state.completedOrders.single.id, 'completed');
    },
  );
}

const _loginResponse = OwnerLoginResponse(
  accessToken: 'worker-jwt',
  tokenType: 'Bearer',
  expiresInSeconds: 3600,
  user: AuthUser(
    id: 'worker-id',
    phone: '13800138102',
    status: 'ACTIVE',
    roles: ['WORKER'],
  ),
);

const _nextLoginResponse = OwnerLoginResponse(
  accessToken: 'worker-next-jwt',
  tokenType: 'Bearer',
  expiresInSeconds: 3600,
  user: AuthUser(
    id: 'worker-next-id',
    phone: '13800138103',
    status: 'ACTIVE',
    roles: ['WORKER'],
  ),
);

final _privacyBooking = RemoteWorkerBooking(
  id: 'booking-old-account',
  ownerUserId: 'owner-old-account',
  ownerName: '旧账号业主',
  ownerPhone: '13800000000',
  serviceRequestId: 'request-old-account',
  workerUserId: 'worker-id',
  workerName: '旧账号工人',
  trade: 'carpentry',
  serviceCity: '成都',
  serviceAddress: '旧账号地址',
  status: 'PENDING',
  createdAt: DateTime.utc(2026, 8, 8),
  updatedAt: DateTime.utc(2026, 8, 8),
);

PaymentApiClient _privacyPaymentApi() => PaymentApiClient(
  baseUrl: Uri.parse('http://example.test'),
  httpClient: MockClient((request) async {
    final data = switch (request.url.path) {
      '/api/v1/payment/orders' => {
        'content': [
          {
            'id': 'payment-old-account',
            'bookingId': _privacyBooking.id,
            'ownerUserId': 'owner-old-account',
            'workerUserId': 'worker-id',
            'quoteId': 'quote-old-account',
            'amount': 220,
            'platformFee': 20,
            'workerSettlement': 180,
            'warrantyRetention': 20,
            'status': 'OWNER_REPORTED_PAID',
            'paymentMethod': 'OFFLINE',
            'createdAt': '2026-08-08T00:00:00Z',
            'updatedAt': '2026-08-08T00:01:00Z',
          },
        ],
      },
      '/api/v1/settlements' => [
        {
          'id': 'settlement-old-account',
          'workerUserId': 'worker-id',
          'bookingId': _privacyBooking.id,
          'paymentOrderId': 'payment-old-account',
          'amount': 180,
          'status': 'SETTLEABLE',
          'frozenReason': null,
          'settledAt': null,
          'createdAt': '2026-08-08T00:00:00Z',
          'updatedAt': '2026-08-08T00:01:00Z',
        },
      ],
      '/api/v1/warranty-retentions' => <Map<String, dynamic>>[],
      '/api/v1/worker-warranty/account' => {
        'id': 'warranty-account-old-account',
        'workerUserId': 'worker-id',
        'effectiveBalance': 3084,
        'deductedTotal': 0,
        'releasedTotal': 0,
        'capAmount': 10000,
        'outstandingAmount': 1084,
        'status': 'ACTIVE',
        'canAcceptNewJobs': false,
      },
      '/api/v1/worker-warranty/contributions' => [
        {
          'id': 'warranty-contribution-old-account',
          'workerUserId': 'worker-id',
          'paymentOrderId': 'payment-old-account',
          'bookingId': _privacyBooking.id,
          'amountDue': 1084,
          'status': 'DUE',
        },
      ],
      _ => <Map<String, dynamic>>[],
    };
    return http.Response.bytes(
      utf8.encode(
        jsonEncode({'code': 'OK', 'message': 'success', 'data': data}),
      ),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }),
);

final class _ControlledPaymentApi {
  _ControlledPaymentApi(this.paymentResult)
    : client = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/v1/payment/orders') {
            return paymentResult.future;
          }
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 'OK',
                'message': 'success',
                'data': <Map<String, dynamic>>[],
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

  final Completer<http.Response> paymentResult;
  final PaymentApiClient client;
}

http.Response _privacyPaymentOrdersResponse() => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'code': 'OK',
      'message': 'success',
      'data': {
        'content': [
          {
            'id': 'payment-old-account',
            'bookingId': _privacyBooking.id,
            'ownerUserId': 'owner-old-account',
            'workerUserId': 'worker-id',
            'quoteId': 'quote-old-account',
            'amount': 220,
            'platformFee': 20,
            'workerSettlement': 180,
            'warrantyRetention': 20,
            'status': 'OWNER_REPORTED_PAID',
            'paymentMethod': 'OFFLINE',
            'createdAt': '2026-08-08T00:00:00Z',
            'updatedAt': '2026-08-08T00:01:00Z',
          },
        ],
      },
    }),
  ),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

final class _RecordingWorkerProfileApi implements OwnerAuthApi {
  _RecordingWorkerProfileApi({this.failUpdate = false, this.remoteProfile});

  final bool failUpdate;
  final RemoteWorkerProfile? remoteProfile;
  Map<String, dynamic>? updatedBody;

  @override
  Future<void> updateWorkerProfile(
    String token,
    Map<String, dynamic> body,
  ) async {
    if (failUpdate) {
      throw const AuthApiException(code: 'UPDATE_FAILED', message: '更新资料失败');
    }
    updatedBody = Map<String, dynamic>.from(body);
  }

  @override
  Future<RemoteWorkerProfile> getWorkerProfile(String token) async =>
      remoteProfile ??
      const RemoteWorkerProfile(
        phone: '13800138102',
        name: '张师傅',
        serviceCity: '成都',
        primaryTrade: 'plumber',
        experienceYears: 8,
        dailyRate: 500,
        bio: '擅长旧房水电改造',
        profileComplete: true,
      );

  @override
  Future<OwnerLoginResponse> loginOwner(String phone, String code) =>
      throw UnimplementedError();

  @override
  Future<OwnerLoginResponse> loginWorker(String phone, String code) =>
      throw UnimplementedError();

  @override
  Future<SmsCodeResponse> requestSmsCode(String phone) =>
      throw UnimplementedError();
}

final class _ControlledWorkerProfileApi implements OwnerAuthApi {
  _ControlledWorkerProfileApi(this.updateResult);

  final Completer<void> updateResult;

  @override
  Future<void> updateWorkerProfile(String token, Map<String, dynamic> body) =>
      updateResult.future;

  @override
  Future<RemoteWorkerProfile> getWorkerProfile(String token) async =>
      const RemoteWorkerProfile(
        phone: '13800138102',
        name: '旧账号延迟资料',
        serviceCity: '成都',
        primaryTrade: 'carpentry',
        experienceYears: 8,
        dailyRate: 500,
        bio: '旧账号资料',
        profileComplete: true,
      );

  @override
  Future<OwnerLoginResponse> loginOwner(String phone, String code) =>
      throw UnimplementedError();

  @override
  Future<OwnerLoginResponse> loginWorker(String phone, String code) =>
      throw UnimplementedError();

  @override
  Future<SmsCodeResponse> requestSmsCode(String phone) =>
      throw UnimplementedError();
}

final class _FakeWorkerBookingApi implements WorkerBookingApi {
  _FakeWorkerBookingApi(this.bookings, {this.delay = Duration.zero});

  List<RemoteWorkerBooking> bookings;
  final Duration delay;

  @override
  Future<List<RemoteWorkerBooking>> listWorkerBookings(
    String accessToken,
  ) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return bookings;
  }

  @override
  Future<RemoteWorkerBooking> acceptBooking(
    String accessToken,
    String bookingId,
  ) => throw UnimplementedError();

  @override
  Future<RemoteWorkerBooking> cancelBooking(
    String accessToken,
    String bookingId,
    String reason,
  ) => throw UnimplementedError();

  @override
  Future<RemoteWorkerBooking> rejectBooking(
    String accessToken,
    String bookingId,
  ) => throw UnimplementedError();
}

final class _ControlledWorkerBookingApi implements WorkerBookingApi {
  _ControlledWorkerBookingApi(this.result);

  final Completer<List<RemoteWorkerBooking>> result;

  @override
  Future<List<RemoteWorkerBooking>> listWorkerBookings(String accessToken) =>
      result.future;

  @override
  Future<RemoteWorkerBooking> acceptBooking(
    String accessToken,
    String bookingId,
  ) => throw UnimplementedError();

  @override
  Future<RemoteWorkerBooking> cancelBooking(
    String accessToken,
    String bookingId,
    String reason,
  ) => throw UnimplementedError();

  @override
  Future<RemoteWorkerBooking> rejectBooking(
    String accessToken,
    String bookingId,
  ) => throw UnimplementedError();
}

final class _DelayedSecondSaveSessionStore implements AuthSessionStore {
  final Completer<void> _secondSave = Completer<void>();
  final Completer<void> _secondSaveStarted = Completer<void>();
  AuthSession? _session;
  int _saveCount = 0;

  void completeSecondSave() => _secondSave.complete();

  Future<void> waitUntilSecondSaveStarted() => _secondSaveStarted.future;

  @override
  Future<void> clear() async {
    _session = null;
  }

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> save(AuthSession session) async {
    _session = session;
    _saveCount += 1;
    if (_saveCount == 2) {
      _secondSaveStarted.complete();
      await _secondSave.future;
    }
  }
}

final class _WarrantyBlockedWorkerBookingApi implements WorkerBookingApi {
  @override
  Future<RemoteWorkerBooking> acceptBooking(
    String accessToken,
    String bookingId,
  ) => throw const AuthApiException(
    code: 'WORKER_WARRANTY_TOP_UP_REQUIRED',
    message: 'worker warranty contribution is outstanding',
  );

  @override
  Future<RemoteWorkerBooking> cancelBooking(
    String accessToken,
    String bookingId,
    String reason,
  ) => throw UnimplementedError();

  @override
  Future<List<RemoteWorkerBooking>> listWorkerBookings(
    String accessToken,
  ) async => const [];

  @override
  Future<RemoteWorkerBooking> rejectBooking(
    String accessToken,
    String bookingId,
  ) => throw UnimplementedError();
}
