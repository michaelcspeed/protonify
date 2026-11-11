import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../pass_service.dart';
import '../setup_state.dart';
import '../theme.dart';
import 'ui.dart';

Future<void> showSettings(BuildContext context) =>
    showDialog(context: context, builder: (_) => const SettingsDialog());

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  bool _menuBarMode = false;
  bool _loading = true;
  bool? _sessionHasLock;
  bool _locking = false;
  final _svc = PassService();

  @override
  void initState() {
    super.initState();
    _loadSetting();
    _loadLockStatus();
  }

  Future<void> _loadSetting() async {
    try {
      final enabled = await windowApi.getMenuBarMode();
      if (mounted) setState(() { _menuBarMode = enabled; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadLockStatus() async {
    final info = await _svc.getSessionInfo();
    if (mounted) setState(() => _sessionHasLock = info?.hasLock);
  }

  Future<void> _lockNow() async {
    setState(() => _locking = true);
    try {
      await _svc.lockSession();
      if (mounted) {
        Navigator.of(context).pop();
        ref.read(setupProvider.notifier).check();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _locking = false);
        showToast(context, friendlyError(e), error: true);
      }
    }
  }

  Future<void> _toggleMenuBar(bool value) async {
    setState(() => _menuBarMode = value);
    try {
      await windowApi.setMenuBarMode(value);
    } catch (_) {
      if (mounted) setState(() => _menuBarMode = !value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final mode = ref.watch(themeModeProvider);
    final has = _sessionHasLock;

    return AppDialog(
      title: 'Settings',
      width: 420,
      actions: [AppButton(label: 'Done', onPressed: () => Navigator.of(context).pop())],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Group(children: [
            _Row(
              icon: Icons.contrast_rounded,
              title: 'Appearance',
              trailing: _Segmented<ThemeMode>(
                value: mode,
                options: const {
                  ThemeMode.system: 'System',
                  ThemeMode.light: 'Light',
                  ThemeMode.dark: 'Dark',
                },
                onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
              ),
            ),
            _Row(
              icon: Icons.menu_open_rounded,
              title: 'Menu bar mode',
              subtitle: 'Live in the menu bar instead of the Dock',
              trailing: _loading
                  ? SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: c.accent))
                  : Switch(value: _menuBarMode, onChanged: _toggleMenuBar),
            ),
          ]),
          const SizedBox(height: 12),
          _Group(children: [
            _Row(
              icon: Icons.lock_outline_rounded,
              title: 'Session lock',
              subtitle: has == null
                  ? 'Checking…'
                  : has
                      ? 'A lock code is set for this session.'
                      : 'No lock code set. Run `pass-cli session create-lock` in Terminal to add one.',
              trailing: has == true
                  ? AppButton(
                      label: 'Lock now',
                      dense: true,
                      loading: _locking,
                      onPressed: _lockNow,
                    )
                  : null,
            ),
          ]),
          const SizedBox(height: 16),
          const SectionLabel('Keyboard shortcuts'),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: const [
              _Shortcut('⌘F', 'Search'),
              _Shortcut('⌘N', 'New item'),
              _Shortcut('↑ ↓', 'Move through items'),
              _Shortcut('⇧⌘C', 'Copy password'),
              _Shortcut('⌘R', 'Refresh'),
              _Shortcut('⌃⌘S', 'Toggle sidebar'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.border, indent: 44),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const _Row({required this.icon, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.subtle),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, color: c.onSurface)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TextStyle(fontSize: 11.5, height: 1.35, color: c.subtle)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  const _Segmented({required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in options.entries)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => onChanged(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: e.key == value ? c.elevated : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: e.key == value
                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 3, offset: const Offset(0, 1))]
                        : null,
                  ),
                  child: Text(e.value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: e.key == value ? FontWeight.w600 : FontWeight.w400,
                        color: e.key == value ? c.onSurface : c.subtle,
                      )),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  final String keys;
  final String label;
  const _Shortcut(this.keys, this.label);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: 170,
      child: Row(children: [
        SizedBox(width: 44, child: Align(alignment: Alignment.centerLeft, child: KeyHint(keys))),
        Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: c.subtle))),
      ]),
    );
  }
}
