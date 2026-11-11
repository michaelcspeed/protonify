import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_state.dart';
import '../models.dart';
import '../pass_service.dart';
import '../theme.dart';
import '../ui_state.dart';
import 'ui.dart';

const double _kRowHeight = 52;

// ── Actions usable from anywhere (shortcuts, buttons) ───────────────────────

/// Moves the selection up/down the visible list.
void moveSelection(WidgetRef ref, int delta) {
  final state = ref.read(appStateProvider);
  final items = state.filteredItems;
  if (items.isEmpty) return;
  final idx = items.indexWhere((i) => i.id == state.selectedItem?.id);
  final next = idx < 0 ? (delta > 0 ? 0 : items.length - 1) : (idx + delta).clamp(0, items.length - 1);
  ref.read(appStateProvider.notifier).selectItem(items[next]);
}

/// ⇧⌘C: copy the selected item's password (or Wi-Fi password).
void copySelectedPassword(BuildContext context, WidgetRef ref) {
  final item = ref.read(appStateProvider).selectedItem;
  final pw = item?.login?.password ?? item?.wifi?.password ?? '';
  if (pw.isEmpty) {
    showToast(context, 'No password on this item', icon: Icons.info_outline_rounded);
    return;
  }
  copyToClipboard(context, pw, label: 'Password', secret: true);
}

/// Opens the new-item flow. If the sidebar is filtered to a type we can
/// create, skip straight to that form.
void openNewItem(BuildContext context, WidgetRef ref) {
  final cat = ref.read(appStateProvider).selectedCategory;
  final preset = _creatableTypes.where((t) => t == cat).firstOrNull;
  showDialog(context: context, builder: (_) => NewItemDialog(initialType: preset));
}

String _paneTitle(AppState s) {
  if (s.selectedFolderId != null) {
    for (final f in s.folders) {
      if (f.id == s.selectedFolderId) return f.name;
    }
  }
  return s.selectedCategory == null ? 'All items' : kindOf(s.selectedCategory).plural;
}

// ── Pane ────────────────────────────────────────────────────────────────────

class ItemListPane extends ConsumerWidget {
  /// Leave room for the window's traffic-light buttons.
  final bool leadingInset;

  /// Shown as a sidebar button when the sidebar isn't visible.
  final VoidCallback? onShowSidebar;

  const ItemListPane({super.key, this.leadingInset = false, this.onShowSidebar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final state = ref.watch(appStateProvider);

    return Material(
      color: c.surface,
      child: Column(
        children: [
          PaneHeader(
            padding: EdgeInsets.only(left: leadingInset ? kTrafficLightInset : 10, right: 10),
            child: Row(
              children: [
                if (onShowSidebar != null) ...[
                  AppIconButton(
                    icon: Icons.view_sidebar_outlined,
                    tooltip: 'Show sidebar  ⌃⌘S',
                    onPressed: onShowSidebar,
                  ),
                  const SizedBox(width: 6),
                ],
                const Expanded(child: _SearchField()),
                const SizedBox(width: 8),
                _NewButton(onTap: () => openNewItem(context, ref)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 14, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    state.searchQuery.isEmpty ? _paneTitle(state) : 'Results',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.onSurface),
                  ),
                ),
                if (!state.loadingItems)
                  Text('${state.filteredItems.length}',
                      style: TextStyle(fontSize: 12, color: c.faint)),
              ],
            ),
          ),
          const Expanded(child: _ItemListBody()),
        ],
      ),
    );
  }
}

class _NewButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NewButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: 'New item  ⌘N',
      child: HoverBuilder(
        cursor: SystemMouseCursors.click,
        builder: (context, hovered) => GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: hovered ? Color.lerp(c.accent, Colors.white, 0.1) : c.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: ref.read(appStateProvider).searchQuery);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        moveSelection(ref, 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        moveSelection(ref, -1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
        final s = ref.read(appStateProvider);
        if (s.selectedItem == null && s.filteredItems.isNotEmpty) {
          ref.read(appStateProvider.notifier).selectItem(s.filteredItems.first);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        if (_controller.text.isNotEmpty) {
          ref.read(appStateProvider.notifier).setSearch('');
        } else {
          ref.read(searchFocusProvider).unfocus();
        }
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    ref.listen<String>(appStateProvider.select((s) => s.searchQuery), (_, next) {
      if (_controller.text != next) {
        _controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    });
    final focus = ref.watch(searchFocusProvider);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: SizedBox(
        height: 30,
        child: ValueListenableBuilder(
          valueListenable: _controller,
          builder: (context, value, _) => TextField(
            controller: _controller,
            focusNode: focus,
            onChanged: ref.read(appStateProvider.notifier).setSearch,
            style: TextStyle(fontSize: 13, color: c.onSurface),
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: 'Search',
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              prefixIcon: Icon(Icons.search_rounded, size: 16, color: c.faint),
              prefixIconConstraints: const BoxConstraints(minWidth: 32),
              suffixIconConstraints: const BoxConstraints(minWidth: 30),
              suffixIcon: value.text.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Center(widthFactor: 1, child: KeyHint('⌘F')),
                    )
                  : MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => ref.read(appStateProvider.notifier).setSearch(''),
                        child: Icon(Icons.cancel_rounded, size: 15, color: c.faint),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── List body ───────────────────────────────────────────────────────────────

class _ItemListBody extends ConsumerStatefulWidget {
  const _ItemListBody();

  @override
  ConsumerState<_ItemListBody> createState() => _ItemListBodyState();
}

class _ItemListBodyState extends ConsumerState<_ItemListBody> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Keep the selected row visible when moving with the keyboard.
  void _ensureVisible(String? id) {
    if (id == null || !_scroll.hasClients) return;
    final items = ref.read(appStateProvider).filteredItems;
    final idx = items.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    final top = idx * _kRowHeight + 4;
    final bottom = top + _kRowHeight;
    final pos = _scroll.position;
    double? target;
    if (top < pos.pixels) target = top - 4;
    if (bottom > pos.pixels + pos.viewportDimension) target = bottom - pos.viewportDimension + 4;
    if (target != null) {
      _scroll.animateTo(target.clamp(0, pos.maxScrollExtent),
          duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final state = ref.watch(appStateProvider);
    ref.listen<String?>(appStateProvider.select((s) => s.selectedItem?.id), (_, id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible(id));
    });

    if (state.loadingItems || (state.loadingVaults && state.items.isEmpty)) {
      return const _SkeletonList();
    }

    if (state.error != null) {
      return _EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Couldn’t load your vaults',
        message: friendlyError(state.error!),
        action: AppButton(
          label: 'Try again',
          icon: Icons.refresh_rounded,
          onPressed: () => ref.read(appStateProvider.notifier).loadVaults(),
        ),
      );
    }

    final items = state.filteredItems;
    if (items.isEmpty) {
      final notifier = ref.read(appStateProvider.notifier);
      if (state.searchQuery.isNotEmpty) {
        return _EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No results',
          message: 'Nothing matches “${state.searchQuery}”'
              '${state.selectedCategory != null || state.selectedFolderId != null ? ' in ${_paneTitle(state)}' : ''}.',
          action: AppButton(label: 'Clear search', onPressed: () => notifier.setSearch('')),
        );
      }
      if (state.items.isNotEmpty) {
        return _EmptyState(
          icon: state.selectedFolderId != null
              ? Icons.folder_open_rounded
              : kindOf(state.selectedCategory).icon,
          title: 'Nothing in ${_paneTitle(state)} yet',
          message: state.selectedFolderId != null
              ? 'Move items here from their detail view.'
              : null,
          action: AppButton(label: 'Show all items', onPressed: () => notifier.selectCategory(null)),
        );
      }
      return _EmptyState(
        icon: Icons.shield_outlined,
        title: 'Your vault is empty',
        message: 'Add your first login, note, card or Wi-Fi network.',
        action: AppButton.primary(
          label: 'New item',
          icon: Icons.add_rounded,
          onPressed: () => openNewItem(context, ref),
        ),
      );
    }

    return Scrollbar(
      controller: _scroll,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        itemExtent: _kRowHeight,
        itemCount: items.length,
        itemBuilder: (ctx, i) => _ItemRow(
          item: items[i],
          selected: state.selectedItem?.id == items[i].id,
          subtitleFallback: c.faint,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  const _EmptyState({required this.icon, required this.title, this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: c.faint),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.onSurface)),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, height: 1.4, color: c.subtle)),
            ],
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bar = c.surfaceVariant.withValues(alpha: 0.7);
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
      itemExtent: _kRowHeight,
      itemCount: 10,
      itemBuilder: (_, i) => Row(
        children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: bar, borderRadius: BorderRadius.circular(9))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.4 + (i * 37 % 40) / 100,
                  child: Container(height: 9, decoration: BoxDecoration(color: bar, borderRadius: BorderRadius.circular(4))),
                ),
                const SizedBox(height: 7),
                FractionallySizedBox(
                  widthFactor: 0.3 + (i * 53 % 30) / 100,
                  child: Container(height: 7, decoration: BoxDecoration(color: bar.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(4))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends ConsumerWidget {
  final PassItem item;
  final bool selected;
  final Color subtitleFallback;
  const _ItemRow({required this.item, required this.selected, required this.subtitleFallback});

  String _subtitle() {
    if (item.displayUsername.isNotEmpty) return item.displayUsername;
    switch (item.type) {
      case ItemType.wifi:
        return item.wifi?.ssid ?? '';
      case ItemType.creditCard:
        final n = item.creditCard?.number ?? '';
        return n.length >= 4 ? '•••• ${n.substring(n.length - 4)}' : (item.creditCard?.cardholderName ?? '');
      case ItemType.identity:
        return item.identity?.fullName ?? '';
      case ItemType.note:
        return item.note.split('\n').first;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final sub = _subtitle();
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: () => ref.read(appStateProvider.notifier).selectItem(item),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? c.accentSoft
                : hovered
                    ? c.surfaceVariant.withValues(alpha: 0.6)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              KindChip(kind: kindOf(item.type)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.isEmpty ? 'Untitled' : item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: c.onSurface,
                      ),
                    ),
                    if (sub.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: c.subtle),
                        ),
                      ),
                  ],
                ),
              ),
              if (item.primaryTotpUri.isNotEmpty) _OtpBadge(uri: item.primaryTotpUri),
            ],
          ),
        ),
      ),
    );
  }
}

// ── New / edit item dialog ──────────────────────────────────────────────────

/// Types the CLI integration can create and edit.
const _creatableTypes = [ItemType.login, ItemType.note, ItemType.creditCard, ItemType.wifi];

class NewItemDialog extends StatefulWidget {
  final PassItem? editItem;
  final ItemType? initialType;
  const NewItemDialog({super.key, this.editItem, this.initialType});

  @override
  State<NewItemDialog> createState() => _NewItemDialogState();
}

class _NewItemDialogState extends State<NewItemDialog> {
  ItemType? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.editItem?.type ?? widget.initialType;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editItem != null;
    final maxW = MediaQuery.sizeOf(context).width - 48;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 440.clamp(260, maxW).toDouble()),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutQuart,
          alignment: Alignment.topCenter,
          child: _selected == null
              ? _TypePicker(onPick: (t) => setState(() => _selected = t))
              : _CreationForm(
                  type: _selected!,
                  editItem: widget.editItem,
                  onBack: isEdit ? null : () => setState(() => _selected = null),
                ),
        ),
      ),
    );
  }
}

class _TypePicker extends StatelessWidget {
  final void Function(ItemType) onPick;
  const _TypePicker({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New item',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.onSurface)),
          const SizedBox(height: 4),
          Text('What would you like to save?', style: TextStyle(fontSize: 12.5, color: c.subtle)),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, box) {
            final cols = box.maxWidth > 320 ? 2 : 1;
            final w = (box.maxWidth - (cols - 1) * 8) / cols;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _creatableTypes)
                  SizedBox(width: w, child: _TypeTile(type: t, onTap: () => onPick(t))),
              ],
            );
          }),
          const SizedBox(height: 14),
          Text('Aliases, identities and SSH keys can be created in the Proton Pass app.',
              style: TextStyle(fontSize: 11.5, color: c.faint)),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
          ),
        ],
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  final ItemType type;
  final VoidCallback onTap;
  const _TypeTile({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final kind = kindOf(type);
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hovered ? c.surfaceVariant.withValues(alpha: 0.7) : c.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: hovered ? c.accent.withValues(alpha: 0.5) : c.border),
          ),
          child: Row(
            children: [
              KindChip(kind: kind, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(kind.label,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.onSurface)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreationForm extends ConsumerStatefulWidget {
  final ItemType type;
  final PassItem? editItem;
  final VoidCallback? onBack;
  const _CreationForm({required this.type, this.editItem, this.onBack});

  @override
  ConsumerState<_CreationForm> createState() => _CreationFormState();
}

class _CreationFormState extends ConsumerState<_CreationForm> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedVault;
  bool _submitting = false;
  String? _error;

  // shared
  final _title = TextEditingController();
  final _note  = TextEditingController();
  // login
  final _email    = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _url      = TextEditingController();
  // card
  final _cardholderName  = TextEditingController();
  final _cardNumber      = TextEditingController();
  final _cvv             = TextEditingController();
  final _expirationDate  = TextEditingController();
  final _pin             = TextEditingController();
  // wifi
  final _ssid            = TextEditingController();
  String _wifiSecurity   = 'wpa2';

  bool get _isEdit => widget.editItem != null;

  @override
  void initState() {
    super.initState();
    final item = widget.editItem;
    if (item != null) {
      _title.text = item.title;
      _note.text = item.note;
      if (item.login != null) {
        _email.text = item.login!.email;
        _username.text = item.login!.username;
        _password.text = item.login!.password;
        _url.text = item.login!.urls.isNotEmpty ? item.login!.urls.first : '';
      }
      if (item.creditCard != null) {
        _cardholderName.text = item.creditCard!.cardholderName;
        _cardNumber.text = item.creditCard!.number;
        _cvv.text = item.creditCard!.verificationNumber;
        _expirationDate.text = item.creditCard!.expirationDate;
        _pin.text = item.creditCard!.pin;
      }
      if (item.wifi != null) {
        _ssid.text = item.wifi!.ssid;
        _password.text = item.wifi!.password;
        final sec = item.wifi!.security;
        if (sec.isNotEmpty) _wifiSecurity = sec;
      }
    } else {
      // Default to the vault of the selected folder, else the first vault.
      final state = ref.read(appStateProvider);
      _selectedVault = state.selectedFolderVault?.name ??
          (state.vaults.isNotEmpty ? state.vaults.first.name : null);
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _note, _email, _username, _password, _url,
                     _cardholderName, _cardNumber, _cvv, _expirationDate, _pin,
                     _ssid]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (!_isEdit && _selectedVault == null) {
      setState(() => _error = 'Choose a vault');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      final notifier = ref.read(appStateProvider.notifier);
      if (_isEdit) {
        final fields = <String, String>{};
        fields['title'] = _title.text.trim();
        fields['note'] = _note.text.trim();
        switch (widget.type) {
          case ItemType.login:
            fields['email'] = _email.text.trim();
            fields['username'] = _username.text.trim();
            fields['password'] = _password.text;
            fields['url'] = _url.text.trim();
          case ItemType.creditCard:
            fields['cardholder_name'] = _cardholderName.text.trim();
            fields['number'] = _cardNumber.text.trim();
            fields['cvv'] = _cvv.text.trim();
            fields['expiration_date'] = _expirationDate.text.trim();
            fields['pin'] = _pin.text.trim();
          case ItemType.wifi:
            fields['ssid'] = _ssid.text.trim();
            fields['password'] = _password.text;
            fields['security'] = _wifiSecurity;
          case ItemType.note:
            break;
          default:
            break;
        }
        await notifier.updateItem(item: widget.editItem!, fields: fields);
      } else {
        // If the chosen vault matches the sidebar's selected folder's vault,
        // auto-place the new item in that folder.
        final state = ref.read(appStateProvider);
        final folderVault = state.selectedFolderVault;
        final folderId = (folderVault != null && folderVault.name == _selectedVault)
            ? state.selectedFolderId
            : null;
        switch (widget.type) {
          case ItemType.login:
            await notifier.createLogin(
              vaultName: _selectedVault!,
              title: _title.text.trim(),
              email: _email.text.trim(),
              username: _username.text.trim(),
              password: _password.text,
              url: _url.text.trim(),
              folderId: folderId,
            );
          case ItemType.note:
            await notifier.createNote(
              vaultName: _selectedVault!,
              title: _title.text.trim(),
              note: _note.text.trim(),
              folderId: folderId,
            );
          case ItemType.creditCard:
            await notifier.createCreditCard(
              vaultName: _selectedVault!,
              title: _title.text.trim(),
              cardholderName: _cardholderName.text.trim(),
              number: _cardNumber.text.trim(),
              cvv: _cvv.text.trim(),
              expirationDate: _expirationDate.text.trim(),
              pin: _pin.text.trim(),
              note: _note.text.trim(),
              folderId: folderId,
            );
          case ItemType.wifi:
            await notifier.createWifi(
              vaultName: _selectedVault!,
              title: _title.text.trim(),
              ssid: _ssid.text.trim(),
              password: _password.text,
              security: _wifiSecurity,
              note: _note.text.trim(),
              folderId: folderId,
            );
          default:
            break;
        }
        ref.read(appStateProvider.notifier).loadVaults();
      }
      if (mounted) {
        final label = kindOf(widget.type).label;
        showToast(context, _isEdit ? 'Saved changes' : '$label created');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vaults = ref.watch(appStateProvider).vaults;
    final c = context.c;
    final kind = kindOf(widget.type);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _submit,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _submit,
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 20, 12),
              child: Row(
                children: [
                  if (widget.onBack != null) ...[
                    AppIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: widget.onBack),
                    const SizedBox(width: 6),
                  ] else
                    const SizedBox(width: 6),
                  KindChip(kind: kind, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_isEdit ? 'Edit ${kind.label.toLowerCase()}' : 'New ${kind.label.toLowerCase()}',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.onSurface)),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isEdit && vaults.length > 1) ...[
                        const _FormLabel('Vault'),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedVault,
                          isDense: true,
                          dropdownColor: c.elevated,
                          borderRadius: BorderRadius.circular(10),
                          style: TextStyle(fontSize: 13, color: c.onSurface),
                          icon: Icon(Icons.expand_more_rounded, size: 18, color: c.subtle),
                          items: [for (final v in vaults) DropdownMenuItem(value: v.name, child: Text(v.name))],
                          onChanged: (v) => setState(() => _selectedVault = v),
                        ),
                        const SizedBox(height: 14),
                      ],
                      const _FormLabel('Title'),
                      _Field(
                        controller: _title,
                        hint: switch (widget.type) {
                          ItemType.login => 'e.g. GitHub',
                          ItemType.wifi => 'e.g. Home network',
                          ItemType.creditCard => 'e.g. Visa debit',
                          _ => 'Title',
                        },
                        autofocus: true,
                        onSubmit: _submit,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Give it a title' : null,
                      ),
                      ..._typeFields(c),
                    ],
                  ),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.error_outline_rounded, size: 16, color: c.danger),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: TextStyle(fontSize: 12, color: c.danger))),
                  ]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Row(
                children: [
                  Text('⌘S to save', style: TextStyle(fontSize: 11, color: c.faint)),
                  const Spacer(),
                  AppButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
                  const SizedBox(width: 8),
                  AppButton.primary(
                    label: _isEdit ? 'Save' : 'Create',
                    loading: _submitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _typeFields(ProtonifyColors c) {
    const gap = SizedBox(height: 14);
    switch (widget.type) {
      case ItemType.login:
        return [
          gap,
          const _FormLabel('Email'),
          _Field(controller: _email, hint: 'name@example.com', keyboardType: TextInputType.emailAddress, onSubmit: _submit),
          gap,
          const _FormLabel('Username', optional: true),
          _Field(controller: _username, hint: 'username', onSubmit: _submit),
          gap,
          const _FormLabel('Password'),
          _PasswordFieldWithTools(controller: _password),
          gap,
          const _FormLabel('Website', optional: true),
          _Field(controller: _url, hint: 'https://', keyboardType: TextInputType.url, onSubmit: _submit),
          gap,
          const _FormLabel('Note', optional: true),
          _Field(controller: _note, hint: 'Anything else worth remembering', maxLines: 3),
        ];
      case ItemType.note:
        return [
          gap,
          const _FormLabel('Note'),
          _Field(controller: _note, hint: 'Write something…', maxLines: 8),
        ];
      case ItemType.wifi:
        return [
          gap,
          const _FormLabel('Network name (SSID)'),
          _Field(controller: _ssid, hint: 'MyWiFi', onSubmit: _submit),
          gap,
          const _FormLabel('Password'),
          _PasswordFieldWithTools(controller: _password),
          gap,
          const _FormLabel('Security'),
          DropdownButtonFormField<String>(
            initialValue: _wifiSecurity,
            isDense: true,
            dropdownColor: c.elevated,
            borderRadius: BorderRadius.circular(10),
            style: TextStyle(fontSize: 13, color: c.onSurface),
            icon: Icon(Icons.expand_more_rounded, size: 18, color: c.subtle),
            items: const [
              DropdownMenuItem(value: 'wpa3', child: Text('WPA3')),
              DropdownMenuItem(value: 'wpa2', child: Text('WPA2')),
              DropdownMenuItem(value: 'wpa',  child: Text('WPA')),
              DropdownMenuItem(value: 'wep',  child: Text('WEP')),
              DropdownMenuItem(value: 'open', child: Text('Open')),
              DropdownMenuItem(value: 'none', child: Text('None')),
            ],
            onChanged: (v) => setState(() => _wifiSecurity = v ?? 'wpa2'),
          ),
          gap,
          const _FormLabel('Note', optional: true),
          _Field(controller: _note, hint: 'Optional note', maxLines: 2),
        ];
      case ItemType.creditCard:
        return [
          gap,
          const _FormLabel('Cardholder name'),
          _Field(controller: _cardholderName, hint: 'Name on card', onSubmit: _submit),
          gap,
          const _FormLabel('Card number'),
          _Field(controller: _cardNumber, hint: '1234 5678 9012 3456', keyboardType: TextInputType.number, onSubmit: _submit),
          gap,
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _FormLabel('Expiry'),
              _Field(controller: _expirationDate, hint: 'YYYY-MM', onSubmit: _submit),
            ])),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _FormLabel('CVV'),
              _Field(controller: _cvv, hint: '•••', obscure: true, keyboardType: TextInputType.number, onSubmit: _submit),
            ])),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _FormLabel('PIN', optional: true),
              _Field(controller: _pin, hint: '••••', obscure: true, keyboardType: TextInputType.number, onSubmit: _submit),
            ])),
          ]),
          gap,
          const _FormLabel('Note', optional: true),
          _Field(controller: _note, hint: 'Optional note', maxLines: 2),
        ];
      default:
        return [
          gap,
          Text('Editing this type isn’t supported yet.',
              style: TextStyle(fontSize: 12, color: c.subtle)),
        ];
    }
  }
}

// ── Form helpers ────────────────────────────────────────────────────────────

class _FormLabel extends StatelessWidget {
  final String text;
  final bool optional;
  const _FormLabel(this.text, {this.optional = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text.rich(TextSpan(children: [
        TextSpan(text: text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.subtle)),
        if (optional) TextSpan(text: '  optional', style: TextStyle(fontSize: 11, color: c.faint)),
      ])),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final int maxLines;
  final bool autofocus;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final VoidCallback? onSubmit;

  const _Field({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.maxLines = 1,
    this.autofocus = false,
    this.keyboardType,
    this.validator,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      autofocus: autofocus,
      minLines: maxLines > 1 ? maxLines : null,
      maxLines: obscure ? 1 : maxLines,
      keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
      validator: validator,
      onFieldSubmitted: maxLines == 1 && onSubmit != null ? (_) => onSubmit!() : null,
      style: TextStyle(fontSize: 13, color: c.onSurface),
      decoration: InputDecoration(hintText: hint),
    );
  }
}

// ── OTP badge ───────────────────────────────────────────────────────────────

int _totpPeriod(String uri) {
  if (!uri.startsWith('otpauth://')) return 30;
  try {
    return int.tryParse(Uri.parse(uri).queryParameters['period'] ?? '') ?? 30;
  } catch (_) {
    return 30;
  }
}

class _OtpBadge extends StatefulWidget {
  final String uri;
  const _OtpBadge({required this.uri});

  @override
  State<_OtpBadge> createState() => _OtpBadgeState();
}

class _OtpBadgeState extends State<_OtpBadge> {
  final PassService _svc = PassService();
  String? _code;
  Timer? _ticker;
  late int _period;
  int _remaining = 30;

  @override
  void initState() {
    super.initState();
    _period = _totpPeriod(widget.uri);
    _refresh();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final secs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remaining = _period - (secs % _period);
    if (remaining == _period) {
      _refresh();
    } else {
      setState(() => _remaining = remaining);
    }
  }

  Future<void> _refresh() async {
    try {
      final code = await _svc.generateTotp(widget.uri);
      if (!mounted) return;
      final secs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      setState(() {
        _code = code;
        _remaining = _period - (secs % _period);
      });
    } catch (_) {
      if (mounted) setState(() => _code = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_code == null) return const SizedBox.shrink();
    final progress = _remaining / _period;
    final ringColor = _remaining <= 5 ? c.danger : c.accent;

    return Tooltip(
      message: 'Copy 2FA code',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => copyToClipboard(context, _code!, label: '2FA code', secret: true),
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 2,
                backgroundColor: c.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(ringColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Password field with generator + strength meter ──────────────────────────

class _PasswordFieldWithTools extends StatefulWidget {
  final TextEditingController controller;
  const _PasswordFieldWithTools({required this.controller});

  @override
  State<_PasswordFieldWithTools> createState() => _PasswordFieldWithToolsState();
}

class _PasswordFieldWithToolsState extends State<_PasswordFieldWithTools> {
  final _svc = PassService();
  PasswordScore? _score;
  Timer? _debounce;
  bool _obscure = true;
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    if (widget.controller.text.isNotEmpty) _scheduleScore();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _debounce?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onChanged() {
    _scheduleScore();
  }

  void _scheduleScore() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final text = widget.controller.text;
      if (text.isEmpty) {
        if (mounted) setState(() => _score = null);
        return;
      }
      final score = await _svc.scorePassword(text);
      if (mounted) setState(() => _score = score);
    });
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _toggleGenerator() {
    if (_overlay != null) {
      _removeOverlay();
      return;
    }
    // Capture the theme here: the overlay lives above the dialog.
    final theme = Theme.of(context);
    _overlay = OverlayEntry(builder: (ctx) {
      return Theme(
        data: theme,
        child: Stack(children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _removeOverlay,
              child: Container(color: Colors.transparent),
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 6),
            child: Material(
              color: Colors.transparent,
              child: _GeneratorPopover(
                onUse: (pw) {
                  widget.controller.text = pw;
                  widget.controller.selection = TextSelection.collapsed(offset: pw.length);
                  setState(() => _obscure = false);
                  _removeOverlay();
                },
              ),
            ),
          ),
        ]),
      );
    });
    Overlay.of(context).insert(_overlay!);
  }

  Color _strengthColor(ProtonifyColors c, PasswordStrength s) {
    return switch (s) {
      PasswordStrength.vulnerable => c.danger,
      PasswordStrength.weak => c.warning,
      PasswordStrength.strong => c.success,
      PasswordStrength.unknown => c.subtle,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final score = _score;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompositedTransformTarget(
          link: _layerLink,
          child: TextFormField(
            controller: widget.controller,
            obscureText: _obscure,
            style: TextStyle(
              fontSize: 13,
              color: c.onSurface,
              fontFamily: _obscure ? null : 'Menlo',
            ),
            decoration: InputDecoration(
              hintText: 'Password',
              suffixIconConstraints: const BoxConstraints(minHeight: 30),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  AppIconButton(
                    icon: _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    tooltip: _obscure ? 'Show' : 'Hide',
                    size: 16,
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  AppIconButton(
                    icon: Icons.auto_awesome_outlined,
                    tooltip: 'Generate password',
                    size: 16,
                    active: _overlay != null,
                    onPressed: _toggleGenerator,
                  ),
                ]),
              ),
            ),
          ),
        ),
        if (score != null && score.strength != PasswordStrength.unknown) ...[
          const SizedBox(height: 7),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (score.numericScore / 100).clamp(0.05, 1.0),
                  minHeight: 3,
                  backgroundColor: c.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation(_strengthColor(c, score.strength)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(score.label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _strengthColor(c, score.strength))),
          ]),
        ],
      ],
    );
  }
}

class _GeneratorPopover extends StatefulWidget {
  final ValueChanged<String> onUse;
  const _GeneratorPopover({required this.onUse});

  @override
  State<_GeneratorPopover> createState() => _GeneratorPopoverState();
}

class _GeneratorPopoverState extends State<_GeneratorPopover> {
  final _svc = PassService();
  bool _isPassphrase = false;
  double _length = 20;
  bool _upper = true;
  bool _numbers = true;
  bool _symbols = true;
  double _words = 4;
  String _separator = 'hyphens';
  String _preview = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  Future<void> _regenerate() async {
    setState(() => _loading = true);
    try {
      final pw = _isPassphrase
          ? await _svc.generatePassphrase(
              count: _words.round(),
              separator: _separator,
              capitalise: true,
              numbers: _numbers,
            )
          : await _svc.generatePassword(
              length: _length.round(),
              uppercase: _upper,
              numbers: _numbers,
              symbols: _symbols,
            );
      if (mounted) setState(() { _preview = pw; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _preview = ''; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 320,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: c.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              _ModeTab(label: 'Random', selected: !_isPassphrase,
                  onTap: () { setState(() => _isPassphrase = false); _regenerate(); }),
              _ModeTab(label: 'Passphrase', selected: _isPassphrase,
                  onTap: () { setState(() => _isPassphrase = true); _regenerate(); }),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.border),
            ),
            child: Row(children: [
              Expanded(
                child: SelectableText(
                  _loading && _preview.isEmpty ? '…' : _preview,
                  style: TextStyle(fontSize: 12.5, fontFamily: 'Menlo', height: 1.4, color: c.onSurface),
                ),
              ),
              AppIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Regenerate',
                size: 16,
                onPressed: _loading ? null : _regenerate,
              ),
            ]),
          ),
          const SizedBox(height: 12),
          if (!_isPassphrase) ...[
            _SettingRow(
              label: 'Length',
              trailing: Text('${_length.round()}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.onSurface)),
            ),
            Slider(
              min: 8, max: 64, divisions: 56, value: _length,
              onChanged: (v) => setState(() => _length = v),
              onChangeEnd: (_) => _regenerate(),
            ),
            const SizedBox(height: 4),
            _CheckRow(label: 'Uppercase (A–Z)', value: _upper,
                onChanged: (v) { setState(() => _upper = v); _regenerate(); }),
            _CheckRow(label: 'Numbers (0–9)', value: _numbers,
                onChanged: (v) { setState(() => _numbers = v); _regenerate(); }),
            _CheckRow(label: 'Symbols (!@#…)', value: _symbols,
                onChanged: (v) { setState(() => _symbols = v); _regenerate(); }),
          ] else ...[
            _SettingRow(
              label: 'Words',
              trailing: Text('${_words.round()}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.onSurface)),
            ),
            Slider(
              min: 3, max: 10, divisions: 7, value: _words,
              onChanged: (v) => setState(() => _words = v),
              onChangeEnd: (_) => _regenerate(),
            ),
            const SizedBox(height: 4),
            _SettingRow(
              label: 'Separator',
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _separator,
                  isDense: true,
                  dropdownColor: c.elevated,
                  borderRadius: BorderRadius.circular(10),
                  style: TextStyle(fontSize: 12, color: c.onSurface),
                  icon: Icon(Icons.expand_more_rounded, size: 16, color: c.subtle),
                  items: const [
                    DropdownMenuItem(value: 'hyphens', child: Text('Hyphens')),
                    DropdownMenuItem(value: 'spaces', child: Text('Spaces')),
                    DropdownMenuItem(value: 'periods', child: Text('Periods')),
                    DropdownMenuItem(value: 'commas', child: Text('Commas')),
                    DropdownMenuItem(value: 'underscores', child: Text('Underscores')),
                    DropdownMenuItem(value: 'numbers', child: Text('Numbers')),
                    DropdownMenuItem(value: 'numbers-and-symbols', child: Text('Numbers & symbols')),
                  ],
                  onChanged: (v) {
                    if (v != null) { setState(() => _separator = v); _regenerate(); }
                  },
                ),
              ),
            ),
            _CheckRow(label: 'Include numbers', value: _numbers,
                onChanged: (v) { setState(() => _numbers = v); _regenerate(); }),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton.primary(
                label: 'Use password',
                dense: true,
                onPressed: _preview.isEmpty ? null : () => widget.onUse(_preview),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? c.elevated : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? c.onSurface : c.subtle)),
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final Widget trailing;
  const _SettingRow({required this.label, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: c.subtle))),
        trailing,
      ]),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _CheckRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(
              width: 16, height: 16,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: c.onSurface))),
          ]),
        ),
      ),
    );
  }
}
