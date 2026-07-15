import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/owner_app_scope.dart';
import '../../../app/owner_models.dart';
import '../../../data/price_standards.dart';
import '../../price/worker_quote_page.dart';

class WorkerDetailPage extends StatefulWidget {
  final String? workerId;
  final String name;
  final bool fromAi;
  final String? workerJob;

  const WorkerDetailPage({
    super.key,
    this.workerId,
    required this.name,
    this.fromAi = false,
    this.workerJob,
  });

  String get resolvedWorkerId =>
      workerId ??
      'legacy:${Uri.encodeComponent(name)}:${Uri.encodeComponent(workerJob ?? '师傅')}';

  @override
  State<WorkerDetailPage> createState() => _WorkerDetailPageState();

  String get _title {
    switch (workerJob) {
      case '拆除师傅':
        return '拆除师傅详情';
      case '油漆师傅':
        return '油漆师傅详情';
      case '美缝师傅':
        return '美缝师傅详情';
      case '室内设计师':
      case '软装设计师':
      case '全屋定制设计师':
        return '设计师详情';
      case '水电验收':
      case '泥工验收':
      case '综合验收':
        return '验收师详情';
      default:
        return '师傅详情';
    }
  }

  IconData get _personIcon {
    switch (workerJob) {
      case '拆除师傅':
        return Icons.construction;
      case '油漆师傅':
        return Icons.format_paint;
      case '美缝师傅':
        return Icons.brush;
      case '室内设计师':
      case '软装设计师':
      case '全屋定制设计师':
        return Icons.design_services;
      case '水电验收':
      case '泥工验收':
      case '综合验收':
        return Icons.fact_check_outlined;
      default:
        return Icons.person_rounded;
    }
  }
}

class _WorkerDetailPageState extends State<WorkerDetailPage> {
  bool _savingFavorite = false;

  Future<void> _toggleFavorite() async {
    if (_savingFavorite) return;
    final state = OwnerAppScope.of(context);
    setState(() => _savingFavorite = true);
    try {
      await state.toggleFavorite(
        FavoriteWorker(
          id: widget.resolvedWorkerId,
          name: widget.name,
          trade: widget.workerJob ?? '师傅',
          city: state.profile.city,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('收藏保存失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _savingFavorite = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoriteSelected = OwnerAppScope.of(
      context,
    ).isFavorite(widget.resolvedWorkerId);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget._title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
        elevation: 0.5,
        actions: [
          _FavoriteAction(
            selected: favoriteSelected,
            saving: _savingFavorite,
            onPressed: _toggleFavorite,
          ),
          TextButton.icon(
            onPressed: () {
              SharePlus.instance.share(
                ShareParams(
                  text:
                      '推荐一位${widget.workerJob ?? "师傅"}：${widget.name}，来看看合不合适！',
                ),
              );
            },
            icon: const Icon(Icons.share_rounded, size: 16),
            label: const Text(
              '分享',
              style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          _HeaderSection(
            name: widget.name,
            personIcon: widget._personIcon,
            workerJob: widget.workerJob,
          ),
          if (widget.fromAi)
            _MatchBanner(name: widget.name)
          else
            const _RankBanner(),
          _SkillsSection(workerJob: widget.workerJob),
          _AboutSection(workerJob: widget.workerJob),
          _PriceDetailSection(workerJob: widget.workerJob),
          _ProjectGallery(workerJob: widget.workerJob),
          _ReviewsSection(),
        ],
      ),
      bottomNavigationBar: _BottomActionBar(
        workerId: widget.resolvedWorkerId,
        workerName: widget.name,
        workerJob: widget.workerJob,
        favoriteSelected: favoriteSelected,
        favoriteSaving: _savingFavorite,
        onToggleFavorite: _toggleFavorite,
      ),
    );
  }
}

class _FavoriteAction extends StatelessWidget {
  const _FavoriteAction({
    required this.selected,
    required this.saving,
    required this.onPressed,
    this.buttonKey,
  });

  final bool selected;
  final bool saving;
  final VoidCallback onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: buttonKey ?? const Key('worker-favorite-button'),
      tooltip: selected ? '取消收藏' : '收藏',
      onPressed: saving ? null : onPressed,
      icon: saving
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              selected ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: selected ? const Color(0xFFFF6A1A) : null,
            ),
    );
  }
}

// ========== 头部信息区 ==========
class _HeaderSection extends StatelessWidget {
  final String name;
  final IconData personIcon;
  final String? workerJob;
  const _HeaderSection({
    required this.name,
    this.personIcon = Icons.person_rounded,
    this.workerJob,
  });

  String get _jobLabel => workerJob ?? '师傅';
  String get _badgeLabel {
    if (workerJob == null) return '金牌师傅';
    if (['室内设计师', '软装设计师', '全屋定制设计师'].contains(workerJob)) return '金牌设计师';
    if (['水电验收', '泥工验收', '综合验收'].contains(workerJob)) return '金牌验收师';
    return '金牌师傅';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像 + 姓名 + 金牌标签
          Row(
            children: [
              // 头像
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEE3),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  personIcon,
                  size: 48,
                  color: const Color(0xFFFF6A1A),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          height: 22,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9800),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 11,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                _badgeLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_jobLabel | 8年经验 | 深圳市',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF999999),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // 认证标识
                    _CertBadge(label: '平台认证'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 认证三项
          const Row(
            children: [
              _CertItem(icon: Icons.verified_user_rounded, label: '实名认证'),
              SizedBox(width: 20),
              _CertItem(icon: Icons.workspace_premium_rounded, label: '技能认证'),
              SizedBox(width: 20),
              _CertItem(icon: Icons.shield_rounded, label: '平台审核'),
              SizedBox(width: 20),
              _CertItem(icon: Icons.verified_rounded, label: '已购保险'),
            ],
          ),

          const SizedBox(height: 20),

          // 四宫格数据
          const Row(
            children: [
              Expanded(
                child: _MetricBox(
                  icon: Icons.star_rounded,
                  value: '4.8',
                  label: '综合评分',
                  color: Color(0xFFFF9800),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _MetricBox(
                  icon: Icons.check_circle_outline_rounded,
                  value: '200+',
                  label: '完成订单',
                  color: Color(0xFF4CAF50),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _MetricBox(
                  icon: Icons.thumb_up_alt_rounded,
                  value: '98%',
                  label: '好评率',
                  color: Color(0xFF2196F3),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _MetricBox(
                  icon: Icons.access_time_rounded,
                  value: '2年',
                  label: '平台服务',
                  color: Color(0xFF9C27B0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CertBadge extends StatelessWidget {
  final String label;
  const _CertBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 12,
            color: Color(0xFFFF9800),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF333333)),
          ),
        ],
      ),
    );
  }
}

class _CertItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _CertItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF4CAF50)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF333333)),
        ),
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MetricBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }
}

// ========== 匹配推荐条 ==========
class _MatchBanner extends StatelessWidget {
  final String name;
  const _MatchBanner({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '根据您的诉求，推荐$name为合适人选',
              style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: Color(0xFF999999),
          ),
        ],
      ),
    );
  }
}

// ========== 业主评价排名条 ==========
class _RankBanner extends StatelessWidget {
  const _RankBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.emoji_events_rounded, size: 18, color: Color(0xFFFF9800)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '该师傅经过业主评价排名靠前，平台无法干涉',
              style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
            ),
          ),
        ],
      ),
    );
  }
}

// ========== 擅长技能 ==========
class _SkillsSection extends StatelessWidget {
  final String? workerJob;
  const _SkillsSection({this.workerJob});

  List<String> get _skills {
    switch (workerJob) {
      case '拆除师傅':
        return ['墙体拆除', '旧装修拆除', '铲墙皮', '拆吊顶', '拆地板', '垃圾清运'];
      case '油漆师傅':
        return ['墙面刷漆', '木器漆', '艺术漆', '硅藻泥', '旧墙翻新', '补墙'];
      case '美缝师傅':
        return ['瓷砖美缝', '环氧彩砂', '马贝填缝', '美容胶收边', '防水胶收边', '台面美容'];
      case '水电师傅':
        return ['水电改造', '管道维修', '电路布线', '强弱电', '排水系统'];
      case '泥工师傅':
        return ['贴砖', '砌墙', '地面找平', '美缝', '大理石铺装'];
      case '防水师傅':
        return ['厨卫防水', '阳台防水', '屋面防水', '地下室防潮', '堵漏', '外墙防水'];
      case '室内设计师':
      case '软装设计师':
      case '全屋定制设计师':
        return ['全屋设计', '户型优化', '效果图制作', '软装搭配', '收纳规划', '灯光设计'];
      case '水电验收':
      case '泥工验收':
      case '综合验收':
        return ['节点验收', '质量检测', '空鼓检查', '隐蔽工程验收', '竣工验收', '问题诊断'];
      default:
        return ['吊顶', '衣柜定制', '橱柜安装', '隔断', '精细木作'];
    }
  }

  String get _title {
    switch (workerJob) {
      default:
        return '擅长技能';
    }
  }

  String get _moreLabel => '全部技能 >';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Text(
                  _moreLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF999999),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _skills
                .map(
                  (s) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF333333),
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
}

// ========== 介绍 ==========
class _AboutSection extends StatelessWidget {
  final String? workerJob;
  const _AboutSection({this.workerJob});

  String get _jobLabel => workerJob ?? '师傅';

  String get _title {
    switch (workerJob) {
      case '拆除师傅':
        return '拆除师傅介绍';
      case '油漆师傅':
        return '油漆师傅介绍';
      case '美缝师傅':
        return '美缝师傅介绍';
      case '室内设计师':
      case '软装设计师':
      case '全屋定制设计师':
        return '设计师介绍';
      case '水电验收':
      case '泥工验收':
      case '综合验收':
        return '验收师介绍';
      default:
        return '师傅介绍';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '从事$_jobLabel行业8年，经验丰富，做事认真负责，注重细节，客户满意度高。擅长全屋定制，从量尺到安装全程亲历亲为，让每一位业主满意。',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.thumb_up_alt_rounded,
                  value: '200+',
                  label: '完成订单',
                  color: Color(0xFF2196F3),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _StatItem(
                  icon: Icons.shield_rounded,
                  value: '98%',
                  label: '好评率',
                  color: Color(0xFF4CAF50),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _StatItem(
                  icon: Icons.favorite_rounded,
                  value: '50+',
                  label: '回头客',
                  color: Color(0xFFFF5722),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _StatItem(
                  icon: Icons.emoji_events_rounded,
                  value: '0',
                  label: '投诉记录',
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }
}

// ========== 工价详情 ==========
class _PriceDetailSection extends StatelessWidget {
  final String? workerJob;
  const _PriceDetailSection({this.workerJob});

  List<_PriceItem> get _priceItems {
    switch (workerJob) {
      case '美缝师傅':
        return const [
          _PriceItem(
            '瓷砖美缝',
            '¥25/米',
            '适用于瓷砖缝隙填充美化，采用高品质美缝剂，防水防霉，颜色丰富可选。包含基层清理、缝隙填充、压缝收光等全流程施工。',
            ['基层清理', '缝隙填充', '压缝收光', '养护完成'],
          ),
          _PriceItem(
            '环氧彩砂',
            '¥45/米',
            '采用进口环氧彩砂材料，硬度高、附着力强，适合高档装修。耐磨耐酸碱，使用寿命长达10年以上。',
            ['基层清理', '材料搅拌', '彩砂填充', '刮平压实', '清洗养护'],
          ),
          _PriceItem(
            '马贝填缝',
            '¥38/米',
            '意大利马贝品牌填缝剂，色彩细腻均匀，适合各类瓷砖填缝。施工精细，接缝平整光滑，不脱落不开裂。',
            ['缝隙清理', '材料调制', '填缝施工', '表面清洁', '固化养护'],
          ),
          _PriceItem(
            '美容胶收边',
            '¥30/米',
            '对台面、踢脚线、门套等收边位置进行美容胶封边处理。防霉防水，线条顺直美观，提升细节品质。',
            ['收边清理', '胶枪注胶', '刮平修整', '固化检查'],
          ),
          _PriceItem(
            '防水胶收边',
            '¥35/米',
            '针对厨卫阳台等潮湿区域的收边防水处理，采用专业防水密封胶。弹性好不开裂，有效阻隔水汽渗透。',
            ['基层干燥', '打胶施工', '抹平压实', '防水测试'],
          ),
          _PriceItem(
            '台面美容',
            '¥200/项',
            '针对石英石、大理石台面进行抛光翻新、划痕修复、接缝打磨等美容处理。恢复台面光泽度，延长使用寿命。',
            ['划痕检查', '打磨抛光', '接缝处理', '镜面修复'],
          ),
        ];
      case '拆除师傅':
        return const [
          _PriceItem(
            '墙体拆除',
            '¥60/平米',
            '专业拆除非承重墙体，含切割、破碎、清渣全流程。施工前做好防护措施，确保结构安全，噪音粉尘控制到位。',
            ['现场防护', '切割分离', '逐段拆除', '废料清运'],
          ),
          _PriceItem(
            '旧装修拆除',
            '¥40/平米',
            '包含旧瓷砖、地板、吊顶、柜体等全面拆除清理。分类堆放建筑垃圾，方便后续清运，不损坏保留部分。',
            ['分类评估', '逐项拆除', '垃圾分类', '装车清运'],
          ),
          _PriceItem(
            '铲墙皮',
            '¥15/平米',
            '铲除旧墙面腻子层、涂料层至基层，为重新批灰刷漆做准备。施工细致，不留残留，基层处理干净平整。',
            ['墙面湿润', '铲除旧层', '基层清理', '检查验收'],
          ),
          _PriceItem(
            '拆吊顶',
            '¥25/平米',
            '拆除原有吊顶及龙骨结构，包含石膏板、铝扣板等各类吊顶。注意保护线路管道，避免损坏隐藏设施。',
            ['断电保护', '面板拆除', '龙骨拆除', '顶面清理'],
          ),
          _PriceItem(
            '拆地板',
            '¥20/平米',
            '拆除复合地板、实木地板、瓷砖地面等。分类拆解，保持地面基层完整，便于后续重新铺装。',
            ['踢脚线拆除', '地板起撬', '基层清理', '分类堆放'],
          ),
          _PriceItem(
            '垃圾清运',
            '¥300-500/车',
            '装修垃圾装车外运至指定消纳场所。按车次计费，含装车人工，确保现场清理干净，不留残余。',
            ['垃圾装袋', '搬运上车', '运输处置', '现场清扫'],
          ),
        ];
      case '油漆师傅':
        return const [
          _PriceItem(
            '墙面刷漆',
            '¥30/平米',
            '包含基层处理、腻子批刮、打磨、底漆面漆涂刷全套工序。采用环保品牌乳胶漆，色彩均匀，漆面光滑细腻。',
            ['基层处理', '腻子批刮', '打磨平整', '底漆涂刷', '面漆涂刷'],
          ),
          _PriceItem(
            '木器漆',
            '¥50/平米',
            '针对木门、柜体、家具等木制品进行刷漆翻新。含打磨、底漆、面漆多道工序，漆面光泽饱满，手感顺滑。',
            ['表面打磨', '底漆涂刷', '再次打磨', '面漆涂刷', '光泽处理'],
          ),
          _PriceItem(
            '艺术漆',
            '¥80/平米',
            '多种艺术效果可选：肌理漆、天鹅绒、金属漆、仿石漆等。由资深技师手工打造，每面墙都是独一无二的艺术品。',
            ['基层处理', '底色涂刷', '纹理制作', '面层罩光', '效果验收'],
          ),
          _PriceItem(
            '硅藻泥',
            '¥65/平米',
            '环保硅藻泥墙面施工，具有吸附甲醛、调节湿度、防火阻燃等功能。多种肌理纹理可选，天然环保无污染。',
            ['基层找平', '底涂施工', '硅藻泥批刮', '纹理造型', '干燥固化'],
          ),
          _PriceItem(
            '旧墙翻新',
            '¥35/平米',
            '针对旧墙面起皮、开裂、泛黄等问题进行修复翻新。含铲除旧层、裂缝修补、重新批灰刷漆，让旧墙焕然一新。',
            ['铲除旧层', '裂缝修补', '重新批灰', '打磨上漆'],
          ),
          _PriceItem(
            '补墙',
            '¥60-120/处',
            '局部墙体破损修补，包括孔洞填补、裂缝修复、墙角修复等。按破损面积和难度计费，修复后与原墙面无色差。',
            ['破损清理', '填补材料', '刮平修整', '表面处理'],
          ),
        ];
      case '水电师傅':
        return const [
          _PriceItem(
            '水电改造',
            '¥80-120/平米',
            '全屋水电线路重新规划铺设，含开槽、布管、穿线、安装底盒等。点位布局合理，管线走向规范，符合国标要求。',
            ['现场勘测', '开槽布管', '穿线布管', '安装底盒', '打压测试'],
          ),
          _PriceItem(
            '管道维修',
            '¥150/处',
            '上下水管道渗漏、堵塞、破裂等故障维修。快速定位问题点，采用热熔焊接或管件更换，确保不再漏水。',
            ['定位检测', '关阀断水', '管件更换', '打压试漏'],
          ),
          _PriceItem(
            '电路布线',
            '¥45/点',
            '按点位计费，含开槽、布管、穿线、安装插座开关面板。线径适配，强弱电分离，安全规范施工。',
            ['点位确认', '开槽走管', '布管穿线', '安装面板'],
          ),
          _PriceItem(
            '强弱电',
            '¥60/点',
            '弱电点位（网线、电视线、音响线等）单独布线安装。强弱电保持安全距离，避免信号干扰，隐蔽工程拍照留档。',
            ['走线规划', '分管铺设', '间距控制', '标识留档'],
          ),
          _PriceItem(
            '排水系统',
            '¥200/项',
            '厨卫阳台排水管道设计改造，含存水弯安装、坡度调整、防水处理。排水通畅无异味，杜绝返水隐患。',
            ['管道设计', '存水弯安装', '坡度调整', '通水测试'],
          ),
        ];
      case '泥工师傅':
        return const [
          _PriceItem(
            '贴砖',
            '¥50/平米',
            '墙地面瓷砖铺贴，含找平、抹灰、铺贴、填缝全套工序。使用水平仪校准，缝隙均匀，空鼓率低于国家标准。',
            ['基层找平', '涂抹砂浆', '铺贴瓷砖', '填缝处理', '清洁验收'],
          ),
          _PriceItem(
            '砌墙',
            '¥120/平米',
            '轻质砖或红砖砌筑隔墙，含拉结筋植筋、门洞过梁、顶部斜砌。墙体垂直平整，结构稳固安全。',
            ['测量放线', '植筋加固', '逐层砌筑', '顶部斜砌', '挂网抹灰'],
          ),
          _PriceItem(
            '地面找平',
            '¥25/平米',
            '水泥砂浆地面找平，为后续铺设地板或地砖做准备。使用水平仪多点校准，误差控制在3mm以内。',
            ['标高校准', '砂浆铺设', '刮平压实', '养护固化'],
          ),
          _PriceItem(
            '美缝',
            '¥20/米',
            '瓷砖美缝施工，色彩搭配美观，防水防霉易清洁。施工前深度清理砖缝，确保美缝材料与瓷砖牢固结合。',
            ['缝隙清理', '美缝打胶', '压缝修整', '表面清洁'],
          ),
          _PriceItem(
            '大理石铺装',
            '¥180/平米',
            '天然大理石、花岗岩等石材铺装，含切割、打磨、铺贴、抛光等工序。纹路对接自然，拼缝细密，彰显高端品质。',
            ['基层处理', '切割下料', '铺贴安装', '打磨抛光', '晶面处理'],
          ),
        ];
      case '防水师傅':
        return const [
          _PriceItem(
            '厨卫防水',
            '¥45/平米',
            '厨房卫生间地面及墙面防水处理，采用聚合物水泥防水涂料。涂刷2-3遍，墙角管根加强处理，闭水试验24小时验收。',
            ['基层清理', '节点处理', '防水涂刷', '闭水试验'],
          ),
          _PriceItem(
            '阳台防水',
            '¥40/平米',
            '阳台地面墙面防水施工，含基层清理、节点处理、防水涂刷、保护层等。有效防止渗漏，保护楼下邻居不受影响。',
            ['基层清理', '节点处理', '防水涂刷', '保护层施工'],
          ),
          _PriceItem(
            '屋面防水',
            '¥55/平米',
            '屋顶屋面防水施工，采用SBS改性沥青卷材或聚氨酯涂料。含基层处理、铺贴/涂刷、封边等，质保5年以上。',
            ['基层处理', '卷材铺贴', '封边处理', '淋水测试'],
          ),
          _PriceItem(
            '地下室防潮',
            '¥65/平米',
            '针对地下室潮湿渗水问题进行专业防潮处理。负压防水工艺，阻断外部水汽渗透，营造干燥宜居空间。',
            ['基层处理', '负压防水', '多层涂刷', '养护固化'],
          ),
          _PriceItem(
            '堵漏',
            '¥80/处',
            '针对局部渗漏点进行快速堵漏处理，采用注浆或堵漏王等专业材料。精准定位漏点，效果立竿见影，不破坏原有结构。',
            ['漏点定位', '注浆封堵', '表面修整', '复查验证'],
          ),
          _PriceItem(
            '外墙防水',
            '¥50/平米',
            '外墙渗水修复防水施工，含裂缝修补、防水涂刷、罩面处理等。采用耐候性外墙专用防水涂料，抗紫外线耐老化。',
            ['裂缝修补', '防水涂刷', '罩面处理', '淋水测试'],
          ),
        ];
      case '室内设计师':
      case '软装设计师':
      case '全屋定制设计师':
        return const [
          _PriceItem(
            '全屋设计',
            '¥120-200/平米',
            '提供完整全屋设计方案，含平面布局、效果图、施工图、软装搭配方案。设计师一对一服务，沟通修改至满意为止。',
            ['需求沟通', '平面布局', '效果图制作', '施工图深化'],
          ),
          _PriceItem(
            '户型优化',
            '¥80-150/平米',
            '针对户型缺陷进行专业优化设计，提高空间利用率和居住舒适度。含多方案比选、动线分析、收纳规划等。',
            ['现场量房', '方案比选', '动线分析', '定稿交付'],
          ),
          _PriceItem(
            '效果图制作',
            '¥500-800/张',
            '3D效果图制作，真实还原设计效果。含材质贴图、灯光渲染、家具软装搭配，所见即所得，帮助业主直观决策。',
            ['建模搭建', '材质贴图', '灯光渲染', '后期出图'],
          ),
          _PriceItem(
            '软装搭配',
            '¥3000/单',
            '全屋软装搭配方案设计，含家具、窗帘、灯具、饰品等选型建议。提供采购清单和搭配效果图，一站式软装设计服务。',
            ['风格定位', '选型搭配', '采购清单', '摆场指导'],
          ),
          _PriceItem(
            '收纳规划',
            '¥50/平米',
            '针对全屋收纳空间进行专业规划设计，含衣柜、橱柜、储物间等。最大化利用每一寸空间，让家井井有条。',
            ['空间测量', '需求分析', '方案设计', '清单交付'],
          ),
          _PriceItem(
            '灯光设计',
            '¥60/平米',
            '专业的家居灯光设计方案，含主灯、辅助灯、氛围灯的布局和选型。营造层次丰富、温馨舒适的居家光环境。',
            ['空间分析', '布灯规划', '选型建议', '效果模拟'],
          ),
        ];
      case '水电验收':
      case '泥工验收':
      case '综合验收':
        return const [
          _PriceItem(
            '节点验收',
            '¥300/次',
            '针对单一施工节点（水电、泥工、木工等）进行专业质量验收。检查工艺标准、材料质量、施工规范，出具验收报告。',
            ['现场勘查', '逐项检查', '问题记录', '验收报告'],
          ),
          _PriceItem(
            '质量检测',
            '¥500/次',
            '使用专业检测仪器进行全面质量检测，含空鼓检测、水平度检测、水电线路检测等。数据化呈现检测结果，问题一目了然。',
            ['仪器检测', '数据记录', '问题标注', '检测报告'],
          ),
          _PriceItem(
            '空鼓检查',
            '¥300/次',
            '使用空鼓锤和专业仪器对全屋瓷砖进行空鼓率检测。逐块检查登记，出具空鼓率统计报告，保障装修质量。',
            ['逐块敲击', '空鼓标记', '数据统计', '检查报告'],
          ),
          _PriceItem(
            '隐蔽工程验收',
            '¥400/次',
            '针对水电线路、防水层等隐蔽工程进行封板前验收。检查走线规范、材料规格、施工工艺，拍照留档，杜绝后患。',
            ['管线检查', '防水检查', '拍照留档', '验收报告'],
          ),
          _PriceItem(
            '竣工验收',
            '¥600/次',
            '装修完工后的全面验收检查，涵盖水电、泥工、木工、油漆、安装等所有项目。出具详细竣工验收报告，确保安心入住。',
            ['全面检查', '逐项验收', '问题清单', '竣工报告'],
          ),
          _PriceItem(
            '问题诊断',
            '¥200/次',
            '针对装修中出现的问题进行专业诊断，找出原因并给出专业修复建议。客观公正第三方视角，帮助业主与施工方有效沟通。',
            ['现场查看', '原因分析', '修复建议', '诊断报告'],
          ),
        ];
      default:
        return const [
          _PriceItem(
            '吊顶',
            '¥80/平米',
            '轻钢龙骨石膏板吊顶施工，含造型设计、龙骨安装、封板、嵌缝处理。造型美观，平整牢固，预留检修口方便后期维护。',
            ['测量设计', '龙骨安装', '封板施工', '嵌缝处理'],
          ),
          _PriceItem(
            '衣柜定制',
            '¥1200/平米',
            '根据空间尺寸全屋定制衣柜，含设计、量尺、生产、安装全流程。板材环保达标，五金配件品质保障，空间利用率最大化。',
            ['上门量尺', '方案设计', '工厂生产', '现场安装'],
          ),
          _PriceItem(
            '橱柜安装',
            '¥800/延米',
            '整体橱柜设计安装，含水槽开孔、台面安装、柜体组装、门板调试等。尺寸精准，功能分区合理，操作动线流畅。',
            ['尺寸复核', '柜体组装', '台面安装', '门板调试'],
          ),
          _PriceItem(
            '隔断',
            '¥300/平米',
            '室内隔断墙/屏风制作安装，可选玻璃隔断、木质隔断、铝合金隔断等。兼顾采光与隐私，提升空间层次感。',
            ['测量定位', '框架安装', '面板安装', '收边处理'],
          ),
          _PriceItem(
            '精细木作',
            '¥600/平米',
            '包含护墙板、背景墙、榻榻米、书柜等定制木作项目。选材考究，工艺精湛，细节处理到位，打造质感家居空间。',
            ['选材下料', '木工制作', '打磨上漆', '安装固定'],
          ),
        ];
    }
  }

  void _openDetail(BuildContext context, _PriceItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _PriceDetailPage(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _priceItems;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '工价详情',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(items.length, (i) {
            final item = items[i];
            return GestureDetector(
              onTap: () => _openDetail(context, item),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.only(top: i > 0 ? 10 : 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ),
                    Text(
                      item.price,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF6B35),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Color(0xFFCCCCCC),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PriceItem {
  final String label;
  final String price;
  final String description;
  final List<String> steps;
  const _PriceItem(this.label, this.price, this.description, this.steps);
}

// ========== 工价详情页 ==========
class _PriceDetailPage extends StatelessWidget {
  final _PriceItem item;
  const _PriceDetailPage({required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          item.label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 施工流程图
          _FlowChart(steps: item.steps, price: item.price),
          const SizedBox(height: 12),
          // 服务说明
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '服务说明',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                    height: 1.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 费用包含
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '费用包含',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 12),
                _includeItem('人工费'),
                _includeItem('材料费（基础材料）'),
                _includeItem('工具及设备使用'),
                _includeItem('施工垃圾清理'),
                _includeItem('成品保护措施'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 费用不含
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '费用不含',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 12),
                _excludeItem('特殊材料升级费用'),
                _excludeItem('超出标准施工范围的额外项目'),
                _excludeItem('因业主原因造成的返工费用'),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                '返回师傅详情',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _includeItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _excludeItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF999999),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Color(0xFF999999)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowChart extends StatelessWidget {
  final List<String> steps;
  final String price;
  const _FlowChart({required this.steps, required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '施工流程',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 72,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (int i = 0; i < steps.length; i++) ...[
                  _FlowStep(number: i + 1, label: steps[i]),
                  if (i < steps.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Color(0xFFDDDDDD),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '参考价格',
                  style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
                ),
              ),
              Text(
                price,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF6B35),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x14FF6B35),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '以实际为准',
                  style: TextStyle(fontSize: 11, color: Color(0xFFFF6B35)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  final int number;
  final String label;
  const _FlowStep({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
          ),
        ],
      ),
    );
  }
}

// ========== 施工案例 ==========
class _ProjectGallery extends StatelessWidget {
  final String? workerJob;
  const _ProjectGallery({this.workerJob});

  static const _placeColors = [
    Color(0xFFE8D5B7),
    Color(0xFFD4C5A9),
    Color(0xFFC9B99A),
    Color(0xFFBFAF8F),
  ];

  static const _labels = ['吊顶施工', '衣柜定制', '橱柜安装', '书柜收纳'];

  String get _title => '施工案例';

  void _openViewer(BuildContext context, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoViewerPage(
          initialIndex: index,
          labels: _labels,
          colors: _placeColors,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              GestureDetector(
                onTap: () => _openViewer(context, 0),
                child: const Text(
                  '查看更多 >',
                  style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: GestureDetector(
                  onTap: () => _openViewer(context, i),
                  child: Container(
                    height: 90,
                    margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                    decoration: BoxDecoration(
                      color: _placeColors[i],
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0D000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.image_rounded,
                          size: 28,
                          color: Color(0x66FFFFFF),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _labels[i],
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0x66FFFFFF),
                          ),
                        ),
                      ],
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
}

// ========== 图片查看器 ==========
class _PhotoViewerPage extends StatefulWidget {
  final int initialIndex;
  final List<String> labels;
  final List<Color> colors;
  const _PhotoViewerPage({
    required this.initialIndex,
    required this.labels,
    required this.colors,
  });

  @override
  State<_PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<_PhotoViewerPage> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final colors = widget.colors;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${labels[_current]} (${_current + 1}/${labels.length})'),
        centerTitle: true,
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: labels.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  maxScale: 4.0,
                  child: Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width - 32,
                      height: MediaQuery.of(context).size.width - 32,
                      decoration: BoxDecoration(
                        color: colors[index],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.image_rounded,
                            size: 64,
                            color: Color(0x66FFFFFF),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            labels[index],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0x66FFFFFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _current > 0
                    ? GestureDetector(
                        onTap: () => _controller.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                        child: const CircleAvatar(
                          backgroundColor: Color(0x44FFFFFF),
                          child: Icon(Icons.chevron_left, color: Colors.white),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _current < labels.length - 1
                    ? GestureDetector(
                        onTap: () => _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                        child: const CircleAvatar(
                          backgroundColor: Color(0x44FFFFFF),
                          child: Icon(Icons.chevron_right, color: Colors.white),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== 业主评价 ==========
class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection();

  static const _reviews = [
    _ReviewData(
      name: '李女士',
      avatar: '李',
      rating: 5,
      tag: '满意',
      time: '2个月前',
      info: '110㎡ 旧房改造',
      content: '张师傅手艺非常好，做事细心，沟通顺畅，完工后现场也收拾得干干净净，强烈推荐！',
      photoCount: 3,
    ),
    _ReviewData(
      name: '王先生',
      avatar: '王',
      rating: 5,
      tag: '满意',
      time: '1个月前',
      info: '89㎡ 新房装修',
      content: '衣柜和橱柜都是张师傅做的，封边处理得很好，细节到位，邻居来看了都说要找他。',
      photoCount: 2,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text(
                    '业主评价',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '(98)',
                    style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {},
                child: const Text(
                  '全部评价 >',
                  style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._reviews.asMap().entries.map(
            (e) => Column(
              children: [
                if (e.key > 0)
                  const Divider(height: 24, color: Color(0xFFF0F0F0)),
                _ReviewCard(data: e.value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewData {
  final String name, avatar, tag, time, info, content;
  final int rating, photoCount;
  const _ReviewData({
    required this.name,
    required this.avatar,
    required this.tag,
    required this.time,
    required this.info,
    required this.content,
    required this.rating,
    required this.photoCount,
  });
}

class _ReviewCard extends StatelessWidget {
  final _ReviewData data;
  const _ReviewCard({required this.data});

  static const _reviewColors = [
    Color(0xFFD4C5A9),
    Color(0xFFC9B99A),
    Color(0xFFBFAF8F),
  ];

  @override
  Widget build(BuildContext context) {
    final labels = List.generate(data.photoCount, (i) => '业主实拍 ${i + 1}');
    final colors = _reviewColors.sublist(0, data.photoCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // 头像
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEE3),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Text(
                  data.avatar,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF6A1A),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        data.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...List.generate(
                        data.rating,
                        (_) => const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFFF9800),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          data.tag,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFFF9800),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${data.time} | ${data.info}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          data.content,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF333333),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        if (data.photoCount > 0)
          Row(
            children: List.generate(
              data.photoCount,
              (i) => GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _PhotoViewerPage(
                      initialIndex: i,
                      labels: labels,
                      colors: colors,
                    ),
                  ),
                ),
                child: Container(
                  width: 72,
                  height: 72,
                  margin: EdgeInsets.only(
                    right: i < data.photoCount - 1 ? 6 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: colors[i],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.image_rounded,
                    size: 22,
                    color: Color(0x66FFFFFF),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WorkerBookingTarget {
  const _WorkerBookingTarget({
    required this.trade,
    required this.phaseName,
    required this.phaseIndex,
  });

  final String trade;
  final String phaseName;
  final int phaseIndex;
}

_WorkerBookingTarget _bookingTargetForJob(String? workerJob) {
  final label = workerJob ?? '师傅';
  if (label.contains('水电')) {
    return const _WorkerBookingTarget(
      trade: '水电工',
      phaseName: '水电',
      phaseIndex: 1,
    );
  }
  if (label.contains('防水')) {
    return const _WorkerBookingTarget(
      trade: '防水工',
      phaseName: '防水',
      phaseIndex: 2,
    );
  }
  if (label.contains('泥') || label.contains('瓦')) {
    return const _WorkerBookingTarget(
      trade: '泥瓦工',
      phaseName: '泥瓦',
      phaseIndex: 3,
    );
  }
  if (label.contains('木')) {
    return const _WorkerBookingTarget(
      trade: '木工',
      phaseName: '木工',
      phaseIndex: 4,
    );
  }
  if (label.contains('油漆')) {
    return const _WorkerBookingTarget(
      trade: '油漆工',
      phaseName: '油漆',
      phaseIndex: 5,
    );
  }
  if (label.contains('安装')) {
    return const _WorkerBookingTarget(
      trade: '安装工',
      phaseName: '安装',
      phaseIndex: 6,
    );
  }
  if (label.contains('清洁') || label.contains('保洁')) {
    return const _WorkerBookingTarget(
      trade: '保洁工',
      phaseName: '清洁',
      phaseIndex: 7,
    );
  }
  return const _WorkerBookingTarget(
    trade: '拆除工',
    phaseName: '拆除',
    phaseIndex: 0,
  );
}

// ========== 底部操作栏 ==========
class _BottomActionBar extends StatelessWidget {
  final String workerId;
  final String workerName;
  final String? workerJob;
  final bool favoriteSelected;
  final bool favoriteSaving;
  final VoidCallback onToggleFavorite;
  const _BottomActionBar({
    required this.workerId,
    required this.workerName,
    required this.favoriteSelected,
    required this.favoriteSaving,
    required this.onToggleFavorite,
    this.workerJob,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: Row(
          children: [
            // 收藏
            _FavoriteAction(
              selected: favoriteSelected,
              saving: favoriteSaving,
              onPressed: onToggleFavorite,
              buttonKey: const Key('bottom-worker-favorite-button'),
            ),
            const SizedBox(width: 16),
            // 客服
            const _ActionIcon(icon: Icons.headset_mic_outlined, label: '客服'),
            const SizedBox(width: 12),
            // 问师傅
            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('聊天功能正在整理中')));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF07C160),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 20),
                  label: Text(
                    '问${workerJob ?? '师傅'}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 查看报价
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkerQuotePage(
                        workerName: workerName,
                        trade: demolitionTrade,
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF9800),
                    side: const BorderSide(color: Color(0xFFFF9800)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    '看报价',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 预约师傅
            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: () async {
                    final state = OwnerAppScope.of(context);
                    final target = _bookingTargetForJob(workerJob);
                    await state.bookWorker(
                      BookedWorker(
                        id: workerId,
                        name: workerName,
                        trade: target.trade,
                        phaseName: target.phaseName,
                        phaseIndex: target.phaseIndex,
                        rating: 4.9,
                        completedOrders: 128,
                        years: 8,
                        avatarEmoji: '👷',
                        skills: [workerJob ?? target.trade],
                        distance: 0,
                      ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已预约$workerName，可在我的家查看施工进度')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    '预约${workerJob ?? '师傅'}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ActionIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: const Color(0xFF999999)),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
        ),
      ],
    );
  }
}
