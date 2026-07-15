/// 装修需求模型
library;

// ── 工种 ──
enum Trade {
  demolition('拆除', '拆墙/砸墙/拆旧', '🔨'),
  plumbing('水电工', '水电改造/布线/开槽', '⚡'),
  masonry('泥瓦工', '贴砖/砌墙/找平/勾缝', '🧱'),
  waterproof('防水工', '防水工程/补漏/防水施工', '💧'),
  carpentry('木工', '吊顶/打柜/木作', '🪚'),
  painting('油漆工', '刮腻子/刷漆/涂料', '🎨'),
  installation('安装工', '橱柜/门/地板/卫浴安装', '🔧'),
  cleaning('保洁', '开荒保洁/精保洁', '🧹');

  const Trade(this.label, this.desc, this.icon);
  final String label;
  final String desc;
  final String icon;
}

// ── 需求类型 ──
enum RequirementType {
  findTrade,
  fullRenovation,
  oldHouseRenovation,
  partialRenovation,
}

// ── 空间 ──
enum Space { kitchen, bathroom, livingRoom, bedroom, balcony, multiple }

extension SpaceLabel on Space {
  String get label => switch (this) {
    Space.kitchen => '厨房',
    Space.bathroom => '卫生间',
    Space.livingRoom => '客厅',
    Space.bedroom => '卧室',
    Space.balcony => '阳台',
    Space.multiple => '多个空间',
  };
}

// ── 施工阶段 ──
class ConstructionPhase {
  final Trade trade;
  final String name;
  final int minDays;
  final int maxDays;
  final String detail;

  const ConstructionPhase({
    required this.trade,
    required this.name,
    required this.minDays,
    required this.maxDays,
    required this.detail,
  });

  String get durationRange => '$minDays–$maxDays天';
}

// ── 标准施工流程（按顺序） ──
const standardPhases = [
  ConstructionPhase(
    trade: Trade.demolition,
    name: '拆除/墙体改造',
    minDays: 2,
    maxDays: 5,
    detail: '旧墙拆除、垃圾清运、新墙砌筑',
  ),
  ConstructionPhase(
    trade: Trade.plumbing,
    name: '水电改造',
    minDays: 5,
    maxDays: 10,
    detail: '开槽布管、电路铺设、水管改造、防水基层',
  ),
  ConstructionPhase(
    trade: Trade.masonry,
    name: '泥瓦施工',
    minDays: 5,
    maxDays: 12,
    detail: '墙地砖铺贴、地面找平、砌墙、勾缝',
  ),
  ConstructionPhase(
    trade: Trade.waterproof,
    name: '防水施工',
    minDays: 2,
    maxDays: 5,
    detail: '防水涂刷、闭水试验、堵漏处理、卷材铺设',
  ),
  ConstructionPhase(
    trade: Trade.carpentry,
    name: '木工施工',
    minDays: 5,
    maxDays: 12,
    detail: '吊顶安装、柜体制作、背景墙木作',
  ),
  ConstructionPhase(
    trade: Trade.painting,
    name: '油漆施工',
    minDays: 7,
    maxDays: 14,
    detail: '墙面基层处理、刮腻子、打磨、刷漆',
  ),
  ConstructionPhase(
    trade: Trade.installation,
    name: '主材安装',
    minDays: 5,
    maxDays: 10,
    detail: '橱柜安装、门套安装、地板铺设、卫浴安装',
  ),
  ConstructionPhase(
    trade: Trade.cleaning,
    name: '保洁验收',
    minDays: 1,
    maxDays: 3,
    detail: '全屋清洁、细节修补、竣工验收',
  ),
];

/// 根据选中工种裁剪施工流程（保留需要的 + 前后依赖）
List<ConstructionPhase> filterPhases(List<Trade> trades) {
  final needed = trades.toSet();
  // 拆除在任意工种前都需要
  if (needed.contains(Trade.masonry) || needed.contains(Trade.plumbing)) {
    needed.add(Trade.demolition);
  }
  // 泥瓦需要水电
  if (needed.contains(Trade.masonry)) needed.add(Trade.plumbing);
  // 防水需要泥瓦和水电
  if (needed.contains(Trade.waterproof)) {
    needed.add(Trade.masonry);
    needed.add(Trade.plumbing);
  }
  // 安装需要在油漆之后
  if (needed.contains(Trade.installation)) needed.add(Trade.painting);

  return standardPhases.where((p) => needed.contains(p.trade)).toList();
}

/// 计算总工期范围
(int fastest, int slowest) calcTotalDays(List<ConstructionPhase> phases) {
  int f = 0, s = 0;
  for (final p in phases) {
    f += p.minDays;
    s += p.maxDays;
  }
  return (f, s);
}

// ── 工人模型 ──
class Worker {
  final String id;
  final String name;
  final Trade trade;
  final int experienceYears;
  final int completedProjects;
  final double rating;
  final String avatar;
  final String intro;
  final List<String> certifications;
  final double creditScore;
  final double distance;
  final bool isOnline;
  bool isSelected;

  Worker({
    required this.id,
    required this.name,
    required this.trade,
    required this.experienceYears,
    required this.completedProjects,
    required this.rating,
    required this.avatar,
    required this.intro,
    this.certifications = const [],
    this.creditScore = 0,
    this.distance = 0,
    this.isOnline = false,
    this.isSelected = false,
  });
}

// ── 模拟工人数据 ──
final mockWorkers = <Trade, List<Worker>>{
  Trade.demolition: [
    Worker(
      id: 'd1',
      name: '张国强',
      trade: Trade.demolition,
      experienceYears: 12,
      completedProjects: 386,
      rating: 4.9,
      avatar: 'https://i.pravatar.cc/150?img=1',
      intro: '从业12年，擅长老房拆除与墙体改造，零投诉',
      creditScore: 98.5,
      distance: 1.2,
      isOnline: true,
      certifications: ['建筑拆除资质'],
    ),
    Worker(
      id: 'd2',
      name: '李建明',
      trade: Trade.demolition,
      experienceYears: 8,
      completedProjects: 215,
      rating: 4.8,
      avatar: 'https://i.pravatar.cc/150?img=2',
      intro: '年轻肯干，拆旧效率高，垃圾清运一条龙',
      creditScore: 92.0,
      distance: 3.5,
      isOnline: false,
    ),
    Worker(
      id: 'd3',
      name: '王大力',
      trade: Trade.demolition,
      experienceYears: 15,
      completedProjects: 502,
      rating: 4.7,
      avatar: 'https://i.pravatar.cc/150?img=3',
      intro: '15年老师傅，任何墙体结构都能处理',
      creditScore: 95.5,
      distance: 2.8,
      isOnline: true,
    ),
    Worker(
      id: 'd4',
      name: '赵建国',
      trade: Trade.demolition,
      experienceYears: 11,
      completedProjects: 298,
      rating: 4.8,
      avatar: 'https://i.pravatar.cc/150?img=4',
      intro: '专注拆除工程10余年，价格透明，活干得干净',
      creditScore: 94.0,
      distance: 4.1,
      isOnline: false,
      certifications: ['建筑拆除资质'],
    ),
    Worker(
      id: 'd5',
      name: '陈志强',
      trade: Trade.demolition,
      experienceYears: 7,
      completedProjects: 178,
      rating: 4.6,
      avatar: 'https://i.pravatar.cc/150?img=5',
      intro: '年轻师傅主力军，拆得快、清得干净、价格实惠',
      creditScore: 88.5,
      distance: 5.6,
      isOnline: true,
    ),
    Worker(
      id: 'd6',
      name: '杨伟',
      trade: Trade.demolition,
      experienceYears: 13,
      completedProjects: 340,
      rating: 4.9,
      avatar: 'https://i.pravatar.cc/150?img=6',
      intro: '老房拆除专家，结构判断精准，从不损坏承重结构',
      creditScore: 97.0,
      distance: 0.8,
      isOnline: false,
      certifications: ['建筑拆除资质', '安全管理认证'],
    ),
    Worker(
      id: 'd7',
      name: '周明',
      trade: Trade.demolition,
      experienceYears: 9,
      completedProjects: 232,
      rating: 4.7,
      avatar: 'https://i.pravatar.cc/150?img=7',
      intro: '擅长精装房拆旧，保护性拆除，可回收材料分类处理',
      creditScore: 91.0,
      distance: 6.3,
      isOnline: true,
    ),
    Worker(
      id: 'd8',
      name: '吴海涛',
      trade: Trade.demolition,
      experienceYears: 16,
      completedProjects: 568,
      rating: 4.8,
      avatar: 'https://i.pravatar.cc/150?img=8',
      intro: '16年拆旧老手，商业空间/住宅拆除经验丰富，重安全零事故',
      creditScore: 99.0,
      distance: 2.1,
      isOnline: false,
      certifications: ['建筑拆除资质', '高级技工证'],
    ),
  ],
  Trade.plumbing: [
    Worker(
      id: 'p1',
      name: '陈志远',
      trade: Trade.plumbing,
      experienceYears: 10,
      completedProjects: 420,
      rating: 4.9,
      avatar: 'https://i.pravatar.cc/150?img=9',
      intro: '持证水电工程师，隐蔽工程零返修',
      isOnline: true,
      certifications: ['电工证', '水管工资质'],
    ),
    Worker(
      id: 'p2',
      name: '刘勇',
      trade: Trade.plumbing,
      experienceYears: 6,
      completedProjects: 180,
      rating: 4.7,
      avatar: 'https://i.pravatar.cc/150?img=10',
      intro: '年轻水电工，走线规范整齐，拍照留档',
      isOnline: false,
    ),
    Worker(
      id: 'p3',
      name: '赵大国',
      trade: Trade.plumbing,
      experienceYears: 18,
      completedProjects: 650,
      rating: 4.8,
      avatar: 'https://i.pravatar.cc/150?img=11',
      intro: '老牌水电，全屋系统改造专家',
      isOnline: true,
      certifications: ['高级电工证'],
    ),
  ],
  Trade.masonry: [
    Worker(
      id: 'm1',
      name: '周建平',
      trade: Trade.masonry,
      experienceYears: 14,
      completedProjects: 520,
      rating: 4.9,
      avatar: 'https://i.pravatar.cc/150?img=12',
      intro: '贴砖14年，阳角对角精准，空鼓率低于行业标准',
      isOnline: false,
      certifications: ['泥瓦工高级'],
    ),
    Worker(
      id: 'm2',
      name: '吴建国',
      trade: Trade.masonry,
      experienceYears: 9,
      completedProjects: 310,
      rating: 4.8,
      avatar: 'https://i.pravatar.cc/150?img=13',
      intro: '专做大户型，地面找平精度高',
      isOnline: true,
    ),
    Worker(
      id: 'm3',
      name: '郑守义',
      trade: Trade.masonry,
      experienceYears: 20,
      completedProjects: 780,
      rating: 4.7,
      avatar: 'https://i.pravatar.cc/150?img=14',
      intro: '二十年的老把式，什么砖都能贴',
      isOnline: false,
    ),
  ],
  Trade.waterproof: [
    Worker(
      id: 'wf1',
      name: '钟国强',
      trade: Trade.waterproof,
      experienceYears: 13,
      completedProjects: 450,
      rating: 4.9,
      avatar: 'https://i.pravatar.cc/150?img=15',
      intro: '专攻防水13年，卫生间/阳台/屋顶无一返修',
      isOnline: true,
      certifications: ['防水施工资质'],
    ),
    Worker(
      id: 'wf2',
      name: '何建国',
      trade: Trade.waterproof,
      experienceYears: 8,
      completedProjects: 260,
      rating: 4.8,
      avatar: 'https://i.pravatar.cc/150?img=16',
      intro: '持证上岗，闭水试验30小时以上，漏一赔十',
      isOnline: false,
      certifications: ['防水施工资质'],
    ),
    Worker(
      id: 'wf3',
      name: '范德明',
      trade: Trade.waterproof,
      experienceYears: 16,
      completedProjects: 590,
      rating: 4.7,
      avatar: 'https://i.pravatar.cc/150?img=17',
      intro: '16年老师傅，地下室/屋面防水专家',
      isOnline: true,
      certifications: ['高级防水资质'],
    ),
  ],
  Trade.carpentry: [
    Worker(
      id: 'c1',
      name: '钱木森',
      trade: Trade.carpentry,
      experienceYears: 11,
      completedProjects: 390,
      rating: 4.9,
      avatar: 'https://i.pravatar.cc/150?img=18',
      intro: '设计出身转木工，审美在线，懂图纸',
      isOnline: false,
      certifications: ['木工技师'],
    ),
    Worker(
      id: 'c2',
      name: '孙德海',
      trade: Trade.carpentry,
      experienceYears: 16,
      completedProjects: 560,
      rating: 4.8,
      avatar: 'https://i.pravatar.cc/150?img=19',
      intro: '老师傅，打柜子、做吊顶一绝',
      isOnline: true,
    ),
  ],
  Trade.painting: [
    Worker(
      id: 'pt1',
      name: '黄志明',
      trade: Trade.painting,
      experienceYears: 8,
      completedProjects: 350,
      rating: 4.8,
      avatar: 'https://i.pravatar.cc/150?img=20',
      intro: '对颜色敏感，调漆精准，基层处理到位',
      isOnline: true,
    ),
    Worker(
      id: 'pt2',
      name: '马俊杰',
      trade: Trade.painting,
      experienceYears: 13,
      completedProjects: 480,
      rating: 4.9,
      avatar: 'https://i.pravatar.cc/150?img=21',
      intro: '老油漆工，乳胶漆/艺术漆都能做',
      isOnline: false,
      certifications: ['涂装高级工'],
    ),
  ],
  Trade.installation: [
    Worker(
      id: 'i1',
      name: '林志强',
      trade: Trade.installation,
      experienceYears: 7,
      completedProjects: 280,
      rating: 4.8,
      avatar: 'https://i.pravatar.cc/150?img=22',
      intro: '橱柜卫浴安装专家，售后率极低',
      isOnline: true,
    ),
    Worker(
      id: 'i2',
      name: '何文斌',
      trade: Trade.installation,
      experienceYears: 10,
      completedProjects: 410,
      rating: 4.7,
      avatar: 'https://i.pravatar.cc/150?img=23',
      intro: '十年安装经验，门/地板/卫浴全通',
      isOnline: false,
    ),
  ],
  Trade.cleaning: [
    Worker(
      id: 'cl1',
      name: '洁美保洁',
      trade: Trade.cleaning,
      experienceYears: 5,
      completedProjects: 1200,
      rating: 4.9,
      avatar: 'https://i.pravatar.cc/150?img=24',
      intro: '专业装修后保洁，16道工序，不满意不验收',
      isOnline: true,
    ),
  ],
};

// ── 计价单位 ──
enum PricingUnit { perSquareMeter, perMeter, perPoint }

extension PricingUnitLabel on PricingUnit {
  String get label => switch (this) {
    PricingUnit.perSquareMeter => '按平方米计价',
    PricingUnit.perMeter => '按米计价',
    PricingUnit.perPoint => '按点位计价',
  };

  String get shortLabel => switch (this) {
    PricingUnit.perSquareMeter => '按㎡计价',
    PricingUnit.perMeter => '按米计价',
    PricingUnit.perPoint => '按点计价',
  };
}

// ── 施工细项 ──
class ConstructionItem {
  final String id;
  final String name;
  final Trade trade;
  final PricingUnit pricingUnit;
  final double unitPrice; // 平台单价

  const ConstructionItem({
    required this.id,
    required this.name,
    required this.trade,
    required this.pricingUnit,
    required this.unitPrice,
  });

  String get pricingLabel => pricingUnit.label;
}

// ── 预定义施工细项目录 ──
const allConstructionItems = [
  // 拆除工程
  ConstructionItem(
    id: 'demo_12wall',
    name: '拆除12墙',
    trade: Trade.demolition,
    pricingUnit: PricingUnit.perSquareMeter,
    unitPrice: 45,
  ),
  ConstructionItem(
    id: 'demo_24wall',
    name: '拆除24墙',
    trade: Trade.demolition,
    pricingUnit: PricingUnit.perSquareMeter,
    unitPrice: 65,
  ),
  ConstructionItem(
    id: 'demo_tile',
    name: '拆除瓷砖/地砖',
    trade: Trade.demolition,
    pricingUnit: PricingUnit.perSquareMeter,
    unitPrice: 25,
  ),
  // 水电改造
  ConstructionItem(
    id: 'plumb_slot',
    name: '水电开槽',
    trade: Trade.plumbing,
    pricingUnit: PricingUnit.perMeter,
    unitPrice: 35,
  ),
  ConstructionItem(
    id: 'plumb_pipe',
    name: '线管布线',
    trade: Trade.plumbing,
    pricingUnit: PricingUnit.perMeter,
    unitPrice: 28,
  ),
  ConstructionItem(
    id: 'plumb_water',
    name: '水路改造',
    trade: Trade.plumbing,
    pricingUnit: PricingUnit.perMeter,
    unitPrice: 55,
  ),
  // 防水工程
  ConstructionItem(
    id: 'water_bath',
    name: '卫生间防水',
    trade: Trade.waterproof,
    pricingUnit: PricingUnit.perSquareMeter,
    unitPrice: 68,
  ),
  ConstructionItem(
    id: 'water_balcony',
    name: '阳台防水',
    trade: Trade.waterproof,
    pricingUnit: PricingUnit.perSquareMeter,
    unitPrice: 58,
  ),
  ConstructionItem(
    id: 'water_kitchen',
    name: '厨房防水',
    trade: Trade.waterproof,
    pricingUnit: PricingUnit.perSquareMeter,
    unitPrice: 55,
  ),
  ConstructionItem(
    id: 'water_roof',
    name: '屋顶防水补漏',
    trade: Trade.waterproof,
    pricingUnit: PricingUnit.perSquareMeter,
    unitPrice: 85,
  ),
  ConstructionItem(
    id: 'water_basement',
    name: '地下室防水',
    trade: Trade.waterproof,
    pricingUnit: PricingUnit.perSquareMeter,
    unitPrice: 95,
  ),
  // 泥瓦施工
  ConstructionItem(
    id: 'mason_wall',
    name: '墙面贴砖',
    trade: Trade.masonry,
    pricingUnit: PricingUnit.perSquareMeter,
    unitPrice: 72,
  ),
  ConstructionItem(
    id: 'mason_floor',
    name: '地面贴砖',
    trade: Trade.masonry,
    pricingUnit: PricingUnit.perSquareMeter,
    unitPrice: 65,
  ),
  ConstructionItem(
    id: 'mason_level',
    name: '地面找平',
    trade: Trade.masonry,
    pricingUnit: PricingUnit.perSquareMeter,
    unitPrice: 35,
  ),
  // 木工
  ConstructionItem(
    id: 'carp_ceiling',
    name: '石膏板吊顶',
    trade: Trade.carpentry,
    pricingUnit: PricingUnit.perSquareMeter,
    unitPrice: 95,
  ),
  ConstructionItem(
    id: 'carp_cabinet',
    name: '定制柜体',
    trade: Trade.carpentry,
    pricingUnit: PricingUnit.perSquareMeter,
    unitPrice: 420,
  ),
  // 油漆
  ConstructionItem(
    id: 'paint_wall',
    name: '墙面刷漆',
    trade: Trade.painting,
    pricingUnit: PricingUnit.perSquareMeter,
    unitPrice: 38,
  ),
  ConstructionItem(
    id: 'paint_putty',
    name: '刮腻子',
    trade: Trade.painting,
    pricingUnit: PricingUnit.perSquareMeter,
    unitPrice: 28,
  ),
  // 安装
  ConstructionItem(
    id: 'inst_door',
    name: '室内门安装',
    trade: Trade.installation,
    pricingUnit: PricingUnit.perPoint,
    unitPrice: 180,
  ),
  ConstructionItem(
    id: 'inst_cab',
    name: '橱柜安装',
    trade: Trade.installation,
    pricingUnit: PricingUnit.perPoint,
    unitPrice: 350,
  ),
  ConstructionItem(
    id: 'inst_floor',
    name: '地板铺设',
    trade: Trade.installation,
    pricingUnit: PricingUnit.perSquareMeter,
    unitPrice: 35,
  ),
];

/// 按工种分组
Map<Trade, List<ConstructionItem>> get groupedItems {
  final map = <Trade, List<ConstructionItem>>{};
  for (final item in allConstructionItems) {
    map.putIfAbsent(item.trade, () => []).add(item);
  }
  return map;
}

/// 工种对应的组标题信息
String tradeGroupLabel(Trade t) {
  return switch (t) {
    Trade.demolition => '准备/正在打拆',
    Trade.plumbing => '改水改电',
    Trade.masonry => '找师傅砌墙/贴砖',
    Trade.waterproof => '找防水师傅',
    Trade.carpentry => '找木工师傅',
    Trade.painting => '找刷乳胶漆师傅',
    Trade.installation => '找定制安装工程',
    Trade.cleaning => '保洁验收',
  };
}

String tradePricingHint(Trade t) {
  return switch (t) {
    Trade.demolition ||
    Trade.masonry ||
    Trade.waterproof ||
    Trade.carpentry ||
    Trade.painting ||
    Trade.cleaning => '按㎡计价 (平台统一价)',
    Trade.plumbing => '按点/米计价 (平台统一价)',
    Trade.installation => '按点/㎡计价 (平台统一价)',
  };
}

// ── 报价状态 ──
enum QuoteStatus { pending, generated }

// ── 施工细项报价行 ──
class ItemQuote {
  final ConstructionItem item;
  final QuoteStatus status;
  final double? laborCost; // 人工费
  final double? materialCost; // 材料费

  const ItemQuote({
    required this.item,
    this.status = QuoteStatus.pending,
    this.laborCost,
    this.materialCost,
  });

  double? get total => (laborCost != null && materialCost != null)
      ? laborCost! + materialCost!
      : null;
}

// ── 业主需求（贯穿整个流程的状态） ──
class RenovationRequirement {
  RequirementType? type;
  List<Trade> trades = [];
  List<Space> spaces = [];
  int? area; // 平米
  int? budget; // 万元
  String? style;
  bool needDemolition = false; // 旧房改造是否需要拆除
  List<ConstructionPhase> phases = [];
  Map<Trade, Worker> team = {};
  List<ConstructionItem> selectedItems = [];

  void reset() {
    type = null;
    trades = [];
    spaces = [];
    area = null;
    budget = null;
    style = null;
    needDemolition = false;
    phases = [];
    team = {};
    selectedItems = [];
  }

  bool get isComplete {
    if (type == null) return false;
    if (trades.isEmpty) return false;
    return true;
  }

  /// 从 selectedItems 推算涉及的工种
  List<Trade> get tradesFromItems {
    return selectedItems.map((e) => e.trade).toSet().toList();
  }
}
