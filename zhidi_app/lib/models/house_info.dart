final class HouseInfo {
  const HouseInfo({
    required this.areaSqm,
    required this.bedroomCount,
    required this.livingRoomCount,
    required this.kitchenCount,
    required this.bathroomCount,
  });

  final double areaSqm;
  final int bedroomCount;
  final int livingRoomCount;
  final int kitchenCount;
  final int bathroomCount;

  static HouseInfo? tryFromJson(Map<String, dynamic> json) {
    final area = json['areaSqm'];
    final bedroom = json['bedroomCount'];
    final livingRoom = json['livingRoomCount'];
    final kitchen = json['kitchenCount'];
    final bathroom = json['bathroomCount'];
    if (area is! num ||
        bedroom is! num ||
        livingRoom is! num ||
        kitchen is! num ||
        bathroom is! num) {
      return null;
    }
    final areaValue = area.toDouble();
    final bedroomValue = bedroom.toInt();
    final livingRoomValue = livingRoom.toInt();
    final kitchenValue = kitchen.toInt();
    final bathroomValue = bathroom.toInt();
    if (areaValue < 1 ||
        areaValue > 9999 ||
        (areaValue * 100 - (areaValue * 100).round()).abs() > 0.000001 ||
        bedroomValue < 1 ||
        bedroomValue > 20 ||
        livingRoomValue < 0 ||
        livingRoomValue > 10 ||
        kitchenValue < 0 ||
        kitchenValue > 10 ||
        bathroomValue < 1 ||
        bathroomValue > 20 ||
        bedroom.toDouble() != bedroomValue ||
        livingRoom.toDouble() != livingRoomValue ||
        kitchen.toDouble() != kitchenValue ||
        bathroom.toDouble() != bathroomValue) {
      return null;
    }
    return HouseInfo(
      areaSqm: areaValue,
      bedroomCount: bedroomValue,
      livingRoomCount: livingRoomValue,
      kitchenCount: kitchenValue,
      bathroomCount: bathroomValue,
    );
  }

  Map<String, dynamic> toJson() => {
    'areaSqm': areaSqm,
    'bedroomCount': bedroomCount,
    'livingRoomCount': livingRoomCount,
    'kitchenCount': kitchenCount,
    'bathroomCount': bathroomCount,
  };

  String get areaLabel {
    final rounded = areaSqm.roundToDouble();
    final value = areaSqm == rounded
        ? rounded.toInt().toString()
        : areaSqm.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    return '$value㎡';
  }

  String get layoutLabel =>
      '$bedroomCount室$livingRoomCount厅$kitchenCount厨$bathroomCount卫';

  String get summaryLabel => '$areaLabel · $layoutLabel';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HouseInfo &&
          areaSqm == other.areaSqm &&
          bedroomCount == other.bedroomCount &&
          livingRoomCount == other.livingRoomCount &&
          kitchenCount == other.kitchenCount &&
          bathroomCount == other.bathroomCount;

  @override
  int get hashCode => Object.hash(
    areaSqm,
    bedroomCount,
    livingRoomCount,
    kitchenCount,
    bathroomCount,
  );
}

const missingHouseInfoLabel = '房屋信息未填写';
