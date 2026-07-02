import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_state.dart';

void main() {
  test(
    'memory store preserves profile changes across state instances',
    () async {
      final store = MemoryOwnerStore();
      final first = OwnerAppState.memory(store: store);

      await first.updateProfileName('李女士');
      final second = OwnerAppState.memory(store: store);

      expect(second.profileName, '李女士');
    },
  );

  test('failed persistence does not mutate or notify state', () async {
    final state = OwnerAppState.memory(store: _FailingOwnerStore());
    var notifications = 0;
    state.addListener(() => notifications++);

    await expectLater(
      state.updateProfileName('李女士'),
      throwsA(isA<StateError>()),
    );

    expect(state.profileName, '王先生');
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
