import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/worker_app_state.dart';
import 'package:zhidi_app/main.dart';
import 'package:zhidi_app/services/auth_api_client.dart';

void main() {
  testWidgets('incomplete online worker must complete profile before home', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    await state.loginOnline(
      _loginResponse,
      remoteProfile: const RemoteWorkerProfile(
        phone: '13800138102',
        serviceCity: '成都',
        profileComplete: false,
      ),
    );

    await tester.pumpWidget(
      WorkerApp(
        workerState: state,
        workerProfileApi: _ProfileApi(),
        workerHome: const Scaffold(body: Text('工匠工作台')),
      ),
    );
    await tester.pump();

    expect(find.text('完善工人资料'), findsOneWidget);
    expect(find.text('工匠工作台'), findsNothing);
  });

  testWidgets('successful profile save opens worker home', (tester) async {
    final state = await WorkerAppState.memory();
    final api = _ProfileApi();
    await state.loginOnline(
      _loginResponse,
      remoteProfile: const RemoteWorkerProfile(
        phone: '13800138102',
        serviceCity: '成都',
        profileComplete: false,
      ),
    );
    await tester.pumpWidget(
      WorkerApp(
        workerState: state,
        workerProfileApi: api,
        workerHome: const Scaffold(body: Text('工匠工作台')),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byKey(const Key('worker-profile-name')), '张师傅');
    await tester.enterText(find.byKey(const Key('worker-profile-city')), '成都');
    await tester.tap(find.byKey(const Key('worker-profile-trade')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('水电工').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('worker-profile-years')), '8');
    await tester.enterText(
      find.byKey(const Key('worker-profile-daily-rate')),
      '500',
    );
    await tester.enterText(
      find.byKey(const Key('worker-profile-bio')),
      '擅长旧房水电改造',
    );
    await tester.ensureVisible(find.byKey(const Key('worker-profile-save')));
    await tester.tap(find.byKey(const Key('worker-profile-save')));
    await tester.pumpAndSettle();

    expect(api.updatedBody?['name'], '张师傅');
    expect(state.profile.isProfileComplete, isTrue);
    expect(find.text('完善工人资料'), findsNothing);
    expect(find.text('工匠工作台'), findsOneWidget);
  });
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

final class _ProfileApi implements OwnerAuthApi {
  Map<String, dynamic>? updatedBody;

  @override
  Future<void> updateWorkerProfile(
    String token,
    Map<String, dynamic> body,
  ) async {
    updatedBody = Map<String, dynamic>.from(body);
  }

  @override
  Future<RemoteWorkerProfile> getWorkerProfile(String token) async =>
      const RemoteWorkerProfile(
        phone: '13800138102',
        name: '张师傅',
        serviceCity: '成都',
        primaryTrade: 'plumbing',
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
