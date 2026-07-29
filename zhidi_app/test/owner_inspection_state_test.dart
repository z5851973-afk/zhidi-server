import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/services/auth_api_client.dart';

void main() {
  test(
    'local-only worker cannot create a fake booking or inspection',
    () async {
      final state = await OwnerAppState.memory(store: MemoryOwnerStore());

      await expectLater(
        state.bookWorker(_localOnlyWorker()),
        throwsA(
          isA<AuthApiException>().having(
            (error) => error.code,
            'code',
            'SERVER_WORKER_REQUIRED',
          ),
        ),
      );

      expect(state.bookedWorkers, isEmpty);
      expect(state.inspections, isEmpty);
      expect(state.completedPhases, isEmpty);
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
  skills: ['拆墙', '垃圾清运'],
);
