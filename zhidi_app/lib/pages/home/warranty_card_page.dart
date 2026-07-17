import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../app/owner_models.dart';
import '../../design/tokens.dart';

const _primary = ZdColors.primary;
const _primaryDark = ZdColors.primaryDark;
const _textDark = ZdColors.textPrimary;
const _textMid = Color(0xFF666666);
const _textLight = ZdColors.textSecondary;

/// 各工种质保年限
int _warrantyYears(String trade) {
  switch (trade) {
    case '水电':
    case '防水':
      return 5;
    case '泥工':
    case '木工':
      return 2;
    default:
      return 1;
  }
}

/// 质保卡页面
/// 展示已完成工序的质保信息：工序名称/师傅/工期/质保年限/平台保障
class WarrantyCardPage extends StatelessWidget {
  const WarrantyCardPage({
    super.key,
    required this.phaseName,
    required this.phaseIndex,
    required this.worker,
    required this.startedAt,
    required this.completedAt,
  });

  final String phaseName;
  final int phaseIndex;
  final BookedWorker? worker;
  final DateTime? startedAt;
  final DateTime completedAt;

  static const _platformGuarantees = [
    ('师傅严选', '多重审核·持证上岗'),
    ('工价透明', '明码标价·拒绝增项'),
    ('施工规范', '节点验收·质量把关'),
    ('售后无忧', '专属客服·及时响应'),
  ];

  @override
  Widget build(BuildContext context) {
    final years = worker != null ? _warrantyYears(worker!.trade) : 1;
    final expiryDate = DateTime(
      completedAt.year + years,
      completedAt.month,
      completedAt.day,
    );
    final duration = startedAt != null
        ? completedAt.difference(startedAt!).inDays
        : null;

    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: const Text(
          '质保卡',
          style: TextStyle(color: _textDark, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: _textDark),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            onPressed: () => _shareWarrantyCard(context, years, expiryDate),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildInfoCard(years, expiryDate, duration),
            const SizedBox(height: 16),
            _buildGuaranteeSection(),
            const SizedBox(height: 20),
            _buildSeal(),
          ],
        ),
      ),
    );
  }

  Future<void> _shareWarrantyCard(
    BuildContext context,
    int years,
    DateTime expiryDate,
  ) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('正在打开分享面板')));

    final expiry =
        '${expiryDate.year}.${expiryDate.month.toString().padLeft(2, '0')}.${expiryDate.day.toString().padLeft(2, '0')}';
    final workerText = worker == null
        ? '平台认证师傅'
        : '${worker!.name}（${worker!.trade}）';
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              '知底装修质保卡\n项目：$phaseIndex. $phaseName\n施工：$workerText\n质保：$years 年，至 $expiry\n平台保障：师傅严选、工价透明、施工规范、售后无忧',
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('分享暂不可用，请稍后重试')));
    }
  }

  // ── 顶部标题区 ──
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _primaryDark],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(Icons.verified_user, color: Colors.white, size: 36),
          const SizedBox(height: 10),
          const Text(
            '知底装修 · 质保卡',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '品质保障 · 安心居住',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'NO. ZD${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 基本信息卡 ──
  Widget _buildInfoCard(int years, DateTime expiryDate, int? duration) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('质保项目', style: TextStyle(fontSize: 12, color: _textLight)),
          const SizedBox(height: 4),
          Text(
            '$phaseIndex. $phaseName',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          const Divider(height: 24),
          _infoRow(
            '施工师傅',
            worker?.name ?? '—',
            trailing: worker != null
                ? '${worker!.avatarEmoji}  ${worker!.trade}'
                : null,
          ),
          if (worker != null) ...[
            const SizedBox(height: 8),
            _infoRow(
              '从业经验',
              '${worker!.years} 年',
              trailing: '${worker!.completedOrders} 单完成',
            ),
          ],
          const SizedBox(height: 8),
          _infoRow(
            '开工日期',
            startedAt != null
                ? '${startedAt!.year}.${startedAt!.month.toString().padLeft(2, '0')}.${startedAt!.day.toString().padLeft(2, '0')}'
                : '—',
          ),
          const SizedBox(height: 8),
          _infoRow(
            '竣工日期',
            '${completedAt.year}.${completedAt.month.toString().padLeft(2, '0')}.${completedAt.day.toString().padLeft(2, '0')}',
            trailing: duration != null ? '工期 $duration 天' : null,
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '质保期限',
                      style: TextStyle(fontSize: 12, color: _textLight),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$years 年',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '质保至',
                      style: TextStyle(fontSize: 12, color: _textLight),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${expiryDate.year}.${expiryDate.month.toString().padLeft(2, '0')}.${expiryDate.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {String? trailing}) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: _textLight),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _textDark,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: const TextStyle(fontSize: 12, color: _textLight),
          ),
      ],
    );
  }

  // ── 平台保障 ──
  Widget _buildGuaranteeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '平台保障',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: _platformGuarantees.map((g) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 16, color: _primary),
                  const SizedBox(width: 6),
                  Text(
                    '${g.$1} · ${g.$2}',
                    style: const TextStyle(fontSize: 13, color: _textMid),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── 印鉴区 ──
  Widget _buildSeal() {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _primary, width: 2.5),
            color: const Color(0xFFFFF7F0),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '知底',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _primary,
                    letterSpacing: 4,
                  ),
                ),
                Text(
                  '装修',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '知底装修平台认证',
          style: TextStyle(fontSize: 12, color: _textLight),
        ),
        const SizedBox(height: 4),
        const Text(
          '本卡由知底装修平台自动生成，记录真实施工信息。\n质保期内如遇质量问题，凭此卡联系平台售后。',
          style: TextStyle(fontSize: 11, color: _textLight, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
