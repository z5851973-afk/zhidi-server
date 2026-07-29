// ============================================================
// 工匠端 — 节点验收管理页（V14 API）
// ============================================================

import 'package:flutter/material.dart';

import '../../app/worker_app_scope.dart';
import '../../design/tokens.dart';
import '../../design/components.dart';
import '../../services/inspection_api_client.dart';
import '../../services/auth_api_client.dart';

const _primary = ZdColors.primary;
const _textDark = ZdColors.textPrimary;
const _textMid = ZdColors.textSecondary;
const _textLight = ZdColors.textHint;
const _success = ZdColors.success;
const _error = ZdColors.error;

class InspectionPage extends StatefulWidget {
  const InspectionPage({
    super.key,
    required this.orderId,
    required this.tradeLabel,
    this.api,
  });

  final String orderId;
  final String tradeLabel;
  final InspectionApi? api;

  @override
  State<InspectionPage> createState() => _InspectionPageState();
}

class _InspectionPageState extends State<InspectionPage> {
  List<RemoteInspectionNode> _nodes = const [];
  bool _loading = true;
  String? _errorMsg;
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) {
      return;
    }
    _loadStarted = true;
    _loadNodes();
  }

  Future<void> _loadNodes() async {
    final state = WorkerAppScope.of(context);
    final token = state.getAccessToken();
    if (token == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = '未登录';
        });
      }
      return;
    }
    try {
      final api = widget.api ?? InspectionApiClient();
      final nodes = await api.getNodes(token, widget.orderId);
      final visibleNodes = _nodesForCurrentTrade(nodes);
      if (visibleNodes.isEmpty) {
        final created = await _createDefaultNodes(token);
        if (mounted) {
          setState(() {
            _nodes = _nodesForCurrentTrade(created);
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _nodes = visibleNodes;
            _loading = false;
          });
        }
      }
    } on AuthApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = '加载失败：$e';
        });
      }
    }
  }

  Future<List<RemoteInspectionNode>> _createDefaultNodes(String token) async {
    final api = widget.api ?? InspectionApiClient();
    final node = _defaultNodeForTrade(widget.tradeLabel);
    return await api.createNodes(token, widget.orderId, [node]);
  }

  List<RemoteInspectionNode> _nodesForCurrentTrade(
    List<RemoteInspectionNode> nodes,
  ) {
    final normalizedTrade = _normalizeTradeLabel(widget.tradeLabel);
    final expectedName = '$normalizedTrade验收';
    return nodes.where((node) {
      final normalizedName = _normalizeTradeLabel(node.name);
      return normalizedName == expectedName ||
          normalizedName.startsWith(normalizedTrade);
    }).toList();
  }

  Future<void> _requestInspection(String nodeId) async {
    final state = WorkerAppScope.of(context);
    // ignore: await_only_futures
    final token = await state.getAccessToken();
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('登录已过期')));
      }
      return;
    }
    try {
      final api = widget.api ?? InspectionApiClient();
      await api.requestInspection(token, nodeId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已申请验收')));
      }
      await _loadNodes();
    } on AuthApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: const Text('节点验收'),
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_errorMsg != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMsg!, style: ZdText.caption.copyWith(color: _textLight)),
            const SizedBox(height: ZdSpacing.md),
            ZdPrimaryButton(
              label: '重试',
              onTap: () {
                setState(() {
                  _loading = true;
                  _errorMsg = null;
                });
                _loadNodes();
              },
            ),
          ],
        ),
      );
    }
    if (_nodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fact_check_outlined, size: 56, color: _textLight),
            const SizedBox(height: ZdSpacing.md),
            Text('暂无验收节点', style: ZdText.caption.copyWith(color: _textLight)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(ZdSpacing.md),
      itemCount: _nodes.length,
      itemBuilder: (ctx, i) => _NodeCard(
        node: _nodes[i],
        onRequestInspection: () => _requestInspection(_nodes[i].id),
      ),
    );
  }
}

Map<String, dynamic> _defaultNodeForTrade(String tradeLabel) {
  final normalized = _normalizeTradeLabel(tradeLabel);
  final description = switch (normalized) {
    '拆除' => '拆除范围、清运和现场安全验收',
    '水电' => '水管、电路布线验收',
    '泥瓦' => '贴砖、砌墙、地面找平验收',
    '防水' => '防水涂刷、闭水和节点验收',
    '木工' => '吊顶、柜体结构验收',
    '油漆' => '墙面平整度、颜色均匀度验收',
    '安装' => '灯具、洁具、五金安装验收',
    '保洁' => '全屋清洁、细节收尾验收',
    _ => '$normalized施工质量验收',
  };
  return {'name': '$normalized验收', 'description': description, 'sortOrder': 1};
}

String _normalizeTradeLabel(String value) {
  final trimmed = value.trim();
  return switch (trimmed) {
    'demolition' || '拆除师傅' || '拆除验收' => '拆除',
    'plumbing' || '水电师傅' || '水电验收' => '水电',
    'masonry' || '泥瓦师傅' || '泥瓦验收' || '泥工' || '泥工验收' => '泥瓦',
    'waterproof' || '防水师傅' || '防水验收' => '防水',
    'carpentry' || '木工师傅' || '木工验收' => '木工',
    'painting' || '油漆师傅' || '油漆验收' => '油漆',
    'installation' || '安装师傅' || '安装验收' => '安装',
    'cleaning' || '保洁师傅' || '保洁验收' => '保洁',
    _ when trimmed.endsWith('师傅') => trimmed.substring(
      0,
      trimmed.length - '师傅'.length,
    ),
    _ when trimmed.endsWith('验收') => trimmed.substring(
      0,
      trimmed.length - '验收'.length,
    ),
    _ => trimmed.isEmpty ? '工种' : trimmed,
  };
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({required this.node, required this.onRequestInspection});
  final RemoteInspectionNode node;
  final VoidCallback onRequestInspection;

  Color get _statusColor {
    switch (node.status) {
      case 'PENDING':
        return _textMid;
      case 'INSPECTING':
        return _primary;
      case 'PASSED':
        return _success;
      case 'FAILED':
        return _error;
      default:
        return _textMid;
    }
  }

  String get _statusLabel {
    switch (node.status) {
      case 'PENDING':
        return '待验收';
      case 'INSPECTING':
        return '验收中';
      case 'PASSED':
        return '已通过';
      case 'FAILED':
        return '未通过';
      default:
        return node.status;
    }
  }

  IconData get _statusIcon {
    switch (node.status) {
      case 'PENDING':
        return Icons.hourglass_empty;
      case 'INSPECTING':
        return Icons.pending_actions;
      case 'PASSED':
        return Icons.check_circle_outline;
      case 'FAILED':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ZdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ZdRadius.sm),
                ),
                child: Icon(_statusIcon, color: _statusColor, size: 20),
              ),
              const SizedBox(width: ZdSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(node.name, style: ZdText.subtitle),
                    if (node.description != null &&
                        node.description!.isNotEmpty)
                      Text(
                        node.description!,
                        style: ZdText.tiny,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ZdRadius.pill),
                ),
                child: Text(
                  _statusLabel,
                  style: ZdText.tiny.copyWith(
                    color: _statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (node.status == 'PENDING') ...[
            const SizedBox(height: ZdSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onRequestInspection,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ZdRadius.pill),
                  ),
                ),
                child: const Text('申请验收'),
              ),
            ),
          ],
          if (node.status == 'FAILED') ...[
            const SizedBox(height: ZdSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(ZdSpacing.sm),
              decoration: BoxDecoration(
                color: _error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(ZdRadius.sm),
              ),
              child: Text(
                '验收未通过，请整改后重新申请',
                style: ZdText.tiny.copyWith(color: _error),
              ),
            ),
            const SizedBox(height: ZdSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onRequestInspection,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ZdRadius.pill),
                  ),
                ),
                child: const Text('申请重新验收'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
