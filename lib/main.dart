import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pass_service.dart';
import 'setup_state.dart';
import 'theme.dart';
import 'screens/main_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/unlock_screen.dart';

// Re-exported so existing `import '../main.dart'` keeps working for colours.
export 'theme.dart' show ProtonifyColors, ProtonifyColorsX, themeModeProvider, kindOf, ItemKind;

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
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const _AppShell(),
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
    if (status == SetupStatus.locked) {
      return const UnlockScreen();
    }
    return const SetupScreen();
  }
}
