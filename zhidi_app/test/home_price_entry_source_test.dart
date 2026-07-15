import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home page keeps transparent pricing entry wired', () {
    final source = File('lib/pages/home/home_page.dart').readAsStringSync();

    expect(source, contains("title: '工价透明'"));
    expect(source, contains('const PriceTransparencyPage()'));
  });
}
