import 'package:flutter/material.dart';
import '../../../design/tokens.dart';
import '../../../services/auth_api_client.dart';
import '../../../services/service_request_api_client.dart';
import '../../../services/worker_directory_api_client.dart';
import '../../renovation/worker_detail_page.dart';

class CandidatePickerResult {
  const CandidatePickerResult({
    required this.requestId,
    required this.candidateIds,
  });

  final String requestId;
  final Set<String> candidateIds;
}

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
    required this.accessToken,
    required this.trade,
    required this.serviceCity,
    this.serviceRequestApi,
    this.workerDirectoryApi,
  });

  final String requestId;
  final String accessToken;
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
  _CandidateSort _sort = _CandidateSort.comprehensive;
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
        _workers = workers.where((w) => _tradeMatch(w.primaryTrade)).toList();
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
        (t.contains('泥') || t.contains('瓦'))) {
      return true;
    }
    if (target.contains('木') && t.contains('木')) return true;
    if ((target.contains('漆') || target.contains('油')) &&
        (t.contains('漆') || t.contains('油'))) {
      return true;
    }
    if (target.contains('安装') && t.contains('安装')) return true;
    if ((target.contains('清洁') || target.contains('保洁')) &&
        (t.contains('清洁') || t.contains('保洁'))) {
      return true;
    }
    if (target.contains('拆') && t.contains('拆')) return true;
    return false;
  }

  bool _isCandidate(String userId) => _candidateIds.contains(userId);

  bool _isAdding(String userId) => _addingIds.contains(userId);

  List<RemoteWorkerDirectoryProfile> get _visibleWorkers {
    final sorted = [..._workers];
    switch (_sort) {
      case _CandidateSort.comprehensive:
        sorted.sort((a, b) {
          final city = _sameCityScore(b).compareTo(_sameCityScore(a));
          if (city != 0) return city;
          return b.experienceYears.compareTo(a.experienceYears);
        });
      case _CandidateSort.experience:
        sorted.sort((a, b) => b.experienceYears.compareTo(a.experienceYears));
      case _CandidateSort.profile:
        sorted.sort((a, b) {
          final complete = _profileScore(b).compareTo(_profileScore(a));
          if (complete != 0) return complete;
          return b.experienceYears.compareTo(a.experienceYears);
        });
    }
    return sorted;
  }

  int _sameCityScore(RemoteWorkerDirectoryProfile worker) {
    return worker.serviceCity == widget.serviceCity ? 1 : 0;
  }

  int _profileScore(RemoteWorkerDirectoryProfile worker) {
    var score = 0;
    if (worker.name.trim().isNotEmpty) score++;
    if ((worker.serviceCity ?? '').trim().isNotEmpty) score++;
    if (worker.primaryTrade.trim().isNotEmpty) score++;
    if (worker.experienceYears > 0) score++;
    if (worker.dailyRate > 0) score++;
    if ((worker.bio ?? '').trim().isNotEmpty) score++;
    return score;
  }

  Future<bool> _addCandidate(RemoteWorkerDirectoryProfile worker) async {
    final uid = worker.userId;
    if (_candidateIds.contains(uid)) return true;
    if (_candidateIds.length >= 3) {
      _showError('最多选择 3 位候选师傅');
      return false;
    }
    if (_addingIds.contains(uid)) return false;
    setState(() => _addingIds = {..._addingIds, uid});
    try {
      await _api.addCandidate(widget.accessToken, widget.requestId, uid);
      if (!mounted) return false;
      setState(() {
        _candidateIds = {..._candidateIds, uid};
        _addingIds = _addingIds.difference({uid});
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      if (_isAlreadyCandidateError(e)) {
        setState(() {
          _candidateIds = {..._candidateIds, uid};
          _addingIds = _addingIds.difference({uid});
        });
        return true;
      }
      setState(() => _addingIds = _addingIds.difference({uid}));
      _showError('添加失败: ${e is AuthApiException ? e.message : '请重试'}');
      return false;
    }
  }

  bool _isAlreadyCandidateError(Object error) {
    if (error is! AuthApiException) return false;
    final code = error.code.toUpperCase();
    final message = error.message;
    return code.contains('CANDIDATE_ALREADY') ||
        code.contains('ALREADY_CANDIDATE') ||
        message.contains('已经是候选') ||
        message.contains('已是候选');
  }

  Future<void> _openWorker(RemoteWorkerDirectoryProfile worker) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkerDetailPage(
          workerName: worker.name,
          remoteProfile: worker,
          candidateSelected: _isCandidate(worker.userId),
          onAddCandidate: () => _addCandidate(worker),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _completeSelection() {
    if (_candidateIds.isEmpty) return;
    Navigator.pop(
      context,
      CandidatePickerResult(
        requestId: widget.requestId,
        candidateIds: Set.unmodifiable(_candidateIds),
      ),
    );
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
          icon: const Icon(
            Icons.arrow_back_ios,
            color: ZdColors.textPrimary,
            size: 20,
          ),
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: FilledButton(
            key: const Key('candidate-complete'),
            onPressed: _candidateIds.isEmpty ? null : _completeSelection,
            child: Text('完成选择（已选 ${_candidateIds.length}/3）'),
          ),
        ),
      ),
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
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: ZdColors.textHint,
            ),
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
          matchedCount: _workers.length,
          selectedSort: _sort,
          onSortChanged: (sort) => setState(() => _sort = sort),
        ),
        Expanded(
          child: _workers.isEmpty
              ? const Center(child: Text('暂无匹配师傅', style: ZdText.caption))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemCount: _visibleWorkers.length,
                  itemBuilder: (_, i) {
                    final worker = _visibleWorkers[i];
                    return _CandidateItem(
                      worker: worker,
                      isCandidate: _isCandidate(worker.userId),
                      isAdding: _isAdding(worker.userId),
                      canAdd: _candidateIds.length < 3,
                      onView: () => _openWorker(worker),
                      onAdd: () => _addCandidate(worker),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

enum _CandidateSort { comprehensive, experience, profile }

/// 需求摘要卡片
class _RequestHeader extends StatelessWidget {
  const _RequestHeader({
    required this.trade,
    required this.cityName,
    required this.candidateCount,
    required this.matchedCount,
    required this.selectedSort,
    required this.onSortChanged,
  });

  final String trade;
  final String cityName;
  final int candidateCount;
  final int matchedCount;
  final _CandidateSort selectedSort;
  final ValueChanged<_CandidateSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: ZdColors.surfaceWarm,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZdColors.primary.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.engineering_rounded,
                  color: ZdColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_tradeLabel(trade)}师傅 · $cityName',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: ZdColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      candidateCount > 0
                          ? '已选 $candidateCount 位候选人'
                          : '已找到 $matchedCount 位可接单师傅，最多可选 3 位候选',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ZdColors.textSecondary,
                      ),
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
                  child: const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: ZdColors.success,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SortChip(
                  label: '综合排序',
                  selected: selectedSort == _CandidateSort.comprehensive,
                  onTap: () => onSortChanged(_CandidateSort.comprehensive),
                ),
                const SizedBox(width: 8),
                _SortChip(
                  label: '经验优先',
                  selected: selectedSort == _CandidateSort.experience,
                  onTap: () => onSortChanged(_CandidateSort.experience),
                ),
                const SizedBox(width: 8),
                _SortChip(
                  label: '资料完整',
                  selected: selectedSort == _CandidateSort.profile,
                  onTap: () => onSortChanged(_CandidateSort.profile),
                ),
                const SizedBox(width: 8),
                const _FilterPill(label: '同城服务'),
                const SizedBox(width: 8),
                const _FilterPill(label: '可预约'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: ZdColors.primary,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? ZdColors.primary : const Color(0xFFEDE3DA),
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : ZdColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZdRadius.pill),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZdRadius.pill),
        border: Border.all(color: const Color(0xFFEDE3DA)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: ZdColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
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
    required this.canAdd,
    required this.onView,
    required this.onAdd,
  });

  final RemoteWorkerDirectoryProfile worker;
  final bool isCandidate;
  final bool isAdding;
  final bool canAdd;
  final VoidCallback onView;
  final VoidCallback onAdd;

  String get _avatarLabel => worker.name.isNotEmpty ? worker.name[0] : '工';

  String get _tradeTitle => '${_tradeLabel(worker.primaryTrade)}师傅';

  String get _cityLabel {
    final city = worker.serviceCity?.trim();
    return city == null || city.isEmpty ? '服务区域待完善' : '$city服务';
  }

  String get _bioSummary {
    final bio = worker.bio?.trim();
    if (bio == null || bio.isEmpty) return '师傅暂未填写自我介绍，可进入详情查看完整资料。';
    return bio.length > 18 ? '${bio.substring(0, 18)}…' : bio;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onView,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: isCandidate
              ? Border.all(color: ZdColors.success.withAlpha(120), width: 1.2)
              : Border.all(color: const Color(0xFFF1E8DF)),
          boxShadow: ZdShadow.cardSoft,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 68,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFEEE3), Color(0xFFF3ECE6)],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              alignment: Alignment.center,
              child: Text(
                _avatarLabel,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: ZdColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          worker.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: ZdColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _TinyBadge(
                        text: isCandidate ? '已选' : '资料完整',
                        color: isCandidate
                            ? ZdColors.success
                            : ZdColors.primaryDark,
                        background: isCandidate
                            ? ZdColors.successSoft
                            : const Color(0xFFFFF0E5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_tradeTitle · ${worker.experienceYears}年经验 · $_cityLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ZdColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    '已认证 · 可预约 · 详情看案例',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ZdColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _bioSummary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ZdColors.textHint,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 9),
            SizedBox(
              width: 88,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: onView,
                    style: FilledButton.styleFrom(
                      backgroundColor: ZdColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ZdRadius.pill),
                      ),
                    ),
                    child: const Text('查看详情'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: isCandidate || !canAdd || isAdding
                        ? null
                        : onAdd,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isCandidate
                          ? ZdColors.success
                          : ZdColors.primaryDark,
                      disabledForegroundColor: isCandidate
                          ? ZdColors.success
                          : ZdColors.textHint,
                      side: BorderSide(
                        color: isCandidate
                            ? ZdColors.success.withAlpha(120)
                            : const Color(0xFFFFC7A3),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ZdRadius.pill),
                      ),
                    ),
                    child: isAdding
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isCandidate
                                ? '已选'
                                : canAdd
                                ? '加入候选'
                                : '已满',
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

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({
    required this.text,
    required this.color,
    required this.background,
  });

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ZdRadius.pill),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

String _tradeLabel(String apiTrade) {
  return switch (apiTrade.trim()) {
    'demolition' => '拆除',
    'plumbing' => '水电',
    'masonry' => '泥瓦',
    'waterproof' => '防水',
    'carpentry' => '木工',
    'painting' => '油漆',
    'installation' => '安装',
    'cleaning' => '保洁',
    final value => value,
  };
}
