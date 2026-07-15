import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/data/price_standards.dart';

void main() {
  test('maps service types to the matching price standard data', () {
    expect(tradeToPriceData('demolition').tradeName, '拆除');
    expect(tradeToPriceData('plumbing').tradeName, '水电');
    expect(tradeToPriceData('masonry').tradeName, '泥瓦');
    expect(tradeToPriceData('waterproof').tradeName, '防水');
    expect(tradeToPriceData('carpentry').tradeName, '木工');
    expect(tradeToPriceData('painter').tradeName, '油漆');
    expect(tradeToPriceData('painting').tradeName, '油漆');
    expect(tradeToPriceData('installation').tradeName, '安装');
    expect(tradeToPriceData('cleaning').tradeName, '保洁');
    expect(tradeToPriceData('unknown').tradeName, '拆除');
  });

  test('published trade standards include quoteable categories and projects', () {
    expect(allTrades.length, greaterThanOrEqualTo(7));

    for (final trade in allTrades) {
      expect(trade.tradeName, isNotEmpty);
      expect(trade.pageTitle, contains(trade.tradeName));
      expect(trade.bannerTitle, isNotEmpty);
      expect(trade.categories, isNotEmpty);

      for (final category in trade.categories) {
        expect(category.name, isNotEmpty);
        expect(category.description, isNotEmpty);
        expect(category.projectCount, category.projects.length);
        expect(category.projects, isNotEmpty);

        for (final project in category.projects) {
          expect(project.name, isNotEmpty);
          expect(project.price, startsWith('¥'));
          expect(project.unit, startsWith('/'));
        }
      }
    }
  });
}
