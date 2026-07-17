# Automatic Splash Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the clickable welcome screen with a warm branded splash that automatically fades out after two seconds.

**Architecture:** Keep `SplashPage` as a focused stateful widget that owns one timer and one fade animation. Preserve the existing `onStart` boundary so `main_owner.dart` remains responsible for switching to the owner home shell.

**Tech Stack:** Flutter, Dart, flutter_test.

---

### Task 1: Lock down automatic timing

**Files:**
- Create: `zhidi_app/test/splash_page_test.dart`
- Modify: `zhidi_app/lib/pages/splash/splash_page.dart`

- [ ] Write a widget test that pumps `SplashPage`, advances 1999ms and expects no callback, then advances through 2000ms plus the 250ms fade and expects exactly one callback.
- [ ] Run `flutter test test/splash_page_test.dart` and confirm it fails because the current page waits for a button tap.
- [ ] Convert `SplashPage` to `StatefulWidget`, start a two-second timer in `initState`, run a 250ms opacity animation, and invoke `onStart` once after the animation.
- [ ] Cancel the timer and animation controller in `dispose`.

### Task 2: Match the approved visual

**Files:**
- Modify: `zhidi_app/lib/pages/splash/splash_page.dart`
- Modify: `zhidi_app/test/splash_page_test.dart`

- [ ] Add failing assertions for the logo, “知底”, main slogan, four-value line, and absence of “开启安心装修之旅”.
- [ ] Keep `assets/splash_bg.png` as a full-screen `BoxFit.cover` image under a warm translucent overlay.
- [ ] Center `assets/logo.png`, brand name, slogan, and “工人透明｜工价透明｜工艺透明｜平台保障” with responsive safe-area spacing.
- [ ] Remove the button, its gesture animation, and unused custom painter.

### Task 3: Verify

**Files:**
- Test: `zhidi_app/test/splash_page_test.dart`

- [ ] Run `dart format lib/pages/splash/splash_page.dart test/splash_page_test.dart`.
- [ ] Run `flutter test test/splash_page_test.dart` and confirm all tests pass at 320px and 390px.
- [ ] Run `flutter analyze lib/pages/splash/splash_page.dart test/splash_page_test.dart` and confirm no issues.

