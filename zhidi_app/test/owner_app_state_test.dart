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

  test('state JSON round-trips all model collections', () {
    final original = OwnerAppState.memory();

    final restored = OwnerAppState.fromJson(original.toJson());

    expect(restored.toJson(), original.toJson());
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
}

class _FailingOwnerStore implements OwnerKeyValueStore {
  @override
  String? getString(String key) => null;

  @override
  Future<void> setString(String key, String value) async {
    throw StateError('write failed');
  }
}
