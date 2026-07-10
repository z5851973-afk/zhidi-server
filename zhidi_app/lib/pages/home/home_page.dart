import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../design/tokens.dart';
import '../../app/owner_app_scope.dart';
import '../../app/owner_models.dart';
import '../../models/renovation.dart';
import '../../widgets/home/top_bar.dart';
import 'my_home_page.dart';
import '../chat/chat_page.dart';
import '../message/message_page.dart';
import '../renovation/trade_select_page.dart';
import 'worker/worker_list_page.dart';
import 'master_selection_page.dart';
import '../price/price_transparency_page.dart';
import '../renovation/construction_guarantee_page.dart';
import '../renovation/fund_bank_escrow_page.dart';
import '../profile/profile_page.dart';
import '../auth/login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentTab = 0;

  void _onTabTapped(int index) async {
    // 首页以外的 tab 需要登录
    if (index != 0) {
      final appState = OwnerAppScope.of(context);
      if (!appState.isLoggedIn) {
        final loggedIn = await Navigator.of(
          context,
        ).push<bool>(MaterialPageRoute(builder: (_) => const LoginPage()));
        if (loggedIn != true) return;
      }
    }
    setState(() => _currentTab = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZdColors.background,
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
            const HomeRequirementHub(),

            const SizedBox(height: 20),

            // ==================== 施工建议 ====================
            _SectionTitle(spacing: 12, title: '今日施工建议'),
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
          final unreadCount = OwnerAppScope.of(context).unreadMessageCount;
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
                      badgeCount: unreadCount,
                    ),
                  ),
                  Expanded(
                    child: _buildTab(
                      Icons.person_outline_rounded,
                      '我的',
                      3,
                      badgeCount: unreadCount,
                    ),
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
                    color: ZdColors.primary,
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
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Badge(
            key: badgeCount > 0
                ? ValueKey('bottom-tab-$index-badge-$badgeCount')
                : null,
            isLabelVisible: badgeCount > 0,
            label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
            child: Icon(
              icon,
              size: 22,
              color: isActive ? ZdColors.primary : ZdColors.textHint,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? ZdColors.primary : ZdColors.textHint,
            ),
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
                      color: ZdColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '26°C  小雨 · 今日不宜室外施工',
                    style: TextStyle(
                      fontSize: 11,
                      color: ZdColors.textSecondary,
                    ),
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
                          colors: [ZdColors.primary, ZdColors.primaryDark],
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
                        color: ZdColors.textPrimary,
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
                        colors: [ZdColors.primaryDark, ZdColors.primary],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: ZdColors.primary.withValues(alpha: 0.25),
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
        return const Color(0xFFFF7A2F);
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
                    color: ZdColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.location,
                  style: const TextStyle(
                    fontSize: 10,
                    color: ZdColors.textHint,
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
        children: [
          Expanded(
            child: _GuaranteeCard(
              icon: Icons.shield_outlined,
              title: '资金银行托管',
              subtitle: '银行监管账户',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FundBankEscrowPage()),
              ),
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
  final VoidCallback? onTap;
  const _GuaranteeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Column(
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
          style: const TextStyle(fontSize: 10, color: ZdColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
    if (onTap == null) return child;
    return GestureDetector(onTap: onTap, child: child);
  }
}

// ==================== 统一板块标题组件 ====================
class _SectionTitle extends StatelessWidget {
  final String title;
  final double spacing;
  const _SectionTitle({
    required this.title,
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
                colors: [ZdColors.primary, ZdColors.primaryDark],
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
                    color: ZdColors.textPrimary,
                    height: 1.2,
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
class HomeRequirementHub extends StatelessWidget {
  const HomeRequirementHub({super.key});

  Future<void> _onMatch(BuildContext context) async {
    final appState = OwnerAppScope.of(context);
    if (!appState.isLoggedIn) {
      final loggedIn = await Navigator.of(
        context,
      ).push<bool>(MaterialPageRoute(builder: (_) => const LoginPage()));
      if (loggedIn != true) return;
    }
    if (!context.mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TradeSelectPage()),
    );
    if (result is Worker && context.mounted) {
      final phaseIndex = WorkerListPage.tradeToPhaseIndex(result.trade);
      if (phaseIndex != null) {
        final booked = BookedWorker(
          id: result.id,
          name: result.name,
          trade: result.trade.label,
          phaseName: WorkerListPage.phaseNames[phaseIndex],
          phaseIndex: phaseIndex,
          rating: result.rating,
          completedOrders: result.completedProjects,
          years: result.experienceYears,
          avatarEmoji: result.trade.icon,
          skills: result.certifications,
          distance: result.distance,
        );
        appState.bookWorker(booked);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // ── Hero: 3分钟匹配合适工人 ──
          _HeroSection(onMatch: () => _onMatch(context)),
          const SizedBox(height: 20),
          // ── 按需找服务 ──
          const _ServiceRow(),
          const SizedBox(height: 24),
          // ── 为什么选择知底 ──
          const _TrustRow(),
        ],
      ),
    );
  }
}

// ── Hero: 3分钟匹配合适工人（主卡片 + 数据统计条）──
class _HeroSection extends StatelessWidget {
  final VoidCallback onMatch;
  const _HeroSection({required this.onMatch});

  static const _orange = ZdColors.primary;
  static const _dark = ZdColors.textPrimary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── 主卡片 ──
        Container(
          key: const Key('home-hero-card'),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF0F0F0), width: 3.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _LeftNumber(),
                        const SizedBox(height: 1),
                        const Text(
                          '匹配合适工人',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: _dark,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: ZdColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _WorkerWithBubble(),
                ],
              ),
              const SizedBox(height: 12),
              _CtaButton(onMatch: onMatch),
              const SizedBox(height: 6),
              const Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  _TagItem(label: '严格筛选'),
                  _TagItem(label: '实名认证'),
                  _TagItem(label: '银行监管'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // ── 数据统计条 ──
        LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              key: const Key('home-stats-panel'),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCFA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF5EDE5), width: 2.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: const _HeroStatsPanel(),
            );
          },
        ),
      ],
    );
  }
}

class _HeroStatsPanel extends StatelessWidget {
  const _HeroStatsPanel();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: const [
          SizedBox(
            width: 70,
            child: _StatCell(
              icon: Icons.people_outline_rounded,
              value: '12,368+',
              label: '业主的选择',
            ),
          ),
          SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: _StatCell(
              icon: Icons.access_time_rounded,
              value: '平均30分钟',
              label: '快速响应',
            ),
          ),
          SizedBox(width: 10),
          SizedBox(
            width: 56,
            child: _StatCell(
              icon: Icons.thumb_up_outlined,
              value: '99%',
              label: '好评率',
            ),
          ),
          SizedBox(width: 10),
          SizedBox(
            width: 56,
            child: _StatCell(
              icon: Icons.verified_user_rounded,
              value: '100%',
              label: '资质认证',
            ),
          ),
        ],
      ),
    );
  }
}

// ── "3 分钟" 数字行（独立组件，const优化）──
class _LeftNumber extends StatelessWidget {
  const _LeftNumber();
  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            '3',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: _HeroSection._orange,
              height: 1,
            ),
          ),
          const SizedBox(width: 2),
          const Padding(
            padding: EdgeInsets.only(bottom: 3),
            child: Text(
              '分钟',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _HeroSection._dark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 工人插画 + 气泡（独立组件）──
class _WorkerWithBubble extends StatelessWidget {
  const _WorkerWithBubble();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 155,
      height: 160,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            top: 2,
            left: 34,
            child: Text(
              '最快当天可上门',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: ZdColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/worker_confident.png',
              width: 150,
              height: 140,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 标签子组件 ──
class _TagItem extends StatelessWidget {
  final String label;
  const _TagItem({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: Color(0xFFFFF0E5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 9, color: Colors.white),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Color(0xFF777777),
          ),
        ),
      ],
    );
  }
}

// ── 立即匹配工人按钮 ──
class _CtaButton extends StatelessWidget {
  final VoidCallback onMatch;
  const _CtaButton({required this.onMatch});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onMatch,
      child: FractionallySizedBox(
        widthFactor: 0.70,
        alignment: Alignment.centerLeft,
        child: Container(
          key: const Key('home-match-action'),
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [ZdColors.primary, ZdColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: ZdColors.primary.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '立即匹配工人',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 统计行：单格 ──
class _StatCell extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatCell({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: ZdColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: ZdColors.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: ZdColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── 按需找服务 ──
class _ServiceRow extends StatelessWidget {
  const _ServiceRow();

  void _openConsultant(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ChatPage(workerName: 'AI装修顾问'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: ZdColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '按需找服务',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: ZdColors.textPrimary,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _openConsultant(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '帮我选服务',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ZdColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.0,
          children: const [
            _SvcCard(
              icon: Icons.engineering_rounded,
              iconColor: ZdColors.primary,
              bgColor: Color(0xFFFFF0E5),
              title: '全屋装修',
            ),
            _SvcCard(
              icon: Icons.home_repair_service_rounded,
              iconColor: Color(0xFF7C4DFF),
              bgColor: Color(0xFFF3E5FF),
              title: '旧房改造',
            ),
            _SvcCard(
              icon: Icons.grid_view_rounded,
              iconColor: Color(0xFF4CAF50),
              bgColor: Color(0xFFE8F5E9),
              title: '局部改造',
            ),
            _SvcCard(
              icon: Icons.water_drop_outlined,
              iconColor: Color(0xFFFFB800),
              bgColor: Color(0xFFFFF8E1),
              title: '防水维修',
            ),
            _SvcCard(
              icon: Icons.fact_check_rounded,
              iconColor: Color(0xFF4CAF50),
              bgColor: Color(0xFFE8F5E9),
              title: '验房收房',
            ),
            _SvcCard(
              icon: Icons.more_horiz_rounded,
              iconColor: Color(0xFF8A6B56),
              bgColor: Color(0xFFF7F1EA),
              title: '更多服务',
            ),
          ],
        ),
      ],
    );
  }
}

class _SvcCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;

  const _SvcCard({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ZdColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 为什么选择知底 ──
class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: ZdColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              '为什么选择知底',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: ZdColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _TrustIndicator(
                key: const Key('home-worker-selection-entry'),
                icon: Icons.engineering_rounded,
                title: '师傅严选',
                sub: '5重审核机制',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MasterSelectionPage(),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _TrustIndicator(
                icon: Icons.monetization_on_outlined,
                title: '工价透明',
                sub: '平台统一标准',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PriceTransparencyPage(),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _TrustIndicator(
                icon: Icons.verified_user_outlined,
                title: '施工保障',
                sub: '过程监管验收',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConstructionGuaranteePage()),
                ),
              ),
            ),
            Expanded(
              child: _TrustIndicator(
                icon: Icons.shield_outlined,
                title: '资金银行托管',
                sub: '银行监管账户',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FundBankEscrowPage()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrustIndicator extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback? onTap;
  const _TrustIndicator({
    super.key,
    required this.icon,
    required this.title,
    required this.sub,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0E5),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 24, color: ZdColors.primary),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ZdColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          style: const TextStyle(fontSize: 10, color: ZdColors.textSecondary),
        ),
      ],
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: content,
    );
  }
}
