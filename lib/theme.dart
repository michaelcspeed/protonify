import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

// ── Theme mode (persisted) ──────────────────────────────────────────────────

const _kThemePrefKey = 'ui.themeMode';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier([super.initial = ThemeMode.system]) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kThemePrefKey);
      final mode = ThemeMode.values.where((m) => m.name == saved).firstOrNull;
      if (mode != null && mounted) state = mode;
    } catch (_) {}
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemePrefKey, mode.name);
    } catch (_) {}
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ThemeModeNotifier());

// ── Colour tokens ───────────────────────────────────────────────────────────

/// Semantic colour tokens. Widgets read these via
/// `Theme.of(context).extension<ProtonifyColors>()!` (or `context.c`).
class ProtonifyColors extends ThemeExtension<ProtonifyColors> {
  /// Main canvas (detail pane).
  final Color background;

  /// Sidebar canvas.
  final Color sidebar;

  /// List pane canvas, cards.
  final Color surface;

  /// Inputs, hover fills, tracks.
  final Color surfaceVariant;

  /// Dialogs, popovers, menus.
  final Color elevated;

  /// Hairlines between panes and around cards.
  final Color border;

  final Color accent;

  /// Accent tint for selected rows and soft buttons.
  final Color accentSoft;

  /// Accent used for text/icons on [accentSoft] (higher contrast).
  final Color accentText;

  /// Primary text.
  final Color onSurface;

  /// Secondary text, icons.
  final Color subtle;

  /// Tertiary text: counts, placeholders, metadata.
  final Color faint;

  final Color danger;
  final Color success;
  final Color warning;

  const ProtonifyColors({
    required this.background,
    required this.sidebar,
    required this.surface,
    required this.surfaceVariant,
    required this.elevated,
    required this.border,
    required this.accent,
    required this.accentSoft,
    required this.accentText,
    required this.onSurface,
    required this.subtle,
    required this.faint,
    required this.danger,
    required this.success,
    required this.warning,
  });

  static const dark = ProtonifyColors(
    background: Color(0xFF16161B),
    sidebar: Color(0xFF1B1B21),
    surface: Color(0xFF1E1E25),
    surfaceVariant: Color(0xFF2A2A33),
    elevated: Color(0xFF25252D),
    border: Color(0xFF2E2E38),
    accent: Color(0xFF7C66FF),
    accentSoft: Color(0x2E7C66FF),
    accentText: Color(0xFFB4A8FF),
    onSurface: Color(0xFFEDEDF3),
    subtle: Color(0xFFA3A3B3),
    faint: Color(0xFF6F6F80),
    danger: Color(0xFFFF6B7D),
    success: Color(0xFF3FD18F),
    warning: Color(0xFFFFB74D),
  );

  static const light = ProtonifyColors(
    background: Color(0xFFFFFFFF),
    sidebar: Color(0xFFF3F2F7),
    surface: Color(0xFFFAFAFC),
    surfaceVariant: Color(0xFFEDECF2),
    elevated: Color(0xFFFFFFFF),
    border: Color(0xFFE3E2EA),
    accent: Color(0xFF6D4AFF),
    accentSoft: Color(0x1F6D4AFF),
    accentText: Color(0xFF5634E0),
    onSurface: Color(0xFF17171F),
    subtle: Color(0xFF5F5E6E),
    faint: Color(0xFF9897A6),
    danger: Color(0xFFD92D45),
    success: Color(0xFF168A55),
    warning: Color(0xFFB86E00),
  );

  @override
  ProtonifyColors copyWith() => this;

  @override
  ProtonifyColors lerp(ProtonifyColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return ProtonifyColors(
      background: l(background, other.background),
      sidebar: l(sidebar, other.sidebar),
      surface: l(surface, other.surface),
      surfaceVariant: l(surfaceVariant, other.surfaceVariant),
      elevated: l(elevated, other.elevated),
      border: l(border, other.border),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      accentText: l(accentText, other.accentText),
      onSurface: l(onSurface, other.onSurface),
      subtle: l(subtle, other.subtle),
      faint: l(faint, other.faint),
      danger: l(danger, other.danger),
      success: l(success, other.success),
      warning: l(warning, other.warning),
    );
  }
}

extension ProtonifyColorsX on BuildContext {
  ProtonifyColors get c => Theme.of(this).extension<ProtonifyColors>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// ── Item kinds ──────────────────────────────────────────────────────────────

/// Icon, colour and labels for each item type, so every screen agrees.
class ItemKind {
  final String label; // singular, e.g. "Login"
  final String plural; // e.g. "Logins"
  final IconData icon;
  final Color color;
  const ItemKind(this.label, this.plural, this.icon, this.color);

  /// Low-saturation tint used behind the icon glyph.
  Color tint(BuildContext context) =>
      color.withValues(alpha: context.isDark ? 0.18 : 0.13);

  /// Glyph colour; slightly deeper in light mode for contrast.
  Color glyph(BuildContext context) => context.isDark
      ? Color.lerp(color, Colors.white, 0.15)!
      : Color.lerp(color, Colors.black, 0.18)!;
}

const _kinds = <ItemType, ItemKind>{
  ItemType.login: ItemKind('Login', 'Logins', Icons.language_rounded, Color(0xFF7C8CFF)),
  ItemType.alias: ItemKind('Alias', 'Aliases', Icons.alternate_email_rounded, Color(0xFF3FB6D3)),
  ItemType.creditCard: ItemKind('Card', 'Cards', Icons.credit_card_rounded, Color(0xFF3DB57E)),
  ItemType.identity: ItemKind('Identity', 'Identities', Icons.badge_outlined, Color(0xFFE77C9E)),
  ItemType.note: ItemKind('Note', 'Notes', Icons.sticky_note_2_outlined, Color(0xFFE0A23F)),
  ItemType.wifi: ItemKind('Wi-Fi', 'Wi-Fi', Icons.wifi_rounded, Color(0xFF4E9FE6)),
  ItemType.sshKey: ItemKind('SSH key', 'SSH keys', Icons.key_rounded, Color(0xFFAE8AF0)),
};

const _fallbackKind =
    ItemKind('Item', 'Items', Icons.description_outlined, Color(0xFF9A9AAA));

ItemKind kindOf(ItemType? t) => _kinds[t] ?? _fallbackKind;

// ── ThemeData ───────────────────────────────────────────────────────────────

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final c = isDark ? ProtonifyColors.dark : ProtonifyColors.light;

  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    visualDensity: VisualDensity.compact,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: c.surfaceVariant.withValues(alpha: 0.6),
    focusColor: c.accentSoft,
    scaffoldBackgroundColor: c.background,
    canvasColor: c.background,
    dividerColor: c.border,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: Colors.white,
      secondary: c.accent,
      onSecondary: Colors.white,
      error: c.danger,
      onError: Colors.white,
      surface: c.elevated,
      onSurface: c.onSurface,
      surfaceContainerHighest: c.surfaceVariant,
      outline: c.border,
      outlineVariant: c.border,
    ),
  );

  final text = base.textTheme.apply(bodyColor: c.onSurface, displayColor: c.onSurface);

  OutlineInputBorder ob(Color color, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: w),
      );

  return base.copyWith(
    textTheme: text.copyWith(
      titleLarge: text.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: text.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      titleSmall: text.titleSmall?.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 14),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 13),
      bodySmall: text.bodySmall?.copyWith(fontSize: 12, color: c.subtle),
      labelSmall: text.labelSmall?.copyWith(fontSize: 11, color: c.faint, fontWeight: FontWeight.w600),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accent,
      selectionColor: c.accent.withValues(alpha: 0.35),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceVariant.withValues(alpha: isDark ? 0.7 : 0.8),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      hintStyle: TextStyle(fontSize: 13, color: c.faint),
      border: ob(Colors.transparent),
      enabledBorder: ob(Colors.transparent),
      focusedBorder: ob(c.accent, 1.5),
      errorBorder: ob(c.danger),
      focusedErrorBorder: ob(c.danger, 1.5),
      errorStyle: TextStyle(fontSize: 11, color: c.danger),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.elevated,
      surfaceTintColor: Colors.transparent,
      elevation: 24,
      shadowColor: Colors.black.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.border),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.elevated,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.border),
      ),
      textStyle: TextStyle(fontSize: 13, color: c.onSurface),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(c.elevated),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: c.border),
        )),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      textStyle: TextStyle(fontSize: 11, color: isDark ? Colors.black : Colors.white),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFFE8E8EE) : const Color(0xFF25252D),
        borderRadius: BorderRadius.circular(6),
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
      thumbColor: WidgetStatePropertyAll(c.subtle.withValues(alpha: 0.35)),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.surfaceVariant),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : Colors.transparent),
      side: BorderSide(color: c.faint, width: 1.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 3,
      activeTrackColor: c.accent,
      inactiveTrackColor: c.surfaceVariant,
      thumbColor: Colors.white,
      overlayShape: SliderComponentShape.noOverlay,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7, elevation: 2),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
    iconTheme: IconThemeData(color: c.subtle, size: 18),
    extensions: [c],
  );
}
