import 'package:flutter/material.dart';

class PriceProject {
  const PriceProject({
    required this.name,
    required this.price,
    required this.unit,
  });

  final String name;
  final String price;
  final String unit;
}

class PriceCategory {
  const PriceCategory({
    required this.name,
    required this.icon,
    required this.description,
    required this.projects,
  });

  final String name;
  final IconData icon;
  final String description;
  final List<PriceProject> projects;
}

class TradePriceData {
  const TradePriceData({required this.tradeName, required this.categories});

  final String tradeName;
  final List<PriceCategory> categories;
}

const demolitionTrade = TradePriceData(
  tradeName: '拆除',
  categories: [
    PriceCategory(
      name: '墙体拆除',
      icon: Icons.construction_rounded,
      description: '墙体拆改报价项目',
      projects: [
        PriceProject(name: '12墙拆除', price: '¥45', unit: '/㎡'),
        PriceProject(name: '24墙拆除', price: '¥65', unit: '/㎡'),
      ],
    ),
  ],
);
