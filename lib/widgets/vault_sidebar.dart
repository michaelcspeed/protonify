import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_state.dart';
import '../main.dart';
import '../models.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final ItemType? category; // null = All
  final Color color;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.category,
    required this.color,
  });
}

const _navItems = [
  _NavItem(label: 'All items',   icon: Icons.apps,             category: null,               color: Color(0xFF8E8E93)),
  _NavItem(label: 'Logins',      icon: Icons.language,         category: ItemType.login,      color: Color(0xFF4A6FFF)),
  _NavItem(label: 'Aliases',     icon: Icons.alternate_email,  category: ItemType.alias,      color: Color(0xFF5AC8FA)),
  _NavItem(label: 'Cards',       icon: Icons.credit_card,      category: ItemType.creditCard, color: Color(0xFF34C759)),
  _NavItem(label: 'Identities',  icon: Icons.person_outline,   category: ItemType.identity,   color: Color(0xFFFF375F)),
  _NavItem(label: 'Notes',       icon: Icons.notes,            category: ItemType.note,       color: Color(0xFFFF9500)),
  _NavItem(label: 'Wi-Fi',       icon: Icons.wifi,             category: ItemType.wifi,       color: Color(0xFF32ADE6)),
  _NavItem(label: 'SSH Keys',    icon: Icons.key_outlined,     category: ItemType.sshKey,     color: Color(0xFFBF5AF2)),
];

class VaultSidebar extends ConsumerWidget {
  const VaultSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<ProtonifyColors>()!;
    final state = ref.watch(appStateProvider);

    // Group folders by vault (name).
    final foldersByVault = <Vault, List<Folder>>{};
    for (final v in state.vaults) {
      foldersByVault[v] = state.folders
          .where((f) => f.shareId == v.shareId)
          .toList();
    }

    return Container(
      color: c.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 52),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text('ITEMS',
                style: Theme.of(context).textTheme.labelSmall),
          ),
          if (state.loadingVaults)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  ..._navItems.map((nav) => _NavTile(nav: nav)),
                  const SizedBox(height: 14),
                  _FoldersHeader(c: c, vaults: state.vaults),
                  if (foldersByVault.values.every((l) => l.isEmpty))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Text(
                        'No folders yet',
                        style: TextStyle(fontSize: 11, color: c.subtle),
                      ),
                    )
                  else
                    for (final entry in foldersByVault.entries)
                      if (entry.value.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                          child: Text(
                            entry.key.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 0.8,
                              color: c.subtle.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        for (final f in entry.value) _FolderTile(folder: f),
                      ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FoldersHeader extends ConsumerWidget {
  final ProtonifyColors c;
  final List<Vault> vaults;
  const _FoldersHeader({required this.c, required this.vaults});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 10, 4),
      child: Row(
        children: [
          Expanded(
            child: Text('FOLDERS',
                style: Theme.of(context).textTheme.labelSmall),
          ),
          if (vaults.isNotEmpty)
            _AddFolderButton(c: c, vaults: vaults),
        ],
      ),
    );
  }
}

class _AddFolderButton extends ConsumerStatefulWidget {
  final ProtonifyColors c;
  final List<Vault> vaults;
  const _AddFolderButton({required this.c, required this.vaults});

  @override
  ConsumerState<_AddFolderButton> createState() => _AddFolderButtonState();
}

class _AddFolderButtonState extends ConsumerState<_AddFolderButton> {
  bool _hovered = false;

  Future<void> _showDialog() async {
    final c = widget.c;
    final controller = TextEditingController();
    final defaultVaultName = ref
            .read(appStateProvider)
            .selectedFolderVault
            ?.name ??
        widget.vaults.first.name;
    String selectedVault = defaultVaultName;
    String? error;
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          return Dialog(
            backgroundColor: c.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New folder',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.onSurface)),
                  const SizedBox(height: 14),
                  Text('Vault', style: TextStyle(fontSize: 11, color: c.subtle)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: c.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedVault,
                        isExpanded: true,
                        dropdownColor: c.surfaceVariant,
                        style: TextStyle(fontSize: 13, color: c.onSurface),
                        icon: Icon(Icons.expand_more, size: 16, color: c.subtle),
                        items: widget.vaults
                            .map((v) => DropdownMenuItem(value: v.name, child: Text(v.name)))
                            .toList(),
                        onChanged: (v) => setLocal(() => selectedVault = v ?? selectedVault),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Name', style: TextStyle(fontSize: 11, color: c.subtle)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: TextStyle(fontSize: 13, color: c.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Folder name',
                      hintStyle: TextStyle(fontSize: 13, color: c.subtle),
                      filled: true,
                      fillColor: c.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: c.accent.withValues(alpha: 0.6)),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(fontSize: 11, color: Color(0xFFFF375F))),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                        child: Text('Cancel', style: TextStyle(color: c.onSurface)),
                      ),
                      const SizedBox(width: 4),
                      FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                final name = controller.text.trim();
                                if (name.isEmpty) {
                                  setLocal(() => error = 'Name required');
                                  return;
                                }
                                setLocal(() { submitting = true; error = null; });
                                try {
                                  await ref
                                      .read(appStateProvider.notifier)
                                      .createFolder(vaultName: selectedVault, name: name);
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                } catch (e) {
                                  setLocal(() { submitting = false; error = e.toString(); });
                                }
                              },
                        style: FilledButton.styleFrom(backgroundColor: c.accent),
                        child: Text(submitting ? 'Creating…' : 'Create'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _showDialog,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: _hovered ? widget.c.surfaceVariant : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(Icons.add, size: 14, color: widget.c.subtle),
        ),
      ),
    );
  }
}

class _NavTile extends ConsumerStatefulWidget {
  final _NavItem nav;
  const _NavTile({required this.nav});

  @override
  ConsumerState<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends ConsumerState<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ProtonifyColors>()!;
    final state = ref.watch(appStateProvider);
    final selected = state.selectedCategory == widget.nav.category &&
        state.selectedFolderId == null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => ref.read(appStateProvider.notifier).selectCategory(widget.nav.category),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? c.accent.withValues(alpha: 0.18)
                : _hovered
                    ? c.surfaceVariant.withValues(alpha: 0.5)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: selected ? widget.nav.color : widget.nav.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(widget.nav.icon,
                    size: 15,
                    color: selected ? Colors.white : widget.nav.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.nav.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? c.accent : c.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderTile extends ConsumerStatefulWidget {
  final Folder folder;
  const _FolderTile({required this.folder});

  @override
  ConsumerState<_FolderTile> createState() => _FolderTileState();
}

class _FolderTileState extends ConsumerState<_FolderTile> {
  bool _hovered = false;

  Future<void> _rename() async {
    final c = Theme.of(context).extension<ProtonifyColors>()!;
    final controller = TextEditingController(text: widget.folder.name);
    String? error;
    bool submitting = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return Dialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rename folder',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.onSurface)),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: TextStyle(fontSize: 13, color: c.onSurface),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: c.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(fontSize: 11, color: Color(0xFFFF375F))),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                      child: Text('Cancel', style: TextStyle(color: c.onSurface)),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      onPressed: submitting
                          ? null
                          : () async {
                              final name = controller.text.trim();
                              if (name.isEmpty) { setLocal(() => error = 'Name required'); return; }
                              setLocal(() { submitting = true; error = null; });
                              try {
                                await ref.read(appStateProvider.notifier)
                                    .renameFolder(folder: widget.folder, newName: name);
                                if (ctx.mounted) Navigator.of(ctx).pop();
                              } catch (e) {
                                setLocal(() { submitting = false; error = e.toString(); });
                              }
                            },
                      style: FilledButton.styleFrom(backgroundColor: c.accent),
                      child: Text(submitting ? 'Saving…' : 'Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Future<void> _delete() async {
    final c = Theme.of(context).extension<ProtonifyColors>()!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Delete folder?',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.onSurface)),
              const SizedBox(height: 10),
              Text(
                'Items inside "${widget.folder.name}" will move to the vault root. This cannot be undone.',
                style: TextStyle(fontSize: 12, color: c.subtle),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('Cancel', style: TextStyle(color: c.onSurface)),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF375F)),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) {
      await ref.read(appStateProvider.notifier).deleteFolder(widget.folder);
    }
  }

  void _showMenu(Offset pos) {
    final c = Theme.of(context).extension<ProtonifyColors>()!;
    showMenu<String>(
      context: context,
      color: c.surface,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      items: [
        PopupMenuItem(value: 'rename', child: Text('Rename', style: TextStyle(color: c.onSurface))),
        PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: const Color(0xFFFF375F)))),
      ],
    ).then((v) {
      if (v == 'rename') _rename();
      if (v == 'delete') _delete();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ProtonifyColors>()!;
    final state = ref.watch(appStateProvider);
    final selected = state.selectedFolderId == widget.folder.id;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => ref
            .read(appStateProvider.notifier)
            .selectFolder(selected ? null : widget.folder.id),
        onSecondaryTapDown: (d) => _showMenu(d.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.fromLTRB(16, 1, 8, 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? c.accent.withValues(alpha: 0.18)
                : _hovered
                    ? c.surfaceVariant.withValues(alpha: 0.5)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.folder : Icons.folder_outlined,
                size: 15,
                color: selected ? c.accent : c.subtle,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  widget.folder.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? c.accent : c.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_hovered)
                GestureDetector(
                  onTapDown: (d) => _showMenu(d.globalPosition),
                  child: Icon(Icons.more_horiz, size: 14, color: c.subtle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
