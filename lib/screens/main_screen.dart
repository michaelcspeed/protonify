import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_state.dart';
import '../generated/window_api.g.dart';
import '../main.dart';
import '../widgets/vault_sidebar.dart';
import '../widgets/item_list.dart';
import '../widgets/item_detail.dart';

const double _kSidebarMin = 140;
const double _kSidebarMax = 360;
const double _kSidebarDefault = 220;
const double _kListMin = 200;
const double _kListMax = 480;
const double _kListDefault = 280;
const String _kSidebarPrefKey = 'pane.sidebarWidth';
const String _kListPrefKey = 'pane.listWidth';

final _windowApi = WindowApi();

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  double _sidebarWidth = _kSidebarDefault;
  double _listWidth = _kListDefault;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(appStateProvider.notifier).loadVaults());
    _loadWidths();
  }

  Future<void> _loadWidths() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _sidebarWidth = (prefs.getDouble(_kSidebarPrefKey) ?? _kSidebarDefault)
          .clamp(_kSidebarMin, _kSidebarMax);
      _listWidth = (prefs.getDouble(_kListPrefKey) ?? _kListDefault)
          .clamp(_kListMin, _kListMax);
    });
  }

  void _setSidebar(double w) {
    final clamped = w.clamp(_kSidebarMin, _kSidebarMax);
    setState(() => _sidebarWidth = clamped);
    _prefs?.setDouble(_kSidebarPrefKey, clamped);
  }

  void _setList(double w) {
    final clamped = w.clamp(_kListMin, _kListMax);
    setState(() => _listWidth = clamped);
    _prefs?.setDouble(_kListPrefKey, clamped);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ProtonifyColors>()!;
    return Scaffold(
      body: Column(
        children: [
          const _TopSearchBar(),
          Expanded(
            child: Row(
              children: [
                SizedBox(width: _sidebarWidth, child: const VaultSidebar()),
                _PaneDivider(
                  c: c,
                  onDrag: (dx) => _setSidebar(_sidebarWidth + dx),
                ),
                SizedBox(width: _listWidth, child: const ItemListPane()),
                _PaneDivider(
                  c: c,
                  onDrag: (dx) => _setList(_listWidth + dx),
                ),
                const Expanded(child: ItemDetailPane()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaneDivider extends StatefulWidget {
  final ProtonifyColors c;
  final void Function(double dx) onDrag;
  const _PaneDivider({required this.c, required this.onDrag});

  @override
  State<_PaneDivider> createState() => _PaneDividerState();
}

class _PaneDividerState extends State<_PaneDivider> {
  bool _hovered = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragEnd: (_) => setState(() => _dragging = false),
        onHorizontalDragCancel: () => setState(() => _dragging = false),
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        child: SizedBox(
          width: 6,
          child: Center(
            child: Container(
              width: 1,
              color: active
                  ? widget.c.accent.withValues(alpha: 0.5)
                  : widget.c.subtle.withValues(alpha: 0.15),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopSearchBar extends ConsumerWidget {
  const _TopSearchBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<ProtonifyColors>()!;
    return GestureDetector(
      onPanStart: (_) => _windowApi.startDrag(),
      child: Container(
      color: c.surface,
      padding: const EdgeInsets.fromLTRB(80, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: ref.read(appStateProvider.notifier).setSearch,
              style: TextStyle(fontSize: 13, color: c.onSurface),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(color: c.subtle, fontSize: 13),
                prefixIcon: Icon(Icons.search, size: 16, color: c.subtle),
                filled: true,
                fillColor: c.surfaceVariant,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: c.accent.withValues(alpha: 0.6), width: 1),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SettingsButton(c: c),
        ],
      ),
    ));
  }
}

class _SettingsButton extends StatelessWidget {
  final ProtonifyColors c;
  const _SettingsButton({required this.c});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.settings_outlined, size: 17, color: c.subtle),
      tooltip: 'Settings',
      onPressed: () => showDialog(
        context: context,
        builder: (_) => _SettingsDialog(c: c),
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}

class _SettingsDialog extends ConsumerStatefulWidget {
  final ProtonifyColors c;
  const _SettingsDialog({required this.c});

  @override
  ConsumerState<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<_SettingsDialog> {
  bool _menuBarMode = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    try {
      final enabled = await _windowApi.getMenuBarMode();
      if (mounted) setState(() { _menuBarMode = enabled; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(bool value) async {
    setState(() => _menuBarMode = value);
    try {
      await _windowApi.setMenuBarMode(value);
    } catch (_) {
      if (mounted) setState(() => _menuBarMode = !value);
    }
  }

  Widget _buildAppearanceRow(ProtonifyColors c) {
    final mode = ref.watch(themeModeProvider);
    final isDark = mode == ThemeMode.dark;
    return Row(
      children: [
        Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined, size: 18, color: c.subtle),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dark mode',
                  style: TextStyle(fontSize: 13, color: c.onSurface)),
              Text('Switch between light and dark theme',
                  style: TextStyle(fontSize: 11, color: c.subtle)),
            ],
          ),
        ),
        Switch.adaptive(
          value: isDark,
          onChanged: (value) {
            ref.read(themeModeProvider.notifier).state =
                value ? ThemeMode.dark : ThemeMode.light;
          },
          activeTrackColor: c.accent,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;

    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 340,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.onSurface)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.dock_outlined, size: 18, color: c.subtle),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Menu bar mode',
                            style: TextStyle(fontSize: 13, color: c.onSurface)),
                        Text('Show in menu bar instead of Dock',
                            style: TextStyle(fontSize: 11, color: c.subtle)),
                      ],
                    ),
                  ),
                  if (_loading)
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent))
                  else
                    Switch.adaptive(
                      value: _menuBarMode,
                      onChanged: _toggle,
                      activeTrackColor: c.accent,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: c.subtle.withValues(alpha: 0.15)),
              const SizedBox(height: 12),
              _buildAppearanceRow(c),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: c.subtle.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Done', style: TextStyle(fontSize: 13, color: c.onSurface)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
