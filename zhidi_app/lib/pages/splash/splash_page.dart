import 'dart:async';

import 'package:flutter/material.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key, this.onStart});

  final VoidCallback? onStart;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _opacityController;
  Timer? _timer;
  bool _didStart = false;

  @override
  void initState() {
    super.initState();
    _opacityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1,
    );
    _timer = Timer(const Duration(seconds: 2), _fadeAndStart);
  }

  Future<void> _fadeAndStart() async {
    if (!mounted || _didStart) return;
    await _opacityController.reverse();
    if (!mounted || _didStart) return;
    _didStart = true;
    widget.onStart?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _opacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _opacityController,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/splash_bg.png', fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x44FFF9F1),
                    Color(0x66FFF8ED),
                    Color(0x88FFF4E8),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 4),
                    Image.asset(
                      'assets/logo.png',
                      width: 112,
                      height: 112,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '知底',
                      style: TextStyle(
                        color: Color(0xFF272727),
                        fontSize: 48,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 36),
                    const _BrandSlogan(),
                    const SizedBox(height: 16),
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '工人透明  |  工价透明  |  工艺透明  |  平台保障',
                        maxLines: 1,
                        style: TextStyle(
                          color: Color(0xFF6C6865),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const Spacer(flex: 5),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandSlogan extends StatelessWidget {
  const _BrandSlogan();

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      color: Color(0xFF292929),
      fontSize: 19,
      height: 1.25,
      fontWeight: FontWeight.w800,
    );
    const accentStyle = TextStyle(
      color: Color(0xFFFF7A2F),
      fontSize: 19,
      height: 1.25,
      fontWeight: FontWeight.w900,
    );
    return const FittedBox(
      fit: BoxFit.scaleDown,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '装修找', style: baseStyle),
            TextSpan(text: '知底', style: accentStyle),
            TextSpan(text: '，心里就有', style: baseStyle),
            TextSpan(text: '底', style: accentStyle),
          ],
        ),
        maxLines: 1,
        textAlign: TextAlign.center,
      ),
    );
  }
}
