import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/renovation.dart';
import '../../app/owner_app_scope.dart';
import '../../app/owner_models.dart';
import 'worker_chat_page.dart';
import 'booking_success_page.dart';
import '../../design/tokens.dart';
import '../../services/auth_api_client.dart';
import '../../services/worker_directory_api_client.dart';
import '../../services/worker_case_api_client.dart';

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
const _allWorkers = <String, WorkerDetail>{};

// ══════════════════════════════════════════
// 师傅详情页
// ══════════════════════════════════════════
class WorkerDetailPage extends StatefulWidget {
  final String workerName;
  final Trade? trade;
  final double? distance;
  final RemoteWorkerDirectoryProfile? remoteProfile;
  final WorkerCaseApi? caseApi;

  const WorkerDetailPage({
    super.key,
    required this.workerName,
    this.trade,
    this.distance,
    this.remoteProfile,
    this.caseApi,
  });

  @override
  State<WorkerDetailPage> createState() => _WorkerDetailPageState();
}

class _WorkerDetailPageState extends State<WorkerDetailPage> {
  bool _savingFavorite = false;
  bool _booking = false;
  bool _casesLoading = false;
  String? _casesError;
  List<RemoteWorkerCase> _remoteCases = const [];

  WorkerCaseApi get _caseApi => widget.caseApi ?? WorkerCaseApiClient();

  @override
  void initState() {
    super.initState();
    if (widget.remoteProfile != null) {
      _casesLoading = true;
      Future<void>.microtask(_loadRemoteCases);
    }
  }

  @override
  void didUpdateWidget(covariant WorkerDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remoteProfile?.userId != widget.remoteProfile?.userId ||
        oldWidget.caseApi != widget.caseApi) {
      _remoteCases = const [];
      _casesError = null;
      _casesLoading = widget.remoteProfile != null;
      if (widget.remoteProfile != null) {
        Future<void>.microtask(_loadRemoteCases);
      }
    }
  }

  Future<void> _loadRemoteCases() async {
    final workerId = widget.remoteProfile?.userId;
    if (workerId == null) return;
    try {
      final values = await _caseApi.listPublicCases(workerId);
      if (!mounted || widget.remoteProfile?.userId != workerId) return;
      setState(() {
        _remoteCases = values;
        _casesError = null;
      });
    } catch (_) {
      if (!mounted || widget.remoteProfile?.userId != workerId) return;
      setState(() => _casesError = '施工案例加载失败');
    } finally {
      if (mounted && widget.remoteProfile?.userId == workerId) {
        setState(() => _casesLoading = false);
      }
    }
  }

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
    return _fallbackFirst();
  }

  WorkerDetail _fallbackFirst() => WorkerDetail(
    name: widget.workerName,
    trades: const [],
    rating: 0.0,
    completedOrders: 0,
    years: 0,
    positiveRate: 0,
    distanceKm: 0.0,
    avatarEmoji: '👷',
    skills: const [],
    matchReason: '',
    reviews: const [],
  );

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

    direct ??= _fallbackFirst();
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
          trade: detail.trades.isEmpty ? '施工' : detail.trades.first,
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
    if (w.trades.isEmpty) return '施工';
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
    if (widget.remoteProfile != null) return _buildRemoteCasesSection();
    final images = _caseImages(w);
    return Container(
      key: const Key('worker-case-mock-gallery'),
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

  Widget _buildRemoteCasesSection() {
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
          Row(
            children: [
              const Icon(
                Icons.photo_library_outlined,
                size: 18,
                color: _primary,
              ),
              const SizedBox(width: 6),
              const Text(
                '施工案例',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const Spacer(),
              if (!_casesLoading && _casesError == null)
                Text(
                  '共${_remoteCases.length}组',
                  style: const TextStyle(fontSize: 12, color: _textLight),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_casesLoading)
            const Center(child: CircularProgressIndicator())
          else if (_casesError != null)
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() => _casesLoading = true);
                  _loadRemoteCases();
                },
                icon: const Icon(Icons.refresh),
                label: Text(_casesError!),
              ),
            )
          else if (_remoteCases.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('暂无施工案例', style: TextStyle(color: _textLight)),
              ),
            )
          else
            SizedBox(
              height: 230,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _remoteCases.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = _remoteCases[index];
                  return SizedBox(
                    width: 250,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item.imageUrls.first,
                            key: Key('worker-case-image-${item.id}'),
                            width: 250,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 250,
                              height: 140,
                              color: const Color(0xFFF0EDE8),
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.serviceCity} · ${item.completionYear}年 · ${item.description}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: _textMid),
                        ),
                      ],
                    ),
                  );
                },
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
                      if (_booking) return;
                      final d = _resolveDetail();
                      final trade = d.trades.isEmpty ? '施工' : d.trades.first;
                      final phaseIndex = _tradeToPhaseIndex(trade);
                      final appState = OwnerAppScope.of(context);
                      final remoteProfile = widget.remoteProfile;
                      final bookedWorker = BookedWorker(
                        id: remoteProfile?.userId ?? 'wrk-${d.name}',
                        name: d.name,
                        trade: trade,
                        phaseName: _phaseNames[phaseIndex],
                        phaseIndex: phaseIndex,
                        rating: d.rating,
                        completedOrders: d.completedOrders,
                        years: d.years,
                        avatarEmoji: d.avatarEmoji,
                        skills: d.skills,
                        distance: d.distanceKm,
                      );
                      setState(() => _booking = true);
                      try {
                        await appState.bookWorker(
                          bookedWorker,
                          remoteWorkerUserId: remoteProfile?.userId,
                          serviceCity: remoteProfile?.serviceCity,
                        );
                      } on AuthApiException catch (error) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(error.message)));
                        return;
                      } catch (_) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('预约失败，请稍后重试')),
                        );
                        return;
                      } finally {
                        if (mounted) setState(() => _booking = false);
                      }
                      if (!mounted) return;
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingSuccessPage(
                            workerName: d.name,
                            workerJob: trade,
                            rating: d.rating,
                            renovationStage: '基础施工',
                            tradeType: trade,
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
                      child: Text(
                        _booking ? '预约中...' : '立即预约师傅',
                        style: const TextStyle(
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
