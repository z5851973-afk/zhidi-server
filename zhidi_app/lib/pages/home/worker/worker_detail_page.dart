import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/owner_app_scope.dart';
import '../../../app/owner_models.dart';
import '../../../data/price_standards.dart';
import '../../renovation/worker_chat_page.dart';
import '../../order/create_order_page.dart';
import '../../price/worker_quote_page.dart';
import '../../../design/tokens.dart';

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
      backgroundColor: ZdColors.background,
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
            color: ZdColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: ZdColors.textPrimary,
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
          _InfoTabsSection(workerJob: widget.workerJob),
          _ProjectGallery(workerJob: widget.workerJob),
          _ReviewsSection(),
        ],
      ),
      bottomNavigationBar: _BottomActionBar(
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
              color: selected ? const Color(0xFFFF7A2F) : null,
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
                  color: const Color(0xFFFF7A2F),
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
                            color: ZdColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          height: 22,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7A2F),
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
                      '$_jobLabel | 8年经验 | 成都市',
                      style: const TextStyle(
                        fontSize: 14,
                        color: ZdColors.textSecondary,
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
                  color: Color(0xFFFF7A2F),
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
            color: Color(0xFFFF7A2F),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: ZdColors.textPrimary),
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
          style: const TextStyle(fontSize: 12, color: ZdColors.textPrimary),
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
              color: ZdColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: ZdColors.textSecondary),
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
            color: ZdColors.textSecondary,
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
          Icon(Icons.emoji_events_rounded, size: 18, color: Color(0xFFFF7A2F)),
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
        return ['墙体拆除', '旧装修拆除', '铲墙皮', '垃圾清运', '地面破除', '门窗拆除'];
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
                  color: ZdColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('更多$_title正在整理中')));
                },
                child: Text(
                  _moreLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ZdColors.textSecondary,
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
                      color: ZdColors.background,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 14,
                        color: ZdColors.textPrimary,
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

// ========== 信息三级Tabs（服务内容｜工价详情｜验收标准） ==========
class _InfoTabsSection extends StatefulWidget {
  final String? workerJob;
  const _InfoTabsSection({this.workerJob});

  @override
  State<_InfoTabsSection> createState() => _InfoTabsSectionState();
}

class _InfoTabsSectionState extends State<_InfoTabsSection> {
  int _tabIndex = 0;

  static const _tabs = ['服务内容', '工价详情', '验收标准'];

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
          // Tab 导航栏
          Row(
            children: List.generate(_tabs.length, (i) {
              final active = _tabIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _tabIndex = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: active ? ZdColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _tabs[i],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active
                          ? ZdColors.primary
                          : const Color(0xFF999999),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          // 内容区
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _buildTabContent(_tabIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(int index) {
    switch (index) {
      case 0:
        return _TabServiceContent(
          workerJob: widget.workerJob,
          key: const ValueKey('service'),
        );
      case 1:
        return _TabPriceContent(
          workerJob: widget.workerJob,
          key: const ValueKey('price'),
        );
      case 2:
        return _TabInspectionContent(
          workerJob: widget.workerJob,
          key: const ValueKey('inspection'),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── 服务内容Tab内容 ──
class _TabServiceContent extends StatelessWidget {
  final String? workerJob;
  const _TabServiceContent({this.workerJob, super.key});

  List<String> get _services {
    switch (workerJob) {
      case '拆除师傅':
        return [
          '拆除墙体施工',
          '铲除白灰/腻子施工',
          '铲除保温层施工',
          '凿踢脚线施工',
          '垃圾清运',
          '地面破除',
          '门窗拆除',
          '吊顶拆除',
        ];
      case '美缝师傅':
        return ['瓷砖美缝', '环氧彩砂', '马贝填缝', '美容胶收边', '防水胶收边', '台面美容'];
      case '水电师傅':
        return ['水电改造', '管道维修', '开关插座安装', '灯具安装', '弱电布线', '电路检测'];
      default:
        return ['专业施工', '质量保证', '现场清理', '验收交付'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = _services;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: ZdColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: services.map((service) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEEEEEE), width: 1),
              ),
              child: Text(
                service,
                style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
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
            SizedBox(width: 6),
            Expanded(
              child: _StatItem(
                icon: Icons.shield_rounded,
                value: '98%',
                label: '好评率',
                color: Color(0xFF4CAF50),
              ),
            ),
            SizedBox(width: 6),
            Expanded(
              child: _StatItem(
                icon: Icons.favorite_rounded,
                value: '50+',
                label: '回头客',
                color: Color(0xFFFF5722),
              ),
            ),
            SizedBox(width: 6),
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
    );
  }

  String get _title {
    switch (workerJob) {
      case '拆除师傅':
        return '拆除师傅服务内容';
      case '油漆师傅':
        return '油漆师傅服务内容';
      case '美缝师傅':
        return '美缝师傅服务内容';
      case '水电师傅':
        return '水电师傅服务内容';
      default:
        return '服务内容';
    }
  }
}

// ── 工价详情Tab内容 ──
class _TabPriceContent extends StatelessWidget {
  final String? workerJob;
  const _TabPriceContent({this.workerJob, super.key});

  static const _primaryColor = Color(0xFFFF7A2F);

  List<_PriceItem> get _priceItems {
    switch (workerJob) {
      case '美缝师傅':
        return const [
          _PriceItem('瓷砖美缝', '¥25/米', '适用于瓷砖缝隙填充美化，采用高品质美缝剂，防水防霉。', [
            '基层清理',
            '缝隙填充',
            '压缝收光',
            '养护完成',
          ]),
          _PriceItem('环氧彩砂', '¥45/米', '采用进口环氧彩砂材料，硬度高、附着力强，适合高档装修。', [
            '基层清理',
            '材料搅拌',
            '彩砂填充',
            '刮平压实',
            '清洗养护',
          ]),
          _PriceItem('马贝填缝', '¥38/米', '意大利马贝品牌填缝剂，色彩细腻均匀，适合各类瓷砖填缝。', [
            '缝隙清理',
            '材料调制',
            '填缝施工',
            '表面清洁',
            '固化养护',
          ]),
          _PriceItem('美容胶收边', '¥30/米', '对台面、踢脚线、门套等收边位置进行美容胶封边处理。', [
            '收边清理',
            '胶枪注胶',
            '刮平修整',
            '固化检查',
          ]),
          _PriceItem('防水胶收边', '¥35/米', '针对厨卫阳台等潮湿区域的收边防水处理。', [
            '基层干燥',
            '打胶施工',
            '抹平压实',
            '防水测试',
          ]),
          _PriceItem('台面美容', '¥200/项', '针对石英石、大理石台面进行抛光翻新、划痕修复。', [
            '划痕检查',
            '打磨抛光',
            '接缝处理',
            '镜面修复',
          ]),
          _PriceItem('阴阳角处理', '¥15/米', '瓷砖阴阳角倒角修边精细处理，收口美观。', [
            '角度测量',
            '切割打磨',
            '拼接修整',
          ]),
          _PriceItem('踢脚线美缝', '¥20/米', '踢脚线与墙面/地面接缝处美缝处理。', [
            '缝隙清理',
            '打胶填充',
            '刮平收光',
          ]),
          _PriceItem('马赛克美缝', '¥35/㎡', '马赛克瓷砖缝隙填充美化，逐格施工精细。', [
            '缝隙清理',
            '逐格填充',
            '表面清洁',
          ]),
        ];
      case '拆除师傅':
        return const [
          _PriceItem('拆墙', '¥35-50/㎡', '专业拆除非承重墙体，含切割、破碎、清渣全流程。', [
            '现场防护',
            '切割分离',
            '逐段拆除',
            '废料清运',
          ]),
          _PriceItem('铲墙皮', '¥8-12/㎡', '铲除旧墙面腻子层、涂料层至基层。', [
            '墙面湿润',
            '铲除旧层',
            '基层清理',
            '检查验收',
          ]),
          _PriceItem('拆地砖', '¥15-25/㎡', '拆除旧地砖及水泥砂浆层，清理基层。', [
            '机械破除',
            '基层清理',
            '废渣装袋',
            '场地清扫',
          ]),
          _PriceItem('拆吊顶', '¥10-20/㎡', '拆除旧吊顶及龙骨，清理顶面基层。', [
            '灯具拆除',
            '吊顶拆除',
            '龙骨清理',
            '顶面修补',
          ]),
          _PriceItem('垃圾清运', '¥300-500/车', '装修垃圾装车清运，运至指定消纳场。', [
            '垃圾分类',
            '装袋搬运',
            '装车运输',
            '场地清扫',
          ]),
          _PriceItem('门窗拆除', '¥50-80/樘', '拆除旧门窗及门套窗套，含清理与洞口修整。', [
            '现场保护',
            '门窗拆除',
            '洞口修整',
            '废料清运',
          ]),
          _PriceItem('凿踢脚线', '¥8-15/m', '凿除旧踢脚线，清理基层。', [
            '沿线切割',
            '凿除旧层',
            '基层清理',
          ]),
          _PriceItem('拆橱柜', '¥100-200/套', '拆除旧橱柜及台面，含搬运与现场清理。', [
            '断水断电',
            '柜体拆除',
            '台面拆除',
            '现场清扫',
          ]),
          _PriceItem('地面破除', '¥20-35/㎡', '破除旧水泥地面或找平层至结构层。', [
            '机械破除',
            '废渣装袋',
            '基层清扫',
          ]),
        ];
      default:
        return const [
          _PriceItem('基础工费', '¥50-150/㎡', '根据具体项目难度和面积综合报价，需现场勘测后确定。', [
            '现场勘测',
            '方案确认',
            '施工执行',
            '验收交付',
          ]),
        ];
    }
  }

  void _openDetail(BuildContext context, _PriceItem item) {
    final items = _priceItems;
    final index = items.indexOf(item);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PriceDetailPage(items: items, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _priceItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 3列九宫格 ──
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.1,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return GestureDetector(
              onTap: () => _openDetail(context, item),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF0F0F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          item.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ZdColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      item.price,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── 验收标准Tab内容 ──
class _TabInspectionContent extends StatelessWidget {
  final String? workerJob;
  const _TabInspectionContent({this.workerJob, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '验收标准',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: ZdColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _buildItem('安全规范', '施工现场配备灭火器材，作业人员持证上岗；高空作业须系安全绳，用电设备须接地保护。'),
        const SizedBox(height: 8),
        _buildItem('工艺标准', '墙面平整度误差不大于3mm，阴阳角方正度误差不大于2mm；瓷砖铺贴空鼓率不超过5%。'),
        const SizedBox(height: 8),
        _buildItem('施工要求', '每日施工时间为8:00-18:00，施工完毕后清理现场；材料堆放整齐，不影响邻里通行。'),
        const SizedBox(height: 8),
        _buildItem('验收流程', '工程完工后由平台验收师逐项检查，出具验收报告，不合格项限期整改。'),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('完整验收标准正在整理中')));
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '查看完整标准',
                style: TextStyle(fontSize: 12, color: ZdColors.primary),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: ZdColors.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItem(String title, String content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.only(top: 7),
          decoration: const BoxDecoration(
            color: ZdColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$title：',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ZdColors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: content,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
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

// ========== 介绍 ==========
class _AboutSection extends StatefulWidget {
  final String? workerJob;
  const _AboutSection() : workerJob = null;

  @override
  State<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<_AboutSection> {
  bool _isExpanded = false;

  String get _jobLabel => widget.workerJob ?? '师傅';

  String get _intro {
    switch (widget.workerJob) {
      case '拆除师傅':
        return '拆除工负责装修第一步的拆旧工作，需要丰富的施工经验和扎实的基本功。'
            '从拆墙、铲墙皮到拆地砖、垃圾清运，每一步都要做到安全、规范、干净利落。'
            '从事拆除行业多年，始终把安全和效率放在第一位，让后续装修施工能够顺利进行。';
      default:
        return '从事$_jobLabel行业8年，经验丰富，做事认真负责，注重细节，客户满意度高。'
            '擅长全屋定制，从量尺到安装全程亲历亲为，让每一位业主满意。';
    }
  }

  String get _title {
    switch (widget.workerJob) {
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
              color: ZdColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _intro,
            maxLines: _isExpanded ? null : 2,
            overflow: _isExpanded ? null : TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Row(
              children: [
                Text(
                  _isExpanded ? '收起' : '展开全文',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: ZdColors.primary,
                  ),
                ),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: ZdColors.primary,
                  ),
                ),
              ],
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
              color: ZdColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: ZdColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ========== 工价详情 ==========

class _PriceItem {
  final String label;
  final String price;
  final String description;
  final List<String> steps;
  const _PriceItem(this.label, this.price, this.description, this.steps);
}

// ========== 工价详情页 ==========
class _PriceDetailPage extends StatelessWidget {
  final List<_PriceItem> items;
  final int initialIndex;
  const _PriceDetailPage({required this.items, this.initialIndex = 0});

  static const _primaryColor = Color(0xFFFF7A2F);

  static const _steps = [
    '现场交底',
    '安全自检',
    '过道保护',
    '区域保护',
    '下水遮盖',
    '建渣装袋',
    '建渣外运',
    '卫生打扫',
    '检查下水',
    '完工验收',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '工价详情',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ZdColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: ZdColors.textPrimary,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          _buildStepBanner(),
          Expanded(child: _buildPriceGrid()),
        ],
      ),
    );
  }

  Widget _buildStepBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '施工流程',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ZdColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalW = constraints.maxWidth;
                final count = _steps.length;
                const circleR = 8.0;
                const circleD = circleR * 2;
                final stepSpacing = (totalW - circleD) / (count - 1);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Horizontal connecting line
                    Positioned(
                      left: circleR,
                      right: circleR,
                      top: circleR - 0.5,
                      child: Container(
                        height: 1,
                        color: const Color(0xFFE0E0E0),
                      ),
                    ),
                    // Circles + labels
                    ...List.generate(count, (i) {
                      final cx = i * stepSpacing + circleR;
                      return Positioned(
                        left: cx - circleR,
                        top: 0,
                        child: SizedBox(
                          width: stepSpacing.clamp(18.0, double.infinity),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: circleD,
                                height: circleD,
                                decoration: const BoxDecoration(
                                  color: _primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _steps[i],
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  color: Color(0xFF999999),
                                  height: 1.3,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        padding: const EdgeInsets.only(top: 12, bottom: 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.1,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _PriceGridCard(item: item);
        },
      ),
    );
  }
}

class _PriceGridCard extends StatelessWidget {
  final _PriceItem item;
  const _PriceGridCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ZdColors.textPrimary,
                ),
              ),
            ),
          ),
          Text(
            item.price,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: ZdColors.primary,
            ),
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
                  color: ZdColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => _openViewer(context, 0),
                child: const Text(
                  '查看更多 >',
                  style: TextStyle(fontSize: 13, color: ZdColors.textSecondary),
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
                      color: ZdColors.textPrimary,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '(98)',
                    style: TextStyle(
                      fontSize: 14,
                      color: ZdColors.textSecondary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已展示全部评价')));
                },
                child: const Text(
                  '全部评价 >',
                  style: TextStyle(fontSize: 13, color: ZdColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._reviews.asMap().entries.map(
            (e) => Column(
              children: [
                if (e.key > 0)
                  const Divider(height: 24, color: ZdColors.divider),
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
                    color: Color(0xFFFF7A2F),
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
                          color: ZdColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...List.generate(
                        data.rating,
                        (_) => const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFFF7A2F),
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
                            color: Color(0xFFFF7A2F),
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
                      color: ZdColors.textSecondary,
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
            color: ZdColors.textPrimary,
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

// ========== 底部操作栏 ==========
class _BottomActionBar extends StatelessWidget {
  final String workerName;
  final String? workerJob;
  final bool favoriteSelected;
  final bool favoriteSaving;
  final VoidCallback onToggleFavorite;
  const _BottomActionBar({
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
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkerChatPage(workerName: workerName),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF07C160),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 20),
                  label: const Text(
                    '问师傅',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
                    foregroundColor: ZdColors.primary,
                    side: const BorderSide(color: ZdColors.primary),
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
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateOrderPage(workerName: workerName),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A2F),
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
        Icon(icon, size: 22, color: ZdColors.textSecondary),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: ZdColors.textSecondary),
        ),
      ],
    );
  }
}
