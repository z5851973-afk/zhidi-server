import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/services/upload_api_client.dart';

void main() {
  test('resolves server-relative upload URL against API base URL', () {
    final result = UploadResult.fromJson({
      'url': '/uploads/chat/photo.jpg',
      'objectKey': 'chat/photo.jpg',
    }, baseUrl: Uri.parse('http://47.109.0.191:8080'));

    expect(result.url, 'http://47.109.0.191:8080/uploads/chat/photo.jpg');
  });

  test('keeps absolute object-storage URL unchanged', () {
    final result = UploadResult.fromJson({
      'url': 'https://cdn.example.com/chat/photo.jpg',
      'objectKey': 'chat/photo.jpg',
    }, baseUrl: Uri.parse('http://47.109.0.191:8080'));

    expect(result.url, 'https://cdn.example.com/chat/photo.jpg');
  });
}
