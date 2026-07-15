import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/renovation.dart';
import '../../app/owner_app_scope.dart';
import '../../app/owner_models.dart';
import 'worker_chat_page.dart';
import 'booking_success_page.dart';
import '../../design/tokens.dart';
import '../../services/worker_directory_api_client.dart';

// ── 主颜色 ──
const _primary = ZdColors.primary;
const _primaryLight = Color(0xFFFFF7F0);
const _textDark = ZdColors.textPrimary;
const _textMid = ZdColors.textSecondary;
const _textLight = ZdColors.textSecondary;
const _bg = Color(0xFFFAF7F2);
const _star = Color(0xFFFFB800);

// ── 师傅详情数据 ──
class WorkerDetail {
  final String name;
  final List<String> trades;
  final double rating;
  final int completedOrders;
  final int years;
  final int positiveRate;
  final double distanceKm;
  final String avatarEmoji;
  final List<String> skills;
  final String matchReason;
  final List<Review> reviews;

  const WorkerDetail({
    required this.name,
    required this.trades,
    required this.rating,
    required this.completedOrders,
    required this.years,
    required this.positiveRate,
    required this.distanceKm,
    required this.avatarEmoji,
    required this.skills,
    required this.matchReason,
    required this.reviews,
  });

  WorkerDetail copyWith({double? distanceKm}) {
    return WorkerDetail(
      name: name,
      trades: trades,
      rating: rating,
      completedOrders: completedOrders,
      years: years,
      positiveRate: positiveRate,
      distanceKm: distanceKm ?? this.distanceKm,
      avatarEmoji: avatarEmoji,
      skills: skills,
      matchReason: matchReason,
      reviews: reviews,
    );
  }
}

// ── 工序-工种映射 ──
const _phaseNames = ['打拆', '水电', '防水', '泥工', '木工', '瓦工', '美缝', '安装', '清洁'];

int _tradeToPhaseIndex(String trade) {
  final m = <String, int>{
    '拆除师傅': 0,
    '水电师傅': 1,
    '防水师傅': 2,
    '泥工师傅': 3,
    '木工师傅': 4,
    '瓦工师傅': 5,
    '美缝师傅': 6,
    '安装师傅': 7,
    '清洁师傅': 8,
  };
  return m[trade] ?? 0;
}

// ── 评价 ──
class Review {
  final String userName;
  final String city;
  final double rating;
  final String text;
  final List<String> photos; // emoji 占位

  const Review({
    required this.userName,
    required this.city,
    required this.rating,
    required this.text,
    required this.photos,
  });
}

// ── 师傅库存（数据来源：首页施工团队「更多师傅」）──
const _allWorkers = <String, WorkerDetail>{
  '何师傅': WorkerDetail(
    name: '何师傅',
    trades: ['拆除师傅'],
    rating: 4.8,
    completedOrders: 312,
    years: 14,
    positiveRate: 98,
    distanceKm: 0.95,
    avatarEmoji: '👷',
    skills: ['墙体拆除', '旧装修拆除', '铲墙皮', '垃圾清运', '地面破除', '门窗拆除'],
    matchReason:
        '拆除工负责装修第一步的拆旧工作，需要丰富的施工经验。该师傅与您的装修需求高度匹配，擅长墙体拆除、旧装修拆除、铲墙皮、垃圾清运、地面破除、门窗拆除，从业14年经验丰富，累计完成312单，好评率98%，距离您0.95km。',
    reviews: [
      Review(
        userName: '宝安刘先生',
        city: '深圳',
        rating: 4.9,
        text: '何师傅干活麻利，两天就把旧装修拆得干干净净，垃圾也清得很彻底！',
        photos: ['🏠', '🔨', '🧹'],
      ),
    ],
  ),
  '黄师傅': WorkerDetail(
    name: '黄师傅',
    trades: ['拆除师傅'],
    rating: 4.7,
    completedOrders: 215,
    years: 10,
    positiveRate: 96,
    distanceKm: 1.8,
    avatarEmoji: '👷',
    skills: ['拆墙', '铲墙皮', '拆吊顶', '拆地板', '门窗拆除', '垃圾清运'],
    matchReason:
        '拆除工负责装修第一步的拆旧工作，需要丰富的施工经验。该师傅与您的装修需求高度匹配，擅长拆墙、铲墙皮、拆吊顶、拆地板、门窗拆除、垃圾清运，从业10年经验丰富，累计完成215单，好评率96%，距离您1.8km。',
    reviews: [
      Review(
        userName: '南山赵女士',
        city: '深圳',
        rating: 4.8,
        text: '拆墙很专业，承重墙一眼就认出来了，帮我们避开了大坑！',
        photos: ['🏗️', '🧹'],
      ),
    ],
  ),
  '赵师傅': WorkerDetail(
    name: '赵师傅',
    trades: ['拆除师傅'],
    rating: 4.8,
    completedOrders: 298,
    years: 11,
    positiveRate: 98,
    distanceKm: 1.2,
    avatarEmoji: '👷',
    skills: ['墙体拆除', '旧装修拆除', '铲墙皮', '垃圾清运', '地面破除', '门窗拆除'],
    matchReason:
        '拆除工负责装修第一步的拆旧工作，需要丰富的施工经验。该师傅与您的装修需求高度匹配，擅长墙体拆除、旧装修拆除、铲墙皮、垃圾清运、地面破除、门窗拆除，从业11年经验丰富，累计完成298单，好评率98%，距离您1.2km。',
    reviews: [
      Review(
        userName: '龙华王女士',
        city: '深圳',
        rating: 4.8,
        text: '赵师傅价格透明，干活利索，拆完还帮我们把地面扫得干干净净，很满意！',
        photos: ['🔨', '🧹'],
      ),
    ],
  ),
  '陈师傅': WorkerDetail(
    name: '陈师傅',
    trades: ['拆除师傅'],
    rating: 4.6,
    completedOrders: 178,
    years: 7,
    positiveRate: 96,
    distanceKm: 2.5,
    avatarEmoji: '👷',
    skills: ['铲墙皮', '拆地砖', '拆吊顶', '垃圾清运', '门窗拆除'],
    matchReason:
        '拆除工负责装修第一步的拆旧工作，需要丰富的施工经验。该师傅与您的装修需求高度匹配，擅长铲墙皮、拆地砖、拆吊顶、垃圾清运、门窗拆除，从业7年经验丰富，累计完成178单，好评率96%，距离您2.5km。',
    reviews: [
      Review(
        userName: '龙岗钱先生',
        city: '深圳',
        rating: 4.6,
        text: '陈师傅年轻但手艺不错，拆得干净价格也实惠，推荐给预算有限的朋友！',
        photos: ['🛠️', '🧹'],
      ),
    ],
  ),
  '杨工': WorkerDetail(
    name: '杨工',
    trades: ['拆除师傅'],
    rating: 4.9,
    completedOrders: 340,
    years: 13,
    positiveRate: 99,
    distanceKm: 0.82,
    avatarEmoji: '👷',
    skills: ['墙体拆除', '旧装修拆除', '铲墙皮', '门窗拆除', '吊顶拆除', '垃圾清运'],
    matchReason:
        '拆除工负责装修第一步的拆旧工作，需要丰富的施工经验。该师傅与您的装修需求高度匹配，擅长墙体拆除、旧装修拆除、铲墙皮、门窗拆除、吊顶拆除、垃圾清运，从业13年经验丰富，累计完成340单，好评率99%，距离您0.82km。',
    reviews: [
      Review(
        userName: '福田陈先生',
        city: '深圳',
        rating: 5.0,
        text: '杨工经验太丰富了，一眼就认出哪面是承重墙，帮我们避免了大麻烦！强烈推荐！',
        photos: ['🏗️', '🔨', '🧹'],
      ),
    ],
  ),
  '周师傅': WorkerDetail(
    name: '周师傅',
    trades: ['拆除师傅'],
    rating: 4.7,
    completedOrders: 232,
    years: 9,
    positiveRate: 97,
    distanceKm: 3.1,
    avatarEmoji: '👷',
    skills: ['旧装修拆除', '铲墙皮', '门窗拆除', '吊顶拆除', '垃圾清运'],
    matchReason:
        '拆除工负责装修第一步的拆旧工作，需要丰富的施工经验。该师傅与您的装修需求高度匹配，擅长旧装修拆除、铲墙皮、门窗拆除、吊顶拆除、垃圾清运，从业9年经验丰富，累计完成232单，好评率97%，距离您3.1km。',
    reviews: [
      Review(
        userName: '南山林女士',
        city: '深圳',
        rating: 4.7,
        text: '周师傅做保护性拆除很到位，能用的材料都帮我们保留下来了，省了不少钱！',
        photos: ['🛠️', '✨'],
      ),
    ],
  ),
  '吴师傅': WorkerDetail(
    name: '吴师傅',
    trades: ['拆除师傅'],
    rating: 4.8,
    completedOrders: 568,
    years: 16,
    positiveRate: 98,
    distanceKm: 1.5,
    avatarEmoji: '👷',
    skills: ['墙体拆除', '旧装修拆除', '地面破除', '垃圾清运', '门窗拆除', '吊顶拆除'],
    matchReason:
        '拆除工负责装修第一步的拆旧工作，需要丰富的施工经验。该师傅与您的装修需求高度匹配，擅长墙体拆除、旧装修拆除、地面破除、垃圾清运、门窗拆除、吊顶拆除，从业16年经验丰富，累计完成568单，好评率98%，距离您1.5km。',
    reviews: [
      Review(
        userName: '宝安周总',
        city: '深圳',
        rating: 4.9,
        text: '吴师傅带团队来的，200平的办公室一天半拆完清完，效率惊人，而且零安全事故！',
        photos: ['🏢', '🔨', '🧹'],
      ),
    ],
  ),
  '李师傅': WorkerDetail(
    name: '李师傅',
    trades: ['水电师傅'],
    rating: 4.9,
    completedOrders: 326,
    years: 18,
    positiveRate: 98,
    distanceKm: 1.6,
    avatarEmoji: '🔌',
    skills: ['水电改造', '管道维修', '电路布线'],
    matchReason:
        '该师傅与您的装修需求高度匹配，擅长水电改造、管道维修、电路布线，从业18年经验丰富，累计完成326单，好评率98%，距离您1.6km。',
    reviews: [
      Review(
        userName: '南山张先生',
        city: '深圳',
        rating: 5.0,
        text: '李师傅干活特别细致，我家老房子水电全改，走线横平竖直，比之前装修公司强太多了！',
        photos: ['🔌', '⚡', '📏'],
      ),
    ],
  ),
  '张师傅': WorkerDetail(
    name: '张师傅',
    trades: ['泥工师傅', '泥瓦工师傅'],
    rating: 4.7,
    completedOrders: 198,
    years: 12,
    positiveRate: 97,
    distanceKm: 2.3,
    avatarEmoji: '🧱',
    skills: ['地砖铺贴', '墙砖铺贴', '地面找平', '砌墙抹灰'],
    matchReason:
        '系统根据您的泥瓦需求和装修阶段，为您推荐该师傅。擅长地砖铺贴、墙砖铺贴、地面找平、砌墙抹灰，从业12年经验丰富，累计完成198单，好评率97%，距离您2.3km。',
    reviews: [
      Review(
        userName: '宝安王先生',
        city: '深圳',
        rating: 4.8,
        text: '瓷砖贴得特别平整，阴阳角处理得非常好，地面找平精度很高，很放心的师傅！',
        photos: ['🧱', '📐', '✨'],
      ),
    ],
  ),
  '吴建国': WorkerDetail(
    name: '吴建国',
    trades: ['泥工师傅', '泥瓦工师傅'],
    rating: 4.8,
    completedOrders: 310,
    years: 9,
    positiveRate: 98,
    distanceKm: 1.2,
    avatarEmoji: '🧱',
    skills: ['地砖铺贴', '墙砖铺贴', '地面找平', '砌墙抹灰'],
    matchReason:
        '系统根据您的泥瓦需求和装修阶段，为您推荐该师傅。专做大户型，地面找平精度高，擅长地砖铺贴、墙砖铺贴、地面找平、砌墙抹灰，从业9年经验丰富，累计完成310单，好评率98%，距离您1.2km。',
    reviews: [
      Review(
        userName: '南山刘先生',
        city: '深圳',
        rating: 4.9,
        text: '吴师傅地面找平做得真准，大户型铺砖一丝不苟，手艺没得说！',
        photos: ['🧱', '📏', '✨'],
      ),
      Review(
        userName: '福田李女士',
        city: '深圳',
        rating: 4.8,
        text: '墙砖贴得整齐漂亮，砌墙抹灰也很到位，很靠谱的师傅。',
        photos: ['🏗️', '🧱'],
      ),
    ],
  ),
  '周建平': WorkerDetail(
    name: '周建平',
    trades: ['泥工师傅', '泥瓦工师傅'],
    rating: 4.9,
    completedOrders: 520,
    years: 14,
    positiveRate: 99,
    distanceKm: 0.85,
    avatarEmoji: '🧱',
    skills: ['地砖铺贴', '墙砖铺贴', '地面找平', '砌墙抹灰'],
    matchReason:
        '系统根据您的泥瓦需求和装修阶段，为您推荐该师傅。贴砖14年，阳角对角精准，空鼓率低于行业标准，擅长地砖铺贴、墙砖铺贴、地面找平、砌墙抹灰，从业14年经验丰富，累计完成520单，好评率99%，距离您0.85km。',
    reviews: [
      Review(
        userName: '罗湖张女士',
        city: '深圳',
        rating: 5.0,
        text: '周师傅手艺是真好，阳角对角做得一点缝都看不出来，质检说空鼓率几乎为零！',
        photos: ['🧱', '📐', '✨'],
      ),
      Review(
        userName: '龙华陈先生',
        city: '深圳',
        rating: 4.9,
        text: '14年老师傅确实不一样，铺砖又快又平整，非常专业。',
        photos: ['🏗️', '🧱'],
      ),
    ],
  ),
  '郑守义': WorkerDetail(
    name: '郑守义',
    trades: ['泥工师傅', '泥瓦工师傅'],
    rating: 4.7,
    completedOrders: 780,
    years: 20,
    positiveRate: 96,
    distanceKm: 3.5,
    avatarEmoji: '🧱',
    skills: ['地砖铺贴', '墙砖铺贴', '地面找平', '砌墙抹灰'],
    matchReason:
        '系统根据您的泥瓦需求和装修阶段，为您推荐该师傅。二十年的老把式，什么砖都能贴，擅长地砖铺贴、墙砖铺贴、地面找平、砌墙抹灰，从业20年经验丰富，累计完成780单，好评率96%，距离您3.5km。',
    reviews: [
      Review(
        userName: '宝安许先生',
        city: '深圳',
        rating: 4.8,
        text: '老郑干了半辈子泥瓦，技术没话说，20年经验不是白给的！',
        photos: ['🧱', '✨'],
      ),
    ],
  ),
  '杨师傅': WorkerDetail(
    name: '杨师傅',
    trades: ['防水师傅'],
    rating: 4.8,
    completedOrders: 245,
    years: 11,
    positiveRate: 98,
    distanceKm: 1.4,
    avatarEmoji: '💧',
    skills: ['厨卫防水', '阳台防水', '屋面防水', '地下室防潮'],
    matchReason:
        '该师傅与您的装修需求高度匹配，擅长厨卫防水、阳台防水、屋面防水、地下室防潮，从业11年经验丰富，累计完成245单，好评率98%，距离您1.4km。',
    reviews: [
      Review(
        userName: '福田孙先生',
        city: '深圳',
        rating: 4.9,
        text: '杨师傅做防水很专业，闭水试验48小时滴水不漏，以后再也不担心楼下投诉了！',
        photos: ['🚿', '🧹'],
      ),
    ],
  ),
  '谭师傅': WorkerDetail(
    name: '谭师傅',
    trades: ['防水师傅'],
    rating: 4.7,
    completedOrders: 167,
    years: 8,
    positiveRate: 96,
    distanceKm: 2.9,
    avatarEmoji: '💧',
    skills: ['卫生间防水', '厨房防水', '外墙防水', '堵漏'],
    matchReason:
        '该师傅与您的装修需求高度匹配，擅长卫生间防水、厨房防水、外墙防水、堵漏，从业8年经验丰富，累计完成167单，好评率96%，距离您2.9km。',
    reviews: [
      Review(
        userName: '宝安廖女士',
        city: '深圳',
        rating: 4.8,
        text: '老房子漏水找谭师傅修的，查得准、修得快，价格也合理！',
        photos: ['🛠️', '💧'],
      ),
    ],
  ),
  '王师傅': WorkerDetail(
    name: '王师傅',
    trades: ['木工师傅'],
    rating: 4.8,
    completedOrders: 278,
    years: 15,
    positiveRate: 96,
    distanceKm: 0.68,
    avatarEmoji: '🪚',
    skills: ['全屋定制', '衣柜橱柜', '吊顶安装'],
    matchReason:
        '该师傅与您的装修需求高度匹配，擅长全屋定制、衣柜橱柜、吊顶安装，从业15年经验丰富，累计完成278单，好评率96%，距离您0.68km。',
    reviews: [
      Review(
        userName: '福田李女士',
        city: '深圳',
        rating: 4.9,
        text: '衣柜和橱柜都是王师傅做的，封边处理得很好，细节到位，邻居来看了都说要找他。',
        photos: ['🪵', '📐', '✨'],
      ),
    ],
  ),
  '宋师傅': WorkerDetail(
    name: '宋师傅',
    trades: ['油漆师傅'],
    rating: 4.8,
    completedOrders: 267,
    years: 13,
    positiveRate: 97,
    distanceKm: 1.2,
    avatarEmoji: '🎨',
    skills: ['墙面刷漆', '木器漆', '艺术漆', '硅藻泥'],
    matchReason:
        '该师傅与您的装修需求高度匹配，擅长墙面刷漆、木器漆、艺术漆、硅藻泥，从业13年经验丰富，累计完成267单，好评率97%，距离您1.2km。',
    reviews: [
      Review(
        userName: '福田王先生',
        city: '深圳',
        rating: 4.9,
        text: '宋师傅刷的墙面特别平整，颜色调得跟效果图一模一样，很满意！',
        photos: ['🎨', '🖌️', '✨'],
      ),
    ],
  ),
  '郑师傅': WorkerDetail(
    name: '郑师傅',
    trades: ['油漆师傅'],
    rating: 4.7,
    completedOrders: 178,
    years: 9,
    positiveRate: 95,
    distanceKm: 3.5,
    avatarEmoji: '🎨',
    skills: ['乳胶漆', '艺术涂料', '旧墙翻新', '补墙'],
    matchReason:
        '该师傅与您的装修需求高度匹配，擅长乳胶漆、艺术涂料、旧墙翻新、补墙，从业9年经验丰富，累计完成178单，好评率95%，距离您3.5km。',
    reviews: [
      Review(
        userName: '罗湖钟女士',
        city: '深圳',
        rating: 4.7,
        text: '老房子墙面发霉全铲了重做，郑师傅做得很细致，半年了没出问题。',
        photos: ['🖼️', '🖌️'],
      ),
    ],
  ),
  '彭师傅': WorkerDetail(
    name: '彭师傅',
    trades: ['美缝师傅'],
    rating: 4.9,
    completedOrders: 332,
    years: 7,
    positiveRate: 99,
    distanceKm: 0.72,
    avatarEmoji: '✨',
    skills: ['瓷砖美缝', '环氧彩砂', '马贝填缝', '美容胶收边'],
    matchReason:
        '该师傅与您的装修需求高度匹配，擅长瓷砖美缝、环氧彩砂、马贝填缝、美容胶收边，从业7年经验丰富，累计完成332单，好评率99%，距离您0.72km。',
    reviews: [
      Review(
        userName: '龙华林女士',
        city: '深圳',
        rating: 5.0,
        text: '彭师傅美缝做得太漂亮了，环氧彩砂颜色配得绝了，朋友都问哪家做的！',
        photos: ['✨', '🧹'],
      ),
    ],
  ),
  '丁师傅': WorkerDetail(
    name: '丁师傅',
    trades: ['美缝师傅'],
    rating: 4.7,
    completedOrders: 198,
    years: 5,
    positiveRate: 96,
    distanceKm: 4.2,
    avatarEmoji: '✨',
    skills: ['美缝', '填缝', '防水胶收边', '厨房台面美容'],
    matchReason:
        '该师傅与您的装修需求高度匹配，擅长美缝、填缝、防水胶收边、厨房台面美容，从业5年经验丰富，累计完成198单，好评率96%，距离您4.2km。',
    reviews: [
      Review(
        userName: '宝安黄女士',
        city: '深圳',
        rating: 4.8,
        text: '小丁师傅年轻但手艺好，做活认真，价格也实惠，推荐！',
        photos: ['🛠️', '✨'],
      ),
    ],
  ),
};

// ══════════════════════════════════════════
// 师傅详情页
// ══════════════════════════════════════════
class WorkerDetailPage extends StatefulWidget {
  final String workerName;
  final Trade? trade;
  final double? distance;
  final RemoteWorkerDirectoryProfile? remoteProfile;

  const WorkerDetailPage({
    super.key,
    required this.workerName,
    this.trade,
    this.distance,
    this.remoteProfile,
  });

  @override
  State<WorkerDetailPage> createState() => _WorkerDetailPageState();
}

class _WorkerDetailPageState extends State<WorkerDetailPage> {
  bool _savingFavorite = false;

  // Trade.label → _allWorkers trades 字符串映射
  static const _labelToTrade = <String, String>{
    '拆除': '拆除师傅',
    '水电工': '水电师傅',
    '泥瓦工': '泥工师傅',
    '防水工': '防水师傅',
    '木工': '木工师傅',
    '油漆工': '油漆师傅',
    '安装工': '安装师傅',
    '保洁': '清洁师傅',
  };

  // 各工种默认技能
  static const _defaultSkills = <String, List<String>>{
    '拆除师傅': ['墙体拆除', '旧装修拆除', '铲墙皮', '垃圾清运', '地面破除', '门窗拆除'],
    '水电师傅': ['水电改造', '管道安装', '电路布线', '开关插座'],
    '泥工师傅': ['地砖铺贴', '墙砖铺贴', '地面找平', '砌墙抹灰'],
    '防水师傅': ['厨卫防水', '阳台防水', '屋面防水', '地下室防潮'],
    '木工师傅': ['全屋定制', '衣柜橱柜', '吊顶安装'],
    '油漆师傅': ['墙面刷漆', '刮腻子', '艺术漆', '旧墙翻新'],
    '安装师傅': ['灯具安装', '五金安装', '卫浴安装'],
    '清洁师傅': ['开荒保洁', '全屋深度', '玻璃清洁'],
  };

  // 工种 emoji
  static const _tradeEmoji = <String, String>{
    '拆除师傅': '👷',
    '水电师傅': '🔌',
    '泥工师傅': '🧱',
    '防水师傅': '💧',
    '木工师傅': '🪚',
    '油漆师傅': '🎨',
    '安装师傅': '🔧',
    '清洁师傅': '🧹',
  };

  // 基于工种+姓名的稳定 picsum URL
  static List<String> _caseImages(WorkerDetail w) => List.generate(
    6,
    (i) => 'https://picsum.photos/seed/${w.name}_case$i/600/400',
  );

  static List<Review> _mockReviews(WorkerDetail w) => [
    Review(
      userName: '李先生',
      city: '杭州',
      rating: 5,
      text: '师傅手艺确实好，${w.skills.first}做得非常到位，现场也收拾得很干净，下次装修还找他！',
      photos: [
        'https://picsum.photos/seed/${w.name}_r1a/400/400',
        'https://picsum.photos/seed/${w.name}_r1b/400/400',
      ],
    ),
    Review(
      userName: '王女士',
      city: '上海',
      rating: 4,
      text:
          '整体满意，${w.skills.length > 1 ? w.skills[1] : w.skills.first}效果不错。中间有点小问题但师傅很快解决了，态度很好。',
      photos: ['https://picsum.photos/seed/${w.name}_r2a/400/400'],
    ),
    Review(
      userName: '张先生',
      city: '南京',
      rating: 5,
      text: '对比了好几家最终选的他，没让我失望。${w.skills.join('、')}都在行，价格也公道，强烈推荐！',
      photos: [
        'https://picsum.photos/seed/${w.name}_r3a/400/400',
        'https://picsum.photos/seed/${w.name}_r3b/400/400',
        'https://picsum.photos/seed/${w.name}_r3c/400/400',
      ],
    ),
  ];

  /// 从 mockWorkers 中动态构建 WorkerDetail
  WorkerDetail _buildFromMock(String workerName, String tradeKey) {
    final tradeLabel = _labelToTrade.entries
        .firstWhere(
          (e) => e.value == tradeKey,
          orElse: () => const MapEntry('', ''),
        )
        .key;
    final trade = tradeLabel.isNotEmpty
        ? Trade.values.firstWhere((t) => t.label == tradeLabel)
        : null;
    if (trade == null) return _fallbackFirst();

    final workers = mockWorkers[trade] ?? [];
    Worker? match;
    // 先精确匹配姓名，再模糊
    match = workers.cast<Worker?>().firstWhere(
      (w) => w!.name == workerName,
      orElse: () => null,
    );
    match ??= workers.isNotEmpty ? workers.first : null;
    if (match == null) return _fallbackFirst();

    return _workerToDetail(match, tradeKey);
  }

  WorkerDetail _workerToDetail(Worker w, String tradeKey) {
    final skills = _defaultSkills[tradeKey] ?? ['基础施工'];
    return WorkerDetail(
      name: w.name,
      trades: [tradeKey],
      rating: w.rating,
      completedOrders: w.completedProjects,
      years: w.experienceYears,
      positiveRate: w.creditScore > 0 ? w.creditScore.round() : 97,
      distanceKm: w.distance,
      avatarEmoji: _tradeEmoji[tradeKey] ?? '👷',
      skills: skills,
      matchReason:
          '系统根据您的装修需求和阶段为您推荐该师傅。${w.intro}，擅长${skills.join('、')}，从业${w.experienceYears}年经验丰富，累计完成${w.completedProjects}单，好评率${w.creditScore > 0 ? w.creditScore.round() : 97}%，距离您${w.distance}km。',
      reviews: _mockReviews(
        WorkerDetail(
          name: w.name,
          trades: [tradeKey],
          rating: w.rating,
          completedOrders: w.completedProjects,
          years: w.experienceYears,
          positiveRate: w.creditScore > 0 ? w.creditScore.round() : 97,
          distanceKm: w.distance,
          avatarEmoji: _tradeEmoji[tradeKey] ?? '👷',
          skills: skills,
          matchReason: '',
          reviews: const [],
        ),
      ),
    );
  }

  WorkerDetail _fallbackFirst() => _allWorkers.values.first;

  WorkerDetail _buildFromRemote(RemoteWorkerDirectoryProfile remote) {
    final tradeKey = _remoteTradeLabel(remote.primaryTrade);
    final skills = _defaultSkills[tradeKey] ?? ['基础施工'];
    final city = remote.serviceCity ?? '本地';
    final bio = remote.bio?.trim();
    final dailyRate = _formatDailyRate(remote.dailyRate);
    return WorkerDetail(
      name: remote.name,
      trades: [tradeKey],
      rating: 4.8,
      completedOrders: 0,
      years: remote.experienceYears,
      positiveRate: 97,
      distanceKm: widget.distance ?? 0,
      avatarEmoji: _tradeEmoji[tradeKey] ?? '👷',
      skills: skills,
      matchReason:
          '服务城市：$city。参考日薪：$dailyRate元/天。${bio?.isNotEmpty == true ? bio! : '该师傅资料来自平台服务端，已完成基础资料登记。'}',
      reviews: _mockReviews(
        WorkerDetail(
          name: remote.name,
          trades: [tradeKey],
          rating: 4.8,
          completedOrders: 0,
          years: remote.experienceYears,
          positiveRate: 97,
          distanceKm: widget.distance ?? 0,
          avatarEmoji: _tradeEmoji[tradeKey] ?? '👷',
          skills: skills,
          matchReason: '',
          reviews: const [],
        ),
      ),
    );
  }

  WorkerDetail _resolveDetail() {
    if (widget.remoteProfile != null) {
      return _buildFromRemote(widget.remoteProfile!);
    }

    // 1. 优先从 _allWorkers 精确匹配姓名
    WorkerDetail? direct = _allWorkers[widget.workerName];

    // 2. 姓名未命中，从 mockWorkers 动态构建（优先于工种回退，避免同名工种匹配到其他人）
    if (direct == null && widget.trade != null) {
      final tradeKey = _labelToTrade[widget.trade!.label];
      if (tradeKey != null) {
        direct = _buildFromMock(widget.workerName, tradeKey);
      }
    }

    // 3. 仍找不到，按工种从 _allWorkers 回退
    if (widget.trade != null && direct == null) {
      final candidates = <String>{
        '${widget.trade!.label}师傅',
        widget.trade!.label,
        _labelToTrade[widget.trade!.label] ?? '',
      };
      for (final d in _allWorkers.values) {
        if (d.trades.any((t) => candidates.contains(t))) {
          direct = d;
          break;
        }
      }
    }

    direct ??= _allWorkers.values.first;
    if (widget.distance != null) {
      direct = direct.copyWith(distanceKm: widget.distance!);
    }
    return direct;
  }

  String _remoteTradeLabel(String primaryTrade) {
    final value = primaryTrade.trim();
    if (value.contains('拆')) return '拆除师傅';
    if (value.contains('水电')) return '水电师傅';
    if (value.contains('防水')) return '防水师傅';
    if (value.contains('泥') || value.contains('瓦')) return '泥工师傅';
    if (value.contains('木')) return '木工师傅';
    if (value.contains('漆') || value.contains('油')) return '油漆师傅';
    if (value.contains('安装')) return '安装师傅';
    if (value.contains('洁') || value.contains('清')) return '清洁师傅';
    return value.endsWith('师傅') ? value : '$value师傅';
  }

  String _formatDailyRate(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  String _favoriteId(WorkerDetail detail) =>
      'renovation:${detail.name}:${detail.trades.join(",")}';

  Future<void> _toggleFavorite(WorkerDetail detail) async {
    if (_savingFavorite) return;
    final state = OwnerAppScope.of(context);
    final id = _favoriteId(detail);
    final wasFavorite = state.isFavorite(id);
    setState(() => _savingFavorite = true);
    try {
      await state.toggleFavorite(
        FavoriteWorker(
          id: id,
          name: detail.name,
          trade: detail.trades.first,
          city: state.profile.city,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(wasFavorite ? '已取消收藏' : '已收藏，可在我的收藏查看')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('收藏保存失败，请稍后重试')));
    } finally {
      if (mounted) setState(() => _savingFavorite = false);
    }
  }

  String _getTradeTag(WorkerDetail w) {
    final t = w.trades.first;
    if (t.contains('泥')) return '泥工';
    if (t.contains('拆除')) return '拆旧';
    if (t.contains('水电')) return '水电';
    if (t.contains('木工')) return '木工';
    if (t.contains('油漆')) return '油漆';
    if (t.contains('美缝')) return '美缝';
    if (t.contains('防水')) return '防水';
    return '施工';
  }

  @override
  Widget build(BuildContext context) {
    final detail = _resolveDetail();
    final state = OwnerAppScope.of(context);
    final favoriteSelected = state.isFavorite(_favoriteId(detail));

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '师傅详情',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: _textDark,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        backgroundColor: _bg,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              favoriteSelected
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: favoriteSelected ? _primary : _textDark,
              size: 22,
            ),
            onPressed: _savingFavorite ? null : () => _toggleFavorite(detail),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: _textDark, size: 22),
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('正在打开分享面板')));
              SharePlus.instance.share(
                ShareParams(
                  text: '推荐一位知底认证师傅：${detail.name}，评分 ${detail.rating}。',
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                // ── 1. 基础信息卡 ──
                _buildBasicCard(detail),
                // ── 2. 擅长领域 ──
                _buildSkills(detail),
                // ── 4. 匹配说明 ──
                _buildMatchReason(detail),
                // ── 4.5. 施工案例 ──
                _buildCasesSection(detail),
                // ── 5. 业主评价 ──
                _buildReviews(detail),
                // ── 6. 服务说明 ──
                _buildServiceInfo(detail),
                const SizedBox(height: 20),
              ],
            ),
          ),
          // ── 底部操作栏 ──
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ── 基础信息卡 ──
  Widget _buildBasicCard(WorkerDetail w) {
    // 高匹配判定：评分 >= 4.9 或 好评率 >= 99%
    final isTop = w.rating >= 4.9 || w.positiveRate >= 99;
    final badgeText = isTop ? '平台优选' : '高匹配';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像 + 信息
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F0EB),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      w.avatarEmoji,
                      style: const TextStyle(fontSize: 50),
                    ),
                  ),
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isTop
                            ? const Color(0xFFFF7A2F)
                            : const Color(0xFF4A90D9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (isTop)
                    Positioned(
                      left: -4,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x20000000),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.workspace_premium_rounded,
                              size: 9,
                              color: Colors.white,
                            ),
                            SizedBox(width: 2),
                            Text(
                              '金牌工人',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...w.trades.map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF7A2F).withAlpha(25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              t,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFF7A2F),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A90D9).withAlpha(18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '高匹配',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4A90D9),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 评分 + 接单量 + 从业年限 强化行
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7F0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          _buildStatItem(
                            '${w.rating}',
                            '分',
                            isHighlighted: true,
                          ),
                          _buildStatDivider(),
                          _buildStatItem('${w.completedOrders}', '单'),
                          _buildStatDivider(),
                          _buildStatItem('${w.years}', '年经验'),
                          _buildStatDivider(),
                          _buildStatItem('${w.positiveRate}%', '好评率'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 平台保障横幅
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF3E6), Color(0xFFFFF8F0)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x33FF7A2F)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  size: 16,
                  color: Color(0xFFFF7A2F),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '平台担保交易 · 不满意可协调处理',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE8650F),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 认证标签
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F6F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _CertTag(icon: Icons.verified_user, label: '实名认证'),
                _CertTag(icon: Icons.workspace_premium, label: '平台考核'),
                _CertTag(icon: Icons.shield, label: '已购保险'),
                _CertTag(icon: Icons.thumb_up_alt, label: '信用良好'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String value,
    String label, {
    bool isHighlighted = false,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: isHighlighted ? 16 : 14,
                  fontWeight: FontWeight.w800,
                  color: isHighlighted ? _primary : _textDark,
                ),
              ),
              if (isHighlighted)
                const Padding(
                  padding: EdgeInsets.only(bottom: 1),
                  child: Icon(Icons.star_rounded, size: 11, color: _star),
                ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: _textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 22, color: const Color(0x20FF6B00));
  }

  // ── 擅长领域 ──
  Widget _buildSkills(WorkerDetail w) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.build_circle_outlined, size: 18, color: _primary),
              SizedBox(width: 6),
              Text(
                '擅长领域',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: w.skills
                .map(
                  (s) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _primary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── 施工案例 ──
  Widget _buildCasesSection(WorkerDetail w) {
    final images = _caseImages(w);
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.photo_library_outlined, size: 18, color: _primary),
              SizedBox(width: 6),
              Text(
                '施工案例',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              Spacer(),
              Text('共6组', style: TextStyle(fontSize: 12, color: _textLight)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 220,
                  child: Image.network(
                    images[i],
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFFF0EDE8),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image,
                        size: 32,
                        color: _textLight,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 匹配说明 ──
  Widget _buildMatchReason(WorkerDetail w) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 主视觉推荐理由
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _primaryLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '系统优选',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '系统已基于您的【工种需求 + 装修阶段】为您优选该师傅',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 匹配原因行
          Text(
            '${_getTradeTag(w)}经验丰富 · 累计${w.completedOrders}单 · 好评率${w.positiveRate}% · 距您${w.distanceKm}km',
            style: const TextStyle(fontSize: 13, color: _textMid, height: 1.7),
          ),
          const SizedBox(height: 8),
          Text(
            w.matchReason,
            style: const TextStyle(fontSize: 13, color: _textMid, height: 1.7),
          ),
          const SizedBox(height: 10),
          // 距离强调
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F8FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0x304A90D9)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: Color(0xFF4A90D9),
                ),
                const SizedBox(width: 4),
                Text(
                  '距您 ${w.distanceKm}km',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A90D9),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '| 即时上门服务',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B9BD2)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 业主评价 ──
  Widget _buildReviews(WorkerDetail w) {
    // 好评关键词
    const keywords = ['靠谱', '准时', '干净', '无加价'];

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.rate_review_outlined, size: 18, color: _primary),
              SizedBox(width: 6),
              Text(
                '真实业主评价',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 好评关键词标签
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: keywords
                .map(
                  (k) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FBF0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x304CAF50)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.thumb_up_rounded,
                          size: 12,
                          color: Color(0xFF4CAF50),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          k,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          ...List.generate(w.reviews.length, (i) {
            final r = w.reviews[i];
            return Column(
              children: [
                _buildReviewItem(r),
                if (i < w.reviews.length - 1)
                  const Divider(height: 24, color: ZdColors.divider),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReviewItem(Review r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EDE8),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.person, size: 18, color: _textLight),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.userName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    r.city,
                    style: const TextStyle(fontSize: 11, color: _textLight),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                ...List.generate(
                  5,
                  (s) => Icon(
                    s < r.rating.floor()
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 14,
                    color: _star,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          r.text,
          style: const TextStyle(fontSize: 13, color: _textMid, height: 1.6),
        ),
        const SizedBox(height: 10),
        Row(
          children: r.photos
              .map(
                (p) => ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: Image.network(
                      p,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFFF5F2EE),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image,
                          size: 20,
                          color: _textLight,
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  // ── 服务说明 ──
  Widget _buildServiceInfo(WorkerDetail w) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: _primary),
              SizedBox(width: 6),
              Text(
                '服务说明',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _BuildServiceRow(
            Icons.check_circle_outline,
            '服务范围',
            w.trades
                .map((t) {
                  switch (t) {
                    case '拆除师傅':
                      return '拆除/砸墙/铲墙皮/垃圾清运/门窗拆除';
                    case '拆除工':
                      return '拆除/砸墙/垃圾清运';
                    case '水电工':
                      return '水电改造/布线/防水施工';
                    case '泥瓦工':
                      return '贴砖/砌墙/地面找平/砌墙抹灰';
                    case '木工':
                      return '吊顶/柜体/木作定制';
                    case '油漆工':
                      return '墙面处理/喷涂/墙纸';
                    case '安装工':
                      return '橱柜/卫浴/灯具安装';
                    case '保洁':
                      return '开荒保洁/精保/除醛';
                    default:
                      return '基础施工';
                  }
                })
                .join('、'),
          ),
          const SizedBox(height: 10),
          const _BuildServiceRow(
            Icons.attach_money_rounded,
            '费用说明',
            '平台统一标准价，无隐藏收费，施工前确认报价',
          ),
          const SizedBox(height: 10),
          const _BuildServiceRow(
            Icons.security_rounded,
            '施工保障',
            '不满意可申诉，平台介入协调，全程保障您的权益',
          ),
        ],
      ),
    );
  }

  // ── 底部操作栏 ──
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 紧迫感引导文案
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.access_time, size: 13, color: Color(0xFFFF7A2F)),
                  SizedBox(width: 4),
                  Text(
                    '已有326人正在预约该类型师傅',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFFF7A2F),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                // 在线咨询 - 弱化
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            WorkerChatPage(workerName: widget.workerName),
                      ),
                    ),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: ZdColors.background,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '客服',
                        style: TextStyle(fontSize: 14, color: _textMid),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 立即预约 - 强化
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () async {
                      final d = _resolveDetail();
                      final phaseIndex = _tradeToPhaseIndex(d.trades.first);
                      final appState = OwnerAppScope.of(context);
                      appState.bookWorker(
                        BookedWorker(
                          id: 'wrk-${d.name}',
                          name: d.name,
                          trade: d.trades.first,
                          phaseName: _phaseNames[phaseIndex],
                          phaseIndex: phaseIndex,
                          rating: d.rating,
                          completedOrders: d.completedOrders,
                          years: d.years,
                          avatarEmoji: d.avatarEmoji,
                          skills: d.skills,
                          distance: d.distanceKm,
                        ),
                      );
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingSuccessPage(
                            workerName: d.name,
                            workerJob: d.trades.first,
                            rating: d.rating,
                            renovationStage: '基础施工',
                            tradeType: d.trades.first,
                            serviceAddress: '您提交的服务地址',
                            estimatedTime: '下单后30分钟内',
                          ),
                        ),
                      );
                      if (result == true && mounted) {
                        Navigator.of(context).pop(true);
                      }
                    },
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5A00), ZdColors.primary],
                        ),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF57C00).withAlpha(77),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '立即预约师傅',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 服务说明行 ──
class _BuildServiceRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _BuildServiceRow(this.icon, this.title, this.content);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _primary),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$title：',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                ),
                TextSpan(
                  text: content,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _textMid,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── 认证标签 ──
class _CertTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CertTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF2EAF5C)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _textMid,
          ),
        ),
      ],
    );
  }
}
