import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/data/owner_service_regions.dart';

void main() {
  test('only opens Sichuan and Gansu with complete official counts', () {
    expect(OwnerServiceRegionCatalog.provinces, ['四川省', '甘肃省']);

    final sichuanCities = OwnerServiceRegionCatalog.citiesFor('四川省');
    expect(sichuanCities, hasLength(21));
    expect(OwnerServiceRegionCatalog.officialCountyLevelCount('四川省'), 183);

    final gansuCities = OwnerServiceRegionCatalog.citiesFor('甘肃省');
    expect(gansuCities, hasLength(14));
    expect(OwnerServiceRegionCatalog.officialCountyLevelCount('甘肃省'), 86);
    expect(OwnerServiceRegionCatalog.districtsFor('甘肃省', '嘉峪关市'), ['嘉峪关市']);
  });

  test('rejects cross-province and non-administrative combinations', () {
    expect(OwnerServiceRegionCatalog.contains('四川省', '成都市', '武侯区'), isTrue);
    expect(OwnerServiceRegionCatalog.contains('甘肃省', '兰州市', '城关区'), isTrue);
    expect(OwnerServiceRegionCatalog.contains('四川省', '兰州市', '城关区'), isFalse);
    expect(OwnerServiceRegionCatalog.contains('甘肃省', '兰州市', '兰州新区'), isFalse);
  });

  test('does not expose duplicate or empty region names', () {
    for (final province in OwnerServiceRegionCatalog.provinces) {
      final cities = OwnerServiceRegionCatalog.citiesFor(province);
      expect(cities.toSet(), hasLength(cities.length));
      for (final city in cities) {
        final districts = OwnerServiceRegionCatalog.districtsFor(
          province,
          city,
        );
        expect(districts, isNotEmpty);
        expect(districts.toSet(), hasLength(districts.length));
        expect(districts.where((item) => item.trim().isEmpty), isEmpty);
      }
    }
  });
}
