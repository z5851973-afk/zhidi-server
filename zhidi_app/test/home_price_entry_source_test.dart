import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home page keeps the fixed price catalog entry wired', () {
    final source = File('lib/pages/home/home_page.dart').readAsStringSync();

    expect(source, contains("title: '工价透明'"));
    expect(source, contains("sub: '平台统一标准'"));
    expect(source, isNot(contains("sub: '服务端固定目录'")));
    expect(source, contains('const PriceTransparencyPage()'));
  });
}
