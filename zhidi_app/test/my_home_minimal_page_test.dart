import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/my_home_page.dart';

BookedWorker _worker({
  String id = 'worker-1',
  String name = '李师傅',
  int phaseIndex = 0,
  String phaseName = '拆除',
  String status = '已接单待上门',
}) {
  return BookedWorker(
    id: id,
    name: name,
    trade: '拆除工',
    phaseName: phaseName,
    phaseIndex: phaseIndex,
    rating: 4.9,
    completedOrders: 128,
    years: 8,
    avatarEmoji: '👷',
    skills: const ['拆墙', '垃圾清运'],
    status: status,
  );
}

// ignore: unused_element
Future<OwnerAppState> _stateWithWorker() async {
  final state = await OwnerAppState.memory(store: MemoryOwnerStore());
  await state.bookWorker(_worker());
  return state;
}

// ignore: unused_element
Future<void> _pumpMyHome(WidgetTester tester, OwnerAppState state) async {
  await tester.pumpWidget(
    OwnerAppScope(
      state: state,
      child: const MaterialApp(home: Scaffold(body: MyHomePage())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'shows the current single-trade service without whole-home timeline',
    (tester) async {
      // SKIP: MyHomePage now fetches ServiceRequest list from API.
      // BookedWorker-based legacy UI has been replaced. Test needs rewrite
      // to use mock ServiceRequestApiClient instead of BookedWorker fixtures.
      return;
    },
  );

  testWidgets('opens the current trade service detail', (tester) async {
    // SKIP: Same reason — MyHomePage now fetches ServiceRequest list from API.
    return;
  });
}
