import 'package:flutter/material.dart';

import '../../app/owner_app_scope.dart';
import '../../app/owner_models.dart';
import '../home/worker/worker_detail_page.dart';
import '../renovation/trade_select_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  static const _primary = Color(0xFFFF5A00);
  final Set<String> _removingWorkers = {};
  final Set<String> _removingQuotes = {};

  Future<void> _removeWorker(FavoriteWorker worker) async {
    setState(() => _removingWorkers.add(worker.id));
    try {
      await OwnerAppScope.of(context).toggleFavorite(worker);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('取消收藏失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _removingWorkers.remove(worker.id));
    }
  }

  Future<void> _removeQuote(SavedQuote quote) async {
    setState(() => _removingQuotes.add(quote.id));
    try {
      await OwnerAppScope.of(context).removeSavedQuote(quote.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('删除报价收藏失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _removingQuotes.remove(quote.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = OwnerAppScope.of(context);
    final workers = scope.favoriteWorkers;
    final quotes = scope.savedQuotes;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: AppBar(
        title: const Text(
          '我的收藏',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF222222),
      ),
      body: workers.isEmpty && quotes.isEmpty
          ? _EmptyFavorites(
              onDiscover: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TradeSelectPage()),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── 师傅收藏 ──
                if (workers.isNotEmpty) ...[
                  const _SectionHeader(title: '师傅收藏', count: null),
                  const SizedBox(height: 8),
                  ...workers.map((worker) {
                    final removing = _removingWorkers.contains(worker.id);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        splashColor: _primary.withValues(alpha: 0.08),
                        contentPadding: const EdgeInsets.all(12),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFFEEE3),
                          child: Icon(
                            Icons.person_rounded,
                            color: _primary,
                          ),
                        ),
                        title: Text(
                          worker.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text('${worker.trade} · ${worker.city}'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WorkerDetailPage(
                              workerId: worker.id,
                              name: worker.name,
                              workerJob: worker.trade,
                            ),
                          ),
                        ),
                        trailing: IconButton(
                          key: Key('remove-favorite-${worker.id}'),
                          tooltip: '取消收藏',
                          onPressed: removing ? null : () => _removeWorker(worker),
                          icon: removing
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.delete_outline_rounded),
                        ),
                      ),
                    );
                  }),
                ],

                // ── 报价收藏 ──
                if (quotes.isNotEmpty) ...[
                  if (workers.isNotEmpty) const SizedBox(height: 8),
                  _SectionHeader(title: '报价收藏', count: quotes.length),
                  const SizedBox(height: 8),
                  ...quotes.map((quote) => _QuoteCard(
                    quote: quote,
                    removing: _removingQuotes.contains(quote.id),
                    onDelete: () => _removeQuote(quote),
                  )),
                ],
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.count});
  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final label = count != null ? '$title（$count）' : title;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF333333)),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote, required this.removing, required this.onDelete});
  final SavedQuote quote;
  final bool removing;
  final VoidCallback onDelete;

  String _formatTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final maxItems = 3;
    final visibleItems = quote.items.take(maxItems).toList();
    final remaining = quote.items.length - maxItems;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行：师傅名 + 工种 + 删除按钮
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.person_rounded, size: 18, color: Color(0xFFFF5A00)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${quote.workerName}  ·  ${quote.tradeName}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: removing ? null : onDelete,
                  child: removing
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFF999999)),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 项目明细列表
            ...visibleItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '¥${item.unitPrice.toStringAsFixed(0)} × ${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)}${item.unit.replaceFirst('/', '')}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '¥${item.subtotal.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                  ),
                ],
              ),
            )),

            // 超出项提示
            if (remaining > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '...等 $remaining 项',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                ),
              ),

            const Divider(height: 20),

            // 合计 + 时间
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('合计 ', style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
                    Text(
                      '¥${quote.grandTotal.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFFFF5A00)),
                    ),
                  ],
                ),
                Text(
                  _formatTime(quote.savedAt),
                  style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites({required this.onDiscover});

  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.favorite_border_rounded,
          size: 54,
          color: Color(0xFFBBBBBB),
        ),
        const SizedBox(height: 12),
        const Text(
          '暂无收藏',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onDiscover, child: const Text('去发现师傅')),
      ],
    ),
  );
}
