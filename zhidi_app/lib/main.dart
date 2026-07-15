import 'package:flutter/material.dart';

import 'app/owner_app_scope.dart';
import 'app/owner_app_state.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/onboarding_page.dart';
import 'pages/home/home_page.dart';
import 'services/auth_api_client.dart';
import 'services/auth_session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sessionStore = SecureAuthSessionStore();
  OwnerAppState ownerState;
  try {
    ownerState = await OwnerAppState.load(sessionStore: sessionStore);
  } catch (_) {
    ownerState = await OwnerAppState.memory(sessionStore: sessionStore);
  }

  runApp(ZhidiApp(ownerState: ownerState, authApi: AuthApiClient()));
}

class ZhidiApp extends StatefulWidget {
  const ZhidiApp({super.key, required this.ownerState, this.authApi});

  final OwnerAppState ownerState;
  final OwnerAuthApi? authApi;

  @override
  State<ZhidiApp> createState() => _ZhidiAppState();
}

enum _OwnerRoute { login, onboarding, home }

class _ZhidiAppState extends State<ZhidiApp> {
  late _OwnerRoute _route;

  @override
  void initState() {
    super.initState();
    _route = _routeForState(widget.ownerState);
    widget.ownerState.addListener(_onOwnerStateChanged);
  }

  @override
  void didUpdateWidget(covariant ZhidiApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerState != widget.ownerState) {
      oldWidget.ownerState.removeListener(_onOwnerStateChanged);
      widget.ownerState.addListener(_onOwnerStateChanged);
      _syncRoute();
    }
  }

  @override
  void dispose() {
    widget.ownerState.removeListener(_onOwnerStateChanged);
    super.dispose();
  }

  void _onOwnerStateChanged() {
    if (!mounted) return;
    _syncRoute();
  }

  void _syncRoute() {
    final nextRoute = _routeForState(widget.ownerState);
    if (nextRoute != _route) {
      setState(() => _route = nextRoute);
    }
  }

  _OwnerRoute _routeForState(OwnerAppState state) {
    if (!state.isLoggedIn) return _OwnerRoute.home;
    if (!state.profile.isProfileComplete) return _OwnerRoute.onboarding;
    return _OwnerRoute.home;
  }

  void _onLoginDone() {
    if (!mounted) return;
    _syncRoute();
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
        debugShowCheckedModeBanner: false,
        home: _buildRoute(),
      ),
    );
  }

  Widget _buildRoute() {
    switch (_route) {
      case _OwnerRoute.login:
        return LoginPage(api: widget.authApi, onLoginDone: _onLoginDone);
      case _OwnerRoute.onboarding:
        return OnboardingPage(onDone: _onOnboardingDone);
      case _OwnerRoute.home:
        return const HomePage();
    }
  }
}
