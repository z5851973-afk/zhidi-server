// ============================================================
// 工匠端首页 — 接单中心
// 底部导航三Tab：接单中心 / 消息 / 我的
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/worker_app_scope.dart';
import '../../app/worker_app_state.dart';
import '../../design/tokens.dart';
import '../../design/components.dart';
import '../../models/chat_models.dart';
import '../../services/auth_api_client.dart';
import '../../services/chat_api_client.dart';
import '../chat/chat_detail_page.dart';
import 'order_detail_page.dart';
import 'daily_report_page.dart';
import 'inspection_page.dart';
import 'worker_profile_page.dart';
import 'worker_earnings_page.dart';
import 'worker_login_page.dart';

// ── 设计常量 ──
const _primary = ZdColors.primary;
const _textDark = ZdColors.textPrimary;
const _textMid = ZdColors.textSecondary;
const _textLight = ZdColors.textHint;
const _divider = ZdColors.divider;
const _bg = ZdColors.background;
const _cardBg = Colors.white;
const _success = ZdColors.success;

class WorkerHomePage extends StatefulWidget {
  const WorkerHomePage({super.key, this.chatApi});

  final ChatApi? chatApi;

  @override
  State<WorkerHomePage> createState() => _WorkerHomePageState();
}

class _WorkerHomePageState extends State<WorkerHomePage>
    with WidgetsBindingObserver {
  static const _remoteRefreshInterval = Duration(seconds: 8);

  int _tabIndex = 0;
  bool _fetched = false;
  Timer? _remoteRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fetched) return;
    _fetched = true;
    unawaited(WorkerAppScope.of(context).connectBackend());
    _startRemoteRefreshTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(WorkerAppScope.of(context).fetchRemoteBookings());
    }
  }

  @override
  void dispose() {
    _remoteRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startRemoteRefreshTimer() {
    _remoteRefreshTimer ??= Timer.periodic(_remoteRefreshInterval, (_) {
      if (!mounted) return;
      final state = WorkerAppScope.of(context);
      if (state.isLoggedIn) {
        unawaited(state.fetchRemoteBookings());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = WorkerAppScope.of(context);
    final earnings = state.totalEarnings;
    final pendingAmount = state.earnings
        .where((e) => e.status == EarningSettlementStatus.pending)
        .fold<double>(0, (s, e) => s + e.amount);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部收入概览卡片
            _buildEarningsBar(earnings, pendingAmount),
            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  _OrdersTab(state: state),
                  _MessagesTab(
                    state: state,
                    chatApi: widget.chatApi ?? ChatApiClient(),
                  ),
                  _ProfileTab(state: state),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          key: const Key('worker-bottom-navigation-content'),
          decoration: const BoxDecoration(
            color: _cardBg,
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.04),
                blurRadius: 8,
                offset: Offset(0, -1),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _tabIndex,
            onTap: (i) => setState(() => _tabIndex = i),
            type: BottomNavigationBarType.fixed,
            backgroundColor: _cardBg,
            selectedItemColor: _primary,
            unselectedItemColor: _textMid,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            items: [
              BottomNavigationBarItem(
                icon: _navIconWithBadge(
                  Icons.assignment_outlined,
                  state.pendingOrders.length,
                ),
                activeIcon: _navIconWithBadge(
                  Icons.assignment,
                  state.pendingOrders.length,
                ),
                label: '接单中心',
              ),
              BottomNavigationBarItem(
                icon: _navIconWithBadge(
                  Icons.message_outlined,
                  state.unreadMessageCount,
                ),
                activeIcon: _navIconWithBadge(
                  Icons.message,
                  state.unreadMessageCount,
                ),
                label: '消息',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline),
                activeIcon: const Icon(Icons.person),
                label: '我的',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navIconWithBadge(IconData icon, int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -8,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(999),
              ),
              constraints: const BoxConstraints(minWidth: 16),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEarningsBar(double total, double pending) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZdSpacing.lg,
        vertical: ZdSpacing.md,
      ),
      decoration: const BoxDecoration(color: _cardBg),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: ZdColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(ZdRadius.sm),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: ZdSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('今日收入', style: ZdText.tiny),
                    Text(
                      '¥${total.toStringAsFixed(0)}',
                      style: ZdText.title.copyWith(color: _primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(width: 1, height: 32, color: _divider),
          const SizedBox(width: ZdSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('待结算', style: ZdText.tiny),
                Text(
                  '¥${pending.toStringAsFixed(0)}',
                  style: ZdText.subtitle.copyWith(color: _textDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// 接单中心 Tab
// ═══════════════════════════════════════════
class _OrdersTab extends StatelessWidget {
  const _OrdersTab({required this.state});
  final WorkerAppState state;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: _cardBg,
            child: TabBar(
              labelColor: _primary,
              unselectedLabelColor: _textMid,
              indicatorColor: _primary,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 15),
              tabs: const [
                Tab(text: '待接单'),
                Tab(text: '进行中'),
                Tab(text: '已完成'),
              ],
            ),
          ),
          Container(height: 1, color: _divider),
          Expanded(
            child: TabBarView(
              children: [
                _PendingList(state: state),
                _ActiveList(state: state),
                _CompletedList(state: state),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 待接单列表 ──
class _PendingList extends StatelessWidget {
  const _PendingList({required this.state});
  final WorkerAppState state;

  @override
  Widget build(BuildContext context) {
    final orders = state.pendingOrders;
    if (orders.isEmpty) {
      return _emptyView('暂无待接订单\n有新的匹配需求会第一时间通知您');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(ZdSpacing.md),
      itemCount: orders.length,
      itemBuilder: (context, i) => _PendingCard(order: orders[i], state: state),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.order, required this.state});
  final WorkerOrder order;
  final WorkerAppState state;

  @override
  Widget build(BuildContext context) {
    return ZdCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：业主 + 时间
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ZdSpacing.lg,
              ZdSpacing.lg,
              ZdSpacing.lg,
              ZdSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(ZdRadius.sm),
                  ),
                  child: const Icon(Icons.person, color: _primary, size: 22),
                ),
                const SizedBox(width: ZdSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.ownerName, style: ZdText.subtitle),
                      const SizedBox(height: 2),
                      Text(_formatTime(order.createdAt), style: ZdText.tiny),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(ZdRadius.pill),
                  ),
                  child: Text(
                    order.trade,
                    style: ZdText.tiny.copyWith(
                      color: _primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (state.isRemoteOrder(order.id))
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(ZdRadius.pill),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '云端',
                      style: ZdText.tiny.copyWith(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 需求信息
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZdSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(
                  Icons.home_outlined,
                  '${order.requirement}（${order.area}）',
                ),
                const SizedBox(height: 6),
                _infoRow(Icons.location_on_outlined, order.ownerAddress),
              ],
            ),
          ),
          const SizedBox(height: ZdSpacing.lg),
          // 分割线 + 操作按钮
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _divider)),
            ),
            child: Row(
              children: [
                // 拒绝
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      if (state.isRemoteOrder(order.id)) {
                        final ok = await state.rejectRemoteBooking(order.id);
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                state.remoteBookingError ?? '拒单失败，请重试',
                              ),
                            ),
                          );
                        }
                      } else {
                        await WorkerAppScope.of(context).rejectOrder(order.id);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: ZdSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: _divider)),
                      ),
                      child: Center(
                        child: Text(
                          '拒绝',
                          style: ZdText.body.copyWith(color: _textMid),
                        ),
                      ),
                    ),
                  ),
                ),
                // 立即接单
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      if (state.isRemoteOrder(order.id)) {
                        final ok = await state.acceptRemoteBooking(order.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? '接单成功，请提出上门时间'
                                  : state.remoteBookingError ?? '接单失败，请重试',
                            ),
                          ),
                        );
                      } else {
                        _showAcceptDialog(context, order);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: ZdSpacing.md,
                      ),
                      child: Center(
                        child: Text(
                          '立即接单',
                          style: ZdText.body.copyWith(
                            color: _primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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

  void _showAcceptDialog(BuildContext context, WorkerOrder order) {
    final priceCtrl = TextEditingController();
    // 默认上门时间：明天上午9点
    var visitTime = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day + 1,
      9,
      0,
    );
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZdRadius.card),
          ),
          title: Text('确认接单', style: ZdText.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${order.ownerName} — ${order.requirement}',
                style: ZdText.caption,
              ),
              const SizedBox(height: ZdSpacing.lg),
              // 上门时间
              Text(
                '约定上门时间',
                style: ZdText.caption.copyWith(
                  color: _textDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: ZdSpacing.sm),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: visitTime,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 180)),
                    locale: const Locale('zh'),
                  );
                  if (date == null) return;
                  if (!ctx.mounted) return;
                  final time = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(visitTime),
                  );
                  if (time == null) return;
                  setDialogState(() {
                    visitTime = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time.hour,
                      time.minute,
                    );
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: _divider),
                    borderRadius: BorderRadius.circular(ZdRadius.sm),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, size: 18, color: _primary),
                      const SizedBox(width: ZdSpacing.sm),
                      Text(
                        '${visitTime.month}月${visitTime.day}日 ${visitTime.hour.toString().padLeft(2, '0')}:${visitTime.minute.toString().padLeft(2, '0')}',
                        style: ZdText.body,
                      ),
                      const Spacer(),
                      Text('修改', style: ZdText.tiny.copyWith(color: _primary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: ZdSpacing.lg),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '报价（选填）',
                  hintText: '请输入报价金额',
                  prefixText: '¥ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ZdRadius.sm),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: ZdText.body.copyWith(color: _textMid)),
            ),
            ZdPrimaryButton(
              label: '确认接单',
              height: 40,
              onTap: () async {
                final p = double.tryParse(priceCtrl.text);
                await WorkerAppScope.of(
                  context,
                ).acceptOrder(order.id, quotedPrice: p, visitTime: visitTime);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: _textMid),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: ZdText.caption)),
      ],
    );
  }

  static String _formatTime(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }
}

// ── 进行中列表 ──
class _ActiveList extends StatelessWidget {
  const _ActiveList({required this.state});
  final WorkerAppState state;

  @override
  Widget build(BuildContext context) {
    final orders = state.activeOrders;
    if (orders.isEmpty) {
      return _emptyView('暂无进行中的订单');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(ZdSpacing.md),
      itemCount: orders.length,
      itemBuilder: (context, i) {
        final o = orders[i];
        return ZdCard(
          padding: EdgeInsets.zero,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: o.id)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(ZdSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头部
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: o.status == WorkerOrderStatus.accepted
                            ? _primary.withValues(alpha: 0.1)
                            : _success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(ZdRadius.pill),
                      ),
                      child: Text(
                        o.statusLabel,
                        style: ZdText.tiny.copyWith(
                          color: o.status == WorkerOrderStatus.accepted
                              ? _primary
                              : _success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(o.ownerName, style: ZdText.body),
                  ],
                ),
                const SizedBox(height: ZdSpacing.md),
                Text(o.requirement, style: ZdText.subtitle),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        o.ownerAddress,
                        style: ZdText.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (o.visitTime != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.schedule, size: 13, color: _primary),
                      const SizedBox(width: 2),
                      Text(
                        '${o.visitTime!.month}月${o.visitTime!.day}日上门',
                        style: ZdText.tiny.copyWith(
                          color: _primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                if (o.phaseName != null) ...[
                  const SizedBox(height: ZdSpacing.sm),
                  Row(
                    children: [
                      Icon(Icons.engineering, size: 14, color: _primary),
                      const SizedBox(width: 4),
                      Text(
                        '当前工序：${o.phaseName}',
                        style: ZdText.tiny.copyWith(color: _primary),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: ZdSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _actionChip(Icons.edit_note, '日报', () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DailyReportPage(orderId: o.id),
                        ),
                      );
                    }),
                    _actionChip(Icons.fact_check_outlined, '验收', () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InspectionPage(orderId: o.id),
                        ),
                      );
                    }),
                    _actionChip(Icons.phone_outlined, '联系', () {
                      // 此处仅示意，实际需 url_launcher
                    }),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actionChip(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ZdSpacing.md,
          vertical: ZdSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: _divider),
          borderRadius: BorderRadius.circular(ZdRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _textDark),
            const SizedBox(width: 4),
            Text(label, style: ZdText.tiny.copyWith(color: _textDark)),
          ],
        ),
      ),
    );
  }
}

// ── 已完成列表 ──
class _CompletedList extends StatelessWidget {
  const _CompletedList({required this.state});
  final WorkerAppState state;

  @override
  Widget build(BuildContext context) {
    final orders = state.completedOrders;
    if (orders.isEmpty) {
      return _emptyView('暂无已完成的订单');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(ZdSpacing.md),
      itemCount: orders.length,
      itemBuilder: (context, i) {
        final o = orders[i];
        // 查找对应收入
        final earning = state.earnings
            .where((e) => e.orderId == o.id)
            .fold<double>(0, (s, e) => s + e.amount);
        return ZdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.requirement, style: ZdText.subtitle),
                        const SizedBox(height: 4),
                        Text(
                          '${o.ownerName} · ${o.ownerAddress}',
                          style: ZdText.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (earning > 0)
                    Text(
                      '¥${earning.toStringAsFixed(0)}',
                      style: ZdText.subtitle.copyWith(color: _primary),
                    ),
                ],
              ),
              const SizedBox(height: ZdSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ZdRadius.pill),
                ),
                child: Text(
                  '已完成',
                  style: ZdText.tiny.copyWith(color: _success),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget _emptyView(String text) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inbox_outlined, size: 56, color: _textLight),
        const SizedBox(height: ZdSpacing.md),
        Text(
          text,
          style: ZdText.caption.copyWith(color: _textLight),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════
// 消息 Tab
// ═══════════════════════════════════════════
class _MessagesTab extends StatefulWidget {
  const _MessagesTab({required this.state, required this.chatApi});
  final WorkerAppState state;
  final ChatApi chatApi;

  @override
  State<_MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<_MessagesTab> {
  List<ChatRoomModel> _rooms = const [];
  bool _loadingRooms = true;
  String? _roomsError;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRooms());
  }

  Future<void> _loadRooms() async {
    final token = widget.state.getAccessToken();
    if (token == null) {
      if (!mounted) return;
      setState(() {
        _loadingRooms = false;
        _roomsError = '登录已过期，请重新登录';
      });
      return;
    }

    setState(() {
      _loadingRooms = true;
      _roomsError = null;
    });

    try {
      final userId = await widget.state.getUserId();
      final rooms = await widget.chatApi.getRooms(token);
      if (!mounted) return;
      setState(() {
        _currentUserId = userId;
        _rooms = rooms;
        _loadingRooms = false;
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        await widget.state.logout();
        if (!mounted) return;
        setState(() {
          _loadingRooms = false;
          _roomsError = '登录已过期，请重新登录';
        });
        return;
      }
      setState(() {
        _loadingRooms = false;
        _roomsError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRooms = false;
        _roomsError = '聊天加载失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final msgs = widget.state.messages;
    if (_loadingRooms && msgs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rooms.isEmpty && msgs.isEmpty && _roomsError == null) {
      return _emptyView('暂无消息');
    }
    return Column(
      children: [
        if (_roomsError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: ZdSpacing.sm),
            color: _primary.withValues(alpha: 0.05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    _roomsError!,
                    style: ZdText.tiny.copyWith(color: _primary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(onPressed: _loadRooms, child: const Text('重试')),
              ],
            ),
          )
        else if (widget.state.unreadMessageCount > 0)
          GestureDetector(
            onTap: () => widget.state.markAllMessagesRead(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: ZdSpacing.sm),
              color: _primary.withValues(alpha: 0.05),
              child: Text(
                '${widget.state.unreadMessageCount} 条通知未读，点击全部标为已读',
                style: ZdText.tiny.copyWith(color: _primary),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadRooms,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (_rooms.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      ZdSpacing.md,
                      ZdSpacing.md,
                      ZdSpacing.md,
                      ZdSpacing.xs,
                    ),
                    child: Text(
                      '聊天',
                      style: ZdText.caption.copyWith(
                        color: _textMid,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final room in _rooms) _chatRoomItem(room),
                ],
                if (msgs.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      ZdSpacing.md,
                      ZdSpacing.md,
                      ZdSpacing.md,
                      ZdSpacing.xs,
                    ),
                    child: Text(
                      '通知',
                      style: ZdText.caption.copyWith(
                        color: _textMid,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final m in msgs) _notificationItem(m),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chatRoomItem(ChatRoomModel room) {
    return ZdListItem(
      image: CircleAvatar(
        backgroundColor: _success.withValues(alpha: 0.12),
        child: Text(
          room.otherUserName.isEmpty ? '业' : room.otherUserName[0],
          style: const TextStyle(
            color: _success,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      title: room.otherUserName.isEmpty ? '业主' : room.otherUserName,
      subtitle: room.lastMessageText ?? '暂无消息',
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_formatRoomTime(room.lastMessageAt), style: ZdText.tiny),
          if (room.unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                room.unreadCount > 99 ? '99+' : '${room.unreadCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: () => _openChat(room),
    );
  }

  Widget _notificationItem(WorkerMessage m) {
    return ZdListItem(
      image: Container(
        decoration: BoxDecoration(
          color: m.isRead
              ? Colors.grey.shade100
              : _primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(ZdRadius.sm),
        ),
        child: Icon(
          m.category == '订单'
              ? Icons.receipt_long_outlined
              : m.category == '验收'
              ? Icons.fact_check_outlined
              : m.category == '收入'
              ? Icons.payments_outlined
              : Icons.notifications_outlined,
          color: m.isRead ? _textMid : _primary,
        ),
      ),
      title: m.title,
      subtitle: m.content,
      trailing: Text(_formatMsgTime(m.createdAt), style: ZdText.tiny),
      onTap: () => widget.state.markMessageRead(m.id),
    );
  }

  void _openChat(ChatRoomModel room) {
    final token = widget.state.getAccessToken();
    final currentUserId = _currentUserId;
    if (token == null || currentUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录已过期，请重新登录')));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          roomId: room.id,
          otherUserName: room.otherUserName.isEmpty ? '业主' : room.otherUserName,
          accessToken: token,
          currentUserId: currentUserId,
        ),
      ),
    );
  }

  String _formatRoomTime(DateTime? time) {
    if (time == null) return '';
    return _formatMsgTime(time);
  }

  String _formatMsgTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }
}

// ═══════════════════════════════════════════
// 我的 Tab
// ═══════════════════════════════════════════
class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.state});
  final WorkerAppState state;

  @override
  Widget build(BuildContext context) {
    final p = state.profile;
    return ListView(
      padding: const EdgeInsets.all(ZdSpacing.md),
      children: [
        // 个人信息卡片
        ZdCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: _primary.withValues(alpha: 0.1),
                child: Text(
                  p.name.isNotEmpty ? p.name[0] : '工',
                  style: const TextStyle(
                    fontSize: 22,
                    color: _primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: ZdSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(p.name, style: ZdText.subtitle),
                        if (p.isVerified) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.verified, size: 16, color: _primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${p.tradeLabel} · ${p.experienceYears}年经验',
                      style: ZdText.caption,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          '${p.rating}',
                          style: ZdText.tiny.copyWith(color: _textDark),
                        ),
                        const SizedBox(width: ZdSpacing.md),
                        Text('接单 ${p.totalOrders}', style: ZdText.tiny),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: _textLight),
            ],
          ),
        ),
        const SizedBox(height: ZdSpacing.md),
        // 功能入口列表
        _menuItem(Icons.person_outline, '个人资料', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WorkerProfilePage()),
          );
        }),
        _menuItem(Icons.account_balance_wallet_outlined, '收入明细', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WorkerEarningsPage()),
          );
        }),
        _menuItem(Icons.article_outlined, '施工标准', () {}),
        _menuItem(Icons.logout, '退出登录', () async {
          final scope = WorkerAppScope.of(context);
          await scope.logout();
          if (!context.mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const WorkerLoginPage()),
            (_) => false,
          );
        }),
        const SizedBox(height: ZdSpacing.md),
        _menuItem(Icons.info_outline, '关于知底', () {}),
      ],
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap) {
    return ZdCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: Icon(icon, color: _textDark),
          title: Text(label, style: ZdText.body),
          trailing: Icon(Icons.chevron_right, color: _textLight),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: ZdSpacing.lg),
          splashColor: ZdColors.primary.withValues(alpha: 0.08),
        ),
      ),
    );
  }
}
