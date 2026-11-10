import 'package:flutter/material.dart';

/// Couleurs de marque de l'appli.
abstract final class AppColors {
  /// Orange « énergie » : action principale (démarrer, tracé…).
  static const ember = Color(0xFFFF5A1F);
  static const emberDark = Color(0xFFFF7A45);

  /// Bleu nuit profond pour les fonds sombres et les cartes héros.
  static const night = Color(0xFF0E1320);
  static const nightSurface = Color(0xFF161C2C);
  static const nightHigh = Color(0xFF1F2638);

  /// Vert menthe : réussite, départ, records.
  static const mint = Color(0xFF16C79A);

  /// Violet électrique, couleur secondaire.
  static const volt = Color(0xFF6C5CE7);

  static const danger = Color(0xFFE5383B);
  static const gold = Color(0xFFFFB627);

  /// Dégradé utilisé pour les cartes « héros » (accueil, partage).
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF5A1F), Color(0xFFFF2E63)],
  );

  static const nightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B2236), Color(0xFF2A1A33)],
  );
}

/// Thème clair et sombre de l'appli (Material 3, police Outfit).
abstract final class AppTheme {
  static const fontFamily = 'Outfit';

  static ThemeData light() => _build(ColorScheme.fromSeed(
        seedColor: AppColors.ember,
        primary: AppColors.ember,
        onPrimary: Colors.white,
        secondary: AppColors.volt,
        tertiary: AppColors.mint,
        error: AppColors.danger,
        surface: const Color(0xFFFAF8F6),
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFF5F2EF),
        surfaceContainer: const Color(0xFFF0ECE8),
        surfaceContainerHigh: const Color(0xFFEAE5E0),
        surfaceContainerHighest: const Color(0xFFE3DDD7),
        onSurface: const Color(0xFF1A1C22),
        onSurfaceVariant: const Color(0xFF5B5F6B),
        outline: const Color(0xFF8A8E99),
        outlineVariant: const Color(0xFFDCD7D1),
      ));

  static ThemeData dark() => _build(ColorScheme.fromSeed(
        seedColor: AppColors.ember,
        brightness: Brightness.dark,
        primary: AppColors.emberDark,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFF5A2410),
        onPrimaryContainer: const Color(0xFFFFDBCC),
        secondary: const Color(0xFF9D92FF),
        tertiary: AppColors.mint,
        error: const Color(0xFFFF6B6E),
        surface: AppColors.night,
        surfaceContainerLowest: const Color(0xFF0A0E18),
        surfaceContainerLow: const Color(0xFF121827),
        surfaceContainer: AppColors.nightSurface,
        surfaceContainerHigh: AppColors.nightHigh,
        surfaceContainerHighest: const Color(0xFF283044),
        onSurface: const Color(0xFFECEEF4),
        onSurfaceVariant: const Color(0xFFA6ADBF),
        outline: const Color(0xFF7A8296),
        outlineVariant: const Color(0xFF2E3549),
      ));

  static ThemeData _build(ColorScheme c) {
    final base = ThemeData(useMaterial3: true, colorScheme: c, fontFamily: fontFamily);
    final t = base.textTheme;
    final text = t.copyWith(
      displayLarge: t.displayLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.5),
      displayMedium: t.displayMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
      displaySmall: t.displaySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineLarge: t.headlineLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2),
      labelMedium: t.labelMedium?.copyWith(fontWeight: FontWeight.w500, letterSpacing: 0.4),
      labelSmall: t.labelSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.8),
    );
    const radius = 20.0;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    const pill = StadiumBorder();
    const buttonPadding = EdgeInsets.symmetric(horizontal: 22, vertical: 14);

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: c.surface,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: c.onSurface, fontSize: 22, fontWeight: FontWeight.w800),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: shape,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: pill, padding: buttonPadding, textStyle: text.labelLarge),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: pill,
          padding: buttonPadding,
          textStyle: text.labelLarge,
          side: BorderSide(color: c.outlineVariant, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(shape: pill, padding: buttonPadding, textStyle: text.labelLarge),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: pill, textStyle: text.labelLarge),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 4,
        highlightElevation: 8,
        shape: pill,
        extendedTextStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.3),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 28),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: c.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.primary.withValues(alpha: 0.16),
        indicatorShape: pill,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? c.primary : c.onSurfaceVariant,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => text.labelMedium?.copyWith(
              color: s.contains(WidgetState.selected) ? c.primary : c.onSurfaceVariant,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            )),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceContainerHigh.withValues(alpha: 0.6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: pill,
        side: BorderSide(color: c.outlineVariant),
        labelStyle: text.labelLarge,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        iconColor: c.onSurfaceVariant,
        titleTextStyle: text.titleMedium?.copyWith(color: c.onSurface),
        subtitleTextStyle: text.bodyMedium?.copyWith(color: c.onSurfaceVariant),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: text.titleLarge?.copyWith(color: c.onSurface),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: c.brightness == Brightness.dark ? c.surfaceContainerHighest : AppColors.night,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: c.primary,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: c.outlineVariant, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary, linearTrackColor: c.surfaceContainerHighest),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : null),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: c.primary.withValues(alpha: 0.16),
          selectedForegroundColor: c.primary,
          side: BorderSide(color: c.outlineVariant),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w500),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),
    );
  }
}

/// Chiffres à chasse fixe : les compteurs ne « sautent » pas pendant la course.
const tabular = [FontFeature.tabularFigures()];
