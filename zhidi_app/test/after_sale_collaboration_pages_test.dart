import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/app/worker_app_scope.dart';
import 'package:zhidi_app/app/worker_app_state.dart';
import 'package:zhidi_app/models/payment_models.dart';
import 'package:zhidi_app/pages/home/owner_after_sale_page.dart';
import 'package:zhidi_app/pages/profile/support_page.dart';
import 'package:zhidi_app/pages/worker/worker_after_sale_page.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/payment_api_client.dart';

void main() {
  testWidgets(
    'owner sees exact order context SLA and timeline then can append',
    (tester) async {
      final state = await _loggedInOwner();
      final api = _FakeAfterSaleApi();
      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: OwnerAfterSalePage(bookingId: 'booking-1', paymentApi: api),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('木作开裂'), findsOneWidget);
      await tester.tap(find.text('木作开裂'));
      await tester.pumpAndSettle();

      expect(find.text('订单信息'), findsOneWidget);
      expect(find.text('李师傅'), findsWidgets);
      expect(find.text('木工'), findsOneWidget);
      expect(find.text('已支付'), findsOneWidget);
      expect(find.text('验收已通过'), findsOneWidget);
      expect(find.textContaining('处理时限'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('平台已受理'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('平台已受理'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('after-sale-reply-field')),
        '请师傅本周返修',
      );
      await tester.tap(find.byKey(const Key('after-sale-reply-submit')));
      await tester.pumpAndSettle();

      expect(api.lastEventContent, '请师傅本周返修');
      expect(api.lastEventTicketId, 'after-sale-1');
    },
  );

  testWidgets(
    'preloaded detail clears sensitive contents immediately after logout',
    (tester) async {
      final state = await _loggedInOwner();
      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: OwnerAfterSalePage(
              bookingId: 'booking-1',
              paymentApi: _FakeAfterSaleApi(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('木作开裂'));
      await tester.pumpAndSettle();
      expect(find.text('木作开裂'), findsOneWidget);
      expect(find.text('李师傅'), findsWidgets);
      expect(find.textContaining('武侯区一号'), findsOneWidget);

      await state.logout();
      await tester.pump();

      expect(find.text('木作开裂'), findsNothing);
      expect(find.text('李师傅'), findsNothing);
      expect(find.textContaining('武侯区一号'), findsNothing);
      expect(find.text('登录状态已变化，售后内容不可用'), findsOneWidget);
    },
  );

  testWidgets('worker discovers the real participant ticket and can reply', (
    tester,
  ) async {
    final state = await _loggedInWorker();
    final api = _FakeAfterSaleApi();
    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(home: WorkerAfterSalePage(paymentApi: api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('张女士'), findsOneWidget);
    expect(find.text('木作开裂'), findsOneWidget);
    await tester.tap(find.text('木作开裂'));
    await tester.pumpAndSettle();
    expect(find.text('订单信息'), findsOneWidget);
    expect(find.textContaining('武侯区一号'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('after-sale-reply-field')),
      '已联系业主安排返修',
    );
    await tester.tap(find.byKey(const Key('after-sale-reply-submit')));
    await tester.pumpAndSettle();
    expect(api.lastEventContent, '已联系业主安排返修');
  });

  testWidgets(
    'support page is the server ticket list, not local fake records',
    (tester) async {
      final state = await _loggedInOwner();
      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: SupportPage(paymentApi: _FakeAfterSaleApi()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('保障与售后'), findsOneWidget);
      expect(find.text('木作开裂'), findsOneWidget);
      expect(find.text('提交售后申请'), findsNothing);
    },
  );

  testWidgets(
    'exact booking entry shows order context before choosing issue type',
    (tester) async {
      final state = await _loggedInOwner();
      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: OwnerAfterSalePage(
              bookingId: 'booking-1',
              paymentApi: _EmptyBookingAfterSaleApi(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('订单信息'), findsOneWidget);
      expect(find.text('李师傅'), findsOneWidget);
      expect(find.text('木工'), findsOneWidget);
      expect(find.text('已支付'), findsOneWidget);
      expect(find.text('验收已通过'), findsOneWidget);
      expect(find.text('申请售后'), findsOneWidget);
    },
  );

  testWidgets('refund request is presented as a manual platform claim', (
    tester,
  ) async {
    final state = await _loggedInOwner();
    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: OwnerAfterSalePage(
            bookingId: 'booking-1',
            paymentApi: _EmptyBookingAfterSaleApi(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('申请售后'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.text('退款诉求（平台人工处理）'), findsOneWidget);
    expect(find.text('平台将人工核实处理，当前不支持自动退款'), findsOneWidget);
    expect(find.text('退款申请'), findsNothing);
  });

  testWidgets(
    'exact booking does not offer after-sale before payment and acceptance',
    (tester) async {
      final state = await _loggedInOwner();
      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: OwnerAfterSalePage(
              bookingId: 'booking-1',
              paymentApi: _IneligibleBookingAfterSaleApi(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('申请售后'), findsNothing);
      expect(find.text('完工验收且付款完成后可申请售后'), findsOneWidget);
    },
  );

  testWidgets('paid but unfinished booking does not offer after-sale', (
    tester,
  ) async {
    final state = await _loggedInOwner();
    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: OwnerAfterSalePage(
            bookingId: 'booking-1',
            paymentApi: _PaidUnfinishedBookingAfterSaleApi(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('申请售后'), findsNothing);
    expect(find.text('完工验收且付款完成后可申请售后'), findsOneWidget);
  });

  testWidgets('completed paid booking does not depend on inspection summary', (
    tester,
  ) async {
    final state = await _loggedInOwner();
    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: OwnerAfterSalePage(
            bookingId: 'booking-1',
            paymentApi: _CompletedPaidNoInspectionAfterSaleApi(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('申请售后'), findsOneWidget);
  });

  testWidgets('resolved ticket explains the warranty deduction to both sides', (
    tester,
  ) async {
    final state = await _loggedInOwner();
    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: OwnerAfterSalePage(paymentApi: _ResolvedAfterSaleApi()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('木作开裂'));
    await tester.pumpAndSettle();

    expect(find.text('本次履约质保扣减 ¥10.00'), findsOneWidget);
    expect(find.text('处理结果：已核实并扣减质保金'), findsOneWidget);
  });

  testWidgets('owner ignores a stale list response after logout', (
    tester,
  ) async {
    final state = await _loggedInOwner();
    final api = _DelayedAfterSaleApi();
    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(home: OwnerAfterSalePage(paymentApi: api)),
      ),
    );
    await tester.pump();

    await state.logout();
    api.result.complete([_ticket]);
    await tester.pumpAndSettle();

    expect(find.text('木作开裂'), findsNothing);
  });

  testWidgets('list error is explicit and retry replaces it with server data', (
    tester,
  ) async {
    final state = await _loggedInOwner();
    final api = _RetryAfterSaleApi();
    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(home: OwnerAfterSalePage(paymentApi: api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('加载失败'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('木作开裂'), findsOneWidget);
    expect(api.calls, 2);
  });

  testWidgets('append failure stays on detail and offers a retry', (
    tester,
  ) async {
    final state = await _loggedInOwner();
    final api = _FailingAppendAfterSaleApi();
    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(home: OwnerAfterSalePage(paymentApi: api)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('木作开裂'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('after-sale-reply-field')),
      '请平台协助',
    );
    await tester.tap(find.byKey(const Key('after-sale-reply-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('发送失败'), findsOneWidget);
    expect(find.text('请平台协助'), findsOneWidget);
  });

  testWidgets('append retry reuses the same idempotency key until success', (
    tester,
  ) async {
    final state = await _loggedInOwner();
    final api = _AmbiguousAppendAfterSaleApi();
    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(home: OwnerAfterSalePage(paymentApi: api)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('木作开裂'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('after-sale-reply-field')),
      '同一份待重试说明',
    );

    await tester.tap(find.byKey(const Key('after-sale-reply-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('after-sale-reply-submit')));
    await tester.pumpAndSettle();

    expect(api.keys, hasLength(2));
    expect(api.keys[1], api.keys[0]);
  });

  testWidgets('stale append failure cannot write into a logged-out owner UI', (
    tester,
  ) async {
    final state = await _loggedInOwner();
    final api = _DelayedAppendAfterSaleApi();
    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(home: OwnerAfterSalePage(paymentApi: api)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('木作开裂'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('after-sale-reply-field')),
      '旧账号消息',
    );
    await tester.tap(find.byKey(const Key('after-sale-reply-submit')));
    await tester.pump();
    await api.started.future;

    await state.logout();
    api.result.completeError(
      const PaymentApiException(statusCode: 503, message: '旧会话失败'),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('发送失败'), findsNothing);
  });

  testWidgets('stale create failure cannot show after owner logout', (
    tester,
  ) async {
    final state = await _loggedInOwner();
    final api = _DelayedCreateAfterSaleApi();
    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: OwnerAfterSalePage(bookingId: 'booking-1', paymentApi: api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('申请售后'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '旧账号创建工单');
    await tester.tap(find.widgetWithText(FilledButton, '提交'));
    await tester.pump();
    await api.started.future;

    await state.logout();
    api.result.completeError(
      const PaymentApiException(statusCode: 503, message: '旧会话失败'),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('创建失败'), findsNothing);
  });

  testWidgets('stale creation evidence upload cannot mutate its dialog', (
    tester,
  ) async {
    const pickerChannel = MethodChannel('plugins.flutter.io/image_picker');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pickerChannel,
      (_) async => <String>['/tmp/after-sale-evidence.jpg'],
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        pickerChannel,
        null,
      ),
    );
    final state = await _loggedInOwner();
    final uploadStarted = Completer<void>();
    final uploadResult = Completer<String>();
    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: OwnerAfterSalePage(
            bookingId: 'booking-1',
            paymentApi: _EmptyBookingAfterSaleApi(),
            imageUploader: (file, token) {
              if (!uploadStarted.isCompleted) uploadStarted.complete();
              return uploadResult.future;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('申请售后'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('添加证据图片'));
    await tester.pump();
    await uploadStarted.future;

    await state.logout();
    uploadResult.completeError(
      const PaymentApiException(statusCode: 503, message: '旧会话上传失败'),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('图片上传失败'), findsNothing);
  });

  testWidgets(
    'same-origin local upload is submitted as canonical relative path',
    (tester) async {
      const pickerChannel = MethodChannel('plugins.flutter.io/image_picker');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        pickerChannel,
        (_) async => <String>['/tmp/after-sale-local.jpg'],
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          pickerChannel,
          null,
        ),
      );
      final state = await _loggedInOwner();
      final api = _CaptureCreateAfterSaleApi();
      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: OwnerAfterSalePage(
              bookingId: 'booking-1',
              paymentApi: api,
              imageUploader: (file, token) async =>
                  'http://47.109.0.191:8080/uploads/after-sales/local.jpg',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('申请售后'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('添加证据图片'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '本地证据');
      await tester.tap(find.widgetWithText(FilledButton, '提交'));
      await tester.pumpAndSettle();

      expect(api.evidenceUrls, ['/uploads/after-sales/local.jpg']);
    },
  );

  testWidgets('sending locks draft and upload until its finally completes', (
    tester,
  ) async {
    final state = await _loggedInOwner();
    final api = _DelayedAppendAfterSaleApi();
    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(home: OwnerAfterSalePage(paymentApi: api)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('木作开裂'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('after-sale-reply-field')),
      '发送中的稳定草稿',
    );
    await tester.tap(find.byKey(const Key('after-sale-reply-submit')));
    await tester.pump();
    await api.started.future;

    final field = tester.widget<TextField>(
      find.byKey(const Key('after-sale-reply-field')),
    );
    final upload = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.add_photo_alternate_outlined),
    );
    expect(field.enabled, isFalse);
    expect(upload.onPressed, isNull);

    api.result.complete(_detail.timeline.last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('after-sale-reply-field')))
          .enabled,
      isTrue,
    );
  });

  testWidgets('worker ignores a stale list response after account logout', (
    tester,
  ) async {
    final state = await _loggedInWorker();
    final api = _DelayedAfterSaleApi();
    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(home: WorkerAfterSalePage(paymentApi: api)),
      ),
    );
    await tester.pump();
    await state.logout();
    api.result.complete([_ticket]);
    await tester.pumpAndSettle();

    expect(find.text('木作开裂'), findsNothing);
  });

  testWidgets('worker empty state explains there are no related tickets', (
    tester,
  ) async {
    final state = await _loggedInWorker();
    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: WorkerAfterSalePage(paymentApi: _EmptyAfterSaleApi()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无相关售后工单'), findsOneWidget);
  });
}

Future<OwnerAppState> _loggedInOwner() async {
  final state = await OwnerAppState.memory();
  await state.completeAuthenticatedLogin(_ownerLogin);
  return state;
}

Future<WorkerAppState> _loggedInWorker() async {
  final state = await WorkerAppState.memory();
  await state.loginOnline(_workerLogin);
  return state;
}

const _ownerLogin = OwnerLoginResponse(
  accessToken: 'owner-token',
  tokenType: 'Bearer',
  expiresInSeconds: 3600,
  user: AuthUser(
    id: 'owner-1',
    phone: '13800138000',
    status: 'ACTIVE',
    roles: ['OWNER'],
  ),
);

const _workerLogin = OwnerLoginResponse(
  accessToken: 'worker-token',
  tokenType: 'Bearer',
  expiresInSeconds: 3600,
  user: AuthUser(
    id: 'worker-1',
    phone: '13800138001',
    status: 'ACTIVE',
    roles: ['WORKER'],
  ),
);

final _ticket = AfterSaleModel.fromJson(_ticketJson);
final _detail = AfterSaleDetailModel.fromJson(_detailJson);

class _FakeAfterSaleApi extends PaymentApiClient {
  String? lastEventTicketId;
  String? lastEventContent;

  @override
  Future<List<AfterSaleModel>> listAfterSales(String accessToken) async => [
    _ticket,
  ];

  @override
  Future<AfterSaleDetailModel> getAfterSale(
    String accessToken,
    String id,
  ) async => _detail;

  @override
  Future<AfterSaleEventModel> appendAfterSaleEvent(
    String accessToken,
    String id, {
    String? content,
    List<String> evidenceUrls = const [],
    required String idempotencyKey,
  }) async {
    lastEventTicketId = id;
    lastEventContent = content;
    return _detail.timeline.last;
  }
}

class _DelayedAfterSaleApi extends PaymentApiClient {
  final result = Completer<List<AfterSaleModel>>();

  @override
  Future<List<AfterSaleModel>> listAfterSales(String accessToken) =>
      result.future;
}

class _RetryAfterSaleApi extends PaymentApiClient {
  int calls = 0;

  @override
  Future<List<AfterSaleModel>> listAfterSales(String accessToken) async {
    calls++;
    if (calls == 1) {
      throw const PaymentApiException(statusCode: 503, message: '服务繁忙');
    }
    return [_ticket];
  }
}

class _EmptyAfterSaleApi extends PaymentApiClient {
  @override
  Future<List<AfterSaleModel>> listAfterSales(String accessToken) async => [];
}

class _EmptyBookingAfterSaleApi extends _EmptyAfterSaleApi {
  @override
  Future<AfterSaleOrderContextModel> getAfterSaleBookingContext(
    String accessToken,
    String bookingId,
  ) async => _detail.context;
}

class _IneligibleBookingAfterSaleApi extends _EmptyAfterSaleApi {
  @override
  Future<AfterSaleOrderContextModel> getAfterSaleBookingContext(
    String accessToken,
    String bookingId,
  ) async => AfterSaleOrderContextModel.fromJson({
    ..._detailJson['context'] as Map<String, dynamic>,
    'paymentStatus': 'PENDING',
    'inspection': {'status': 'PENDING', 'passedCount': 0, 'totalCount': 1},
  });
}

class _PaidUnfinishedBookingAfterSaleApi extends _EmptyAfterSaleApi {
  @override
  Future<AfterSaleOrderContextModel> getAfterSaleBookingContext(
    String accessToken,
    String bookingId,
  ) async => AfterSaleOrderContextModel.fromJson({
    ..._detailJson['context'] as Map<String, dynamic>,
    'bookingStatus': 'HIRED',
    'paymentStatus': 'PAID',
    'inspection': {'status': 'PASSED', 'passedCount': 1, 'totalCount': 1},
  });
}

class _CompletedPaidNoInspectionAfterSaleApi extends _EmptyAfterSaleApi {
  @override
  Future<AfterSaleOrderContextModel> getAfterSaleBookingContext(
    String accessToken,
    String bookingId,
  ) async => AfterSaleOrderContextModel.fromJson({
    ..._detailJson['context'] as Map<String, dynamic>,
    'bookingStatus': 'COMPLETED',
    'paymentStatus': 'PAID',
    'inspection': {
      'status': 'NOT_AVAILABLE',
      'passedCount': 0,
      'totalCount': 0,
    },
  });
}

class _ResolvedAfterSaleApi extends PaymentApiClient {
  @override
  Future<List<AfterSaleModel>> listAfterSales(String accessToken) async => [
    _resolvedDetail.ticket,
  ];

  @override
  Future<AfterSaleDetailModel> getAfterSale(
    String accessToken,
    String id,
  ) async => _resolvedDetail;
}

class _FailingAppendAfterSaleApi extends _FakeAfterSaleApi {
  @override
  Future<AfterSaleEventModel> appendAfterSaleEvent(
    String accessToken,
    String id, {
    String? content,
    List<String> evidenceUrls = const [],
    required String idempotencyKey,
  }) {
    throw const PaymentApiException(statusCode: 503, message: '服务繁忙');
  }
}

class _AmbiguousAppendAfterSaleApi extends _FakeAfterSaleApi {
  final List<String> keys = [];

  @override
  Future<AfterSaleEventModel> appendAfterSaleEvent(
    String accessToken,
    String id, {
    String? content,
    List<String> evidenceUrls = const [],
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    if (keys.length == 1) {
      throw const PaymentApiException(statusCode: 503, message: '响应超时');
    }
    return _detail.timeline.last;
  }
}

class _DelayedAppendAfterSaleApi extends _FakeAfterSaleApi {
  final started = Completer<void>();
  final result = Completer<AfterSaleEventModel>();

  @override
  Future<AfterSaleEventModel> appendAfterSaleEvent(
    String accessToken,
    String id, {
    String? content,
    List<String> evidenceUrls = const [],
    required String idempotencyKey,
  }) {
    if (!started.isCompleted) started.complete();
    return result.future;
  }
}

class _DelayedCreateAfterSaleApi extends _EmptyBookingAfterSaleApi {
  final started = Completer<void>();
  final result = Completer<AfterSaleModel>();

  @override
  Future<AfterSaleModel> createAfterSale(
    String accessToken, {
    required String bookingId,
    required String type,
    required String reason,
    List<String> evidenceUrls = const [],
  }) {
    if (!started.isCompleted) started.complete();
    return result.future;
  }
}

class _CaptureCreateAfterSaleApi extends _EmptyBookingAfterSaleApi {
  List<String>? evidenceUrls;

  @override
  Future<AfterSaleModel> createAfterSale(
    String accessToken, {
    required String bookingId,
    required String type,
    required String reason,
    List<String> evidenceUrls = const [],
  }) async {
    this.evidenceUrls = evidenceUrls;
    return _ticket;
  }
}

const _ticketJson = <String, dynamic>{
  'id': 'after-sale-1',
  'bookingId': 'booking-1',
  'ownerUserId': 'owner-1',
  'workerUserId': 'worker-1',
  'type': 'COMPLAINT',
  'reason': '木作开裂',
  'evidenceUrls': <String>[],
  'status': 'PLATFORM_PROCESSING',
  'acceptedAt': '2026-08-09T01:10:00Z',
  'dueAt': '2026-08-12T01:00:00Z',
  'lastActivityAt': '2026-08-09T01:20:00Z',
  'createdAt': '2026-08-09T01:00:00Z',
  'updatedAt': '2026-08-09T01:20:00Z',
};

const _detailJson = <String, dynamic>{
  'ticket': _ticketJson,
  'context': {
    'bookingId': 'booking-1',
    'bookingStatus': 'COMPLETED',
    'trade': 'carpentry',
    'ownerName': '张女士',
    'workerName': '李师傅',
    'serviceCity': '成都市',
    'serviceAddress': '武侯区一号',
    'quoteId': 'quote-1',
    'quoteAmount': 10840,
    'paymentOrderId': 'payment-1',
    'paymentAmount': 11924,
    'paymentStatus': 'PAID',
    'inspection': {'status': 'PASSED', 'passedCount': 1, 'totalCount': 1},
  },
  'timeline': [
    {
      'id': 'event-1',
      'afterSaleId': 'after-sale-1',
      'actorUserId': 'owner-1',
      'actorRole': 'OWNER',
      'type': 'CREATED',
      'content': '木作开裂',
      'evidenceUrls': <String>[],
      'idempotencyKey': 'created-after-sale-1',
      'createdAt': '2026-08-09T01:00:00Z',
    },
    {
      'id': 'event-2',
      'afterSaleId': 'after-sale-1',
      'actorUserId': 'admin-1',
      'actorRole': 'ADMIN',
      'type': 'PLATFORM_ACCEPTED',
      'content': '平台已受理',
      'evidenceUrls': <String>[],
      'idempotencyKey': 'accept-after-sale-1',
      'createdAt': '2026-08-09T01:10:00Z',
    },
  ],
};

final _resolvedDetail = AfterSaleDetailModel.fromJson({
  ..._detailJson,
  'ticket': {
    ..._ticketJson,
    'status': 'CLOSED',
    'resolution': '已核实并扣减质保金',
    'warrantyDeductionAmount': 10,
    'resolvedAt': '2026-08-09T02:00:00Z',
    'closedAt': '2026-08-09T02:10:00Z',
  },
});
