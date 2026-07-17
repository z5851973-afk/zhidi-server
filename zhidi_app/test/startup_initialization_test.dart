import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/main.dart' as app;

void main() {
  test(
    'Firebase startup initialization times out instead of blocking app launch',
    () async {
      final stopwatch = Stopwatch()..start();

      await app.initializeFirebaseForStartup(
        () => Completer<void>().future,
        timeout: const Duration(milliseconds: 20),
      );

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
    },
  );
}
