import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/pages/home/my_home_page.dart';

void main() {
  test('service request status labels include quote pending', () {
    expect(serviceRequestStatusLabel('QUOTE_PENDING'), '待确认报价');
  });
}
