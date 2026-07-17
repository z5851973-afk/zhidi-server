import 'package:flutter/material.dart';
import '../../app/owner_appointment.dart';
import '../../app/owner_app_scope.dart';
import '../renovation/trade_select_page.dart';
import '../../design/tokens.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  bool _fetched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fetched) return;
    _fetched = true;
    OwnerAppScope.of(context).fetchRemoteBookings();
  }

  @override
  Widget build(BuildContext context) {
    final state = OwnerAppScope.of(context);
    final orders = state.appointments;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: AppBar(
        title: const Text(
          '我的预约',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: ZdColors.textPrimary,
        elevation: 0,
      ),
      body: state.isFetchingRemoteBookings && orders.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.remoteBookingError != null && orders.isEmpty
          ? _RemoteBookingError(
              message: state.remoteBookingError!,
              onRetry: state.fetchRemoteBookings,
            )
          : orders.isEmpty
          ? const _EmptyOrders()
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final order = orders[index];
                return Dismissible(
                  key: ValueKey(order.id),
                  direction: DismissDirection.endToStart,
                  background: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 80,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  confirmDismiss: (_) async {
                    final isRemote = order.id.startsWith('rm-');
                    final dialogTitle = isRemote ? '确认取消预约' : '确认删除';
                    final dialogContent = isRemote
                        ? '确定要取消「${order.workerName}」的预约吗？取消后不可恢复。'
                        : '确定要删除「${order.workerName}」的预约吗？';
                    final actionLabel = isRemote ? '取消预约' : '删除';
                    return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(dialogTitle),
                        content: Text(dialogContent),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                            ),
                            child: Text(actionLabel),
                          ),
                        ],
                      ),
                    ) ?? false;
                  },
                  onDismissed: (_) {
                    if (order.id.startsWith('rm-')) {
                      OwnerAppScope.of(context)
                          .cancelRemoteBooking(order.id);
                    } else {
                      OwnerAppScope.of(context).removeAppointment(order.id);
                    }
                  },
                  child: _OrderCard(order: order),
                );
              },
            ),
    );
  }
}

class _RemoteBookingError extends StatelessWidget {
  const _RemoteBookingError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    ),
  );
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.event_busy_rounded,
            size: 54,
            color: Color(0xFFBBBBBB),
          ),
          const SizedBox(height: 12),
          const Text(
            '暂无预约',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF777777),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TradeSelectPage()),
            ),
            child: const Text('去发现师傅'),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderItem order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_turned_in_rounded,
                color: Color(0xFFFF7A2F),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.workerName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: ZdColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF8ED),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  order.status,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF15A34A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _RowText(title: '联系人', value: order.customerName),
          const SizedBox(height: 8),
          _RowText(title: '手机号', value: order.phone),
          const SizedBox(height: 8),
          _RowText(title: '地址', value: order.address),
          const SizedBox(height: 8),
          _RowText(title: '上门时间', value: order.visitTime),
          const SizedBox(height: 12),
          Text(
            order.description,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF666666),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RowText extends StatelessWidget {
  final String title;
  final String value;

  const _RowText({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: ZdColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: ZdColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}
