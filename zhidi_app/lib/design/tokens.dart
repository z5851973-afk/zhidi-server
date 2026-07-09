import 'package:flutter/material.dart';

/// 知底 App 统一设计 Token — 禁止在页面中直接写死魔法数值，全部引用此处。

// ═══════════════════════════════════════════
// 颜色
// ═══════════════════════════════════════════
abstract final class ZdColors {
  // 品牌主色
  static const primary = Color(0xFFFF7A2F);
  static const primaryDark = Color(0xFFFF5A1F);

  // 渐变色表
  static const gradientPrimary = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // 背景
  static const background = Color(0xFFF7F4F0);
  static const surfaceWhite = Colors.white;
  static const surfaceWarm = Color(0xFFFFFCF8);
  static const surfaceMuted = Color(0xFFF4EFE8);
  static const cardBg = surfaceWarm;

  // Hero 氛围色
  static const heroWoodDark = Color(0xFF2E241D);
  static const heroWoodMid = Color(0xFF4A3A30);
  static const heroMist = Color(0xFF6B7280);

  // 文字
  static const textPrimary = Color(0xFF1F1A17);
  static const textSecondary = Color(0xFF766B63);
  static const textHint = Color(0xFFB4AAA3);

  // 分割线 / 边框
  static const divider = Color(0xFFEEEEEE);

  // 功能色（保留但主品牌不使用科技蓝）
  static const success = Color(0xFF34C759);
  static const successSoft = Color(0xFFE5F4EA);
  static const error = Color(0xFFFF3B30);
  static const warning = Color(0xFFFFCC00);
  static const warningSoft = Color(0xFFFFF1E3);
}

// ═══════════════════════════════════════════
// 间距 （只允许这些值，禁止随意数字）
// ═══════════════════════════════════════════
abstract final class ZdSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

// ═══════════════════════════════════════════
// 圆角
// ═══════════════════════════════════════════
abstract final class ZdRadius {
  static const double sm = 8;
  static const double md = 12;
  /// 卡片统一圆角
  static const double card = 16;
  /// 大圆角，图标/弹窗用
  static const double xl = 24;
  /// 胶囊按钮
  static const double pill = 999;
}

// ═══════════════════════════════════════════
// 阴影
// ═══════════════════════════════════════════
abstract final class ZdShadow {
  /// 卡片轻阴影
  static const card = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.06),
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
  ];

  /// 更轻更柔和的内容卡阴影
  static const cardSoft = [
    BoxShadow(
      color: Color.fromRGBO(44, 30, 18, 0.08),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// 按钮浮层阴影
  static const button = [
    BoxShadow(
      color: Color.fromRGBO(255, 122, 47, 0.35),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color.fromRGBO(255, 122, 47, 0.12),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];
}

// ═══════════════════════════════════════════
// 字体体系（响应式基准 375w）
// ═══════════════════════════════════════════
abstract final class ZdText {
  /// 大标题 20-24
  static const headline = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: ZdColors.textPrimary,
    height: 1.3,
    letterSpacing: -0.3,
  );

  /// 标题 18-20
  static const title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: ZdColors.textPrimary,
    height: 1.3,
  );

  /// 副标题 16
  static const subtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: ZdColors.textPrimary,
    height: 1.4,
  );

  /// 正文 14-16
  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: ZdColors.textPrimary,
    height: 1.5,
  );

  /// 辅助文字 12-13
  static const caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: ZdColors.textSecondary,
    height: 1.4,
  );

  /// 最小辅助
  static const tiny = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: ZdColors.textHint,
    height: 1.3,
  );
}

/// 响应式字号工具：按 375 基准等比缩放到当前屏幕宽
class ZdFontScaled {
  final BuildContext context;
  ZdFontScaled(this.context);

  double get _scale {
    final sw = MediaQuery.of(context).size.width;
    return (sw / 375).clamp(0.9, 1.25);
  }

  TextStyle headline() => ZdText.headline.copyWith(fontSize: 22 * _scale);
  TextStyle title() => ZdText.title.copyWith(fontSize: 18 * _scale);
  TextStyle subtitle() => ZdText.subtitle.copyWith(fontSize: 16 * _scale);
  TextStyle body() => ZdText.body.copyWith(fontSize: 15 * _scale);
  TextStyle caption() => ZdText.caption.copyWith(fontSize: 13 * _scale);
  TextStyle tiny() => ZdText.tiny.copyWith(fontSize: 12 * _scale);
}
