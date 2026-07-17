import 'worker_models.dart';

/// 报价模版项
class QuotationTemplateItem {
  const QuotationTemplateItem({
    required this.name,
    required this.category,
    this.phase = '',
    this.specs = const [],
    required this.unitPrice,
    this.unit = '项',
  });

  final String name;
  final QuotationItemCategory category;
  final String phase;
  final List<String> specs;
  final double unitPrice;
  final String unit;
}

/// 按工种返回预置报价模版
List<QuotationTemplateItem> quotationTemplateForTrade(String trade) {
  switch (trade) {
    case '水电工':
      return _waterElectric;
    case '瓦工':
      return _tiler;
    case '木工':
      return _carpenter;
    default:
      return _generic;
  }
}

// ═══════════════════════════════════════════
// 水电工
// ═══════════════════════════════════════════
const _waterElectric = <QuotationTemplateItem>[
  // ── 拆除/开槽 ──
  QuotationTemplateItem(name: '墙面开槽', category: QuotationItemCategory.labor, phase: '开槽', unitPrice: 25, unit: '米'),
  QuotationTemplateItem(name: '地面开槽', category: QuotationItemCategory.labor, phase: '开槽', unitPrice: 20, unit: '米'),
  QuotationTemplateItem(name: '旧线管拆除', category: QuotationItemCategory.labor, phase: '拆除', unitPrice: 8, unit: '米'),

  // ── 布管布线 ──
  QuotationTemplateItem(name: '强电布线（2.5mm²）', category: QuotationItemCategory.labor, phase: '布线', unitPrice: 30, unit: '米'),
  QuotationTemplateItem(name: '强电布线（4mm²）', category: QuotationItemCategory.labor, phase: '布线', unitPrice: 35, unit: '米'),
  QuotationTemplateItem(name: '弱电布线（网线）', category: QuotationItemCategory.labor, phase: '布线', unitPrice: 20, unit: '米'),
  QuotationTemplateItem(name: '水管布管（PPR冷水）', category: QuotationItemCategory.labor, phase: '水路', unitPrice: 35, unit: '米'),
  QuotationTemplateItem(name: '水管布管（PPR热水）', category: QuotationItemCategory.labor, phase: '水路', unitPrice: 40, unit: '米'),
  QuotationTemplateItem(name: '排水管安装（PVC）', category: QuotationItemCategory.labor, phase: '水路', unitPrice: 30, unit: '米'),

  // ── 安装 ──
  QuotationTemplateItem(name: '开关插座安装', category: QuotationItemCategory.labor, phase: '安装', unitPrice: 10, unit: '个'),
  QuotationTemplateItem(name: '灯具安装（吸顶灯）', category: QuotationItemCategory.labor, phase: '安装', unitPrice: 30, unit: '个'),
  QuotationTemplateItem(name: '灯具安装（吊灯）', category: QuotationItemCategory.labor, phase: '安装', unitPrice: 50, unit: '个'),
  QuotationTemplateItem(name: '配电箱安装', category: QuotationItemCategory.labor, phase: '安装', unitPrice: 200, unit: '台'),
  QuotationTemplateItem(name: '水龙头安装', category: QuotationItemCategory.labor, phase: '安装', unitPrice: 20, unit: '个'),
  QuotationTemplateItem(name: '马桶安装', category: QuotationItemCategory.labor, phase: '安装', unitPrice: 80, unit: '个'),
  QuotationTemplateItem(name: '浴室柜安装', category: QuotationItemCategory.labor, phase: '安装', unitPrice: 100, unit: '套'),

  // ── 辅料 ──
  QuotationTemplateItem(name: 'PVC线管（Φ20）', category: QuotationItemCategory.auxiliary, phase: '布线', specs: ['联塑', '日丰', '伟星'], unitPrice: 3, unit: '米'),
  QuotationTemplateItem(name: 'PVC线管（Φ25）', category: QuotationItemCategory.auxiliary, phase: '布线', specs: ['联塑', '日丰', '伟星'], unitPrice: 4, unit: '米'),
  QuotationTemplateItem(name: '直接/弯头/三通', category: QuotationItemCategory.auxiliary, phase: '布线', unitPrice: 15, unit: '套'),
  QuotationTemplateItem(name: '电工胶带', category: QuotationItemCategory.auxiliary, phase: '安装', specs: ['3M', '公牛', '德力西'], unitPrice: 5, unit: '卷'),

  // ── 主材 ──
  QuotationTemplateItem(name: 'BV电线 2.5mm²', category: QuotationItemCategory.mainMaterial, phase: '布线', specs: ['熊猫', '远东', '正泰'], unitPrice: 3.5, unit: '米'),
  QuotationTemplateItem(name: 'BV电线 4mm²', category: QuotationItemCategory.mainMaterial, phase: '布线', specs: ['熊猫', '远东', '正泰'], unitPrice: 5.5, unit: '米'),
  QuotationTemplateItem(name: '超五类网线', category: QuotationItemCategory.mainMaterial, phase: '布线', specs: ['安普', '秋叶原', '山泽'], unitPrice: 3, unit: '米'),
  QuotationTemplateItem(name: 'PPR冷水管（Φ25）', category: QuotationItemCategory.mainMaterial, phase: '水路', specs: ['日丰', '伟星', '金牛'], unitPrice: 12, unit: '米'),
  QuotationTemplateItem(name: 'PPR热水管（Φ25）', category: QuotationItemCategory.mainMaterial, phase: '水路', specs: ['日丰', '伟星', '金牛'], unitPrice: 15, unit: '米'),
  QuotationTemplateItem(name: '86型底盒', category: QuotationItemCategory.mainMaterial, phase: '安装', specs: ['公牛', '正泰', '德力西'], unitPrice: 2, unit: '个'),
];

// ═══════════════════════════════════════════
// 瓦工
// ═══════════════════════════════════════════
const _tiler = <QuotationTemplateItem>[
  QuotationTemplateItem(name: '墙面贴砖（300×600）', category: QuotationItemCategory.labor, phase: '贴砖', unitPrice: 50, unit: '㎡'),
  QuotationTemplateItem(name: '墙面贴砖（600×1200）', category: QuotationItemCategory.labor, phase: '贴砖', unitPrice: 65, unit: '㎡'),
  QuotationTemplateItem(name: '地面贴砖（600×600）', category: QuotationItemCategory.labor, phase: '贴砖', unitPrice: 45, unit: '㎡'),
  QuotationTemplateItem(name: '地面贴砖（800×800）', category: QuotationItemCategory.labor, phase: '贴砖', unitPrice: 55, unit: '㎡'),
  QuotationTemplateItem(name: '防水施工（墙面）', category: QuotationItemCategory.labor, phase: '防水', unitPrice: 25, unit: '㎡'),
  QuotationTemplateItem(name: '防水施工（地面）', category: QuotationItemCategory.labor, phase: '防水', unitPrice: 30, unit: '㎡'),
  QuotationTemplateItem(name: '瓷砖倒角', category: QuotationItemCategory.labor, phase: '贴砖', unitPrice: 15, unit: '米'),
  QuotationTemplateItem(name: '回填找平', category: QuotationItemCategory.labor, phase: '找平', unitPrice: 35, unit: '㎡'),

  QuotationTemplateItem(name: '水泥（425#）', category: QuotationItemCategory.auxiliary, phase: '贴砖', specs: ['海螺', '华新', '山水'], unitPrice: 35, unit: '袋'),
  QuotationTemplateItem(name: '黄沙', category: QuotationItemCategory.auxiliary, phase: '贴砖', unitPrice: 10, unit: '袋'),
  QuotationTemplateItem(name: '瓷砖胶', category: QuotationItemCategory.auxiliary, phase: '贴砖', specs: ['德高', '立邦', '雨虹'], unitPrice: 45, unit: '袋'),
  QuotationTemplateItem(name: '填缝剂', category: QuotationItemCategory.auxiliary, phase: '美缝', specs: ['德高', '立邦', '卓高'], unitPrice: 35, unit: '桶'),
  QuotationTemplateItem(name: '防水涂料', category: QuotationItemCategory.auxiliary, phase: '防水', specs: ['德高', '雨虹', '科顺'], unitPrice: 180, unit: '桶'),

  QuotationTemplateItem(name: '瓷砖 300×600', category: QuotationItemCategory.mainMaterial, phase: '贴砖', unitPrice: 45, unit: '片'),
  QuotationTemplateItem(name: '瓷砖 600×600', category: QuotationItemCategory.mainMaterial, phase: '贴砖', unitPrice: 55, unit: '片'),
  QuotationTemplateItem(name: '瓷砖 800×800', category: QuotationItemCategory.mainMaterial, phase: '贴砖', unitPrice: 85, unit: '片'),
];

// ═══════════════════════════════════════════
// 木工
// ═══════════════════════════════════════════
const _carpenter = <QuotationTemplateItem>[
  QuotationTemplateItem(name: '石膏板吊顶（平顶）', category: QuotationItemCategory.labor, phase: '吊顶', unitPrice: 85, unit: '㎡'),
  QuotationTemplateItem(name: '石膏板吊顶（造型）', category: QuotationItemCategory.labor, phase: '吊顶', unitPrice: 120, unit: '㎡'),
  QuotationTemplateItem(name: '轻钢龙骨隔墙', category: QuotationItemCategory.labor, phase: '隔断', unitPrice: 65, unit: '㎡'),
  QuotationTemplateItem(name: '衣柜制作（投影面积）', category: QuotationItemCategory.labor, phase: '柜体', unitPrice: 350, unit: '㎡'),
  QuotationTemplateItem(name: '橱柜制作（延米）', category: QuotationItemCategory.labor, phase: '柜体', unitPrice: 280, unit: '米'),
  QuotationTemplateItem(name: '窗帘盒制作', category: QuotationItemCategory.labor, phase: '细节', unitPrice: 60, unit: '米'),

  QuotationTemplateItem(name: '石膏板（9.5mm）', category: QuotationItemCategory.auxiliary, phase: '吊顶', specs: ['龙牌', '杰科', '泰山'], unitPrice: 38, unit: '张'),
  QuotationTemplateItem(name: '轻钢龙骨（主骨）', category: QuotationItemCategory.auxiliary, phase: '吊顶', unitPrice: 12, unit: '根'),
  QuotationTemplateItem(name: '自攻螺丝', category: QuotationItemCategory.auxiliary, phase: '吊顶', unitPrice: 15, unit: '盒'),
  QuotationTemplateItem(name: '白乳胶', category: QuotationItemCategory.auxiliary, phase: '柜体', specs: ['百得', '汉高'], unitPrice: 45, unit: '桶'),
  QuotationTemplateItem(name: '木工板（18mm）', category: QuotationItemCategory.mainMaterial, phase: '柜体', specs: ['兔宝宝', '千年舟'], unitPrice: 140, unit: '张'),
  QuotationTemplateItem(name: '饰面板', category: QuotationItemCategory.mainMaterial, phase: '柜体', unitPrice: 85, unit: '张'),
];

// ═══════════════════════════════════════════
// 通用
// ═══════════════════════════════════════════
const _generic = <QuotationTemplateItem>[
  QuotationTemplateItem(name: '材料搬运费', category: QuotationItemCategory.labor, unitPrice: 200, unit: '项'),
  QuotationTemplateItem(name: '垃圾清运费', category: QuotationItemCategory.labor, unitPrice: 300, unit: '项'),
  QuotationTemplateItem(name: '成品保护', category: QuotationItemCategory.auxiliary, unitPrice: 150, unit: '项'),
];
