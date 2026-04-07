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
  _NavItem(label: 'SSH Keys',    icon: Icons.key_outlined,     category: ItemType.sshKey,     color: Color(0xFFBF5AF2)),
];

class VaultSidebar extends ConsumerWidget {
  const VaultSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<ProtonifyColors>()!;
    final state = ref.watch(appStateProvider);

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
                children: _navItems
                    .map((nav) => _NavTile(nav: nav))
                    .toList(),
              ),
            ),
        ],
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
    final selected = state.selectedCategory == widget.nav.category;

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
