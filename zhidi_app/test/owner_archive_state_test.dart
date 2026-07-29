import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/services/auth_api_client.dart';

void main() {
  test(
    'failed server booking never creates a local renovation archive',
    () async {
      final state = await OwnerAppState.memory(store: MemoryOwnerStore());

      await expectLater(
        state.bookWorker(_localOnlyWorker()),
        throwsA(isA<AuthApiException>()),
      );

      expect(state.bookedWorkers, isEmpty);
      expect(state.inspections, isEmpty);
      expect(state.archives, isEmpty);
    },
  );
}

BookedWorker _localOnlyWorker() => const BookedWorker(
  id: 'worker-1',
  name: '李师傅',
  trade: '拆除工',
  phaseName: '拆除',
  phaseIndex: 0,
  rating: 0,
  completedOrders: 0,
  years: 8,
  avatarEmoji: '李',
  skills: ['拆墙'],
);
