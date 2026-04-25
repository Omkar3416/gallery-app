import 'package:flutter/material.dart';

class AppTheme {
  static const Color _defaultSeed = Color(0xFF6750A4); // playful purple

  // Common component styling (extracted for both light/dark)
  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,

      // AppBar: neat, modern; tint off so color is literal
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 3,
        shadowColor: scheme.shadow.withOpacity(.2),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
      ),

      // Cards (your grids use Card → they pick this up)
      cardTheme: CardThemeData(
        elevation: 2,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        surfaceTintColor: Colors.transparent,
        shadowColor: scheme.shadow.withOpacity(.18),
      ),

      // Lists (ListTile look professional & consistent)
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: scheme.surfaceVariant.withOpacity(.30),
        selectedTileColor: scheme.primaryContainer.withOpacity(.55),
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            // hello
      ),

      // Bottom sheets (capture sheet etc.)
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface.withOpacity(.95),
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surface.withOpacity(.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        showDragHandle: true,
      ),

      // Navigation Bar (if you use Material 3 NavigationBar anywhere)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: MaterialStateProperty.all(
          TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface),
        ),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          foregroundColor: scheme.onPrimary,
          backgroundColor: scheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          foregroundColor: scheme.onPrimaryContainer,
          backgroundColor: scheme.primaryContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      // Chips (tags/search filters)
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        shape: const StadiumBorder(),
        selectedColor: scheme.primaryContainer,
        secondarySelectedColor: scheme.secondaryContainer,
        labelStyle: TextStyle(color: scheme.onSurface),
        secondaryLabelStyle: TextStyle(color: scheme.onSecondaryContainer),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        showCheckmark: false,
      ),

      // Inputs / Search
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceVariant.withOpacity(.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),

      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
    );
  }

  /// Light theme — pass a seed or omit to use default.
  static ThemeData light([Color? seed]) {
    final c = seed ?? _defaultSeed;
    final scheme = ColorScheme.fromSeed(
      seedColor: c,
      brightness: Brightness.light,
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: scheme.surface,
    );
  }

  /// Dark theme — pass a seed or omit to use default.
  static ThemeData dark([Color? seed]) {
    final c = seed ?? _defaultSeed;
    final scheme = ColorScheme.fromSeed(
      seedColor: c,
      brightness: Brightness.dark,
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: scheme.surface,
    );
  }
}
