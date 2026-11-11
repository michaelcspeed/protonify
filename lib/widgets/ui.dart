// Shared building blocks so every screen looks and behaves the same.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../generated/window_api.g.dart';
import '../theme.dart';

final windowApi = WindowApi();

/// Height of pane headers; matches the macOS titlebar so traffic lights sit
/// vertically centred in it.
const double kHeaderHeight = 52;

/// Horizontal space reserved for the traffic-light buttons.
const double kTrafficLightInset = 78;

// ── Hover ───────────────────────────────────────────────────────────────────

class HoverBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovered) builder;
  final MouseCursor cursor;
  const HoverBuilder({super.key, required this.builder, this.cursor = MouseCursor.defer});

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: widget.cursor,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: widget.builder(context, _hovered),
      );
}

// ── Window drag region ──────────────────────────────────────────────────────

/// Lets the user drag the window by any empty part of [child].
class DragArea extends StatelessWidget {
  final Widget child;
  const DragArea({super.key, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => windowApi.startDrag().catchError((_) {}),
        child: child,
      );
}

/// A pane header bar: fixed height, bottom hairline, draggable.
class PaneHeader extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  final bool border;
  const PaneHeader({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.border = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DragArea(
      child: Container(
        height: kHeaderHeight,
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          border: border ? Border(bottom: BorderSide(color: c.border)) : null,
        ),
        child: child,
      ),
    );
  }
}

// ── Buttons ─────────────────────────────────────────────────────────────────

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final bool active;
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 18,
    this.color,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: HoverBuilder(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        builder: (context, hovered) => GestureDetector(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: active
                  ? c.accentSoft
                  : hovered && enabled
                      ? c.surfaceVariant
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              icon,
              size: size,
              color: !enabled
                  ? c.faint.withValues(alpha: 0.5)
                  : active
                      ? c.accentText
                      : color ?? (hovered ? c.onSurface : c.subtle),
            ),
          ),
        ),
      ),
    );
  }
}

enum AppButtonStyle { primary, secondary, danger, ghost }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final IconData? icon;
  final bool loading;
  final bool dense;
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = AppButtonStyle.secondary,
    this.icon,
    this.loading = false,
    this.dense = false,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.dense = false,
  }) : style = AppButtonStyle.primary;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final enabled = onPressed != null && !loading;
    final (Color bg, Color bgHover, Color fg, Color? borderColor) = switch (style) {
      AppButtonStyle.primary => (c.accent, Color.lerp(c.accent, Colors.white, 0.1)!, Colors.white, null),
      AppButtonStyle.danger => (c.danger, Color.lerp(c.danger, Colors.white, 0.1)!, Colors.white, null),
      AppButtonStyle.secondary => (c.surfaceVariant.withValues(alpha: 0.6), c.surfaceVariant, c.onSurface, c.border),
      AppButtonStyle.ghost => (Colors.transparent, c.surfaceVariant, c.onSurface, null),
    };
    return HoverBuilder(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      builder: (context, hovered) => GestureDetector(
        onTap: enabled ? onPressed : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: enabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            height: dense ? 28 : 32,
            padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 14),
            decoration: BoxDecoration(
              color: hovered && enabled ? bgHover : bg,
              borderRadius: BorderRadius.circular(8),
              border: borderColor != null ? Border.all(color: borderColor) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.6, color: fg),
                    ),
                  )
                else if (icon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(icon, size: 15, color: fg),
                  ),
                Text(label,
                    style: TextStyle(
                      fontSize: dense ? 12 : 13,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Item type chip ──────────────────────────────────────────────────────────

class KindChip extends StatelessWidget {
  final ItemKind kind;
  final double size;
  const KindChip({super.key, required this.kind, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: kind.tint(context),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(kind.icon, size: size * 0.5, color: kind.glyph(context)),
    );
  }
}

// ── Text bits ───────────────────────────────────────────────────────────────

class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  final EdgeInsets padding;
  const SectionLabel(this.text,
      {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(4, 0, 4, 8)});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.faint,
                  letterSpacing: 0.2,
                )),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Keyboard shortcut hint, e.g. `⌘N`.
class KeyHint extends StatelessWidget {
  final String keys;
  const KeyHint(this.keys, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.border),
      ),
      child: Text(keys, style: TextStyle(fontSize: 10.5, color: c.faint)),
    );
  }
}

// ── Dialogs ─────────────────────────────────────────────────────────────────

class AppDialog extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? leading;
  final Widget? child;
  final List<Widget> actions;
  final double width;
  const AppDialog({
    super.key,
    required this.title,
    this.message,
    this.leading,
    this.child,
    this.actions = const [],
    this.width = 380,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final maxW = MediaQuery.sizeOf(context).width - 48;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width.clamp(240, maxW)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (leading != null) ...[leading!, const SizedBox(width: 10)],
                Expanded(
                  child: Text(title,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.onSurface)),
                ),
              ]),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(message!, style: TextStyle(fontSize: 13, height: 1.45, color: c.subtle)),
              ],
              if (child != null) ...[const SizedBox(height: 16), child!],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      actions[i],
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): () => Navigator.pop(ctx, true),
      },
      child: Focus(
        autofocus: true,
        child: AppDialog(
          title: title,
          message: message,
          actions: [
            AppButton(label: 'Cancel', onPressed: () => Navigator.pop(ctx, false)),
            AppButton(
              label: confirmLabel,
              style: destructive ? AppButtonStyle.danger : AppButtonStyle.primary,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    ),
  );
  return ok == true;
}

// ── Toasts ──────────────────────────────────────────────────────────────────

OverlayEntry? _toastEntry;
Timer? _toastTimer;

void showToast(BuildContext context, String message,
    {IconData icon = Icons.check_circle_rounded,
    bool error = false,
    String? actionLabel,
    VoidCallback? onAction}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final c = context.c;
  _toastTimer?.cancel();
  _toastEntry?.remove();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: 16,
      right: 16,
      bottom: 20,
      child: IgnorePointer(
        ignoring: onAction == null,
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            builder: (_, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: c.elevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(error ? Icons.error_outline_rounded : icon,
                        size: 16, color: error ? c.danger : c.success),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(message,
                          style: TextStyle(fontSize: 12.5, color: c.onSurface),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(width: 12),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            _toastTimer?.cancel();
                            _toastEntry?.remove();
                            _toastEntry = null;
                            onAction();
                          },
                          child: Text(actionLabel,
                              style: TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w600, color: c.accentText)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  _toastEntry = entry;
  overlay.insert(entry);
  _toastTimer = Timer(Duration(milliseconds: error || onAction != null ? 5000 : 2200), () {
    if (_toastEntry == entry) {
      entry.remove();
      _toastEntry = null;
    }
  });
}

String friendlyError(Object e) =>
    e.toString().replaceFirst(RegExp(r'^(Exception|StateError|Bad state): ?'), '');

// ── Clipboard ───────────────────────────────────────────────────────────────

Timer? _clipboardClearTimer;
const _kClipboardClearAfter = Duration(seconds: 60);

/// Copies [value]; for secrets, clears the clipboard after a minute if it
/// still holds the same value (so we never wipe something the user copied
/// afterwards).
Future<void> copyToClipboard(BuildContext context, String value,
    {required String label, bool secret = false}) async {
  await Clipboard.setData(ClipboardData(text: value));
  _clipboardClearTimer?.cancel();
  if (secret) {
    _clipboardClearTimer = Timer(_kClipboardClearAfter, () async {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current?.text == value) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }
  if (context.mounted) {
    showToast(
      context,
      secret ? '$label copied · clears in ${_kClipboardClearAfter.inSeconds}s' : '$label copied',
      icon: Icons.content_copy_rounded,
    );
  }
}
