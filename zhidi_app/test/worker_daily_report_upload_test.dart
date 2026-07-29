import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zhidi_app/pages/worker/daily_report_page.dart';

void main() {
  test('uploads every selected report image and preserves URL order', () async {
    final uploadedPaths = <String>[];

    final urls = await uploadDailyReportImages(
      [XFile('/tmp/first.jpg'), XFile('/tmp/second.png')],
      (File file) async {
        uploadedPaths.add(file.path);
        return 'http://api.example.test/uploads/${file.uri.pathSegments.last}';
      },
    );

    expect(uploadedPaths, ['/tmp/first.jpg', '/tmp/second.png']);
    expect(urls, [
      'http://api.example.test/uploads/first.jpg',
      'http://api.example.test/uploads/second.png',
    ]);
  });

  test('does not report success when an image upload fails', () async {
    await expectLater(
      uploadDailyReportImages([
        XFile('/tmp/broken.jpg'),
      ], (_) async => throw const FileSystemException('upload failed')),
      throwsA(isA<FileSystemException>()),
    );
  });
}
