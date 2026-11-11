// UI-only state shared between panes (not vault data — that's app_state.dart).
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Focus node of the search field, so ⌘F can reach it from anywhere.
final searchFocusProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'search');
  ref.onDispose(node.dispose);
  return node;
});

/// Whether the sidebar is shown inline when the window is wide enough.
class SidebarPinnedNotifier extends StateNotifier<bool> {
  static const _key = 'ui.sidebarPinned';
  SidebarPinnedNotifier() : super(true) {
    SharedPreferences.getInstance().then((p) {
      final v = p.getBool(_key);
      if (v != null && mounted) state = v;
    }).catchError((_) {});
  }

  void set(bool v) {
    state = v;
    SharedPreferences.getInstance().then((p) => p.setBool(_key, v)).catchError((_) => false);
  }
}

final sidebarPinnedProvider =
    StateNotifierProvider<SidebarPinnedNotifier, bool>((ref) => SidebarPinnedNotifier());

/// Sidebar shown as a floating panel (narrow windows, or when unpinned).
final sidebarOverlayProvider = StateProvider<bool>((ref) => false);
