import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../design/tokens.dart';
import '../../app/owner_app_scope.dart';
import '../../app/owner_app_state.dart';
import '../../models/renovation.dart';
import '../../widgets/home/top_bar.dart';
import 'my_home_page.dart';
import '../chat/chat_page.dart';
import '../message/message_page.dart';
import '../renovation/renovation_budget_report_page.dart';
import '../renovation/trade_select_page.dart';
import 'worker/worker_list_page.dart';
import 'master_selection_page.dart';
import '../price/price_transparency_page.dart';
import '../renovation/construction_guarantee_page.dart';
import '../renovation/fund_bank_escrow_page.dart';
import '../renovation/construction_standards_page.dart';
import '../profile/profile_page.dart';
import '../auth/login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentTab = 0;
  OwnerAppState? _appState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextState = OwnerAppScope.of(context);
    if (_appState == nextState) return;
    _appState?.removeListener(_handleOwnerStateChanged);
    _appState = nextState..addListener(_handleOwnerStateChanged);
  }

  @override
  void dispose() {
    _appState?.removeListener(_handleOwnerStateChanged);
    super.dispose();
  }

  void _handleOwnerStateChanged() {
    final appState = _appState;
    if (!mounted || appState == null) return;
    if (!appState.isLoggedIn && _currentTab != 0) {
      setState(() => _currentTab = 0);
    }
  }

  void _onTabTapped(int index) async {
    final appState = OwnerAppScope.of(context);
    // 首页以外的 tab 需要登录
    if (index != 0) {
      if (!appState.isLoggedIn) {
        final loggedIn = await Navigator.of(
          context,
        ).push<bool>(MaterialPageRoute(builder: (_) => const LoginPage()));
        if (!mounted) return;
        if (loggedIn != true) return;
      }
    }
    setState(() => _currentTab = index);
    if (index == 2) {
      unawaited(appState.fetchRemoteBookings());
    }
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
          final appState = OwnerAppScope.of(context);
          final unreadCount = appState.isLoggedIn
              ? appState.unreadMessageCount
              : 0;
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
              const Expanded(
                child: Column(
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
  const _SectionTitle({required this.title, this.spacing = 10});

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
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
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
                          _TrustItem(
                            icon: Icons.shield_outlined,
                            label: '平台托底',
                          ),
                        ],
                      ),
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

  void _openBudgetFlow(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _NewHomeRenovationFlowPage(scene: _ServiceRow.newHomeScene),
      ),
    );
  }

  void _openPriceTransparency(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PriceTransparencyPage()));
  }

  void _openConstructionStandards(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ConstructionStandardsPage()),
    );
  }

  void _openWorkerSelection(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TradeSelectPage()));
  }

  void _openFundEscrow(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const FundBankEscrowPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // ── Hero: 3分钟匹配合适工人 ──
          _HeroSection(onMatch: () => _onMatch(context)),
          const SizedBox(height: 14),
          _TrustFlowCard(
            onBudget: () => _openBudgetFlow(context),
            onPrice: () => _openPriceTransparency(context),
            onStandards: () => _openConstructionStandards(context),
            onFindWorker: () => _openWorkerSelection(context),
            onEscrow: () => _openFundEscrow(context),
          ),
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
          clipBehavior: Clip.none,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LeftNumber(),
                            SizedBox(height: 2),
                            Text(
                              '匹配合适师傅',
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                                color: _dark,
                                height: 1.05,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 145),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _CtaButton(onMatch: onMatch),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Text(
                      '先选需求，平台马上匹配师傅',
                      style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    children: [
                      _TagItem(label: '严格筛选'),
                      _TagItem(label: '实名认证'),
                      _TagItem(label: '银行监管'),
                    ],
                  ),
                ],
              ),
              const Positioned(right: 0, top: 30, child: _WorkerImage()),
              const Positioned(right: 3, top: 0, child: _WorkerBubble()),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // ── 数据统计条 ──
        Container(
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: const _HeroStatsPanel(),
        ),
      ],
    );
  }
}

class _HeroStatsPanel extends StatelessWidget {
  const _HeroStatsPanel();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _StatCell(
            icon: Icons.people_outline_rounded,
            value: '12,368+',
            label: '业主的选择',
          ),
        ),
        SizedBox(width: 4),
        Expanded(
          child: _StatCell(
            icon: Icons.access_time_rounded,
            value: '平均30分钟',
            label: '快速响应',
          ),
        ),
        SizedBox(width: 4),
        Expanded(
          child: _StatCell(
            icon: Icons.thumb_up_outlined,
            value: '99%',
            label: '好评率',
          ),
        ),
        SizedBox(width: 4),
        Expanded(
          child: _StatCell(
            icon: Icons.verified_user_rounded,
            value: '100%',
            label: '资质认证',
          ),
        ),
      ],
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
            '10',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              color: _HeroSection._orange,
              height: 1,
            ),
          ),
          const SizedBox(width: 2),
          const Padding(
            padding: EdgeInsets.only(bottom: 3),
            child: Text(
              '秒',
              style: TextStyle(
                fontSize: 21,
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

// ── 工人图片（放大，溢出卡片）──
class _WorkerImage extends StatelessWidget {
  const _WorkerImage();
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/worker_confident.png',
      width: 155,
      height: 135,
      fit: BoxFit.contain,
    );
  }
}

// ── 气泡标签 ──
class _WorkerBubble extends StatelessWidget {
  const _WorkerBubble();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Text(
        '3分钟内响应',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: ZdColors.primary,
          fontWeight: FontWeight.w600,
        ),
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
        widthFactor: 0.52,
        alignment: Alignment.centerLeft,
        child: Container(
          key: const Key('home-match-action'),
          constraints: const BoxConstraints(minHeight: 30),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
              '立即找师傅',
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
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: ZdColors.primary,
            ),
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

class _TrustFlowCard extends StatelessWidget {
  const _TrustFlowCard({
    required this.onBudget,
    required this.onPrice,
    required this.onStandards,
    required this.onFindWorker,
    required this.onEscrow,
  });

  final VoidCallback onBudget;
  final VoidCallback onPrice;
  final VoidCallback onStandards;
  final VoidCallback onFindWorker;
  final VoidCallback onEscrow;

  static const _steps = [
    _TrustFlowStepData(
      index: '1',
      title: '看预算',
      subtitle: '先知道大概要花多少',
      icon: Icons.calculate_outlined,
    ),
    _TrustFlowStepData(
      index: '2',
      title: '看工价',
      subtitle: '每项人工价格有标准',
      icon: Icons.price_check_outlined,
    ),
    _TrustFlowStepData(
      index: '3',
      title: '看标准',
      subtitle: '知道师傅该怎么施工',
      icon: Icons.rule_outlined,
    ),
    _TrustFlowStepData(
      index: '4',
      title: '找师傅',
      subtitle: '按需求匹配可接单师傅',
      icon: Icons.engineering_outlined,
    ),
    _TrustFlowStepData(
      index: '5',
      title: '托管下单',
      subtitle: '验收通过后再付款',
      icon: Icons.verified_user_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('home-trust-flow-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFE5D1)),
        boxShadow: [
          BoxShadow(
            color: ZdColors.primary.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: ZdColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '装修找师傅，先知底再下单',
                      style: TextStyle(
                        color: ZdColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '先了解价格和标准，再选择师傅，最后通过平台验收付款',
                      style: TextStyle(
                        color: ZdColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            children: [
              for (int i = 0; i < _steps.length; i++) ...[
                _TrustFlowStep(
                  data: _steps[i],
                  isLast: i == _steps.length - 1,
                  onTap: switch (i) {
                    0 => onBudget,
                    1 => onPrice,
                    2 => onStandards,
                    3 => onFindWorker,
                    _ => onEscrow,
                  },
                ),
                if (i != _steps.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TrustFlowStepData {
  const _TrustFlowStepData({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String index;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _TrustFlowStep extends StatelessWidget {
  const _TrustFlowStep({
    required this.data,
    required this.isLast,
    required this.onTap,
  });

  final _TrustFlowStepData data;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0E5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(data.icon, color: ZdColors.primary, size: 17),
                ),
                if (!isLast)
                  Container(
                    width: 1,
                    height: 12,
                    margin: const EdgeInsets.only(top: 4),
                    color: const Color(0xFFFFD6BC),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: const TextStyle(
                        color: ZdColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${data.index}. ${data.subtitle}',
                      style: const TextStyle(
                        color: ZdColors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: ZdColors.textHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 按需找服务 ──
class _ServiceRow extends StatelessWidget {
  const _ServiceRow();

  static const newHomeScene = _ServiceScene(
    title: '新房装修',
    subtitle: '从毛坯到入住，一站式施工服务',
    flowTitle: '新房装修流程',
    icon: Icons.apartment_rounded,
    accentColor: ZdColors.primary,
    image: null,
  );

  static const _scenes = [
    newHomeScene,
    _ServiceScene(
      title: '老房翻新',
      subtitle: '解决老房空间、功能和美观问题',
      flowTitle: '旧改流程',
      icon: Icons.home_work_rounded,
      accentColor: Color(0xFF8A6B56),
      image: null,
    ),
    _ServiceScene(
      title: '局部改造',
      subtitle: '针对单个空间快速升级',
      flowTitle: '局改需求',
      icon: Icons.grid_view_rounded,
      accentColor: Color(0xFF4CAF50),
      image: null,
    ),
    _ServiceScene(
      title: '找设计师',
      subtitle: '专业方案规划，避免装修踩坑',
      flowTitle: '设计师匹配',
      icon: Icons.design_services_rounded,
      accentColor: Color(0xFF7C4DFF),
      image: null,
    ),
    _ServiceScene(
      title: '验房收房',
      subtitle: '入住前检查房屋质量问题',
      flowTitle: '验房服务',
      icon: Icons.fact_check_rounded,
      accentColor: Color(0xFF2E7D32),
      image: null,
    ),
  ];

  void _openConsultant(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatPage(workerName: 'AI装修顾问')),
    );
  }

  void _openScene(BuildContext context, _ServiceScene scene) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _ServiceSceneFlowPage(scene: scene)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstRow = _scenes.take(2).toList();
    final secondRow = _scenes.skip(2).take(2).toList();
    final finalScene = _scenes.last;

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
        _ServiceSceneRow(
          scenes: firstRow,
          onTap: (scene) => _openScene(context, scene),
        ),
        const SizedBox(height: 10),
        _ServiceSceneRow(
          scenes: secondRow,
          onTap: (scene) => _openScene(context, scene),
        ),
        const SizedBox(height: 10),
        _ServiceSceneCard(
          scene: finalScene,
          fullWidth: true,
          onTap: () => _openScene(context, finalScene),
        ),
      ],
    );
  }
}

class _ServiceScene {
  const _ServiceScene({
    required this.title,
    required this.subtitle,
    required this.flowTitle,
    required this.icon,
    required this.accentColor,
    required this.image,
  });

  final String title;
  final String subtitle;
  final String flowTitle;
  final IconData icon;
  final Color accentColor;
  final ImageProvider? image;
}

class _ServiceSceneRow extends StatelessWidget {
  const _ServiceSceneRow({required this.scenes, required this.onTap});

  final List<_ServiceScene> scenes;
  final void Function(_ServiceScene scene) onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < scenes.length; i++) ...[
          Expanded(
            child: _ServiceSceneCard(
              scene: scenes[i],
              onTap: () => onTap(scenes[i]),
            ),
          ),
          if (i != scenes.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _ServiceSceneCard extends StatelessWidget {
  final _ServiceScene scene;
  final bool fullWidth;
  final VoidCallback onTap;

  const _ServiceSceneCard({
    required this.scene,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: BoxConstraints(minHeight: fullWidth ? 128 : 166),
          decoration: BoxDecoration(
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
            padding: const EdgeInsets.all(10),
            child: fullWidth
                ? Row(
                    children: [
                      SizedBox(
                        width: 112,
                        height: 92,
                        child: _ServiceSceneImage(scene: scene),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _ServiceSceneCopy(scene: scene)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 58,
                        width: double.infinity,
                        child: _ServiceSceneImage(scene: scene),
                      ),
                      const SizedBox(height: 10),
                      _ServiceSceneCopy(scene: scene),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ServiceSceneImage extends StatelessWidget {
  const _ServiceSceneImage({required this.scene});

  final _ServiceScene scene;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          image: scene.image == null
              ? null
              : DecorationImage(image: scene.image!, fit: BoxFit.cover),
          gradient: scene.image == null
              ? LinearGradient(
                  colors: [
                    scene.accentColor.withValues(alpha: 0.18),
                    const Color(0xFFFFF7F0),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Stack(
          children: [
            Positioned(
              right: -12,
              bottom: -12,
              child: Icon(
                scene.icon,
                size: 64,
                color: scene.accentColor.withValues(alpha: 0.12),
              ),
            ),
            Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.86),
                  shape: BoxShape.circle,
                ),
                child: Icon(scene.icon, size: 20, color: scene.accentColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceSceneCopy extends StatelessWidget {
  const _ServiceSceneCopy({required this.scene});

  final _ServiceScene scene;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          scene.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: ZdColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          scene.subtitle,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            height: 1.3,
            color: ZdColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ServiceSceneFlowPage extends StatelessWidget {
  const _ServiceSceneFlowPage({required this.scene});

  final _ServiceScene scene;

  @override
  Widget build(BuildContext context) {
    if (scene.flowTitle == '新房装修流程') {
      return _NewHomeRenovationFlowPage(scene: scene);
    }

    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: Text(scene.flowTitle),
        backgroundColor: ZdColors.background,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 180,
                width: double.infinity,
                child: _ServiceSceneImage(scene: scene),
              ),
              const SizedBox(height: 14),
              Text(
                scene.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: ZdColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                scene.subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: ZdColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewHomeRenovationFlowPage extends StatefulWidget {
  const _NewHomeRenovationFlowPage({required this.scene});

  final _ServiceScene scene;

  @override
  State<_NewHomeRenovationFlowPage> createState() =>
      _NewHomeRenovationFlowPageState();
}

class _NewHomeRenovationFlowPageState
    extends State<_NewHomeRenovationFlowPage> {
  String _area = '50-90㎡';
  String _houseType = '普通住宅';
  String _stage = '毛坯房';
  String _grade = '品质装修';

  void _openBudgetResult() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RenovationBudgetReportPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: const Text('新房装修流程'),
        backgroundColor: ZdColors.background,
        foregroundColor: ZdColors.textPrimary,
        elevation: 0,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _openBudgetResult,
            style: ElevatedButton.styleFrom(
              backgroundColor: ZdColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text(
              '生成装修预算',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NewHomeIntroCard(scene: widget.scene),
            const SizedBox(height: 14),
            _RenovationStepCard(
              stepLabel: '第一步：房屋信息',
              title: '请输入您的房屋情况',
              children: [
                _RenovationChoiceGroup(
                  label: '房屋面积：',
                  options: const ['50㎡以下', '50-90㎡', '90-120㎡', '120㎡以上'],
                  selectedValue: _area,
                  onChanged: (value) => setState(() => _area = value),
                ),
                const SizedBox(height: 18),
                _RenovationChoiceGroup(
                  label: '房屋类型：',
                  options: const ['普通住宅', '公寓', '别墅'],
                  selectedValue: _houseType,
                  onChanged: (value) => setState(() => _houseType = value),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _RenovationStepCard(
              stepLabel: '第二步：装修情况',
              children: [
                _RenovationChoiceGroup(
                  label: '装修阶段：',
                  options: const ['毛坯房', '精装改造'],
                  selectedValue: _stage,
                  onChanged: (value) => setState(() => _stage = value),
                ),
                const SizedBox(height: 18),
                _RenovationChoiceGroup(
                  label: '装修档次：',
                  options: const ['简约实用', '品质装修', '高端装修'],
                  selectedValue: _grade,
                  onChanged: (value) => setState(() => _grade = value),
                ),
              ],
            ),
            const SizedBox(height: 88),
          ],
        ),
      ),
    );
  }
}

class _NewHomeIntroCard extends StatelessWidget {
  const _NewHomeIntroCard({required this.scene});

  final _ServiceScene scene;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            width: double.infinity,
            child: _ServiceSceneImage(scene: scene),
          ),
          const SizedBox(height: 14),
          Text(
            scene.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: ZdColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            scene.subtitle,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: ZdColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RenovationStepCard extends StatelessWidget {
  const _RenovationStepCard({
    required this.stepLabel,
    required this.children,
    this.title,
  });

  final String stepLabel;
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: ZdColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: ZdColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  stepLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: ZdColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (title != null) ...[
            const SizedBox(height: 10),
            Text(
              title!,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: ZdColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

class _RenovationChoiceGroup extends StatelessWidget {
  const _RenovationChoiceGroup({
    required this.label,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final String selectedValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: ZdColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final option in options)
              _RenovationChoicePill(
                label: option,
                selected: option == selectedValue,
                onTap: () => onChanged(option),
              ),
          ],
        ),
      ],
    );
  }
}

class _RenovationChoicePill extends StatelessWidget {
  const _RenovationChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFFFF0E5) : ZdColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? ZdColors.primary
                  : ZdColors.textSecondary.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: ZdColors.primary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected ? ZdColors.primary : ZdColors.textPrimary,
                ),
              ),
            ],
          ),
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
                  MaterialPageRoute(
                    builder: (_) => const ConstructionGuaranteePage(),
                  ),
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
