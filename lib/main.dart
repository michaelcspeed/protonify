import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pass_service.dart';
import 'setup_state.dart';
import 'screens/main_screen.dart';
import 'screens/setup_screen.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

void main() {
  runApp(
    const ProviderScope(
      child: ProtonifyApp(),
    ),
  );
}

class ProtonifyApp extends ConsumerWidget {
  const ProtonifyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Protonify',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const _AppShell(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final background = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final surface = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF);
    final surfaceVariant = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA);
    const accent = Color(0xFF6D4AFF);
    final onBackground = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    final onSurface = isDark ? const Color(0xFFEBEBF5) : const Color(0xFF1C1C1E);
    final subtle = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        error: const Color(0xFFFF3B30),
        onError: Colors.white,
        surface: surface,
        onSurface: onSurface,
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(
            color: onBackground, fontSize: 16, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(
            color: onSurface, fontSize: 14, fontWeight: FontWeight.w500),
        bodyMedium: TextStyle(color: onSurface, fontSize: 13),
        bodySmall: TextStyle(color: subtle, fontSize: 12),
        labelSmall:
            TextStyle(color: subtle, fontSize: 11, letterSpacing: 0.5),
      ),
      dividerColor: isDark ? Colors.white12 : Colors.black12,
      extensions: [
        ProtonifyColors(
          background: background,
          surface: surface,
          surfaceVariant: surfaceVariant,
          accent: accent,
          subtle: subtle,
          onSurface: onSurface,
        ),
      ],
    );
  }
}

class _AppShell extends ConsumerWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(setupProvider);
    if (status == SetupStatus.ready) {
      return const MainScreen();
    }
    return const SetupScreen();
  }
}

class ProtonifyColors extends ThemeExtension<ProtonifyColors> {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color accent;
  final Color subtle;
  final Color onSurface;

  const ProtonifyColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.accent,
    required this.subtle,
    required this.onSurface,
  });

  @override
  ProtonifyColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? accent,
    Color? subtle,
    Color? onSurface,
  }) =>
      ProtonifyColors(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceVariant: surfaceVariant ?? this.surfaceVariant,
        accent: accent ?? this.accent,
        subtle: subtle ?? this.subtle,
        onSurface: onSurface ?? this.onSurface,
      );

  @override
  ProtonifyColors lerp(ProtonifyColors? other, double t) => this;
}
