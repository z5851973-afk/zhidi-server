import 'package:flutter/material.dart';
import '../../../design/tokens.dart';
import '../../../services/auth_api_client.dart';
import '../../../services/service_request_api_client.dart';
import '../../../services/worker_directory_api_client.dart';
import '../../../models/house_info.dart';
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
    this.houseInfo,
    this.serviceRequestApi,
    this.workerDirectoryApi,
  });

  final String requestId;
  final String accessToken;
  final String trade;
  final String serviceCity;
  final HouseInfo? houseInfo;
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
  Map<String, RemoteCandidateBooking> _activeCandidatesByWorkerId = const {};
  Set<String> _cooperatedWorkerIds = const {};
  Set<String> _addingIds = {}; // in-flight add calls
  RemoteServiceRequest? _request;
  RemoteCandidateBooking? _replacementCandidate;
  _CandidateSort _sort = _CandidateSort.comprehensive;
  String? _error;
  bool _loadingWorkers = true;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
    _loadCooperationHistory();
  }

  static const _cooperatedBookingStatuses = {
    'READY_TO_START',
    'HIRED',
    'COMPLETED',
  };

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

  Future<void> _loadCooperationHistory() async {
    try {
      final requests = await _api.listOwnerRequests(widget.accessToken);
      final cooperatedWorkerIds = <String>{};
      RemoteServiceRequest? currentRequest;
      for (final request in requests) {
        if (request.id == widget.requestId) {
          currentRequest = request;
          continue;
        }
        for (final candidate in request.candidates) {
          final status = candidate.status.trim().toUpperCase();
          if (_cooperatedBookingStatuses.contains(status)) {
            cooperatedWorkerIds.add(candidate.workerUserId);
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _cooperatedWorkerIds = cooperatedWorkerIds;
        if (currentRequest != null) _applyRequest(currentRequest);
      });
    } catch (_) {
      // 合作历史仅用于展示，不影响师傅目录或候选操作。
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

  bool get _canAddCandidates =>
      _request?.canAddCandidates ?? _candidateIds.length < 3;

  void _applyRequest(RemoteServiceRequest request) {
    final active = {
      for (final candidate in request.candidates)
        if (candidate.isActiveCandidate) candidate.workerUserId: candidate,
    };
    _request = request;
    _activeCandidatesByWorkerId = active;
    _candidateIds = active.keys.toSet();
    final replacing = _replacementCandidate;
    if (replacing != null && !active.containsKey(replacing.workerUserId)) {
      _replacementCandidate = null;
    }
  }

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
    if (!_canAddCandidates) {
      _showError('最多选择 3 位候选师傅');
      return false;
    }
    if (_addingIds.contains(uid)) return false;
    setState(() => _addingIds = {..._addingIds, uid});
    try {
      final updated = await _api.addCandidate(
        widget.accessToken,
        widget.requestId,
        uid,
      );
      if (!mounted) return false;
      setState(() {
        _applyRequest(updated);
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

  Future<void> _removeCandidate(RemoteCandidateBooking candidate) async {
    if (!candidate.canRemove || _addingIds.contains(candidate.workerUserId)) {
      return;
    }
    setState(() => _addingIds = {..._addingIds, candidate.workerUserId});
    try {
      final updated = await _api.removeCandidate(
        widget.accessToken,
        widget.requestId,
        candidate.id,
      );
      if (!mounted) return;
      setState(() {
        _applyRequest(updated);
        _addingIds = _addingIds.difference({candidate.workerUserId});
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _addingIds = _addingIds.difference({candidate.workerUserId}),
      );
      _showError('移除失败: ${e is AuthApiException ? e.message : '请重试'}');
    }
  }

  void _startReplacement(RemoteCandidateBooking candidate) {
    if (!candidate.canReplace) return;
    setState(() => _replacementCandidate = candidate);
  }

  Future<bool> _replaceCandidate(
    RemoteWorkerDirectoryProfile replacement,
  ) async {
    final oldCandidate = _replacementCandidate;
    if (oldCandidate == null) return false;
    if (_addingIds.contains(replacement.userId)) return false;
    setState(() => _addingIds = {..._addingIds, replacement.userId});
    try {
      final updated = await _api.replaceCandidate(
        widget.accessToken,
        widget.requestId,
        oldCandidate.id,
        replacement.userId,
      );
      if (!mounted) return false;
      setState(() {
        _replacementCandidate = null;
        _applyRequest(updated);
        _addingIds = _addingIds.difference({replacement.userId});
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _addingIds = _addingIds.difference({replacement.userId}));
      _showError('更换失败: ${e is AuthApiException ? e.message : '请重试'}');
      return false;
    }
  }

  Future<bool> _selectWorker(RemoteWorkerDirectoryProfile worker) {
    return _replacementCandidate == null
        ? _addCandidate(worker)
        : _replaceCandidate(worker);
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
          onAddCandidate: () => _selectWorker(worker),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_candidateIds.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _request != null && !_request!.canAddCandidates
                        ? '需求已进入后续流程，不能调整候选师傅'
                        : '请先加入至少 1 位候选师傅',
                    style: ZdText.caption,
                  ),
                ),
              FilledButton(
                key: const Key('candidate-complete'),
                onPressed: _candidateIds.isEmpty ? null : _completeSelection,
                child: Text('完成选择（已选 ${_candidateIds.length}/3）'),
              ),
            ],
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
          houseInfo: _request?.houseInfo ?? widget.houseInfo,
          candidateCount: _candidateIds.length,
          matchedCount: _workers.length,
          selectedSort: _sort,
          onSortChanged: (sort) => setState(() => _sort = sort),
          replacementWorkerName: _replacementCandidate?.workerName,
          onCancelReplacement: _replacementCandidate == null
              ? null
              : () => setState(() => _replacementCandidate = null),
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
                    final candidate =
                        _activeCandidatesByWorkerId[worker.userId];
                    return _CandidateItem(
                      worker: worker,
                      hasCooperated: _cooperatedWorkerIds.contains(
                        worker.userId,
                      ),
                      isCandidate: _isCandidate(worker.userId),
                      isAdding: _isAdding(worker.userId),
                      canAdd: _canAddCandidates,
                      candidate: candidate,
                      replacementMode: _replacementCandidate != null,
                      isReplacementSource:
                          _replacementCandidate?.id == candidate?.id,
                      onView: () => _openWorker(worker),
                      onAdd: () => _selectWorker(worker),
                      onRemove: candidate == null
                          ? null
                          : () => _removeCandidate(candidate),
                      onReplace: candidate == null
                          ? null
                          : () => _startReplacement(candidate),
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
    this.houseInfo,
    required this.candidateCount,
    required this.matchedCount,
    required this.selectedSort,
    required this.onSortChanged,
    this.replacementWorkerName,
    this.onCancelReplacement,
  });

  final String trade;
  final String cityName;
  final HouseInfo? houseInfo;
  final int candidateCount;
  final int matchedCount;
  final _CandidateSort selectedSort;
  final ValueChanged<_CandidateSort> onSortChanged;
  final String? replacementWorkerName;
  final VoidCallback? onCancelReplacement;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_tradeLabel(trade)}师傅 · $cityName',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: ZdColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            houseInfo?.summaryLabel ?? missingHouseInfoLabel,
            style: const TextStyle(fontSize: 13, color: ZdColors.textSecondary),
          ),
          if (replacementWorkerName != null) ...[
            const SizedBox(height: 8),
            Container(
              key: const Key('candidate-replacement-banner'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '正在更换 $replacementWorkerName，请选择替代师傅',
                      style: const TextStyle(
                        color: ZdColors.primaryDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onCancelReplacement,
                    child: const Text('取消更换'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            candidateCount > 0
                ? '已选 $candidateCount 位候选人'
                : '可选 $matchedCount 位师傅，最多加入 3 位候选',
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: ZdColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
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
                  label: '看案例',
                  selected: selectedSort == _CandidateSort.profile,
                  onTap: () => onSortChanged(_CandidateSort.profile),
                ),
                const SizedBox(width: 8),
                const _FilterPill(label: '资料完整'),
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
      selectedColor: const Color(0xFFFFEEE3),
      backgroundColor: const Color(0xFFFAF7F4),
      side: BorderSide(
        color: selected ? ZdColors.primary : const Color(0xFFEDE3DA),
      ),
      labelStyle: TextStyle(
        color: selected ? ZdColors.primaryDark : ZdColors.textSecondary,
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
        color: const Color(0xFFFAF7F4),
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
    required this.hasCooperated,
    required this.isCandidate,
    required this.isAdding,
    required this.canAdd,
    required this.onView,
    required this.onAdd,
    required this.candidate,
    required this.replacementMode,
    required this.isReplacementSource,
    this.onRemove,
    this.onReplace,
  });

  final RemoteWorkerDirectoryProfile worker;
  final bool hasCooperated;
  final bool isCandidate;
  final bool isAdding;
  final bool canAdd;
  final VoidCallback onView;
  final VoidCallback onAdd;
  final RemoteCandidateBooking? candidate;
  final bool replacementMode;
  final bool isReplacementSource;
  final VoidCallback? onRemove;
  final VoidCallback? onReplace;

  String get _avatarLabel => worker.name.isNotEmpty ? worker.name[0] : '工';

  String get _tradeTitle => '${_tradeLabel(worker.primaryTrade)}师傅';

  String get _cityLabel {
    final city = worker.serviceCity?.trim();
    return city == null || city.isEmpty ? '服务区域待完善' : city;
  }

  String get _commonServicesText => _tradeCommonServices(worker.primaryTrade);

  String get _bioSummary {
    final bio = worker.bio?.trim();
    if (bio == null || bio.isEmpty) return '师傅暂未填写自我介绍，可进入详情查看完整资料。';
    return bio.length > 24 ? '${bio.substring(0, 24)}…' : bio;
  }

  String get _casePillLabel =>
      worker.caseCount > 0 ? '${worker.caseCount}个案例' : '暂无案例';

  String get _hiredPillLabel => '${worker.hiredCount}次被选中';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('candidate-worker-${worker.userId}'),
      onTap: onView,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isCandidate
              ? Border.all(color: ZdColors.success.withAlpha(140), width: 1.2)
              : Border.all(color: const Color(0xFFF1E8DF)),
          boxShadow: ZdShadow.cardSoft,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _WorkerAvatar(label: _avatarLabel),
            const SizedBox(width: 13),
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
                            fontSize: 18,
                            color: ZdColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      _TinyBadge(
                        text: '资料已完善',
                        color: ZdColors.primaryDark,
                        background: const Color(0xFFFFF0E5),
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
                  Text(
                    '该工种常见服务：$_commonServicesText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ZdColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '简介：$_bioSummary',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ZdColors.textHint,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      _TrustPill(label: _casePillLabel),
                      _TrustPill(label: _hiredPillLabel),
                      if (hasCooperated)
                        const _TrustPill(label: '已合作', success: true),
                      const _TrustPill(label: '资料完整'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 88,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    onPressed: onView,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ZdColors.textPrimary,
                      side: const BorderSide(color: Color(0xFFEEDFD4)),
                      backgroundColor: const Color(0xFFFFFCFA),
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
                  FilledButton(
                    onPressed:
                        isCandidate || (!canAdd && !replacementMode) || isAdding
                        ? null
                        : onAdd,
                    style: FilledButton.styleFrom(
                      backgroundColor: isCandidate
                          ? ZdColors.successSoft
                          : ZdColors.primary,
                      foregroundColor: isCandidate
                          ? ZdColors.success
                          : Colors.white,
                      disabledBackgroundColor: isCandidate
                          ? ZdColors.successSoft
                          : const Color(0xFFE5DED9),
                      disabledForegroundColor: isCandidate
                          ? ZdColors.success
                          : ZdColors.textHint,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
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
                                ? '已加入'
                                : replacementMode
                                ? '替换为此师傅'
                                : canAdd
                                ? '加入候选'
                                : '已满',
                          ),
                  ),
                  if (isCandidate && candidate != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (candidate!.canRemove)
                          InkWell(
                            key: Key('candidate-remove-${candidate!.id}'),
                            onTap: isAdding ? null : onRemove,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                '移除',
                                style: TextStyle(
                                  color: ZdColors.error,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        if (candidate!.canReplace)
                          InkWell(
                            key: Key('candidate-replace-${candidate!.id}'),
                            onTap: isAdding ? null : onReplace,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                isReplacementSource ? '更换中' : '更换',
                                style: const TextStyle(
                                  color: ZdColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
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

class _WorkerAvatar extends StatelessWidget {
  const _WorkerAvatar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 68,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF2EA), Color(0xFFFFE4D4)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE2D1)),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            color: ZdColors.primaryDark,
          ),
        ),
      ),
    );
  }
}

class _TrustPill extends StatelessWidget {
  const _TrustPill({required this.label, this.success = false});

  final String label;
  final bool success;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: success ? ZdColors.successSoft : const Color(0xFFFAF7F4),
        borderRadius: BorderRadius.circular(ZdRadius.pill),
        border: Border.all(
          color: success
              ? ZdColors.success.withAlpha(80)
              : const Color(0xFFF0E5DD),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: success ? ZdColors.success : ZdColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
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

String _tradeCommonServices(String apiTrade) {
  return switch (_tradeLabel(apiTrade)) {
    '拆除' => '拆旧 / 拆墙 / 垃圾清运',
    '水电' => '水电改造 / 线路排查 / 管道安装',
    '泥瓦' => '贴砖 / 找平 / 修补',
    '防水' => '厨卫防水 / 阳台防水 / 堵漏',
    '木工' => '吊顶 / 柜体 / 木作修补',
    '油漆' => '墙面修复 / 喷涂 / 翻新',
    '安装' => '灯具安装 / 五金安装 / 维修',
    '保洁' => '开荒保洁 / 深度清洁 / 收尾',
    final value => '$value施工 / 现场沟通 / 收尾处理',
  };
}
