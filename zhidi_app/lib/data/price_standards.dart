import 'package:flutter/material.dart';
import '../models/renovation.dart';

/// 工价标准 — 完整数据定义
/// 7个工种，每个工种包含多个分类，每个分类包含多个项目
/// 详情页包含施工内容、不包含、施工流程、平台保障

// ────────────────────────────────────────────
// 数据模型
// ────────────────────────────────────────────

class PriceProject {
  final String name;
  final String price; // 如 "¥45"
  final String unit; // 如 "/㎡"、"/个"、"/m"、"/套"、"/次" 等

  const PriceProject({
    required this.name,
    required this.price,
    required this.unit,
  });
}

class PriceCategory {
  final String name;
  final IconData icon;
  final String description;
  final List<PriceProject> projects;
  final String? imageAsset; // 卡片缩略图，null 时 fallback 到 icon

  int get projectCount => projects.length;

  const PriceCategory({
    required this.name,
    required this.icon,
    required this.description,
    required this.projects,
    this.imageAsset,
  });
}

class TradePriceData {
  final Trade trade; // 对应工种枚举（用于跳转工人列表）
  final String tradeName; // 工种名，如 "拆除"
  final IconData icon;
  final String bannerTitle; // Banner 大标题
  final String bannerImage; // 施工场景图（asset 路径）
  final List<PriceCategory> categories;

  const TradePriceData({
    required this.trade,
    required this.tradeName,
    required this.icon,
    required this.bannerTitle,
    required this.bannerImage,
    required this.categories,
  });

  String get pageTitle => '$tradeName工价标准';
}

// ────────────────────────────────────────────
// 7个工种数据
// ────────────────────────────────────────────

const List<TradePriceData> allTrades = [
  demolitionTrade,
  plumbingElectricTrade,
  masonryTrade,
  carpentryTrade,
  paintingTrade,
  installationTrade,
  cleaningTrade,
];

/// 将后端 Trade 枚举映射到新工价标准页面的 TradePriceData
/// 注意：旧枚举中的 Trade.waterproof 合并到 masonryTrade（泥瓦包含防水分类）
TradePriceData tradeToPriceData(String tradeServiceType) {
  switch (tradeServiceType) {
    case 'demolition':
      return demolitionTrade;
    case 'plumbing':
      return plumbingElectricTrade;
    case 'masonry':
      return masonryTrade;
    case 'waterproof':
      return waterproofTrade;
    case 'carpentry':
      return carpentryTrade;
    case 'painter':
    case 'painting':
      return paintingTrade;
    case 'installation':
      return installationTrade;
    case 'cleaning':
      return cleaningTrade;
    default:
      return demolitionTrade;
  }
}

// ---- 1. 拆除工价 ----

const demolitionTrade = TradePriceData(
  trade: Trade.demolition,
  tradeName: '拆除',
  icon: Icons.handyman,
  bannerTitle: '平台统一工价 透明不加价',
  bannerImage: 'assets/images/trades/demolition_banner.jpg',
  categories: [
    PriceCategory(
      name: '墙体拆除',
      icon: Icons.domain,
      description: '拆除各类墙体',
      projects: [
        PriceProject(name: '12墙拆除', price: '¥45', unit: '/㎡'),
        PriceProject(name: '24墙拆除', price: '¥65', unit: '/㎡'),
        PriceProject(name: '24以上墙拆除', price: '¥90', unit: '/㎡'),
      ],
    ),
    PriceCategory(
      name: '地面拆除',
      icon: Icons.layers,
      description: '各类地面材料拆除',
      projects: [
        PriceProject(name: '瓷砖地面拆除', price: '¥25', unit: '/㎡'),
        PriceProject(name: '木地板拆除', price: '¥20', unit: '/㎡'),
        PriceProject(name: '水泥地面破除', price: '¥35', unit: '/㎡'),
        PriceProject(name: '地暖层拆除', price: '¥40', unit: '/㎡'),
        PriceProject(name: '石材地面拆除', price: '¥30', unit: '/㎡'),
      ],
    ),
    PriceCategory(
      name: '厨卫拆除',
      icon: Icons.kitchen,
      description: '厨房卫生间设施拆除',
      projects: [
        PriceProject(name: '马桶拆除', price: '¥50', unit: '/个'),
        PriceProject(name: '洗手盆拆除', price: '¥40', unit: '/个'),
        PriceProject(name: '浴缸拆除', price: '¥150', unit: '/个'),
        PriceProject(name: '淋浴房拆除', price: '¥120', unit: '/套'),
        PriceProject(name: '橱柜拆除', price: '¥80', unit: '/延米'),
        PriceProject(name: '吊柜拆除', price: '¥60', unit: '/延米'),
        PriceProject(name: '集成吊顶拆除', price: '¥25', unit: '/㎡'),
        PriceProject(name: '排风扇拆除', price: '¥30', unit: '/个'),
      ],
    ),
    PriceCategory(
      name: '门窗拆除',
      icon: Icons.door_front_door,
      description: '各类门窗拆除',
      projects: [
        PriceProject(name: '防盗门拆除', price: '¥100', unit: '/樘'),
        PriceProject(name: '室内木门拆除', price: '¥60', unit: '/樘'),
        PriceProject(name: '铝合金窗拆除', price: '¥60', unit: '/樘'),
        PriceProject(name: '推拉门拆除', price: '¥80', unit: '/樘'),
      ],
    ),
    PriceCategory(
      name: '其他拆除',
      icon: Icons.more_horiz,
      description: '吊顶、墙纸、清运等',
      projects: [
        PriceProject(name: '吊顶拆除', price: '¥25', unit: '/㎡'),
        PriceProject(name: '扣板拆除', price: '¥20', unit: '/㎡'),
        PriceProject(name: '墙纸墙布撕除', price: '¥8', unit: '/㎡'),
        PriceProject(name: '旧家具清运', price: '¥200', unit: '/件'),
        PriceProject(name: '建筑垃圾清运', price: '¥400', unit: '/车'),
        PriceProject(name: '隔断拆除', price: '¥60', unit: '/㎡'),
      ],
    ),
  ],
);

// ---- 2. 水电工价 ----

const plumbingElectricTrade = TradePriceData(
  trade: Trade.plumbing,
  tradeName: '水电',
  icon: Icons.water_drop,
  bannerTitle: '平台统一工价 透明不加价',
  bannerImage: 'assets/images/trades/plumbing_banner.jpg',
  categories: [
    PriceCategory(
      name: '开槽布线',
      icon: Icons.cable,
      description: '墙面地面开槽与布线',
      projects: [
        PriceProject(name: '墙面开槽', price: '¥15', unit: '/m'),
        PriceProject(name: '地面开槽', price: '¥20', unit: '/m'),
        PriceProject(name: '强弱电布线', price: '¥25', unit: '/m'),
        PriceProject(name: '网线布线', price: '¥18', unit: '/m'),
      ],
    ),
    PriceCategory(
      name: '水管安装',
      icon: Icons.plumbing,
      description: '水管及配件安装',
      projects: [
        PriceProject(name: 'PPR水管安装', price: '¥35', unit: '/m'),
        PriceProject(name: '排水管安装', price: '¥30', unit: '/m'),
        PriceProject(name: '暖气管道', price: '¥45', unit: '/m'),
        PriceProject(name: '水表安装', price: '¥80', unit: '/个'),
      ],
    ),
    PriceCategory(
      name: '电路改造',
      icon: Icons.electrical_services,
      description: '强电弱电改造',
      projects: [
        PriceProject(name: '强电改造', price: '¥30', unit: '/m'),
        PriceProject(name: '弱电改造', price: '¥20', unit: '/m'),
        PriceProject(name: '配电箱改造', price: '¥200', unit: '/个'),
        PriceProject(name: '线路检测', price: '¥100', unit: '/次'),
      ],
    ),
    PriceCategory(
      name: '开关插座安装',
      icon: Icons.toggle_on,
      description: '开关面板插座安装',
      projects: [
        PriceProject(name: '单开开关安装', price: '¥15', unit: '/个'),
        PriceProject(name: '双开开关安装', price: '¥20', unit: '/个'),
        PriceProject(name: '五孔插座安装', price: '¥18', unit: '/个'),
        PriceProject(name: '网线面板安装', price: '¥20', unit: '/个'),
      ],
    ),
  ],
);

// ---- 3. 泥瓦工价 ----

const masonryTrade = TradePriceData(
  trade: Trade.masonry,
  tradeName: '泥瓦',
  icon: Icons.format_paint,
  bannerTitle: '平台统一工价 透明不加价',
  bannerImage: 'assets/images/trades/masonry_banner.jpg',
  categories: [
    PriceCategory(
      name: '地砖铺贴',
      icon: Icons.view_quilt,
      description: '各类地砖铺贴',
      imageAsset: 'assets/images/trades/masonry.jpg',
      projects: [
        PriceProject(name: '600×600地砖', price: '¥45', unit: '/㎡'),
        PriceProject(name: '800×800地砖', price: '¥50', unit: '/㎡'),
        PriceProject(name: '木纹砖铺贴', price: '¥55', unit: '/㎡'),
        PriceProject(name: '波打线铺贴', price: '¥30', unit: '/m'),
        PriceProject(name: '门槛石铺贴', price: '¥35', unit: '/块'),
      ],
    ),
    PriceCategory(
      name: '墙砖铺贴',
      icon: Icons.wallpaper,
      description: '各类墙砖铺贴',
      imageAsset: 'assets/images/trades/masonry.jpg',
      projects: [
        PriceProject(name: '300×600墙砖', price: '¥45', unit: '/㎡'),
        PriceProject(name: '马赛克铺贴', price: '¥80', unit: '/㎡'),
        PriceProject(name: '背景墙砖', price: '¥120', unit: '/㎡'),
        PriceProject(name: '瓷砖倒角', price: '¥15', unit: '/m'),
      ],
    ),
    PriceCategory(
      name: '地面找平',
      icon: Icons.straighten,
      description: '地面找平处理',
      imageAsset: 'assets/images/trades/masonry.jpg',
      projects: [
        PriceProject(name: '水泥砂浆找平', price: '¥25', unit: '/㎡'),
        PriceProject(name: '自流平找平', price: '¥35', unit: '/㎡'),
      ],
    ),
    PriceCategory(
      name: '砌墙抹灰',
      icon: Icons.format_shapes,
      description: '砌筑墙体与抹灰',
      imageAsset: 'assets/images/trades/masonry.jpg',
      projects: [
        PriceProject(name: '12墙砌筑', price: '¥80', unit: '/㎡'),
        PriceProject(name: '24墙砌筑', price: '¥120', unit: '/㎡'),
        PriceProject(name: '墙面抹灰', price: '¥30', unit: '/㎡'),
        PriceProject(name: '挂网抹灰', price: '¥35', unit: '/㎡'),
      ],
    ),
  ],
);

// ---- 3.5 防水工价 ----

const waterproofTrade = TradePriceData(
  trade: Trade.waterproof,
  tradeName: '防水',
  icon: Icons.water,
  bannerTitle: '平台统一工价 透明不加价',
  bannerImage: 'assets/images/trades/plumbing_banner.jpg',
  categories: [
    PriceCategory(
      name: '厨卫防水',
      icon: Icons.bathroom,
      description: '厨房卫生间防水施工',
      projects: [
        PriceProject(name: '卫生间地面防水', price: '¥55', unit: '/㎡'),
        PriceProject(name: '卫生间墙面防水', price: '¥48', unit: '/㎡'),
        PriceProject(name: '厨房地面防水', price: '¥50', unit: '/㎡'),
        PriceProject(name: '厨房墙面防水', price: '¥42', unit: '/㎡'),
      ],
    ),
    PriceCategory(
      name: '阳台防水',
      icon: Icons.balcony,
      description: '阳台区域防水施工',
      projects: [
        PriceProject(name: '阳台地面防水', price: '¥45', unit: '/㎡'),
        PriceProject(name: '阳台墙面防水', price: '¥38', unit: '/㎡'),
        PriceProject(name: '露台防水', price: '¥60', unit: '/㎡'),
      ],
    ),
    PriceCategory(
      name: '地下/屋面防水',
      icon: Icons.roofing,
      description: '地下室及屋面防水',
      projects: [
        PriceProject(name: '地下室防水', price: '¥65', unit: '/㎡'),
        PriceProject(name: '屋面防水', price: '¥70', unit: '/㎡'),
        PriceProject(name: '外墙防水', price: '¥55', unit: '/㎡'),
      ],
    ),
    PriceCategory(
      name: '防水检测',
      icon: Icons.engineering,
      description: '闭水试验与检测',
      projects: [
        PriceProject(name: '闭水试验', price: '¥200', unit: '/次'),
        PriceProject(name: '渗漏检测', price: '¥300', unit: '/次'),
      ],
    ),
  ],
);

// ---- 4. 木工工价 ----

const carpentryTrade = TradePriceData(
  trade: Trade.carpentry,
  tradeName: '木工',
  icon: Icons.carpenter,
  bannerTitle: '平台统一工价 透明不加价',
  bannerImage: 'assets/images/trades/carpentry_banner.jpg',
  categories: [
    PriceCategory(
      name: '吊顶施工',
      icon: Icons.view_agenda,
      description: '各类吊顶安装',
      projects: [
        PriceProject(name: '石膏板吊顶', price: '¥85', unit: '/㎡'),
        PriceProject(name: '铝扣板吊顶', price: '¥65', unit: '/㎡'),
        PriceProject(name: 'PVC吊顶', price: '¥45', unit: '/㎡'),
        PriceProject(name: '双眼皮吊顶', price: '¥60', unit: '/m'),
      ],
    ),
    PriceCategory(
      name: '柜体制作',
      icon: Icons.kitchen,
      description: '定制柜体制作',
      projects: [
        PriceProject(name: '衣柜制作', price: '¥600', unit: '/㎡'),
        PriceProject(name: '橱柜制作', price: '¥550', unit: '/延米'),
        PriceProject(name: '书柜制作', price: '¥500', unit: '/㎡'),
        PriceProject(name: '鞋柜制作', price: '¥450', unit: '/㎡'),
        PriceProject(name: '榻榻米制作', price: '¥700', unit: '/㎡'),
      ],
    ),
    PriceCategory(
      name: '门套安装',
      icon: Icons.door_sliding,
      description: '门套窗套安装',
      projects: [
        PriceProject(name: '实木门套', price: '¥150', unit: '/m'),
        PriceProject(name: '复合门套', price: '¥100', unit: '/m'),
        PriceProject(name: '窗套安装', price: '¥80', unit: '/m'),
      ],
    ),
  ],
);

// ---- 5. 油漆工价 ----

const paintingTrade = TradePriceData(
  trade: Trade.painting,
  tradeName: '油漆',
  icon: Icons.brush,
  bannerTitle: '平台统一工价 透明不加价',
  bannerImage: 'assets/images/trades/painting_banner.jpg',
  categories: [
    PriceCategory(
      name: '墙面基层处理',
      icon: Icons.cleaning_services,
      description: '墙面清理与修补',
      projects: [
        PriceProject(name: '墙面清理', price: '¥8', unit: '/㎡'),
        PriceProject(name: '界面剂涂刷', price: '¥5', unit: '/㎡'),
        PriceProject(name: '裂缝修补', price: '¥15', unit: '/m'),
        PriceProject(name: '阴阳角处理', price: '¥10', unit: '/m'),
      ],
    ),
    PriceCategory(
      name: '刮腻子',
      icon: Icons.texture,
      description: '腻子批刮打磨',
      projects: [
        PriceProject(name: '第一遍腻子', price: '¥12', unit: '/㎡'),
        PriceProject(name: '第二遍腻子', price: '¥10', unit: '/㎡'),
        PriceProject(name: '打磨处理', price: '¥8', unit: '/㎡'),
      ],
    ),
    PriceCategory(
      name: '乳胶漆施工',
      icon: Icons.colorize,
      description: '底漆面漆涂刷',
      projects: [
        PriceProject(name: '底漆涂刷', price: '¥8', unit: '/㎡'),
        PriceProject(name: '面漆第一遍', price: '¥10', unit: '/㎡'),
        PriceProject(name: '面漆第二遍', price: '¥10', unit: '/㎡'),
        PriceProject(name: '分色处理', price: '¥20', unit: '/m'),
      ],
    ),
  ],
);

// ---- 6. 安装工价 ----

const installationTrade = TradePriceData(
  trade: Trade.installation,
  tradeName: '安装',
  icon: Icons.build,
  bannerTitle: '平台统一工价 透明不加价',
  bannerImage: 'assets/images/trades/installation_banner.jpg',
  categories: [
    PriceCategory(
      name: '灯具安装',
      icon: Icons.lightbulb,
      description: '各类灯具安装',
      projects: [
        PriceProject(name: '吸顶灯安装', price: '¥30', unit: '/个'),
        PriceProject(name: '吊灯安装', price: '¥80', unit: '/个'),
        PriceProject(name: '筒灯射灯', price: '¥20', unit: '/个'),
        PriceProject(name: '灯带安装', price: '¥25', unit: '/m'),
      ],
    ),
    PriceCategory(
      name: '五金安装',
      icon: Icons.handyman,
      description: '五金挂件安装',
      projects: [
        PriceProject(name: '毛巾架安装', price: '¥20', unit: '/个'),
        PriceProject(name: '置物架安装', price: '¥30', unit: '/个'),
        PriceProject(name: '挂钩安装', price: '¥10', unit: '/个'),
        PriceProject(name: '窗帘杆安装', price: '¥40', unit: '/m'),
        PriceProject(name: '挂画安装', price: '¥15', unit: '/个'),
      ],
    ),
    PriceCategory(
      name: '卫浴安装',
      icon: Icons.bathtub,
      description: '卫浴洁具安装',
      projects: [
        PriceProject(name: '马桶安装', price: '¥80', unit: '/个'),
        PriceProject(name: '花洒安装', price: '¥60', unit: '/套'),
        PriceProject(name: '浴室柜安装', price: '¥120', unit: '/套'),
        PriceProject(name: '浴霸安装', price: '¥100', unit: '/个'),
      ],
    ),
  ],
);

// ---- 7. 保洁工价 ----

const cleaningTrade = TradePriceData(
  trade: Trade.cleaning,
  tradeName: '保洁',
  icon: Icons.clean_hands,
  bannerTitle: '平台统一工价 透明不加价',
  bannerImage: 'assets/images/trades/cleaning_banner.jpg',
  categories: [
    PriceCategory(
      name: '开荒保洁',
      icon: Icons.home_repair_service,
      description: '装修后深度清洁',
      projects: [
        PriceProject(name: '全屋开荒', price: '¥8', unit: '/㎡'),
        PriceProject(name: '玻璃清洁', price: '¥3', unit: '/㎡'),
        PriceProject(name: '地面清洗', price: '¥4', unit: '/㎡'),
        PriceProject(name: '墙面除尘', price: '¥2', unit: '/㎡'),
      ],
    ),
    PriceCategory(
      name: '精细保洁',
      icon: Icons.auto_awesome,
      description: '日常与深度保洁',
      projects: [
        PriceProject(name: '日常保洁', price: '¥5', unit: '/㎡'),
        PriceProject(name: '厨房深度', price: '¥200', unit: '/次'),
        PriceProject(name: '卫生间深度', price: '¥150', unit: '/次'),
        PriceProject(name: '沙发清洗', price: '¥100', unit: '/座'),
      ],
    ),
  ],
);
