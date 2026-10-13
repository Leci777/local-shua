import 'package:flutter/material.dart';

/// 深色沉浸主题。规范来自 docs/UI-DESIGN.md：
/// 视频是主角，UI 默认隐藏；深色下用表面明度分层，不堆阴影。
/// 改颜色/字阶/圆角只改这一个文件。
class AppTheme {
  AppTheme._();

  // ===== 色彩 =====
  static const Color surface = Color(0xFF0B0B0F);
  static const Color surfaceContainer = Color(0xFF14141A);
  static const Color surfaceContainerHigh = Color(0xFF1F1F28);
  static const Color onSurface = Color(0xFFF2F2F7);
  static const Color onSurfaceVariant = Color(0xFFA6A6B3);

  /// 主色：播放焦点、主按钮、进度已播放
  static const Color primary = Color(0xFFFF4D6D);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF3A1622);

  /// 次色：下载中状态
  static const Color secondary = Color(0xFF5BD3C8);

  /// 第三色：收藏激活
  static const Color tertiary = Color(0xFFFFC757);

  static const Color error = Color(0xFFFF6B6B);
  static const Color outline = Color(0xFF3A3A44);
  static const Color outlineVariant = Color(0xFF26262F);

  // ===== 圆角 =====
  static const double radiusButton = 12;
  static const double radiusCard = 16;
  static const double radiusDialog = 20;

  // ===== 动效 =====
  static const Duration motionFast = Duration(milliseconds: 150); // 控制层显隐
  static const Duration motionStandard = Duration(milliseconds: 200); // 微交互
  static const Duration motionPage = Duration(milliseconds: 250); // 页面转场
  static const Curve easeStandard = Curves.fastOutSlowIn; // 对应 CSS cubic-bezier(0.2,0,0,1) 的近似

  // 触控热区下限（Apple HIG / Material 都认 48）
  static const double minTouchTarget = 48;

  static ThemeData get dark {
    final colorScheme = const ColorScheme.dark(
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceContainerHigh,
      onSurfaceVariant: onSurfaceVariant,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: primary,
      secondary: secondary,
      tertiary: tertiary,
      error: error,
      outline: outline,
      outlineVariant: outlineVariant,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      fontFamily: null, // 用系统字体（ColorOS 上中文渲染够好），不打包字体省 APK
    );

    return base.copyWith(
      // 深色下阴影基本不用，层级靠 surface 明度；只给对话框一点 elevation
      dialogTheme: const DialogThemeData(
        backgroundColor: surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusDialog)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusDialog)),
        ),
      ),
      cardTheme: const CardThemeData(
        color: surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: outlineVariant, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceContainerHigh,
        contentTextStyle: const TextStyle(color: onSurface, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: onSurfaceVariant,
        textColor: onSurface,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return onPrimary;
          return onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return outline;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: outlineVariant,
      ),
      textTheme: _textTheme,
      // 主按钮：48 高、12 圆角、600 字重
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(minTouchTarget - 4),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: secondary,
          minimumSize: const Size(minTouchTarget, minTouchTarget - 12),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size.fromHeight(minTouchTarget - 8),
          side: const BorderSide(color: outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerHigh,
        hintStyle: const TextStyle(color: Color(0xFF6E6E7A), fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
    );
  }

  // ===== 字阶（UI-DESIGN §2.2）=====
  static const TextTheme _textTheme = TextTheme(
    displaySmall: TextStyle(fontSize: 36, height: 1.15, fontWeight: FontWeight.w600, color: onSurface),
    headlineSmall: TextStyle(fontSize: 24, height: 1.25, fontWeight: FontWeight.w600, color: onSurface),
    titleLarge: TextStyle(fontSize: 20, height: 1.3, fontWeight: FontWeight.w600, color: onSurface),
    titleMedium: TextStyle(fontSize: 16, height: 1.45, fontWeight: FontWeight.w500, color: onSurface),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w400, color: onSurface),
    bodyMedium: TextStyle(fontSize: 14, height: 1.45, fontWeight: FontWeight.w400, color: onSurfaceVariant),
    labelLarge: TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w600, color: onSurface),
    labelMedium: TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w500, color: onSurfaceVariant),
    labelSmall: TextStyle(fontSize: 11, height: 1.4, fontWeight: FontWeight.w500, color: onSurfaceVariant),
  );
}

/// 时长格式化：不足 1 小时 mm:ss，以上 h:mm:ss（与 intl 口径一致）
String formatDuration(double? seconds) {
  if (seconds == null || seconds <= 0) return '--:--';
  final total = seconds.round();
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final secs = total % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = secs.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}
