import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/owner_app_scope.dart';
import 'app/owner_app_state.dart';
import 'app/worker_app_scope.dart';
import 'app/worker_app_state.dart';
import 'design/theme.dart';
import 'pages/home/home_page.dart';
import 'pages/splash/splash_page.dart';
import 'pages/worker/worker_login_page.dart';
import 'pages/worker/worker_home_page.dart';
import 'pages/worker/worker_profile_page.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/onboarding_page.dart';
import 'services/auth_api_client.dart';
import 'services/auth_session_store.dart';
import 'services/daily_report_api_client.dart';
import 'services/worker_booking_api_client.dart';

/// 通用入口：根据 --flavor 分流到业主端 / 工人端
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // release 下 Flutter 异常显示为红色错误屏，不再静默灰屏
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Container(
      color: const Color(0xFFFF0000),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Text(
            'ERROR: ${details.exception}\n\n${details.stack}',
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  };
  ZdTheme.setSystemUIOverlay();
  await initializeFirebaseForStartup(Firebase.initializeApp);

  final flavor = const String.fromEnvironment(
    'ZHIDI_APP_FLAVOR',
    defaultValue: 'worker',
  ).toLowerCase();

  if (flavor == 'owner') {
    await _runOwner();
  } else {
    await _runWorker();
  }
}

Future<void> initializeFirebaseForStartup(
  Future<void> Function() initialize, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  try {
    await initialize().timeout(timeout);
  } on TimeoutException {
    // Firebase/GMS 在模拟器或弱网环境可能长时间无响应；当前主闭环走 ECS REST API，
    // 所以启动阶段超时后继续进入 App，避免卡在 Android 系统 splash。
  } catch (_) {
    // Firebase 配置不可用时继续使用本地 mock 数据，避免阻塞 App 启动。
  }
}

Future<void> _runOwner() async {
  final sessionStore = SecureAuthSessionStore();
  OwnerAppState ownerState;
  try {
    ownerState = await OwnerAppState.load(sessionStore: sessionStore);
  } catch (_) {
    ownerState = await OwnerAppState.memory(sessionStore: sessionStore);
  }
  runApp(ZhidiApp(ownerState: ownerState, authApi: AuthApiClient()));
}

Future<void> _runWorker() async {
  final sessionStore = SecureAuthSessionStore.worker();
  WorkerAppState workerState;
  try {
    workerState = await WorkerAppState.load(sessionStore: sessionStore);
  } catch (_) {
    workerState = await WorkerAppState.memory(sessionStore: sessionStore);
  }

  // 支持通过 dart-define 注入预颁发 Token，跳过登录页直接进首页
  const token = String.fromEnvironment('WORKER_ACCESS_TOKEN', defaultValue: '');
  if (token.isNotEmpty) {
    workerState.loginWithToken(token);
    workerState.initBookingApi(
      api: WorkerBookingApiClient(),
      accessToken: token,
    );
    workerState.initReportApi(api: DailyReportApiClient(), accessToken: token);
  } else if (await workerState.restoreOnlineSession()) {
    workerState.initBookingApi(
      api: WorkerBookingApiClient(),
      accessToken: workerState.accessToken!,
    );
    workerState.initReportApi(
      api: DailyReportApiClient(),
      accessToken: workerState.accessToken!,
    );
  }

  runApp(WorkerApp(workerState: workerState));
}

class ZhidiApp extends StatefulWidget {
  const ZhidiApp({super.key, required this.ownerState, this.authApi});
  final OwnerAppState ownerState;
  final OwnerAuthApi? authApi;

  @override
  State<ZhidiApp> createState() => _ZhidiAppState();
}

enum _OwnerRoute { splash, login, onboarding, home }

class _ZhidiAppState extends State<ZhidiApp> {
  _OwnerRoute _route = _OwnerRoute.splash;

  @override
  void initState() {
    super.initState();
    widget.ownerState.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(covariant ZhidiApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerState != widget.ownerState) {
      oldWidget.ownerState.removeListener(_onStateChanged);
      widget.ownerState.addListener(_onStateChanged);
      _syncRoute();
    }
  }

  @override
  void dispose() {
    widget.ownerState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    _syncRoute();
  }

  void _syncRoute() {
    final state = widget.ownerState;
    if (!state.isLoggedIn) {
      if (_route == _OwnerRoute.login || _route == _OwnerRoute.onboarding) {
        setState(() => _route = _OwnerRoute.home);
      }
    } else if (!state.profile.isProfileComplete) {
      if (_route == _OwnerRoute.home) {
        setState(() => _route = _OwnerRoute.onboarding);
      }
    } else {
      if (_route != _OwnerRoute.home) {
        setState(() => _route = _OwnerRoute.home);
      }
    }
  }

  void _onSplashDone() {
    if (!mounted) return;
    final state = widget.ownerState;
    if (!state.isLoggedIn) {
      setState(() => _route = _OwnerRoute.home);
    } else if (!state.profile.isProfileComplete) {
      setState(() => _route = _OwnerRoute.onboarding);
    } else {
      setState(() => _route = _OwnerRoute.home);
    }
  }

  void _onLoginDone() {
    if (!mounted) return;
    final state = widget.ownerState;
    if (!state.profile.isProfileComplete) {
      setState(() => _route = _OwnerRoute.onboarding);
    } else {
      setState(() => _route = _OwnerRoute.home);
    }
  }

  void _onOnboardingDone() {
    if (!mounted) return;
    setState(() => _route = _OwnerRoute.home);
  }

  @override
  Widget build(BuildContext context) {
    return OwnerAppScope(
      state: widget.ownerState,
      child: MaterialApp(
        title: '知底',
        theme: ZdTheme.light,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh')],
        home: _buildRoute(),
      ),
    );
  }

  Widget _buildRoute() {
    switch (_route) {
      case _OwnerRoute.splash:
        return SplashPage(onStart: _onSplashDone);
      case _OwnerRoute.login:
        return LoginPage(api: widget.authApi, onLoginDone: _onLoginDone);
      case _OwnerRoute.onboarding:
        return OnboardingPage(onDone: _onOnboardingDone);
      case _OwnerRoute.home:
        return const HomePage();
    }
  }
}

class WorkerApp extends StatelessWidget {
  const WorkerApp({
    super.key,
    required this.workerState,
    this.workerProfileApi,
    this.workerHome,
  });
  final WorkerAppState workerState;
  final OwnerAuthApi? workerProfileApi;
  final Widget? workerHome;

  @override
  Widget build(BuildContext context) {
    return WorkerAppScope(
      state: workerState,
      child: AnimatedBuilder(
        animation: workerState,
        builder: (context, _) {
          return MaterialApp(
            title: '知底工匠',
            theme: ZdTheme.light,
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('zh')],
            home: !workerState.isLoggedIn
                ? const WorkerLoginPage()
                : workerState.profile.isProfileComplete
                ? (workerHome ?? const WorkerHomePage())
                : WorkerProfilePage(onboarding: true, api: workerProfileApi),
          );
        },
      ),
    );
  }
}
