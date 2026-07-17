import 'package:flutter/material.dart';
import '../../../design/tokens.dart';
import '../../../services/service_request_api_client.dart';
import '../../../services/worker_directory_api_client.dart';

/// 候选人选择页 — 业主为已创建的需求挑选多个候选师傅
///
/// 链路: 创建 ServiceRequest → 本页（多选师傅）→ 完成
///
/// [requestId] 已创建的需求 ID
/// [trade] 需求工种
/// [serviceCity] 需求城市
class CandidatePickerPage extends StatefulWidget {
  const CandidatePickerPage({
    super.key,
    required this.requestId,
    required this.trade,
    required this.serviceCity,
    this.serviceRequestApi,
    this.workerDirectoryApi,
  });

  final String requestId;
  final String trade;
  final String serviceCity;
  final ServiceRequestApi? serviceRequestApi;
  final WorkerDirectoryApi? workerDirectoryApi;

  @override
  State<CandidatePickerPage> createState() => _CandidatePickerPageState();
}

class _CandidatePickerPageState extends State<CandidatePickerPage> {
  ServiceRequestApi get _api =>
      widget.serviceRequestApi ?? ServiceRequestApiClient();
  WorkerDirectoryApi get _workerApi =>
      widget.workerDirectoryApi ?? WorkerDirectoryApiClient();

  List<RemoteWorkerDirectoryProfile> _workers = const [];
  Set<String> _candidateIds = {}; // workerUserId of already-added candidates
  Set<String> _addingIds = {}; // in-flight add calls
  String? _error;
  bool _loadingWorkers = true;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    try {
      final workers = await _workerApi.listWorkers();
      if (!mounted) return;
      // filter by trade match
      setState(() {
        _workers = workers
            .where((w) => _tradeMatch(w.primaryTrade))
            .toList();
        _loadingWorkers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingWorkers = false;
        _error = '加载工人列表失败';
      });
    }
  }

  bool _tradeMatch(String primaryTrade) {
    final t = primaryTrade.trim();
    final target = widget.trade.trim();
    if (t == target) return true;
    // Chinese fuzzy match
    if (target.contains('水电') && t.contains('水电')) return true;
    if (target.contains('防水') && t.contains('防水')) return true;
    if ((target.contains('泥') || target.contains('瓦')) &&
        (t.contains('泥') || t.contains('瓦'))) return true;
    if (target.contains('木') && t.contains('木')) return true;
    if ((target.contains('漆') || target.contains('油')) &&
        (t.contains('漆') || t.contains('油'))) return true;
    if (target.contains('安装') && t.contains('安装')) return true;
    if ((target.contains('清洁') || target.contains('保洁')) &&
        (t.contains('清洁') || t.contains('保洁'))) return true;
    if (target.contains('拆') && t.contains('拆')) return true;
    return false;
  }

  bool _isCandidate(String userId) => _candidateIds.contains(userId);

  bool _isAdding(String userId) => _addingIds.contains(userId);

  Future<void> _addCandidate(RemoteWorkerDirectoryProfile worker) async {
    final uid = worker.userId;
    if (_addingIds.contains(uid)) return;
    setState(() => _addingIds = {..._addingIds, uid});
    try {
      await _api.addCandidate(widget.requestId, uid);
      if (!mounted) return;
      setState(() {
        _candidateIds = {..._candidateIds, uid};
        _addingIds = _addingIds.difference({uid});
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _addingIds = _addingIds.difference({uid}));
      _showError('添加失败: ${e is AuthApiException ? e.message : '请重试'}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: ZdColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: ZdColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context, _candidateIds),
        ),
        title: const Text(
          '选择候选师傅',
          style: TextStyle(
            color: ZdColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadingWorkers) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null && _workers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: ZdColors.textHint),
            const SizedBox(height: 12),
            Text(_error!, style: ZdText.caption),
          ],
        ),
      );
    }
    return Column(
      children: [
        _RequestHeader(
          trade: widget.trade,
          cityName: widget.serviceCity,
          candidateCount: _candidateIds.length,
        ),
        Expanded(
          child: _workers.isEmpty
              ? const Center(child: Text('暂无匹配师傅', style: ZdText.caption))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: _workers.length,
                  itemBuilder: (_, i) {
                    final worker = _workers[i];
                    return _CandidateItem(
                      worker: worker,
                      isCandidate: _isCandidate(worker.userId),
                      isAdding: _isAdding(worker.userId),
                      onAdd: () => _addCandidate(worker),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// 需求摘要卡片
class _RequestHeader extends StatelessWidget {
  const _RequestHeader({
    required this.trade,
    required this.cityName,
    required this.candidateCount,
  });

  final String trade;
  final String cityName;
  final int candidateCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZdColors.surfaceWarm,
        borderRadius: BorderRadius.circular(ZdRadius.card),
        border: Border.all(color: ZdColors.primary.withAlpha(30)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.engineering_rounded,
                color: ZdColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$trade · $cityName',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: ZdColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  candidateCount > 0
                      ? '已选 $candidateCount 位候选人'
                      : '请为需求挑选候选师傅',
                  style: const TextStyle(
                      fontSize: 12, color: ZdColors.textSecondary),
                ),
              ],
            ),
          ),
          if (candidateCount > 0)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: ZdColors.successSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_rounded,
                  size: 18, color: ZdColors.success),
            ),
        ],
      ),
    );
  }
}

/// 单个工人候选条目
class _CandidateItem extends StatelessWidget {
  const _CandidateItem({
    required this.worker,
    required this.isCandidate,
    required this.isAdding,
    required this.onAdd,
  });

  final RemoteWorkerDirectoryProfile worker;
  final bool isCandidate;
  final bool isAdding;
  final VoidCallback onAdd;

  String get _avatarLabel => worker.name.isNotEmpty ? worker.name[0] : '工';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCandidate ? const Color(0xFFFAF8F5) : Colors.white,
        borderRadius: BorderRadius.circular(ZdRadius.card),
        border: isCandidate
            ? Border.all(color: ZdColors.success.withAlpha(80))
            : null,
        boxShadow: ZdShadow.card,
      ),
      child: Row(
        children: [
          // 头像
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0EB),
              borderRadius: BorderRadius.circular(ZdRadius.md),
            ),
            alignment: Alignment.center,
            child: Text(
              _avatarLabel,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ZdColors.primaryDark),
            ),
          ),
          const SizedBox(width: 12),
          // 信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(worker.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: ZdColors.textPrimary)),
                    if (isCandidate) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ZdColors.successSoft,
                          borderRadius: BorderRadius.circular(ZdRadius.pill),
                        ),
                        child: const Text('已选',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: ZdColors.success)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  worker.primaryTrade,
                  style: const TextStyle(
                      fontSize: 13, color: ZdColors.textSecondary),
                ),
              ],
            ),
          ),
          // 操作按钮
          if (isCandidate)
            const Icon(Icons.check_circle_rounded,
                size: 28, color: ZdColors.success)
          else if (isAdding)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: ZdColors.primary,
                  borderRadius: BorderRadius.circular(ZdRadius.pill),
                ),
                child: const Text('添加',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
}
