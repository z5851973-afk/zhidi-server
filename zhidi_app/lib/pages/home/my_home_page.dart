import 'package:flutter/material.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';

import '../../design/tokens.dart';
import '../../models/renovation.dart' show Trade;
import '../../services/service_request_api_client.dart';
import '../../services/worker_quote_api_client.dart';
import '../../services/auth_api_client.dart';
import '../../services/chat_api_client.dart';
import '../../models/chat_models.dart';
import '../chat/chat_detail_page.dart';
import '../renovation/construction_standards_page.dart';
import '../renovation/trade_select_page.dart';
import 'renovation_archive_page.dart';
import 'owner_quote_compare_page.dart';
import 'owner_inspection_page.dart';
import '../../services/daily_report_api_client.dart';
import 'owner_payment_page.dart';
import 'owner_after_sale_page.dart';

const _primary = ZdColors.primary;
const _bg = ZdColors.background;
const _card = ZdColors.surfaceWarm;
const _textDark = ZdColors.textPrimary;
const _textMid = ZdColors.textSecondary;
const _textLight = Color(0xFF9B8F86);
const _line = Color(0xFFF0E4D8);
const _green = ZdColors.success;
const _orangeSoft = Color(0xFFFFF1E7);
const _gold = Color(0xFFC8871A);

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<RemoteServiceRequest> _requests = const [];
  final Map<String, List<RemoteQuote>> _quotes = {};
  bool _loading = true;
  String? _error;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadRequests();
    }
  }

  Future<void> _loadRequests() async {
    final state = OwnerAppScope.of(context);
    final token = await state.getAccessToken();
    if (token == null) {
      if (mounted) setState(() { _loading = false; _error = '请先登录'; });
      return;
    }
    try {
      final api = ServiceRequestApiClient();
      final list = await api.listOwnerRequests(token);
      if (mounted) {
        setState(() { _requests = list; _loading = false; });
        _checkAndFetchQuotes(token);
      }
    } on AuthApiException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = '加载失败：$e'; });
    }
  }

  Future<void> _checkAndFetchQuotes(String token) async {
    for (final req in _requests) {
      for (final c in req.candidates) {
        if (c.status == 'QUOTE_PENDING' && !_quotes.containsKey(c.id)) {
          _fetchQuotesFor(c.id, token);
        }
      }
    }
  }

  Future<void> _fetchQuotesFor(String bookingId, String token) async {
    try {
      final api = WorkerQuoteApiClient();
      final quotes = await api.listQuotesForBooking(token, bookingId);
      if (mounted) {
        setState(() {
          _quotes[bookingId] = quotes;
        });
      }
    } catch (_) {
      // 报价加载失败不阻断页面
    }
  }

  List<RemoteQuote> _quotesForCandidate(RemoteCandidateBooking c) {
    return _quotes[c.id] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return _MyHomeManagementView(
      requests: _requests,
      loading: _loading,
      error: _error,
      onRetry: _loadRequests,
      quotesForCandidate: _quotesForCandidate,
    );
  }
}

class _MyHomeManagementView extends StatelessWidget {
  const _MyHomeManagementView({
    this.requests = const [],
    this.loading = false,
    this.error,
    this.onRetry,
    this.quotesForCandidate,
  });

  final List<RemoteServiceRequest> requests;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final List<RemoteQuote> Function(RemoteCandidateBooking)? quotesForCandidate;

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _showHint(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final state = OwnerAppScope.of(context);
    final workers = _uniqueServiceWorkers(state.bookedWorkers)
      ..sort((a, b) => a.phaseIndex.compareTo(b.phaseIndex));
    final cost = _CostSummary.fromState(state, workers);

    return ColoredBox(
      color: _bg,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            const _PageHeader(),
            const SizedBox(height: 16),
            // ── ServiceRequest 区域 ──
            _ServiceRequestsSection(
              requests: requests,
              loading: loading,
              error: error,
              onRetry: onRetry,
              onFindWorker: () => _push(context, const TradeSelectPage()),
              onTapRequest: (req) {
                _push(context, _ServiceRequestDetailPage(
                  request: req,
                  quotesForCandidate: quotesForCandidate,
                ));
              },
            ),
            const SizedBox(height: 12),
            _CostCard(
              key: const Key('my-home-cost-card'),
              summary: cost,
              onDetail: () => _showHint(context, '先预约师傅后可生成费用明细'),
            ),
            const SizedBox(height: 12),
            _DocumentsCard(
              key: const Key('my-home-documents-card'),
              onQuote: () => _showHint(context, '暂无报价清单，先开始找师傅'),
              onStandard: () =>
                  _push(context, const ConstructionStandardsPage()),
              onInspection: () => _push(context, const RenovationArchivePage()),
              onPayment: () => _showHint(context, '付款记录正在接入平台托管流程'),
            ),
          ],
        ),
      ),
    );
  }

}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '我的家',
          style: TextStyle(
            fontSize: 30,
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: _textDark,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '管理我的装修服务，让每一步装修都有记录、有保障。',
          style: TextStyle(fontSize: 14, height: 1.45, color: _textMid),
        ),
      ],
    );
  }
}







class _CostCard extends StatelessWidget {
  const _CostCard({super.key, required this.summary, required this.onDetail});

  final _CostSummary summary;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionTitle(title: '装修费用'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _orangeSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '固定工价 · 报价透明',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CostMetric(
                  label: '已确认费用',
                  value: _money(summary.confirmed),
                  prominent: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CostMetric(label: '人工费用', value: _money(summary.labor)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CostMetric(
                  label: '辅材费用',
                  value: _money(summary.material),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton(
              onPressed: onDetail,
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: Color(0xFFFFC7A3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '查看费用详情',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentsCard extends StatelessWidget {
  const _DocumentsCard({
    super.key,
    required this.onQuote,
    required this.onStandard,
    required this.onInspection,
    required this.onPayment,
  });

  final VoidCallback onQuote;
  final VoidCallback onStandard;
  final VoidCallback onInspection;
  final VoidCallback onPayment;

  @override
  Widget build(BuildContext context) {
    final items = [
      _DocEntry(Icons.receipt_long_rounded, '报价清单', onQuote),
      _DocEntry(Icons.verified_user_outlined, '施工标准', onStandard),
      _DocEntry(Icons.fact_check_outlined, '验收记录', onInspection),
      _DocEntry(Icons.account_balance_wallet_outlined, '付款记录', onPayment),
    ];
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: '装修资料'),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.65,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBF7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _orangeSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.icon, size: 18, color: _primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}








class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
        boxShadow: ZdShadow.cardSoft,
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: _textDark,
      ),
    );
  }
}




class _CostMetric extends StatelessWidget {
  const _CostMetric({
    required this.label,
    required this.value,
    this.prominent = false,
  });

  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: prominent ? _orangeSoft : const Color(0xFFFFFBF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _textMid)),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: prominent ? 18 : 15,
                fontWeight: FontWeight.w900,
                color: prominent ? _primary : _textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _DocEntry {
  const _DocEntry(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _CostSummary {
  const _CostSummary({
    required this.confirmed,
    required this.labor,
    required this.material,
  });

  final double confirmed;
  final double labor;
  final double material;

  static _CostSummary fromState(
    OwnerAppState state,
    List<BookedWorker> workers,
  ) {
    final quoteTotal = state.savedQuotes.fold<double>(
      0.0,
      (sum, quote) => sum + quote.grandTotal,
    );
    final fallbackLabor = workers.isEmpty ? 0.0 : workers.length * 1800.0;
    final labor = quoteTotal > 0 ? quoteTotal : fallbackLabor;
    final material = state.materialEstimates.fold<double>(
      0.0,
      (sum, estimate) => sum + estimate.selectedTotal,
    );
    return _CostSummary(
      confirmed: labor + material,
      labor: labor,
      material: material,
    );
  }
}


Trade? _tradeFromWorker(BookedWorker worker) {
  final text = '${worker.trade} ${worker.phaseName}';
  if (text.contains('拆')) return Trade.demolition;
  if (text.contains('水电')) return Trade.plumbing;
  if (text.contains('泥') || text.contains('瓦') || text.contains('贴砖')) {
    return Trade.masonry;
  }
  if (text.contains('防水')) return Trade.waterproof;
  if (text.contains('木')) return Trade.carpentry;
  if (text.contains('油漆') || text.contains('涂')) return Trade.painting;
  if (text.contains('安装')) return Trade.installation;
  if (text.contains('清洁') || text.contains('保洁')) return Trade.cleaning;
  return null;
}

List<BookedWorker> _uniqueServiceWorkers(List<BookedWorker> workers) {
  final byService = <String, BookedWorker>{};
  for (final worker in workers) {
    final key = _serviceKey(worker);
    final existing = byService[key];
    if (existing == null || _preferWorker(worker, existing)) {
      byService[key] = worker;
    }
  }
  return byService.values.toList();
}

String _serviceKey(BookedWorker worker) {
  if (worker.phaseIndex >= 0) return 'phase-${worker.phaseIndex}';
  final trade = _tradeFromWorker(worker);
  if (trade != null) return 'trade-${trade.name}';
  final normalized = '${worker.phaseName}-${worker.trade}'.trim();
  return normalized.isEmpty ? worker.id : normalized;
}

bool _preferWorker(BookedWorker candidate, BookedWorker current) {
  if (!candidate.isCompleted && current.isCompleted) return true;
  if (candidate.isCompleted && !current.isCompleted) return false;
  final candidateTime = candidate.bookedAt;
  final currentTime = current.bookedAt;
  if (candidateTime != null && currentTime != null) {
    return candidateTime.isAfter(currentTime);
  }
  if (candidateTime != null) return true;
  return false;
}







String _money(double value) {
  if (value <= 0) return '¥0';
  return '¥${value.toStringAsFixed(0)}';
}

// ══════════════════════════════════════════
// ServiceRequest 区域 — 替代旧 CurrentServiceCard / ServiceListCard
// ══════════════════════════════════════════

String _tradeLabel(String apiTrade) {
  return switch (apiTrade) {
    'demolition' => '拆除',
    'plumbing' => '水电',
    'masonry' => '泥瓦',
    'waterproof' => '防水',
    'carpentry' => '木工',
    'painting' => '油漆',
    'installation' => '安装',
    _ => apiTrade,
  };
}

String _statusLabel(String status) {
  return switch (status) {
    'OPEN' => '待匹配',
    'COMPARING' => '比价中',
    'WORKER_SELECTED' => '已选定',
    'ASSIGNED' => '已选定',
    _ => status,
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'OPEN' => ZdColors.primary,
    'COMPARING' => _gold,
    'WORKER_SELECTED' => _green,
    'ASSIGNED' => _green,
    _ => _textMid,
  };
}

String _formatDateTime(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

String _bookingStatusLabel(String status) {
  return switch (status) {
    'VISIT_PROPOSED' => '工人已建议上门时间',
    'VISIT_SCHEDULED' => '上门时间已确认',
    'ARRIVAL_PENDING' => '双方已标记到达',
    'ON_SITE' => '师傅已到场',
    'HIRED' => '已选定',
    _ => status,
  };
}

class _ServiceRequestsSection extends StatelessWidget {
  const _ServiceRequestsSection({
    required this.requests,
    required this.loading,
    this.error,
    this.onRetry,
    required this.onFindWorker,
    required this.onTapRequest,
  });

  final List<RemoteServiceRequest> requests;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback onFindWorker;
  final ValueChanged<RemoteServiceRequest> onTapRequest;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '我的装修需求',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                TextButton.icon(
                  onPressed: onFindWorker,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('找师傅'),
                  style: TextButton.styleFrom(
                    foregroundColor: _primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: _primary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (loading) ...[
              const SizedBox(height: 32),
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(height: 32),
            ] else if (error != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(error: error!, onRetry: onRetry),
            ] else if (requests.isEmpty) ...[
              const SizedBox(height: 32),
              _EmptyGuide(onFindWorker: onFindWorker),
              const SizedBox(height: 16),
            ] else ...[
              const SizedBox(height: 12),
              ...requests.map((r) => _ServiceRequestCard(
                    request: r,
                    onTap: () => onTapRequest(r),
                  )),
            ],
          ],
        ),
    );
  }
}

class _EmptyGuide extends StatelessWidget {
  const _EmptyGuide({required this.onFindWorker});
  final VoidCallback onFindWorker;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.home_work_outlined, size: 40, color: _primary.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          const Text(
            '还没有装修需求',
            style: TextStyle(fontSize: 14, color: _textMid),
          ),
          const SizedBox(height: 4),
          const Text(
            '发布需求后，平台为你匹配同城师傅',
            style: TextStyle(fontSize: 12, color: _textLight),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onFindWorker,
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('开始找师傅'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error, this.onRetry});
  final String error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(error, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('重试', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

class _ServiceRequestCard extends StatelessWidget {
  const _ServiceRequestCard({required this.request, required this.onTap});
  final RemoteServiceRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(request.status);
    final activeCount = request.candidates
        .where((c) => c.status != 'CANCELLED')
        .length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.handyman_outlined,
                color: statusColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${_tradeLabel(request.trade)}师傅',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _statusLabel(request.status),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${request.serviceCity} · $activeCount位候选师傅 · ${request.candidates.length}次邀请',
                    style: const TextStyle(fontSize: 12, color: _textLight),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _textLight),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// ServiceRequest 候选详情页（含取消）
// ══════════════════════════════════════════
class _ServiceRequestDetailPage extends StatefulWidget {
  const _ServiceRequestDetailPage({
    required this.request,
    this.quotesForCandidate,
  });

  final RemoteServiceRequest request;
  final List<RemoteQuote> Function(RemoteCandidateBooking)? quotesForCandidate;

  @override
  State<_ServiceRequestDetailPage> createState() =>
      _ServiceRequestDetailPageState();
}

class _ServiceRequestDetailPageState extends State<_ServiceRequestDetailPage> {
  bool _cancelling = false;
  bool _visitLoading = false;
  bool _quoteLoading = false;

  Future<String?> _getToken() async {
    final state = OwnerAppScope.of(context);
    final token = await state.getAccessToken();
    if (token == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登录已过期，请重新登录')),
      );
    }
    return token;
  }

  void _handleError(Object e) {
    if (!mounted) return;
    final msg = e is AuthApiException ? e.message : '操作失败：$e';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _acceptVisit(RemoteCandidateBooking candidate) async {
    setState(() => _visitLoading = true);
    try {
      final token = await _getToken();
      if (token == null) return;
      final api = ServiceRequestApiClient();
      await api.acceptVisit(token, candidate.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已确认上门时间')),
        );
        Navigator.pop(context);
      }
    } on Exception catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _visitLoading = false);
    }
  }

  Future<void> _rejectVisit(RemoteCandidateBooking candidate) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('拒绝上门时间'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${candidate.workerName} 建议 '
                '${_formatDateTime(candidate.proposedTime)} 上门'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: '拒绝原因（必填）',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('返回'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('请填写拒绝原因')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认拒绝'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty) return;

    setState(() => _visitLoading = true);
    try {
      final token = await _getToken();
      if (token == null) return;
      final api = ServiceRequestApiClient();
      await api.rejectVisit(token, candidate.id, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已拒绝上门时间，工人可重新提出')),
        );
        Navigator.pop(context);
      }
    } on Exception catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _visitLoading = false);
    }
  }

  Future<void> _ownerArrive(RemoteCandidateBooking candidate) async {
    setState(() => _visitLoading = true);
    try {
      final token = await _getToken();
      if (token == null) return;
      final api = ServiceRequestApiClient();
      await api.ownerArrive(token, candidate.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已标记到达')),
        );
        Navigator.pop(context);
      }
    } on Exception catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _visitLoading = false);
    }
  }

  Future<void> _ownerConfirmArrival(RemoteCandidateBooking candidate) async {
    setState(() => _visitLoading = true);
    try {
      final token = await _getToken();
      if (token == null) return;
      final api = ServiceRequestApiClient();
      await api.ownerConfirmArrival(token, candidate.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已确认师傅到场')),
        );
        Navigator.pop(context);
      }
    } on Exception catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _visitLoading = false);
    }
  }

  Future<void> _acceptQuote(RemoteCandidateBooking candidate, RemoteQuote quote) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认选人'),
        content: Text(
          '确定选 ${candidate.workerName} 师傅？选定后其他候选人的预约将自动关闭。',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认选择'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _quoteLoading = true);
    try {
      final token = await _getToken();
      if (token == null) return;
      final api = WorkerQuoteApiClient();
      await api.acceptQuote(token, quote.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已选定 ${candidate.workerName} 师傅')),
        );
        Navigator.pop(context);
      }
    } on AuthApiException catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _quoteLoading = false);
    }
  }

  Future<void> _rejectQuote(RemoteCandidateBooking candidate, RemoteQuote quote) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('拒绝报价'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('确定拒绝 ${candidate.workerName} 的报价？'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: '拒绝原因（必填）',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('返回'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('请填写拒绝原因')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认拒绝'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty) return;

    setState(() => _quoteLoading = true);
    try {
      final token = await _getToken();
      if (token == null) return;
      final api = WorkerQuoteApiClient();
      await api.rejectQuote(token, quote.id, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已拒绝报价，工人可重新报价')),
        );
        Navigator.pop(context);
      }
    } on AuthApiException catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _quoteLoading = false);
    }
  }

  void _openComparePage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerQuoteComparePage(
          serviceRequestId: widget.request.id,
        ),
      ),
    );
  }

  void _openDailyReport(RemoteCandidateBooking candidate) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerDailyReportViewPage(bookingId: candidate.id),
      ),
    );
  }

  void _openInspection(RemoteCandidateBooking candidate) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerInspectionPage(bookingId: candidate.id),
      ),
    );
  }

  void _openChat(RemoteCandidateBooking candidate) async {
    final state = OwnerAppScope.of(context);
    final token = await state.getAccessToken();
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录已过期，请重新登录')),
        );
      }
      return;
    }

    // get/create chat room by booking ID
    final chatApi = ChatApiClient();
    ChatRoomModel room;
    try {
      room = await chatApi.getOrCreateRoom(token, candidate.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法创建聊天：$e')),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          roomId: room.id,
          otherUserName: candidate.workerName,
          accessToken: token,
          currentUserId: candidate.ownerUserId,
        ),
      ),
    );
  }

  void _openPayment(RemoteCandidateBooking candidate) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerPaymentPage(bookingId: candidate.id),
      ),
    );
  }

  void _openAfterSale(RemoteCandidateBooking candidate) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerAfterSalePage(bookingId: candidate.id),
      ),
    );
  }

  Future<void> _cancelCandidate(RemoteCandidateBooking candidate) async {
    if (candidate.status == 'CANCELLED') return;

    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消候选'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('确定要取消与 ${candidate.workerName} 的预约吗？'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: '取消原因（必填）',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('返回'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('请填写取消原因')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认取消'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty) return;

    setState(() => _cancelling = true);
    try {
      // ignore: use_build_context_synchronously
      final state = OwnerAppScope.of(context);
      // ignore: await_only_futures
      final token = await state.getAccessToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('登录已过期，请重新登录')),
          );
        }
        return;
      }
      final api = ServiceRequestApiClient();
      await api.cancelAsOwner(token, candidate.id, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已取消与 ${candidate.workerName} 的预约')),
      );
      Navigator.pop(context); // return to my_home_page
    } on AuthApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('取消失败：${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('取消失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final active = req.candidates.where((c) => c.status != 'CANCELLED').toList();
    final cancelled = req.candidates.where((c) => c.status == 'CANCELLED').toList();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text('${_tradeLabel(req.trade)}师傅 · 候选'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _textDark,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 需求摘要
          _GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(req.status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _statusLabel(req.status),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(req.status),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        req.serviceCity,
                        style: const TextStyle(fontSize: 13, color: _textLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '已邀请 ${req.candidates.length} 位师傅，当前 ${active.length} 位候选',
                    style: const TextStyle(fontSize: 14, color: _textMid),
                  ),
                ],
              ),
          ),
          const SizedBox(height: 12),
          // 候选列表
          if (active.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                '候选师傅',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _textDark,
                ),
              ),
            ),
            ...active.map((c) => _CandidateTile(
                  candidate: c,
                  onCancel: _cancelling ? null : () => _cancelCandidate(c),
                  onAcceptVisit: () => _acceptVisit(c),
                  onRejectVisit: () => _rejectVisit(c),
                  onArrive: () => _ownerArrive(c),
                  onConfirmArrival: () => _ownerConfirmArrival(c),
                  visitLoading: _visitLoading,
                  quoteLoading: _quoteLoading,
                  onAcceptQuote: (quote) => _acceptQuote(c, quote),
                  onRejectQuote: (quote) => _rejectQuote(c, quote),
                  quotesFor: widget.quotesForCandidate?.call(c) ?? [],
                  onViewDailyReport: () => _openDailyReport(c),
                  onViewInspection: () => _openInspection(c),
                  onChat: () => _openChat(c),
                  onPayment: () => _openPayment(c),
                  onAfterSale: () => _openAfterSale(c),
                )),
          ],
          // 多人比价入口
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _openComparePage,
              icon: const Icon(Icons.compare_arrows, size: 18),
              label: const Text('查看所有报价'),
              style: TextButton.styleFrom(foregroundColor: _primary),
            ),
          ),
          const SizedBox(height: 12),
          if (cancelled.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                '已取消',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _textLight,
                ),
              ),
            ),
            ...cancelled.map((c) => _CandidateTile(
                  candidate: c,
                  onCancel: null,
                )),
          ],
        ],
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.candidate,
    this.onCancel,
    this.onAcceptVisit,
    this.onRejectVisit,
    this.onArrive,
    this.onConfirmArrival,
    this.visitLoading = false,
    this.quoteLoading = false,
    this.onAcceptQuote,
    this.onRejectQuote,
    this.quotesFor = const [],
    this.onViewDailyReport,
    this.onViewInspection,
    this.onChat,
    this.onPayment,
    this.onAfterSale,
  });
  final RemoteCandidateBooking candidate;
  final VoidCallback? onCancel;
  final VoidCallback? onAcceptVisit;
  final VoidCallback? onRejectVisit;
  final VoidCallback? onArrive;
  final VoidCallback? onConfirmArrival;
  final bool visitLoading;
  final bool quoteLoading;
  final void Function(RemoteQuote)? onAcceptQuote;
  final void Function(RemoteQuote)? onRejectQuote;
  final List<RemoteQuote> quotesFor;
  final VoidCallback? onViewDailyReport;
  final VoidCallback? onViewInspection;
  final VoidCallback? onChat;
  final VoidCallback? onPayment;
  final VoidCallback? onAfterSale;

  @override
  Widget build(BuildContext context) {
    final isCancelled = candidate.status == 'CANCELLED';
    final status = candidate.status;
    final isVisitFlow = status == 'VISIT_PROPOSED' ||
        status == 'VISIT_SCHEDULED' ||
        status == 'ARRIVAL_PENDING' ||
        status == 'ON_SITE' ||
        status == 'QUOTE_PENDING' ||
        status == 'HIRED';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _primary.withValues(alpha: 0.12),
                child: Text(
                  candidate.workerName.isNotEmpty
                      ? candidate.workerName[0]
                      : '师',
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.workerName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isCancelled ? _textLight : _textDark,
                      ),
                    ),
                    if (isCancelled && candidate.cancelReason != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        candidate.cancelReason!,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (!isCancelled && !isVisitFlow && onCancel != null)
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('取消', style: TextStyle(fontSize: 13)),
                )
              else if (isCancelled)
                const Text(
                  '已取消',
                  style: TextStyle(fontSize: 12, color: _textLight),
                ),
            ],
          ),
          if (isVisitFlow) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _VisitFlowSection(
              status: status,
              proposedTime: candidate.proposedTime,
              onSiteAt: candidate.onSiteAt,
              arrivalConfirmedByOwner: candidate.arrivalConfirmedByOwner,
              arrivalConfirmedByWorker: candidate.arrivalConfirmedByWorker,
              onAcceptVisit: onAcceptVisit,
              onRejectVisit: onRejectVisit,
              onArrive: onArrive,
              onConfirmArrival: onConfirmArrival,
              onCancel: onCancel,
              loading: visitLoading,
              quoteLoading: quoteLoading,
              onAcceptQuote: onAcceptQuote,
              onRejectQuote: onRejectQuote,
              quotes: quotesFor,
              workerName: candidate.workerName,
              workerUserId: candidate.workerUserId,
              bookingId: candidate.id,
              onViewDailyReport: onViewDailyReport,
              onViewInspection: onViewInspection,
              onChat: onChat,
              onPayment: onPayment,
              onAfterSale: onAfterSale,
            ),
          ],
        ],
      ),
    );
  }
}

class _VisitFlowSection extends StatelessWidget {
  const _VisitFlowSection({
    required this.status,
    this.proposedTime,
    this.onSiteAt,
    this.arrivalConfirmedByOwner = false,
    this.arrivalConfirmedByWorker = false,
    this.onAcceptVisit,
    this.onRejectVisit,
    this.onArrive,
    this.onConfirmArrival,
    this.onCancel,
    this.loading = false,
    this.quotes = const [],
    this.quoteLoading = false,
    this.onAcceptQuote,
    this.onRejectQuote,
    this.workerName,
    this.workerUserId,
    this.bookingId,
    this.onViewDailyReport,
    this.onViewInspection,
    this.onChat,
    this.onPayment,
    this.onAfterSale,
  });

  final String status;
  final DateTime? proposedTime;
  final DateTime? onSiteAt;
  final bool arrivalConfirmedByOwner;
  final bool arrivalConfirmedByWorker;
  final VoidCallback? onAcceptVisit;
  final VoidCallback? onRejectVisit;
  final VoidCallback? onArrive;
  final VoidCallback? onConfirmArrival;
  final VoidCallback? onCancel;
  final bool loading;
  final List<RemoteQuote> quotes;
  final bool quoteLoading;
  final void Function(RemoteQuote)? onAcceptQuote;
  final void Function(RemoteQuote)? onRejectQuote;
  final String? workerName;
  final String? workerUserId;
  final String? bookingId;
  final VoidCallback? onViewDailyReport;
  final VoidCallback? onViewInspection;
  final VoidCallback? onChat;
  final VoidCallback? onPayment;
  final VoidCallback? onAfterSale;

  @override
  Widget build(BuildContext context) {
    Widget statusRow(String label, [Color? color]) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (color ?? _primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color ?? _primary,
          ),
        ),
      );
    }

    Widget actionButton(
      String label, {
      VoidCallback? onPressed,
      Color? color,
    }) {
      return SizedBox(
        height: 32,
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? _primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(label),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            statusRow(_bookingStatusLabel(status)),
          ],
        ),
        const SizedBox(height: 8),
        if (status == 'VISIT_PROPOSED' && proposedTime != null) ...[
          Text(
            '工人建议 ${_formatDateTime(proposedTime)} 上门',
            style: const TextStyle(fontSize: 13, color: _textDark),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              actionButton('确认时间', onPressed: onAcceptVisit),
              const SizedBox(width: 8),
              actionButton(
                '拒绝',
                onPressed: onRejectVisit,
                color: Colors.orange,
              ),
              const Spacer(),
              if (onCancel != null)
                actionButton('取消预约', onPressed: onCancel, color: Colors.red),
            ],
          ),
        ] else if (status == 'VISIT_SCHEDULED' && proposedTime != null) ...[
          Text(
            '约定 ${_formatDateTime(proposedTime)} 上门',
            style: const TextStyle(fontSize: 13, color: _textDark),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              actionButton('我已到达', onPressed: onArrive),
              const Spacer(),
              if (onCancel != null)
                actionButton('取消预约', onPressed: onCancel, color: Colors.red),
            ],
          ),
        ] else if (status == 'ARRIVAL_PENDING') ...[
          Text(
            '工人已标记到达，请确认对方已到场',
            style: const TextStyle(fontSize: 13, color: _textDark),
          ),
          const SizedBox(height: 10),
          actionButton('确认师傅已到场', onPressed: onConfirmArrival),
        ] else if (status == 'ON_SITE') ...[
          Text(
            onSiteAt != null
                ? '师傅已于 ${_formatDateTime(onSiteAt)} 到场'
                : '师傅已到场',
            style: const TextStyle(fontSize: 13, color: _textDark),
          ),
        ] else if (status == 'QUOTE_PENDING') ...[
          Text(
            '报价单已提交',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.indigo,
            ),
          ),
          if (quotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...quotes.map((q) => _QuoteSummary(quote: q)),
            const SizedBox(height: 10),
            if (quoteLoading) ...[
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _QuoteActionBtn(
                      label: '接受报价',
                      color: _primary,
                      onPressed: onAcceptQuote != null
                          ? () => onAcceptQuote!(quotes.first)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuoteActionBtn(
                      label: '拒绝报价',
                      color: Colors.orange,
                      onPressed: onRejectQuote != null
                          ? () => onRejectQuote!(quotes.first)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              '报价信息加载中…',
              style: TextStyle(fontSize: 13, color: _textLight),
            ),
          ],
        ] else if (status == 'HIRED') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 16, color: _green),
                const SizedBox(width: 6),
                Text(
                  workerName != null
                      ? '已选定 $workerName 师傅'
                      : '已选定师傅',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _green,
                  ),
                ),
                if (quotes.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '报价 ¥${quotes.first.totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13, color: _textDark),
                  ),
                ],
              ],
            ),
          ),
          if (quotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            _QuoteSummary(quote: quotes.first),
          ],
          if (status == 'HIRED') ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // 联系师傅按钮
            if (onChat != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onChat,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text('联系${workerName ?? '师傅'}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF07C160),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            if (onChat != null) const SizedBox(height: 8),
            // 支付入口
            if (onPayment != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onPayment,
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text('去支付'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            if (onPayment != null) const SizedBox(height: 8),
            // 售后入口
            if (onAfterSale != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAfterSale,
                  icon: const Icon(Icons.support_agent_outlined, size: 18),
                  label: const Text('售后'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            if (onAfterSale != null) const SizedBox(height: 8),
            _DailyReportSection(bookingId: bookingId, workerName: workerName),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onViewInspection,
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('节点验收'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

// ── 报价摘要组件 ──
class _QuoteSummary extends StatelessWidget {
  const _QuoteSummary({required this.quote});

  final RemoteQuote quote;

  double get _total {
    double t = 0;
    for (final item in quote.items) {
      t += item.subtotal ?? (item.unitPrice ?? 0) * (item.quantity ?? 0);
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...quote.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name ?? item.tradeName,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '${item.quantity?.toStringAsFixed(0) ?? '-'}${item.unit ?? ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '¥${item.unitPrice?.toStringAsFixed(0) ?? '-'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '¥${item.subtotal?.toStringAsFixed(0) ?? '-'}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )),
          const Divider(height: 1),
          const SizedBox(height: 4),
          Row(
            children: [
              const Spacer(),
              const Text('合计 ', style: TextStyle(fontSize: 13)),
              Text(
                '¥${_total.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuoteActionBtn extends StatelessWidget {
  const _QuoteActionBtn({
    required this.label,
    required this.color,
    this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade500,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}


// ── 施工日报区域（业主端）──
class _DailyReportSection extends StatefulWidget {
  const _DailyReportSection({required this.bookingId, this.workerName});
  final String? bookingId;
  final String? workerName;

  @override
  State<_DailyReportSection> createState() => _DailyReportSectionState();
}

class _DailyReportSectionState extends State<_DailyReportSection> {
  List<RemoteDailyReport> _reports = const [];
  bool _loading = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    if (widget.bookingId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final state = OwnerAppScope.of(context);
    try {
      final token = await state.getAccessToken();
      if (token == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final api = DailyReportApiClient();
      final list = await api.getReportsByBooking(token, widget.bookingId!);
      if (mounted) setState(() { _reports = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (_reports.isEmpty) return const SizedBox.shrink();

    final latest = _reports.first;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.article_outlined, size: 16, color: _primary),
              const SizedBox(width: 6),
              Text('施工日报', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark)),
              const Spacer(),
              Text(latest.reportDate, style: const TextStyle(fontSize: 12, color: _textMid)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            latest.content,
            style: const TextStyle(fontSize: 13, color: _textDark),
            maxLines: _expanded ? null : 2,
            overflow: _expanded ? null : TextOverflow.ellipsis,
          ),
          if (_reports.length > 1 || !_expanded) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? '收起' : '展开全部（${_reports.length}篇）',
                style: const TextStyle(fontSize: 12, color: _primary),
              ),
            ),
          ],
          if (_expanded)
            ..._reports.skip(1).map((r) => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(r.reportDate, style: const TextStyle(fontSize: 12, color: _textMid)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(r.content, style: const TextStyle(fontSize: 13, color: _textDark)),
                ],
              ),
            )),
        ],
      ),
    );
  }
}
