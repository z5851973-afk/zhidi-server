import 'package:flutter/material.dart';
import 'worker_chat_page.dart';
import 'construction_standards_page.dart';
import '../../design/tokens.dart';

// ── 颜色常量 ──
const _green = ZdColors.success;
const _greenBg = Color(0xFFE8F8EE);
const _textDark = ZdColors.textPrimary;
const _textMid = ZdColors.textSecondary;
const _textLight = ZdColors.textSecondary;
const _textDisabled = ZdColors.textHint;
const _bg = ZdColors.background;
const _orange = ZdColors.primary;
const _orangeLight = ZdColors.cardBg;
const _star = Color(0xFFFFB800);
const _cardBg = ZdColors.surfaceWhite;

class BookingSuccessPage extends StatelessWidget {
  final String workerName;
  final String workerJob;
  final double rating;
  final String renovationStage;
  final String tradeType;
  final String serviceAddress;
  final String estimatedTime;

  const BookingSuccessPage({
    super.key,
    required this.workerName,
    required this.workerJob,
    required this.rating,
    required this.renovationStage,
    required this.tradeType,
    required this.serviceAddress,
    required this.estimatedTime,
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
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  _buildSuccessHeader(),
                  const SizedBox(height: 16),
                  _buildTipBar(),
                  const SizedBox(height: 16),
                  _buildWorkerInfoCard(),
                  const SizedBox(height: 12),
                  _buildProgressCard(),
                  const SizedBox(height: 12),
                  _buildGuaranteeCard(),
                  const SizedBox(height: 12),
                  _buildBookingInfoCard(),
                  const SizedBox(height: 24),
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
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: _green,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 16),
        const Text(
          '预约成功',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '师傅已接单，将尽快与您联系',
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
          // 姓名 + 工种 + 评分
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _orangeLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        workerJob,
                        style: const TextStyle(fontSize: 11, color: _orange),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...List.generate(5, (i) {
                      return Icon(
                        i < rating.floor() ? Icons.star : Icons.star_border,
                        size: 12,
                        color: _star,
                      );
                    }),
                    const SizedBox(width: 2),
                    Text(
                      rating.toString(),
                      style: const TextStyle(fontSize: 11, color: _textMid),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 状态标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _greenBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 7, color: _green),
                SizedBox(width: 5),
                Text(
                  '已接单·正在联系您',
                  style: TextStyle(fontSize: 11, color: _green, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. 平台服务进度 ──
  Widget _buildProgressCard() {
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
            '平台服务进度',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textDark),
          ),
          const SizedBox(height: 16),
          _TimelineStep(
            title: '系统已分配师傅',
            status: TimelineStatus.completed,
            isFirst: true,
          ),
          _TimelineStep(
            title: '师傅已确认接单',
            status: TimelineStatus.completed,
          ),
          _TimelineStep(
            title: '预计30分钟内联系',
            status: TimelineStatus.inProgress,
          ),
          _TimelineStep(
            title: '上门服务中',
            status: TimelineStatus.pending,
            isLast: true,
          ),
        ],
      ),
    );
  }

  // ── 4. 平台保障提示卡 ──
  Widget _buildGuaranteeCard() {
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
            '平台保障',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textDark),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(child: _GuaranteeItem(icon: Icons.lock_outline, label: '工价已锁定')),
              SizedBox(width: 12),
              Expanded(child: _GuaranteeItem(icon: Icons.verified_user_outlined, label: '师傅实名可查')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: _GuaranteeItem(icon: Icons.shield_outlined, label: '服务全程托管')),
              SizedBox(width: 12),
              Expanded(child: _GuaranteeItem(icon: Icons.support_agent_outlined, label: '异常平台介入')),
            ],
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textDark),
          ),
          const SizedBox(height: 16),
          _InfoRow(label: '装修阶段', value: renovationStage),
          const SizedBox(height: 12),
          _InfoRow(label: '工种类型', value: tradeType),
          const SizedBox(height: 12),
          _InfoRow(label: '服务地址', value: serviceAddress),
          const SizedBox(height: 12),
          _InfoRow(label: '预计上门', value: estimatedTime),
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
            child: const Icon(Icons.warning_amber_rounded,
                size: 20, color: ZdColors.primary),
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
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkerChatPage(workerName: workerName),
                  ),
                ),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(23),
                    border: Border.all(color: _green, width: 1),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '联系师傅',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _green),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ConstructionStandardsPage()),
                  );
                },
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5A00), ZdColors.primary],
                    ),
                    borderRadius: BorderRadius.circular(23),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '查看施工标准',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// 子组件
// ══════════════════════════════════════════

// ── 时间轴步骤 ──
enum TimelineStatus { completed, inProgress, pending }

class _TimelineStep extends StatefulWidget {
  final String title;
  final TimelineStatus status;
  final bool isFirst;
  final bool isLast;

  const _TimelineStep({
    required this.title,
    required this.status,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  State<_TimelineStep> createState() => _TimelineStepState();
}

class _TimelineStepState extends State<_TimelineStep> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    if (widget.status == TimelineStatus.inProgress) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    if (widget.status == TimelineStatus.inProgress) {
      _pulseController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInProgress = widget.status == TimelineStatus.inProgress;
    final isPending = widget.status == TimelineStatus.pending;

    final dotColor = isPending ? _textDisabled : (isInProgress ? _orange : _green);
    final lineColor = isPending ? _textDisabled : _green;
    final textColor = isPending ? _textDisabled : _textDark;
    final fontWeight = isPending ? FontWeight.normal : FontWeight.w600;

    return SizedBox(
      height: 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 竖线 + 圆点
          SizedBox(
            width: 24,
            child: Column(
              children: [
                // 上方竖线
                Expanded(
                  child: Container(
                    width: 2,
                    color: widget.isFirst ? Colors.transparent : lineColor,
                  ),
                ),
                // 圆点
                _buildDot(dotColor, isInProgress),
                // 下方竖线
                Expanded(
                  child: Container(
                    width: 2,
                    color: widget.isLast ? Colors.transparent : lineColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 文字
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(fontSize: 14, fontWeight: fontWeight, color: textColor),
                  ),
                  if (isInProgress) ...[
                    const SizedBox(width: 8),
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: 0.4 + 0.6 * _pulseController.value,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: _orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(Color color, bool isInProgress) {
    if (isInProgress) {
      return Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 10, color: Colors.white),
      );
    }
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ── 保障项 ──
class _GuaranteeItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _GuaranteeItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _green),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: _textMid),
        ),
      ],
    );
  }
}

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
