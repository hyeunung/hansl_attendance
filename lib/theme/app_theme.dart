import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      surface: AppColors.backgroundPrimary,
      onSurface: AppColors.textPrimary,
      outline: AppColors.border,
    ),
    fontFamily: 'NotoSans',
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.backgroundPrimary,

    // ─── AppBar Theme (Apple 스타일: 화이트 배경) ───
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      // iconTheme 을 고정하지 않는다: 지정하면 화면별 foregroundColor(예: 검은 이미지
      // 뷰어의 흰 아이콘)를 덮어써 아이콘이 배경에 묻힌다. 기본은 foregroundColor를 따름.
      titleTextStyle: TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    ),

    // ─── Card Theme ───
    cardTheme: CardThemeData(
      color: AppColors.backgroundCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.borderLight, width: 0.5),
      ),
    ),

    // ─── Bottom Navigation ───
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.gray400,
    ),

    // ─── Divider ───
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 0.5,
      space: 0,
    ),

    // ─── Input ───
    // ─── Input (전역) ───
    // 채움을 끈다: 테두리 컨테이너로 감싼 입력칸마다 안쪽에 회색 박스가
    // 한 번 더 그려지던 '이중 박스' 문제의 근본 원인. 채움이 필요한 곳(검색창)은
    // 개별 위젯에서 filled: true 를 명시한다.
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      fillColor: Colors.white,
      isDense: true,
      hintStyle: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textDisabled,
      ),
      labelStyle: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 12,
        color: AppColors.textSecondary,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),

    // ─── 기본 본문 글자 (스타일 미지정 TextField 입력값·드롭다운 항목 등) ───
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontSize: 13, color: AppColors.textPrimary),
      bodyMedium: TextStyle(fontSize: 12, color: AppColors.textPrimary),
      titleMedium: TextStyle(fontSize: 13, color: AppColors.textPrimary),
    ),

    // ─── ElevatedButton ───
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        // 기본 터치영역 패딩(상하 8px 추가)을 제거해 버튼 높이를 여백대로 유지
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 36),
        visualDensity: VisualDensity.compact,
      ),
    ),

    // ─── TextButton ───
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 34),
        visualDensity: VisualDensity.compact,
      ),
    ),

    // ─── OutlinedButton ───
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 36),
        visualDensity: VisualDensity.compact,
      ),
    ),

    // ─── Dialog (AlertDialog 전역: 제목 18 / 본문 12, 여백 축소) ───
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      contentTextStyle: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.5,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    ),

    // ─── ListTile (사진 선택 시트 등): 행 높이 44, 제목 13, 아이콘 20 ───
    listTileTheme: const ListTileThemeData(
      dense: true,
      minTileHeight: 44,
      horizontalTitleGap: 12,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      iconColor: AppColors.textSecondary,
      titleTextStyle: TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 11,
        color: AppColors.textSecondary,
      ),
    ),

    // ─── Bottom Sheet (전역: 흰 배경, 상단 radius 10, 틴트 없음) ───
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
    ),

    // ─── FilledButton (ElevatedButton과 동일 규격) ───
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 36),
        visualDensity: VisualDensity.compact,
      ),
    ),

    // ─── IconButton (기본 48pt 터치영역 → 36pt, 아이콘 20) ───
    iconButtonTheme: IconButtonThemeData(
      // 전경색은 지정하지 않는다: AppBar·다크 뷰어 등 주변 IconTheme 색을 따르도록
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(8),
        minimumSize: const Size(36, 36),
        iconSize: 20,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),

    // ─── Date Picker (앱 전역 showDatePicker 공통 스타일) ───
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      headerBackgroundColor: Colors.white,
      headerForegroundColor: AppColors.textPrimary,
      headerHelpStyle: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
      headerHeadlineStyle: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      weekdayStyle: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
      dayStyle: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return AppColors.gray400;
        if (states.contains(WidgetState.selected)) return Colors.white;
        return AppColors.textPrimary;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return null;
      }),
      dayOverlayColor: WidgetStateProperty.all(
        AppColors.primary.withValues(alpha: 0.08),
      ),
      todayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return AppColors.primary;
      }),
      todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return null;
      }),
      todayBorder: const BorderSide(color: AppColors.primary, width: 1),
      yearStyle: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      yearForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return AppColors.gray400;
        if (states.contains(WidgetState.selected)) return Colors.white;
        return AppColors.textPrimary;
      }),
      yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return null;
      }),
      dividerColor: AppColors.borderLight,
      // 기간 선택(showDateRangePicker) 규격
      rangePickerBackgroundColor: Colors.white,
      rangePickerSurfaceTintColor: Colors.transparent,
      rangePickerElevation: 2,
      rangePickerShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      rangePickerHeaderBackgroundColor: Colors.white,
      rangePickerHeaderForegroundColor: AppColors.textPrimary,
      rangePickerHeaderHelpStyle: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
      rangePickerHeaderHeadlineStyle: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      rangeSelectionBackgroundColor: AppColors.primary.withValues(alpha: 0.12),
      rangeSelectionOverlayColor: WidgetStateProperty.all(
        AppColors.primary.withValues(alpha: 0.08),
      ),
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        textStyle: const TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 36),
        visualDensity: VisualDensity.compact,
      ),
      confirmButtonStyle: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 36),
        visualDensity: VisualDensity.compact,
      ),
    ),

    // ─── SnackBar ───
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.gray900,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );
}
