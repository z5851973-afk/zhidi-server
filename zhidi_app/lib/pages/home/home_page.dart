import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../app/owner_app_scope.dart';
import '../../models/renovation.dart';
import '../../widgets/home/top_bar.dart';
import 'my_home_page.dart';
import '../message/message_page.dart';
import '../renovation/trade_select_page.dart';
import '../renovation/full_renovation_page.dart';
import '../renovation/partial_renovation_page.dart';
import '../profile/profile_page.dart';
import 'worker/worker_list_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: IndexedStack(
        index: _currentTab,
        children: [
          // 0: 首页
          _buildHomeTab(),
          // 1: 我的家
          const MyHomePage(),
          // 2: 消息
          const MessagePage(),
          // 3: 我的
          const ProfilePage(),
        ],
      ),

      // ==================== 底部导航栏 ====================
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildHomeTab() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================== 顶部导航栏 ====================
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: HomeTopBar(),
            ),

            const SizedBox(height: 14),

            // ==================== 品牌 Banner ====================
            const _HomeBanner(),

            const SizedBox(height: 20),

            // ==================== 需求选择入口 ====================
            const _RequirementHub(),

            const SizedBox(height: 20),

            // ==================== 推荐师傅团队 ====================
            _SectionTitle(
              spacing: 12,
              title: '为你匹配的施工团队',
              trailing: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => WorkerListPage()),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '更多师傅',
                      style: TextStyle(fontSize: 12, color: Color(0xFF8A8580)),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: Color(0xFF999999),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: _TeamMatchSection(),
            ),

            const SizedBox(height: 20),

            // ==================== "为什么选择知底？" 四宫格 ====================
            _SectionTitle(title: '为什么选择知底？', subtitle: '4大保障 · 让装修更省心更放心'),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: _WhyChooseUs(),
            ),

            const SizedBox(height: 20),

            // ==================== 施工建议 ====================
            _SectionTitle(spacing: 12, title: '施工建议'),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: _ConstructionAdvice(),
            ),

            const SizedBox(height: 20),

            // ==================== 真实案例 ====================
            _SectionTitle(spacing: 12, title: '真实案例'),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: _RealCases(),
            ),

            const SizedBox(height: 20),

            // ==================== 四大保障 ====================
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: _FourGuarantees(),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / 4;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // 四个 Tab 均分
              Row(
                children: [
                  Expanded(child: _buildTab(Icons.home_rounded, '首页', 0)),
                  Expanded(
                    child: _buildTab(Icons.favorite_border_rounded, '我的家', 1),
                  ),
                  Expanded(
                    child: _buildTab(
                      Icons.chat_bubble_outline_rounded,
                      '消息',
                      2,
                      badgeCount: OwnerAppScope.of(context).unreadMessageCount,
                    ),
                  ),
                  Expanded(
                    child: _buildTab(Icons.person_outline_rounded, '我的', 3),
                  ),
                ],
              ),
              // 选中指示条
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                left: _currentTab * tabWidth + (tabWidth - 32) / 2,
                top: 0,
                child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTab(
    IconData icon,
    String label,
    int index, {
    int badgeCount = 0,
  }) {
    final isActive = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Badge(
            key: badgeCount > 0 && index == 2
                ? const Key('bottom-message-badge')
                : null,
            isLabelVisible: badgeCount > 0,
            label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
            child: Icon(
              icon,
              size: 22,
              color: isActive
                  ? const Color(0xFFFF6B35)
                  : const Color(0xFFAAAAAA),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive
                  ? const Color(0xFFFF6B35)
                  : const Color(0xFFAAAAAA),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== "为什么选择知底？" 四宫格 ====================
class _WhyChooseUs extends StatelessWidget {
  const _WhyChooseUs();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 2×2 卡片网格
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (context, index) {
            final configs = [
              _WhyCardConfig(
                icon: Icons.engineering_rounded,
                title: '师傅知底',
                details: ['实名认证', '技能审核', '履历透明可查'],
                gradient: const [Color(0xFFFF6B35), Color(0xFFFF8A3D)],
              ),
              _WhyCardConfig(
                icon: Icons.monetization_on_outlined,
                title: '工价知底',
                details: ['价格透明', '合理报价', '杜绝隐形增项'],
                gradient: const [Color(0xFFFFB800), Color(0xFFFFCA28)],
              ),
              _WhyCardConfig(
                icon: Icons.build_circle_outlined,
                title: '工艺知底',
                details: ['工艺标准', '节点验收', '全程质量把控'],
                gradient: const [Color(0xFF4CAF50), Color(0xFF66BB6A)],
              ),
              _WhyCardConfig(
                icon: Icons.shield_outlined,
                title: '平台托底',
                details: ['先行赔付', '资金托管', '售后无忧保障'],
                gradient: const [Color(0xFF5B8DEF), Color(0xFF7BA7FF)],
              ),
            ];
            return _WhyCard(config: configs[index]);
          },
        ),
        const SizedBox(height: 14),
        // 底部 CTA 横幅
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF3E8), Color(0xFFFFFBF7)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFE0C8), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF8A3D)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.verified_user,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '知底平台全程保障，让每一笔装修都更透明、更安心',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5D4037),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF8A3D), Color(0xFFFF6B35)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Text(
                  '了解详情',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WhyCardConfig {
  final IconData icon;
  final String title;
  final List<String> details;
  final List<Color> gradient;
  const _WhyCardConfig({
    required this.icon,
    required this.title,
    required this.details,
    required this.gradient,
  });
}

class _WhyCard extends StatelessWidget {
  final _WhyCardConfig config;
  const _WhyCard({required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: config.gradient.first.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部图标 + 标题
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: config.gradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: config.gradient.first.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(config.icon, size: 22, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  config.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...config.details.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: config.gradient.first,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      d,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF777777),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Container(height: 1, color: const Color(0xFFF0F0F0)),
              ),
              const SizedBox(width: 6),
              Text(
                '查看',
                style: TextStyle(
                  fontSize: 10,
                  color: config.gradient.first,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 12,
                color: config.gradient.first,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== 施工建议模块 ====================
class _ConstructionAdvice extends StatelessWidget {
  const _ConstructionAdvice();

  @override
  Widget build(BuildContext context) {
    return const _WeatherAdviceCard();
  }
}

// ==================== 真实案例模块 ====================
class _RealCases extends StatelessWidget {
  const _RealCases();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: _caseDataList.length,
      itemBuilder: (context, index) => _XhsCaseCard(data: _caseDataList[index]),
    );
  }
}

class _CaseData {
  final String label;
  final String title;
  final String location;
  final int likes;
  final String coverUrl; // 预留真实图片 URL

  const _CaseData({
    required this.label,
    required this.title,
    required this.location,
    required this.likes,
  }) : coverUrl = '';
}

final List<_CaseData> _caseDataList = [
  _CaseData(label: '老房翻新', title: '89㎡老房翻新', location: '成都市 · 李先生', likes: 128),
  _CaseData(
    label: '新房软装',
    title: '120㎡现代简约',
    location: '成都市 · 王女士',
    likes: 256,
  ),
  _CaseData(label: '老房改造', title: '65㎡温馨小窝', location: '成都市 · 张先生', likes: 98),
  _CaseData(label: '局部改造', title: '厨房改造前后对比', location: '成都市 · 陈女士', likes: 75),
];

class _WeatherAdviceCard extends StatelessWidget {
  const _WeatherAdviceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4FC3F7).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // 天气头部
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.cloud_outlined,
                  size: 26,
                  color: Color(0xFF42A5F5),
                ),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '成都市',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '26°C  小雨 · 今日不宜室外施工',
                    style: TextStyle(fontSize: 11, color: Color(0xFF999999)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // AI 建议区域
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFBF7), Color(0xFFFFF8F2)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFE8D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFF8A3D)],
                        ),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'AI 今日建议',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _AdviceRow(
                  icon: Icons.check_circle_rounded,
                  text: '水电施工、木工施工、室内测量',
                  color: const Color(0xFF4CAF50),
                ),
                const SizedBox(height: 6),
                _AdviceRow(
                  icon: Icons.cancel_rounded,
                  text: '外墙施工、防水施工、室外测量',
                  color: const Color(0xFFFF5252),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF8A3D), Color(0xFFFF6B35)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFFF6B35,
                          ).withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '查看详情',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdviceRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _AdviceRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== 小红书风格案例卡片 ====================
class _XhsCaseCard extends StatelessWidget {
  final _CaseData data;

  const _XhsCaseCard({required this.data});

  Color get _tagColor {
    switch (data.label) {
      case '老房翻新':
        return const Color(0xFFFF9800);
      case '局部改造':
        return const Color(0xFF9C27B0);
      case '新房软装':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF2196F3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _tagColor.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面图区域
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _tagColor.withValues(alpha: 0.12),
                        _tagColor.withValues(alpha: 0.04),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: 36,
                      color: _tagColor.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                // 左上角标签
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _tagColor,
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [
                        BoxShadow(
                          color: _tagColor.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      data.label,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // 右下角点赞
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        size: 13,
                        color: Color(0xFFFF6B6B),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${data.likes}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFFFF6B6B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 底部信息区
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.location,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFAAAAAA),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 四大保障 ====================
class _FourGuarantees extends StatelessWidget {
  const _FourGuarantees();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0F5E8), Color(0xFFF5F9EE)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8CC), width: 0.5),
      ),
      child: Row(
        children: const [
          Expanded(
            child: _GuaranteeCard(
              icon: Icons.shield_outlined,
              title: '资金托管',
              subtitle: '装修款专用账户',
            ),
          ),
          _GuaranteeDivider(),
          Expanded(
            child: _GuaranteeCard(
              icon: Icons.fact_check_outlined,
              title: '过程监督',
              subtitle: '节点验收严格把控',
            ),
          ),
          _GuaranteeDivider(),
          Expanded(
            child: _GuaranteeCard(
              icon: Icons.schedule_rounded,
              title: '工期保障',
              subtitle: '按时交付超期赔付',
            ),
          ),
          _GuaranteeDivider(),
          Expanded(
            child: _GuaranteeCard(
              icon: Icons.verified_user_outlined,
              title: '售后保障',
              subtitle: '装修问题平台负责',
            ),
          ),
        ],
      ),
    );
  }
}

class _GuaranteeDivider extends StatelessWidget {
  const _GuaranteeDivider();
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: const Color(0xFFDCE8CC));
  }
}

class _GuaranteeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _GuaranteeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF5A8F3F).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF5A8F3F)),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 10, color: Color(0xFF888888)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ==================== 推荐师傅团队 ====================
class _TeamMatchSection extends StatelessWidget {
  const _TeamMatchSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 团队卡片
        _TeamCard(
          teamName: '王工团队',
          location: '金牛区',
          members: '水电·泥瓦·木工·油漆',
          completedCount: 26,
          rating: 4.9,
          nearbyCount: 3,
          nearbyLocation: '金牛区',
          avatarColor: const Color(0xFFFF6B35),
        ),
        const SizedBox(height: 10),
        _TeamCard(
          teamName: '赵工团队',
          location: '武侯区',
          members: '水电·泥瓦·木工·油漆',
          completedCount: 18,
          rating: 4.8,
          nearbyCount: 2,
          nearbyLocation: '武侯区',
          avatarColor: const Color(0xFF5B8DEF),
        ),

        const SizedBox(height: 12),

        // 平台托管付款 CTA
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF0F5E8), Color(0xFFF5F9EE)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDCE8CC), width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF5A8F3F).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: Color(0xFF5A8F3F),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '平台托管付款，按工序验收后分批释放，不满意可冻结',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4A6B30),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TeamCard extends StatelessWidget {
  final String teamName;
  final String location;
  final String members;
  final int completedCount;
  final double rating;
  final int nearbyCount;
  final String nearbyLocation;
  final Color avatarColor;

  const _TeamCard({
    required this.teamName,
    required this.location,
    required this.members,
    required this.completedCount,
    required this.rating,
    required this.nearbyCount,
    required this.nearbyLocation,
    required this.avatarColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: avatarColor.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              // 左侧渐变头像
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [avatarColor.withValues(alpha: 0.8), avatarColor],
                  ),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  size: 26,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              // 中间信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          teamName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            location,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF999999),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      members,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF777777),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _SignalChip(
                          icon: Icons.home_work_outlined,
                          text: '$completedCount 套',
                          color: const Color(0xFF5A8F3F),
                        ),
                        const SizedBox(width: 8),
                        _SignalChip(
                          icon: Icons.star_rounded,
                          text: '$rating',
                          color: const Color(0xFFFFB800),
                        ),
                        const SizedBox(width: 8),
                        _SignalChip(
                          icon: Icons.location_on_outlined,
                          text: '$nearbyLocation $nearbyCount 个',
                          color: const Color(0xFF5B8DEF),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFFDDDDDD),
              ),
            ],
          ),
        ),
        // 推荐标签 — 右上角
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              '推荐',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: avatarColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TagChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SignalChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _SignalChip({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF5A8F3F);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: c),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ==================== 统一板块标题组件 ====================
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final double spacing;
  const _SectionTitle({
    required this.title,
    this.subtitle,
    this.trailing,
    this.spacing = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 14, right: 14, bottom: spacing),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFF8A3D)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A),
                    height: 1.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ==================== 首页品牌 Banner ====================
class _HomeBanner extends StatelessWidget {
  const _HomeBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF613925).withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          image: const DecorationImage(
            image: AssetImage('assets/images/banner_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 0, 12),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFFFDF5ED), Color(0x00FDF5ED), Color(0x00FDF5ED)],
              stops: [0.39, 0.72, 1.0],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧文案 + 右侧区域
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧文案区
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '装修找知底',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4A3B32),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '心里就有底',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFD35400),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '业主直连靠谱工人，平台全程托底',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF4A3B32),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 右侧盾牌徽标
                  const Padding(
                    padding: EdgeInsets.only(right: 14, top: 4),
                    child: _ShieldBadge(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 底部信任标签 — 磨砂玻璃整条
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 5,
                      horizontal: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 0.2,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TrustItem(
                          icon: Icons.verified_user_outlined,
                          label: '工人知底',
                        ),
                        _Divider(),
                        _TrustItem(
                          icon: Icons.bar_chart_outlined,
                          label: '工价知底',
                        ),
                        _Divider(),
                        _TrustItem(icon: Icons.build_outlined, label: '工艺知底'),
                        _Divider(),
                        _TrustItem(icon: Icons.shield_outlined, label: '平台托底'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShieldBadge extends StatelessWidget {
  const _ShieldBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFFDAA520).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFC8963E).withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF613925).withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_rounded, size: 20, color: Colors.white),
          SizedBox(height: 2),
          Text(
            '平台保障',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          SizedBox(height: 1),
          Text(
            '装修更安心',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustItem({required this.icon, required this.label});

  static const _golden = Color(0xFFDAA520);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: _golden),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Color(0xFF3E2723),
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '｜',
        style: TextStyle(
          fontSize: 10,
          color: Colors.white70,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}

// ==================== 需求选择入口 ====================
class _RequirementHub extends StatelessWidget {
  const _RequirementHub();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题区
          const Text(
            '选择你的装修需求',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2D2D2D),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '我们帮你找工人、排工期、组团队',
            style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
          ),
          const SizedBox(height: 16),

          // 找工种 — 大卡片
          _HeroWorkerCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TradeSelectPage()),
            ),
          ),
          const SizedBox(height: 12),

          // 小卡片 — 2×2 宫格
          Row(
            children: [
              Expanded(
                child: _SmallServiceCard(
                  icon: Icons.home_work_rounded,
                  title: '全屋装修',
                  subtitle: '毛坯房·新房整装',
                  desc: '设计·施工·材料一站式服务',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FullRenovationPage(
                        type: RequirementType.fullRenovation,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallServiceCard(
                  icon: Icons.autorenew_rounded,
                  title: '旧房改造',
                  subtitle: '老房翻新·拆除重建',
                  desc: '设计·施工·材料一站式服务',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FullRenovationPage(
                        type: RequirementType.oldHouseRenovation,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SmallServiceCard(
                  icon: Icons.format_paint_rounded,
                  title: '局部改造',
                  subtitle: '厨房·卫生间·墙面',
                  desc: '设计·施工·材料一站式服务',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PartialRenovationPage(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallServiceCard(
                  icon: Icons.grid_view_rounded,
                  title: '更多服务',
                  subtitle: '定制·监理·软装等',
                  desc: '一站式解决装修难题',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('更多服务，敬请期待'),
                      duration: Duration(seconds: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== 找工种 · 大卡片 ====================
class _HeroWorkerCard extends StatelessWidget {
  final VoidCallback onTap;
  const _HeroWorkerCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF8C00);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // 左侧：文案区
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 图标 + 标题 + 角标
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFFFF5EB),
                            ),
                            child: const Icon(
                              Icons.engineering_rounded,
                              size: 22,
                              color: orange,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Flexible(
                            child: Text(
                              '找工种',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2D2D2D),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE8D6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '♥',
                                  style: TextStyle(fontSize: 8, color: orange),
                                ),
                                SizedBox(width: 3),
                                Text(
                                  '平台优选',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '水电·泥瓦·木工·油漆等',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        '精准匹配靠谱工人',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF999999),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '去匹配工人',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 右侧：砌砖工人场景图
              Expanded(
                flex: 4,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                  ),
                  child: Image.asset(
                    'assets/images/worker_bricklaying.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 小卡片 — 横排布局 ====================
class _SmallServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String desc;
  final VoidCallback onTap;

  const _SmallServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.desc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF8C00);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 10, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // 图标
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFF5EB),
              ),
              child: Icon(icon, size: 22, color: orange),
            ),
            const SizedBox(width: 10),
            // 文案区
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题行：标题 + 箭头
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // 副标题
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF777777),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 1),
                  // 第三行描述
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFAAAAAA),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
