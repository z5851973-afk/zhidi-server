import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/services/auth_api_client.dart';

void main() {
  test(
    'construction state is unchanged when worker lacks server identity',
    () async {
      final state = await OwnerAppState.memory(store: MemoryOwnerStore());
      final before = state.toJson();

      await expectLater(
        state.bookWorker(_localOnlyWorker()),
        throwsA(
          isA<AuthApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            409,
          ),
        ),
      );

      expect(state.toJson(), before);
    },
  );
}

BookedWorker _localOnlyWorker() => const BookedWorker(
  id: 'worker-1',
  name: '李师傅',
  trade: '拆除工',
  phaseName: '阳台改造',
  phaseIndex: 42,
  rating: 0,
  completedOrders: 0,
  years: 8,
  avatarEmoji: '李',
  skills: ['拆墙'],
);
