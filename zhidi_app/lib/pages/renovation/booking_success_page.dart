import 'package:flutter/material.dart';
import '../../design/tokens.dart';

// ── 颜色常量 ──
const _green = ZdColors.success;
const _greenBg = Color(0xFFE8F8EE);
const _textDark = ZdColors.textPrimary;
const _textLight = ZdColors.textSecondary;
const _bg = ZdColors.background;
const _orange = ZdColors.primary;
const _orangeLight = ZdColors.cardBg;
const _cardBg = ZdColors.surfaceWhite;

class BookingSuccessPage extends StatelessWidget {
  final String workerName;
  final String workerJob;
  final String tradeType;
  final String serviceAddress;

  const BookingSuccessPage({
    super.key,
    required this.workerName,
    required this.workerJob,
    required this.tradeType,
    required this.serviceAddress,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(true);
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: const Text(
            '预约结果',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: _textDark,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 28),
                    _buildSuccessHeader(),
                    const SizedBox(height: 20),
                    _buildWorkerInfoCard(),
                    const SizedBox(height: 12),
                    _buildBookingInfoCard(),
                    const SizedBox(height: 12),
                    _buildTipBar(),
                  ],
                ),
              ),
            ),
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  // ── 1. 顶部成功区 ──
  Widget _buildSuccessHeader() {
    return Column(
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            color: _greenBg,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.assignment_turned_in_outlined,
            color: _green,
            size: 42,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '预约已提交',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '上门时间待双方确认',
          style: TextStyle(fontSize: 14, color: _textLight),
        ),
      ],
    );
  }

  // ── 2. 师傅信息卡片 ──
  Widget _buildWorkerInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 头像
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: _orangeLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: _orange, size: 26),
          ),
          const SizedBox(width: 10),
          // 姓名 + 工种
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _orangeLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    workerJob,
                    style: const TextStyle(fontSize: 11, color: _orange),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ZdColors.warningSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '待确认',
              style: TextStyle(
                fontSize: 12,
                color: _orange,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 5. 本次预约信息 ──
  Widget _buildBookingInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '预约信息',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 16),
          const _InfoRow(label: '上门时间', value: '待双方确认'),
          const SizedBox(height: 12),
          _InfoRow(label: '服务类型', value: tradeType),
          const SizedBox(height: 12),
          _InfoRow(label: '上门地址', value: serviceAddress),
        ],
      ),
    );
  }

  // ── 温馨提示 ──
  Widget _buildTipBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ZdColors.primary.withAlpha(40), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: ZdColors.primary.withAlpha(18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: ZdColors.primary.withAlpha(12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              size: 20,
              color: ZdColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '温馨提示',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: ZdColors.primaryDark,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '为保障您的业主权益，请勿与师傅私下交易，否则无法获得平台保障。',
                  style: TextStyle(
                    fontSize: 13,
                    color: ZdColors.primaryDark,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. 底部固定栏 ──
  Widget _buildBottomBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        top: false,
        child: FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            backgroundColor: _orange,
          ),
          child: const Text('完成'),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// 子组件
// ══════════════════════════════════════════

// ── 预约信息行 ──
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: _textLight),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: _textDark),
          ),
        ),
      ],
    );
  }
}
