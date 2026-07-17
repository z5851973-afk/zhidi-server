import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tokens.dart';

/// 知底 App 全局主题
class ZdTheme {
  ZdTheme._();

  /// 必须在 main.dart 的 MaterialApp 中注入
  static ThemeData get light => ThemeData(
        // 颜色
        primaryColor: ZdColors.primary,
        scaffoldBackgroundColor: ZdColors.background,
        colorScheme: const ColorScheme.light(
          primary: ZdColors.primary,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: ZdColors.textPrimary,
        ),

        // AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: ZdColors.textPrimary,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: ZdColors.textPrimary,
          ),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),

        // 卡片
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZdRadius.card),
          ),
          margin: EdgeInsets.zero,
        ),

        // 底部导航
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: ZdColors.primary,
          unselectedItemColor: ZdColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),

        // 分割线
        dividerTheme: const DividerThemeData(
          color: ZdColors.divider,
          thickness: 0.5,
          space: 0,
        ),

        // 文本默认
        textTheme: const TextTheme(
          headlineLarge: ZdText.headline,
          titleLarge: ZdText.title,
          titleMedium: ZdText.subtitle,
          bodyLarge: ZdText.body,
          bodyMedium: ZdText.caption,
          bodySmall: ZdText.tiny,
        ),

        // 输入框
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: ZdColors.background,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: ZdSpacing.lg,
            vertical: ZdSpacing.md,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ZdRadius.md),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ZdRadius.md),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ZdRadius.md),
            borderSide: const BorderSide(color: ZdColors.primary, width: 1.5),
          ),
        ),
      );

  /// 全局状态栏样式
  static void setSystemUIOverlay() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  }
}
