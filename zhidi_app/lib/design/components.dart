import 'package:flutter/material.dart';
import 'tokens.dart';

/// 知底 App 标准化组件库 — 所有页面统一使用，不自行造轮子。

// ═══════════════════════════════════════════
// 主 CTA 胶囊按钮（橙色渐变 + 阴影 + 点击缩放反馈）
// ═══════════════════════════════════════════
class ZdPrimaryButton extends StatefulWidget {
  const ZdPrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.height,
  });

  final String label;
  final VoidCallback? onTap;
  final double? height;

  @override
  State<ZdPrimaryButton> createState() => _ZdPrimaryButtonState();
}

class _ZdPrimaryButtonState extends State<ZdPrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height ?? 52;
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          height: h,
          decoration: BoxDecoration(
            gradient: ZdColors.gradientPrimary,
            borderRadius: BorderRadius.circular(h / 2),
            boxShadow: ZdShadow.button,
          ),
          child: Center(
            child: Text(
              widget.label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// 统一卡片容器
// ═══════════════════════════════════════════
class ZdCard extends StatelessWidget {
  const ZdCard({
    super.key,
    this.margin,
    this.padding,
    this.child,
    this.onTap,
  });

  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Widget? child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin ?? const EdgeInsets.symmetric(
        horizontal: ZdSpacing.lg,
        vertical: ZdSpacing.sm,
      ),
      padding: padding ?? const EdgeInsets.all(ZdSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZdRadius.card),
        boxShadow: ZdShadow.card,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

// ═══════════════════════════════════════════
// 电商列表项（左图右文 + 右侧价格/箭头）
// ═══════════════════════════════════════════
class ZdListItem extends StatelessWidget {
  const ZdListItem({
    super.key,
    required this.image,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget image;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(ZdSpacing.md),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: ZdColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(ZdRadius.sm),
              child: SizedBox(width: 72, height: 72, child: image),
            ),
            const SizedBox(width: ZdSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: ZdText.subtitle, maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: ZdText.caption, maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: ZdSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
