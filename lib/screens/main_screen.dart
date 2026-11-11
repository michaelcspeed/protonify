import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_state.dart';
import '../theme.dart';
import '../ui_state.dart';
import '../widgets/item_detail.dart';
import '../widgets/item_list.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/vault_sidebar.dart';

// Layout breakpoints (logical px of window width).
const double _kWideMin = 960; // sidebar can sit inline
const double _kSplitMin = 620; // list + detail side by side

const double _kSidebarMin = 180;
const double _kSidebarMax = 320;
const double _kSidebarDefault = 220;
const double _kListMin = 240;
const double _kListMax = 460;
const double _kListDefault = 300;
const double _kDetailMin = 340;
const double _kOverlaySidebarWidth = 260;

const String _kSidebarPrefKey = 'pane.sidebarWidth';
const String _kListPrefKey = 'pane.listWidth';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  double _sidebarWidth = _kSidebarDefault;
  double _listWidth = _kListDefault;
  SharedPreferences? _prefs;

  // Current layout, refreshed on every build; used by shortcut handlers.
  bool _sidebarInlineAvailable = true;
  bool _single = false;

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

  void _setList(double w, double maxAllowed) {
    final clamped = w.clamp(_kListMin, maxAllowed.clamp(_kListMin, _kListMax));
    setState(() => _listWidth = clamped);
    _prefs?.setDouble(_kListPrefKey, clamped);
  }

  // ── Actions ────────────────────────────────────────────────────────────

  void _showSidebar() {
    if (_sidebarInlineAvailable) {
      ref.read(sidebarPinnedProvider.notifier).set(true);
    } else {
      ref.read(sidebarOverlayProvider.notifier).state = true;
    }
  }

  void _hideSidebar() {
    if (ref.read(sidebarOverlayProvider)) {
      ref.read(sidebarOverlayProvider.notifier).state = false;
    } else {
      ref.read(sidebarPinnedProvider.notifier).set(false);
    }
  }

  void _toggleSidebar() {
    final visible = ref.read(sidebarOverlayProvider) ||
        (_sidebarInlineAvailable && ref.read(sidebarPinnedProvider));
    visible ? _hideSidebar() : _showSidebar();
  }

  void _back() => ref.read(appStateProvider.notifier).selectItem(null);

  void _focusSearch() {
    if (_single) _back();
    ref.read(sidebarOverlayProvider.notifier).state = false;
    final node = ref.read(searchFocusProvider);
    // Wait a frame in case the list pane is being (re)built.
    WidgetsBinding.instance.addPostFrameCallback((_) => node.requestFocus());
  }

  void _onEscape() {
    if (ref.read(sidebarOverlayProvider)) {
      ref.read(sidebarOverlayProvider.notifier).state = false;
    } else if (_single && ref.read(appStateProvider).selectedItem != null) {
      _back();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pinned = ref.watch(sidebarPinnedProvider);
    final overlayOpen = ref.watch(sidebarOverlayProvider);
    final hasSelection = ref.watch(appStateProvider.select((s) => s.selectedItem != null));

    // Close the floating sidebar once the user picks a category/folder.
    ref.listen(
      appStateProvider.select((s) => (s.selectedCategory, s.selectedFolderId)),
      (_, _) {
        if (ref.read(sidebarOverlayProvider)) {
          ref.read(sidebarOverlayProvider.notifier).state = false;
        }
      },
    );

    return Scaffold(
      backgroundColor: c.background,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _focusSearch,
          const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () => openNewItem(context, ref),
          const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () =>
              ref.read(appStateProvider.notifier).loadVaults(),
          const SingleActivator(LogicalKeyboardKey.comma, meta: true): () => showSettings(context),
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true, control: true): _toggleSidebar,
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => moveSelection(ref, 1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => moveSelection(ref, -1),
          const SingleActivator(LogicalKeyboardKey.escape): _onEscape,
          const SingleActivator(LogicalKeyboardKey.keyC, meta: true, shift: true): () =>
              copySelectedPassword(context, ref),
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            _sidebarInlineAvailable = w >= _kWideMin;
            _single = w < _kSplitMin;
            final sidebarInline = _sidebarInlineAvailable && pinned;

            final Widget content;
            if (_single) {
              // One pane at a time: list, or the selected item.
              content = hasSelection
                  ? ItemDetailPane(leadingInset: true, onBack: _back)
                  : ItemListPane(leadingInset: true, onShowSidebar: _showSidebar);
            } else {
              final sidebarW = sidebarInline ? _sidebarWidth : 0.0;
              final maxList = w - sidebarW - _kDetailMin - 2;
              final listW = _listWidth.clamp(_kListMin, maxList.clamp(_kListMin, _kListMax));
              final divider = Container(width: 1, color: c.border);
              content = Stack(
                children: [
                  Positioned.fill(
                    child: Row(
                      children: [
                        if (sidebarInline) ...[
                          SizedBox(width: sidebarW, child: VaultSidebar(onHide: _hideSidebar)),
                          divider,
                        ],
                        SizedBox(
                          width: listW,
                          child: ItemListPane(
                            leadingInset: !sidebarInline,
                            onShowSidebar: sidebarInline ? null : _showSidebar,
                          ),
                        ),
                        divider,
                        const Expanded(child: ItemDetailPane()),
                      ],
                    ),
                  ),
                  if (sidebarInline)
                    _ResizeHandle(
                      x: sidebarW,
                      onDrag: (dx) => _setSidebar(_sidebarWidth + dx),
                    ),
                  _ResizeHandle(
                    x: sidebarW + (sidebarInline ? 1 : 0) + listW,
                    onDrag: (dx) => _setList(listW + dx, maxList),
                  ),
                ],
              );
            }

            return Stack(
              children: [
                Positioned.fill(child: content),
                // Floating sidebar for narrow windows / unpinned.
                if (overlayOpen && !sidebarInline) ...[
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _hideSidebar,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 160),
                        builder: (_, t, _) => ColoredBox(
                          color: Colors.black.withValues(alpha: 0.32 * t),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: _kOverlaySidebarWidth.clamp(0, w - 48),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: -1, end: 0),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      builder: (_, t, child) => FractionalTranslation(
                        translation: Offset(t, 0),
                        child: child,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: VaultSidebar(onHide: _hideSidebar),
                      ),
                    ),
                  ),
                ],
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Invisible drag strip centred on a pane boundary at [x]; highlights the
/// boundary while hovered or dragged.
class _ResizeHandle extends StatefulWidget {
  final double x;
  final void Function(double dx) onDrag;
  const _ResizeHandle({required this.x, required this.onDrag});

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _hovered = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final active = _hovered || _dragging;
    return Positioned(
      left: widget.x - 4,
      top: 0,
      bottom: 0,
      width: 9,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) => setState(() => _dragging = true),
          onHorizontalDragEnd: (_) => setState(() => _dragging = false),
          onHorizontalDragCancel: () => setState(() => _dragging = false),
          onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: active ? 2 : 0,
              color: c.accent.withValues(alpha: active ? 0.6 : 0),
            ),
          ),
        ),
      ),
    );
  }
}
