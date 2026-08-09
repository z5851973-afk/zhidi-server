import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/profile/address_page.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/owner_address_api_client.dart';
import 'package:zhidi_app/services/owner_booking_api_client.dart';
import 'package:zhidi_app/services/owner_profile_api_client.dart';

void main() {
  testWidgets('lists server addresses with province masked phone and default', (
    tester,
  ) async {
    final api = FakeAddressApi([
      remoteAddress(id: 'address-1', isDefault: true),
    ]);
    final state = await buildState(api);

    await pumpAddressPage(tester, state);

    expect(find.text('林先生'), findsOneWidget);
    expect(find.text('138****8201'), findsOneWidget);
    expect(find.textContaining('四川省成都市武侯区'), findsOneWidget);
    expect(find.text('默认地址'), findsOneWidget);
    expect(api.listCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('adds a complete address and uses only the server response', (
    tester,
  ) async {
    final api = FakeAddressApi([])
      ..createResult = remoteAddress(id: 'server-created', isDefault: true);
    final state = await buildState(api);
    await pumpAddressPage(tester, state);

    await tester.tap(find.text('新增地址'));
    await tester.pumpAndSettle();
    await fillAddressForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, '保存地址'));
    await tester.pumpAndSettle();

    expect(api.creates, hasLength(1));
    expect(api.creates.single.province, '四川省');
    expect(state.addresses.single.id, 'server-created');
    expect(find.text('138****8201'), findsOneWidget);
  });

  testWidgets('failed save keeps every field and shows a Chinese retry error', (
    tester,
  ) async {
    final api = FakeAddressApi([])
      ..createError = const AuthApiException(
        code: 'NETWORK_UNAVAILABLE',
        message: '无法连接服务器',
      );
    final state = await buildState(api);
    await pumpAddressPage(tester, state);

    await tester.tap(find.text('新增地址'));
    await tester.pumpAndSettle();
    await fillAddressForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, '保存地址'));
    await tester.pumpAndSettle();

    expect(find.byType(AddressFormPage), findsOneWidget);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(find.text('四川省'), findsOneWidget);
    expect(find.text('科华路 1 号'), findsOneWidget);
  });

  testWidgets('selects province city district from searchable pickers', (
    tester,
  ) async {
    final state = await buildState(FakeAddressApi([]));
    await pumpAddressPage(tester, state);

    await tester.tap(find.text('新增地址'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('address-province')));
    await tester.pumpAndSettle();
    expect(find.text('四川省'), findsOneWidget);
    expect(find.text('甘肃省'), findsOneWidget);
    await tester.tap(find.text('四川省'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('address-city')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('region-search')), '成都');
    await tester.pump();
    expect(find.text('成都市'), findsOneWidget);
    await tester.tap(find.text('成都市'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('address-district')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('region-search')), '武侯');
    await tester.pump();
    expect(find.text('武侯区'), findsOneWidget);
    await tester.tap(find.text('武侯区'));
    await tester.pumpAndSettle();

    expect(find.text('四川省'), findsOneWidget);
    expect(find.text('成都市'), findsOneWidget);
    expect(find.text('武侯区'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('changing province clears the selected city and district', (
    tester,
  ) async {
    final state = await buildState(FakeAddressApi([]));
    await pumpAddressPage(tester, state);
    await tester.tap(find.text('新增地址'));
    await tester.pumpAndSettle();
    await selectRegions(tester, province: '四川省', city: '成都市', district: '武侯区');

    await tester.tap(find.byKey(const Key('address-province')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('甘肃省'));
    await tester.pumpAndSettle();

    expect(find.text('甘肃省'), findsOneWidget);
    expect(find.text('请选择城市'), findsOneWidget);
    expect(find.text('请选择区县'), findsOneWidget);
    expect(find.text('成都市'), findsNothing);
    expect(find.text('武侯区'), findsNothing);
  });

  testWidgets('shows but blocks an out-of-scope legacy address', (
    tester,
  ) async {
    final api = FakeAddressApi([
      remoteAddress(
        id: 'legacy',
        isDefault: true,
        province: '广东省',
        city: '深圳市',
        district: '南山区',
      ),
    ]);
    final state = await buildState(api);
    await pumpAddressPage(tester, state);

    await tester.tap(find.byKey(const Key('edit-legacy')));
    await tester.pumpAndSettle();
    expect(find.text('广东省'), findsOneWidget);
    expect(find.text('当前地区暂未开放'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, '保存地址'));
    await tester.pump();

    expect(api.updates, isEmpty);
    expect(find.text('请选择已开放且匹配的省市区'), findsOneWidget);
  });

  testWidgets('sets default and requires confirmation before deleting', (
    tester,
  ) async {
    final api = FakeAddressApi([
      remoteAddress(id: 'address-1', isDefault: true),
      remoteAddress(id: 'address-2', isDefault: false, recipient: '王女士'),
    ]);
    final state = await buildState(api);
    await pumpAddressPage(tester, state);

    await tester.tap(find.byKey(const Key('default-address-2')));
    await tester.pumpAndSettle();
    expect(
      state.addresses.singleWhere((item) => item.id == 'address-2').isDefault,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('delete-address-1')));
    await tester.pumpAndSettle();
    expect(find.text('确认删除这个地址？'), findsOneWidget);
    expect(api.deletes, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(api.deletes, ['address-1']);
  });
}

Future<OwnerAppState> buildState(FakeAddressApi api) => OwnerAppState.memory(
  sessionStore: MemoryAuthSessionStore(validSession()),
  profileApi: const FakeProfileApi(),
  addressApi: api,
  bookingApi: const EmptyBookingApi(),
);

Future<void> pumpAddressPage(WidgetTester tester, OwnerAppState state) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    OwnerAppScope(
      state: state,
      child: const MaterialApp(home: AddressPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> fillAddressForm(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('address-recipient')), '林先生');
  await tester.enterText(find.byKey(const Key('address-phone')), '13800138201');
  await selectRegions(tester, province: '四川省', city: '成都市', district: '武侯区');
  await tester.enterText(find.byKey(const Key('address-detail')), '科华路 1 号');
  await tester.pump();
}

Future<void> selectRegions(
  WidgetTester tester, {
  required String province,
  required String city,
  required String district,
}) async {
  await tester.tap(find.byKey(const Key('address-province')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(province));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('address-city')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(city));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('address-district')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(district));
  await tester.pumpAndSettle();
}

final class FakeAddressApi implements OwnerAddressApi {
  FakeAddressApi(List<RemoteOwnerAddress> values) : values = [...values];

  List<RemoteOwnerAddress> values;
  RemoteOwnerAddress? createResult;
  Object? createError;
  var listCalls = 0;
  final List<OwnerAddressDraft> creates = [];
  final List<OwnerAddressDraft> updates = [];
  final List<String> deletes = [];

  @override
  Future<List<RemoteOwnerAddress>> list(String accessToken) async {
    listCalls += 1;
    return List.unmodifiable(values);
  }

  @override
  Future<RemoteOwnerAddress> create(
    String accessToken,
    OwnerAddressDraft draft,
  ) async {
    creates.add(draft);
    if (createError case final error?) throw error;
    final created = createResult!;
    values = [...values, created];
    return created;
  }

  @override
  Future<RemoteOwnerAddress> update(
    String accessToken,
    String addressId,
    OwnerAddressDraft draft,
  ) async {
    updates.add(draft);
    final current = values.singleWhere((item) => item.id == addressId);
    final updated = RemoteOwnerAddress(
      id: addressId,
      recipient: draft.recipient,
      phone: draft.phone,
      province: draft.province,
      city: draft.city,
      district: draft.district,
      detail: draft.detail,
      isDefault: draft.isDefault,
      createdAt: current.createdAt,
      updatedAt: DateTime.utc(2026, 8, 2, 10),
    );
    values = [
      for (final item in values)
        if (item.id == addressId) updated else item,
    ];
    return updated;
  }

  @override
  Future<RemoteOwnerAddress> setDefault(
    String accessToken,
    String addressId,
  ) async {
    values = [
      for (final item in values)
        RemoteOwnerAddress(
          id: item.id,
          recipient: item.recipient,
          phone: item.phone,
          province: item.province,
          city: item.city,
          district: item.district,
          detail: item.detail,
          isDefault: item.id == addressId,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
        ),
    ];
    return values.singleWhere((item) => item.id == addressId);
  }

  @override
  Future<void> delete(String accessToken, String addressId) async {
    deletes.add(addressId);
    values = values.where((item) => item.id != addressId).toList();
    if (values.isNotEmpty && !values.any((item) => item.isDefault)) {
      final first = values.first;
      values[0] = RemoteOwnerAddress(
        id: first.id,
        recipient: first.recipient,
        phone: first.phone,
        province: first.province,
        city: first.city,
        district: first.district,
        detail: first.detail,
        isDefault: true,
        createdAt: first.createdAt,
        updatedAt: first.updatedAt,
      );
    }
  }
}

final class FakeProfileApi implements OwnerProfileApi {
  const FakeProfileApi();

  @override
  Future<RemoteOwnerProfile> getCurrent(String accessToken) async =>
      const RemoteOwnerProfile(
        userId: 'owner-1',
        phone: '13800138201',
        name: '林先生',
        city: '成都',
        avatarUrl: null,
        gender: null,
        decorationType: null,
        address: null,
        area: null,
        profileComplete: true,
      );

  @override
  Future<RemoteOwnerProfile> updateCurrent(
    String accessToken,
    OwnerProfileUpdate request,
  ) => throw UnsupportedError('not used');
}

final class EmptyBookingApi implements OwnerBookingApi {
  const EmptyBookingApi();

  @override
  Future<List<RemoteOwnerBooking>> listOwnerBookings(
    String accessToken,
  ) async => const [];

  @override
  Future<RemoteOwnerBooking> createBooking(
    String accessToken,
    OwnerBookingCreateRequest request,
  ) => throw UnsupportedError('not used');

  @override
  Future<RemoteOwnerBooking> cancelBooking(
    String accessToken,
    String bookingId,
    String reason,
  ) => throw UnsupportedError('not used');
}

AuthSession validSession() => AuthSession(
  accessToken: 'token',
  tokenType: 'Bearer',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  userId: 'owner-1',
  phone: '13800138201',
  roles: const ['OWNER'],
);

RemoteOwnerAddress remoteAddress({
  required String id,
  required bool isDefault,
  String recipient = '林先生',
  String province = '四川省',
  String city = '成都市',
  String district = '武侯区',
}) => RemoteOwnerAddress(
  id: id,
  recipient: recipient,
  phone: '13800138201',
  province: province,
  city: city,
  district: district,
  detail: '科华路 1 号',
  isDefault: isDefault,
  createdAt: DateTime.utc(2026, 8, 2, 8),
  updatedAt: DateTime.utc(2026, 8, 2, 9),
);
