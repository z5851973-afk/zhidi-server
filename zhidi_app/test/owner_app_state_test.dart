import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_state.dart';

void main() {
  test('seeds a Chengdu owner profile and 2026 demo data', () {
    final state = OwnerAppState.memory();

    expect(state.profile.name, '王先生');
    expect(state.profile.city, '成都');
    expect(state.projects, isNotEmpty);
    expect(state.projects.first.city, '成都');
    expect(state.projects.first.startDate.year, 2026);
    expect(state.messages, isNotEmpty);
  });

  test('adds, edits, and deletes an address', () async {
    final state = OwnerAppState.memory();
    const address = OwnerAddress(
      id: 'address-2',
      recipient: '王先生',
      phone: '13800000000',
      city: '成都',
      district: '武侯区',
      detail: '天府三街 88 号',
    );

    await state.addAddress(address);
    await state.updateAddress(address.copyWith(detail: '天府三街 99 号'));
    expect(
      state.addresses.singleWhere((item) => item.id == address.id).detail,
      '天府三街 99 号',
    );

    await state.deleteAddress(address.id);
    expect(state.addresses.where((item) => item.id == address.id), isEmpty);
  });

  test('first address added to an empty list becomes default', () async {
    final state = OwnerAppState.memory();
    await state.deleteAddress(state.addresses.single.id);

    await state.addAddress(
      const OwnerAddress(
        id: 'first-address',
        recipient: '李女士',
        phone: '13900000000',
        city: '成都',
        district: '锦江区',
        detail: '春熙路 1 号',
      ),
    );

    expect(state.addresses.single.isDefault, isTrue);
  });

  test('unsetting the current default preserves exactly one default', () async {
    final state = OwnerAppState.memory();
    final current = state.addresses.single;

    await state.updateAddress(current.copyWith(isDefault: false));

    expect(state.addresses.where((item) => item.isDefault), hasLength(1));
    expect(state.addresses.single.isDefault, isTrue);
  });

  test('marks one message and then all messages read', () async {
    final state = OwnerAppState.memory();
    final unread = state.messages.where((message) => !message.isRead).toList();
    expect(unread.length, greaterThan(1));

    await state.markMessageRead(unread.first.id);
    expect(
      state.messages.singleWhere((m) => m.id == unread.first.id).isRead,
      isTrue,
    );

    await state.markAllMessagesRead();
    expect(state.messages.every((message) => message.isRead), isTrue);
  });

  test('toggles a favorite worker', () async {
    final state = OwnerAppState.memory();
    const worker = FavoriteWorker(
      id: 'worker-9',
      name: '陈师傅',
      trade: '木工',
      city: '成都',
    );

    await state.toggleFavorite(worker);
    expect(state.isFavorite(worker.id), isTrue);
    await state.toggleFavorite(worker);
    expect(state.isFavorite(worker.id), isFalse);
  });

  test('completes a reminder', () async {
    final state = OwnerAppState.memory();
    final reminder = state.reminders.firstWhere((item) => !item.isCompleted);

    await state.completeReminder(reminder.id);

    expect(
      state.reminders.singleWhere((item) => item.id == reminder.id).isCompleted,
      isTrue,
    );
  });

  test('submits feedback and updates settings', () async {
    final state = OwnerAppState.memory();
    final feedback = FeedbackEntry(
      id: 'feedback-1',
      category: '产品建议',
      description: '希望增加工期日历',
      createdAt: DateTime(2026, 7, 2),
    );

    await state.submitFeedback(feedback);
    await state.updateSettings(
      state.settings.copyWith(pushNotifications: false, darkMode: true),
    );

    expect(
      state.feedbackEntries.any((entry) => entry.id == feedback.id),
      isTrue,
    );
    expect(state.settings.pushNotifications, isFalse);
    expect(state.settings.darkMode, isTrue);
  });

  test('state JSON round-trips non-empty optional collections', () async {
    final original = OwnerAppState.memory();
    await original.toggleFavorite(
      const FavoriteWorker(
        id: 'round-worker',
        name: '周师傅',
        trade: '油漆工',
        city: '成都',
      ),
    );
    await original.submitAfterSales(
      AfterSalesRequest(
        id: 'round-after-sales',
        issueType: '施工质量',
        description: '墙面需要复检',
        createdAt: DateTime(2026, 7, 2),
      ),
    );
    await original.submitFeedback(
      FeedbackEntry(
        id: 'round-feedback',
        category: '产品建议',
        description: '增加验收清单',
        createdAt: DateTime(2026, 7, 2),
      ),
    );

    final restored = OwnerAppState.fromJson(original.toJson());

    expect(restored.toJson(), original.toJson());
    expect(restored.favoriteWorkers, hasLength(1));
    expect(restored.afterSalesRequests, hasLength(1));
    expect(restored.feedbackEntries, hasLength(1));
  });

  test('reminder copyWith can explicitly clear projectId', () {
    final reminder = OwnerAppState.memory().reminders.first;

    final cleared = reminder.copyWith(projectId: null);

    expect(cleared.projectId, isNull);
  });

  test(
    'submitAfterSales notifies once on success and not on duplicate',
    () async {
      final state = OwnerAppState.memory();
      var notifications = 0;
      state.addListener(() => notifications++);
      final request = AfterSalesRequest(
        id: 'after-sales-1',
        issueType: '材料问题',
        description: '瓷砖批次色差',
        createdAt: DateTime(2026, 7, 2),
      );

      await state.submitAfterSales(request);
      await state.submitAfterSales(request);

      expect(state.afterSalesRequests, hasLength(1));
      expect(notifications, 1);
    },
  );

  test('concurrent mutations serialize and preserve both changes', () async {
    final store = _ControlledOwnerStore();
    final state = OwnerAppState.memory(store: store);
    const address = OwnerAddress(
      id: 'concurrent-address',
      recipient: '李女士',
      phone: '13900000000',
      city: '成都',
      district: '青羊区',
      detail: '宽窄巷子 8 号',
    );

    final profileUpdate = state.updateProfile(
      state.profile.copyWith(name: '李女士'),
    );
    await store.firstWriteStarted;
    final addressUpdate = state.addAddress(address);
    await Future<void>.delayed(Duration.zero);

    expect(store.writeCount, 1);
    store.releaseFirstWrite();
    await Future.wait([profileUpdate, addressUpdate]);

    expect(state.profile.name, '李女士');
    expect(state.addresses.any((item) => item.id == address.id), isTrue);
    final restored = OwnerAppState.memory(store: store);
    expect(restored.toJson(), state.toJson());
  });

  test('one JSON document preserves mutations across instances', () async {
    final store = MemoryOwnerStore();
    final first = OwnerAppState.memory(store: store);
    await first.updateProfile(first.profile.copyWith(name: '李女士'));
    await first.addAddress(
      const OwnerAddress(
        id: 'persisted',
        recipient: '李女士',
        phone: '13900000000',
        city: '成都',
        district: '锦江区',
        detail: '春熙路 1 号',
      ),
    );

    final second = OwnerAppState.memory(store: store);

    expect(second.profile.name, '李女士');
    expect(
      second.addresses.any((address) => address.id == 'persisted'),
      isTrue,
    );
    expect(store.getString(OwnerAppState.documentKey), isNotNull);
    expect(store.getString('owner.profileName'), isNull);
  });

  test('failed persistence does not mutate or notify state', () async {
    final state = OwnerAppState.memory(store: _FailingOwnerStore());
    var notifications = 0;
    state.addListener(() => notifications++);

    await expectLater(
      state.updateProfile(state.profile.copyWith(name: '李女士')),
      throwsA(isA<StateError>()),
    );

    expect(state.profile.name, '王先生');
    expect(notifications, 0);
  });

  test(
    'reset settings persists defaults without changing owner data',
    () async {
      final store = MemoryOwnerStore();
      final state = OwnerAppState.memory(store: store);
      final originalProfile = state.profile.toJson();
      final originalAddresses = state.addresses.map((e) => e.toJson()).toList();
      await state.updateSettings(
        state.settings.copyWith(pushNotifications: false, hidePhone: false),
      );

      await state.resetSettings();

      expect(state.settings.toJson(), const OwnerSettings().toJson());
      expect(state.profile.toJson(), originalProfile);
      expect(
        state.addresses.map((e) => e.toJson()).toList(),
        originalAddresses,
      );
      expect(
        OwnerAppState.memory(store: store).settings.toJson(),
        const OwnerSettings().toJson(),
      );
    },
  );
}

class _FailingOwnerStore implements OwnerKeyValueStore {
  @override
  String? getString(String key) => null;

  @override
  Future<void> setString(String key, String value) async {
    throw StateError('write failed');
  }
}

class _ControlledOwnerStore implements OwnerKeyValueStore {
  final Map<String, String> _values = {};
  final Completer<void> _firstWriteStarted = Completer<void>();
  final Completer<void> _releaseFirstWrite = Completer<void>();
  var writeCount = 0;

  Future<void> get firstWriteStarted => _firstWriteStarted.future;

  void releaseFirstWrite() => _releaseFirstWrite.complete();

  @override
  String? getString(String key) => _values[key];

  @override
  Future<void> setString(String key, String value) async {
    writeCount++;
    if (writeCount == 1) {
      _firstWriteStarted.complete();
      await _releaseFirstWrite.future;
    }
    _values[key] = value;
  }
}
