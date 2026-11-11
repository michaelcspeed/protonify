import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'settings_dialog.dart';
import 'ui.dart';

const _categories = <ItemType?>[
  null,
  ItemType.login,
  ItemType.alias,
  ItemType.creditCard,
  ItemType.identity,
  ItemType.note,
  ItemType.wifi,
  ItemType.sshKey,
];

class VaultSidebar extends ConsumerWidget {
  /// Hides (unpins or closes) the sidebar.
  final VoidCallback onHide;
  const VaultSidebar({super.key, required this.onHide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final state = ref.watch(appStateProvider);

    final counts = <ItemType?, int>{null: state.items.length};
    for (final i in state.items) {
      counts[i.type] = (counts[i.type] ?? 0) + 1;
    }
    final folderCounts = <String, int>{};
    for (final i in state.items) {
      if (i.folderId != null) folderCounts[i.folderId!] = (folderCounts[i.folderId!] ?? 0) + 1;
    }

    final foldersByVault = <Vault, List<Folder>>{
      for (final v in state.vaults) v: state.folders.where((f) => f.shareId == v.shareId).toList(),
    };
    final hasFolders = foldersByVault.values.any((l) => l.isNotEmpty);

    return Material(
      color: c.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaneHeader(
            border: false,
            padding: const EdgeInsets.only(left: kTrafficLightInset, right: 8),
            child: Row(
              children: [
                const Spacer(),
                AppIconButton(
                  icon: Icons.view_sidebar_outlined,
                  tooltip: 'Hide sidebar  ⌃⌘S',
                  onPressed: onHide,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              children: [
                for (final cat in _categories)
                  _NavTile(
                    icon: cat == null ? Icons.grid_view_rounded : kindOf(cat).icon,
                    iconColor: cat == null ? null : kindOf(cat).glyph(context),
                    label: cat == null ? 'All items' : kindOf(cat).plural,
                    count: state.loadingItems ? null : counts[cat] ?? 0,
                    selected: state.selectedCategory == cat && state.selectedFolderId == null,
                    onTap: () => ref.read(appStateProvider.notifier).selectCategory(cat),
                  ),
                const SizedBox(height: 18),
                SectionLabel(
                  'Folders',
                  padding: const EdgeInsets.fromLTRB(10, 0, 2, 4),
                  trailing: state.vaults.isEmpty
                      ? null
                      : AppIconButton(
                          icon: Icons.add_rounded,
                          size: 16,
                          tooltip: 'New folder',
                          onPressed: () => _createFolder(context, ref),
                        ),
                ),
                if (!hasFolders && !state.loadingVaults)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 2, 10, 4),
                    child: Text('No folders yet', style: TextStyle(fontSize: 12, color: c.faint)),
                  ),
                for (final entry in foldersByVault.entries)
                  if (entry.value.isNotEmpty) ...[
                    if (state.vaults.length > 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
                        child: Text(entry.key.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: c.faint)),
                      ),
                    for (final f in entry.value)
                      _FolderTile(folder: f, count: folderCounts[f.id] ?? 0),
                  ],
              ],
            ),
          ),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
            child: Row(
              children: [
                AppIconButton(
                  icon: Icons.settings_outlined,
                  tooltip: 'Settings  ⌘,',
                  onPressed: () => showSettings(context),
                ),
                AppIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh  ⌘R',
                  onPressed: state.loadingItems || state.loadingVaults
                      ? null
                      : () => ref.read(appStateProvider.notifier).loadVaults(),
                ),
                const Spacer(),
                if (state.loadingItems || state.loadingVaults)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(children: [
                      SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.6, color: c.faint)),
                      const SizedBox(width: 8),
                      Text('Syncing…', style: TextStyle(fontSize: 11.5, color: c.faint)),
                    ]),
                  )
                else if (state.vaults.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${state.vaults.length} ${state.vaults.length == 1 ? 'vault' : 'vaults'}',
                      style: TextStyle(fontSize: 11.5, color: c.faint),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;
  final void Function(Offset)? onSecondaryTap;
  final Widget? trailing;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.iconColor,
    this.count,
    this.onSecondaryTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: onTap,
        onSecondaryTapDown: onSecondaryTap == null ? null : (d) => onSecondaryTap!(d.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 32,
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.only(left: 10, right: 8),
          decoration: BoxDecoration(
            color: selected
                ? c.accentSoft
                : hovered
                    ? c.surfaceVariant.withValues(alpha: 0.7)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: selected ? c.accentText : iconColor ?? c.subtle),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? c.accentText : c.onSurface,
                  ),
                ),
              ),
              if (hovered && trailing != null)
                trailing!
              else if (count != null && count! > 0)
                Text('$count',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: selected ? c.accentText : c.faint,
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Folders ─────────────────────────────────────────────────────────────────

class _FolderTile extends ConsumerWidget {
  final Folder folder;
  final int count;
  const _FolderTile({required this.folder, required this.count});

  void _menu(BuildContext context, WidgetRef ref, Offset pos) async {
    final c = context.c;
    final v = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      items: [
        PopupMenuItem(height: 36, value: 'rename', child: Text('Rename…', style: TextStyle(fontSize: 13, color: c.onSurface))),
        PopupMenuItem(height: 36, value: 'delete', child: Text('Delete…', style: TextStyle(fontSize: 13, color: c.danger))),
      ],
    );
    if (!context.mounted) return;
    if (v == 'rename') _renameFolder(context, ref, folder);
    if (v == 'delete') _deleteFolder(context, ref, folder);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(appStateProvider.select((s) => s.selectedFolderId == folder.id));
    return Builder(builder: (context) {
      return _NavTile(
        icon: selected ? Icons.folder_rounded : Icons.folder_outlined,
        label: folder.name,
        count: count,
        selected: selected,
        onTap: () => ref.read(appStateProvider.notifier).selectFolder(selected ? null : folder.id),
        onSecondaryTap: (pos) => _menu(context, ref, pos),
        trailing: Builder(
          builder: (btnContext) => GestureDetector(
            onTapDown: (d) => _menu(context, ref, d.globalPosition),
            child: Icon(Icons.more_horiz_rounded, size: 16, color: context.c.subtle),
          ),
        ),
      );
    });
  }
}

/// Text-entry dialog used for creating and renaming folders.
Future<void> _folderNameDialog(
  BuildContext context, {
  required String title,
  required String actionLabel,
  String initial = '',
  List<Vault>? vaults,
  String? initialVault,
  required Future<void> Function(String name, String? vault) onSubmit,
}) {
  final controller = TextEditingController(text: initial);
  String? vault = initialVault;
  String? error;
  bool submitting = false;

  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
      final c = ctx.c;
      Future<void> submit() async {
        final name = controller.text.trim();
        if (name.isEmpty) {
          setLocal(() => error = 'Enter a name');
          return;
        }
        setLocal(() { submitting = true; error = null; });
        try {
          await onSubmit(name, vault);
          if (ctx.mounted) Navigator.of(ctx).pop();
        } catch (e) {
          setLocal(() { submitting = false; error = friendlyError(e); });
        }
      }

      return AppDialog(
        title: title,
        width: 360,
        actions: [
          AppButton(label: 'Cancel', onPressed: submitting ? null : () => Navigator.of(ctx).pop()),
          AppButton.primary(label: actionLabel, loading: submitting, onPressed: submit),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (vaults != null && vaults.length > 1) ...[
              DropdownButtonFormField<String>(
                initialValue: vault,
                isDense: true,
                dropdownColor: c.elevated,
                borderRadius: BorderRadius.circular(10),
                decoration: const InputDecoration(labelText: 'Vault'),
                style: TextStyle(fontSize: 13, color: c.onSurface),
                items: [for (final v in vaults) DropdownMenuItem(value: v.name, child: Text(v.name))],
                onChanged: (v) => setLocal(() => vault = v ?? vault),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: controller,
              autofocus: true,
              onSubmitted: (_) => submitting ? null : submit(),
              style: TextStyle(fontSize: 13, color: c.onSurface),
              decoration: InputDecoration(hintText: 'Folder name', errorText: error),
            ),
          ],
        ),
      );
    }),
  ).whenComplete(controller.dispose);
}

void _createFolder(BuildContext context, WidgetRef ref) {
  final state = ref.read(appStateProvider);
  final vaults = state.vaults;
  _folderNameDialog(
    context,
    title: 'New folder',
    actionLabel: 'Create',
    vaults: vaults,
    initialVault: state.selectedFolderVault?.name ?? vaults.first.name,
    onSubmit: (name, vault) => ref
        .read(appStateProvider.notifier)
        .createFolder(vaultName: vault ?? vaults.first.name, name: name),
  );
}

void _renameFolder(BuildContext context, WidgetRef ref, Folder folder) {
  _folderNameDialog(
    context,
    title: 'Rename folder',
    actionLabel: 'Save',
    initial: folder.name,
    onSubmit: (name, _) =>
        ref.read(appStateProvider.notifier).renameFolder(folder: folder, newName: name),
  );
}

Future<void> _deleteFolder(BuildContext context, WidgetRef ref, Folder folder) async {
  final ok = await confirm(
    context,
    title: 'Delete “${folder.name}”?',
    message: 'Items in this folder will move to the vault root. This can’t be undone.',
    confirmLabel: 'Delete folder',
    destructive: true,
  );
  if (!ok) return;
  try {
    await ref.read(appStateProvider.notifier).deleteFolder(folder);
  } catch (e) {
    if (context.mounted) showToast(context, friendlyError(e), error: true);
  }
}
