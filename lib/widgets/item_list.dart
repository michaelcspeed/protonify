import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_state.dart';
import '../main.dart';
import '../models.dart';

String _categoryLabel(ItemType? category) {
  switch (category) {
    case ItemType.login:      return 'LOGINS';
    case ItemType.alias:      return 'ALIASES';
    case ItemType.creditCard: return 'CARDS';
    case ItemType.identity:   return 'IDENTITIES';
    case ItemType.note:       return 'NOTES';
    case ItemType.sshKey:     return 'SSH KEYS';
    case null:                return 'ALL ITEMS';
    default:                  return 'ITEMS';
  }
}

class ItemListPane extends ConsumerWidget {
  const ItemListPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<ProtonifyColors>()!;
    final state = ref.watch(appStateProvider);

    return Container(
      color: c.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
            child: Row(
              children: [
                Text(
                  _categoryLabel(state.selectedCategory),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const Spacer(),
                if (!state.loadingItems)
                  Text('${state.filteredItems.length}',
                      style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(width: 6),
                _NewItemButton(c: c),
              ],
            ),
          ),
          Expanded(child: _ItemListBody(c: c)),
        ],
      ),
    );
  }
}

class _NewItemButton extends StatefulWidget {
  final ProtonifyColors c;
  const _NewItemButton({required this.c});

  @override
  State<_NewItemButton> createState() => _NewItemButtonState();
}

class _NewItemButtonState extends State<_NewItemButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) => const NewItemDialog(),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: _hovered
                ? widget.c.accent.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.add, size: 16, color: widget.c.subtle),
        ),
      ),
    );
  }
}

class _ItemListBody extends ConsumerWidget {
  final ProtonifyColors c;
  const _ItemListBody({required this.c});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);

    if (state.loadingItems) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(state.error!,
              style: TextStyle(color: c.subtle, fontSize: 12)),
        ),
      );
    }

    final items = state.filteredItems;
    if (items.isEmpty) {
      return Center(
          child: Text('No items', style: TextStyle(color: c.subtle)));
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (ctx, i) => _ItemRow(item: items[i], c: c),
    );
  }
}

class _ItemRow extends ConsumerStatefulWidget {
  final PassItem item;
  final ProtonifyColors c;
  const _ItemRow({required this.item, required this.c});

  @override
  ConsumerState<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends ConsumerState<_ItemRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final selected = state.selectedItem?.id == widget.item.id;
    final c = widget.c;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () =>
            ref.read(appStateProvider.notifier).selectItem(widget.item),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? c.accent.withValues(alpha: 0.2)
                : _hovered
                    ? c.surfaceVariant.withValues(alpha: 0.6)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _ItemIcon(item: widget.item, selected: selected, c: c),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: selected ? c.accent : c.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.item.displayUsername.isNotEmpty)
                      Text(
                        widget.item.displayUsername,
                        style: TextStyle(fontSize: 11, color: c.subtle),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemIcon extends StatelessWidget {
  final PassItem item;
  final bool selected;
  final ProtonifyColors c;
  const _ItemIcon({required this.item, required this.selected, required this.c});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color bg;

    switch (item.type) {
      case ItemType.login:
        icon = Icons.language;
        bg = const Color(0xFF4A6FFF);
      case ItemType.note:
        icon = Icons.notes;
        bg = const Color(0xFFFF9500);
      case ItemType.creditCard:
        icon = Icons.credit_card;
        bg = const Color(0xFF34C759);
      case ItemType.identity:
        icon = Icons.person_outline;
        bg = const Color(0xFFFF375F);
      case ItemType.alias:
        icon = Icons.alternate_email;
        bg = const Color(0xFF5AC8FA);
      default:
        icon = Icons.key_outlined;
        bg = c.surfaceVariant;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bg.withValues(alpha: selected ? 1.0 : 0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }
}

class _NewItemType {
  final String label;
  final IconData icon;
  final Color color;
  final ItemType type;
  const _NewItemType({required this.label, required this.icon, required this.color, required this.type});
}

const _newItemTypes = [
  _NewItemType(label: 'Login',    icon: Icons.language,        color: Color(0xFF4A6FFF), type: ItemType.login),
  _NewItemType(label: 'Alias',    icon: Icons.alternate_email, color: Color(0xFF5AC8FA), type: ItemType.alias),
  _NewItemType(label: 'Card',     icon: Icons.credit_card,     color: Color(0xFF34C759), type: ItemType.creditCard),
  _NewItemType(label: 'Identity', icon: Icons.person_outline,  color: Color(0xFFFF375F), type: ItemType.identity),
  _NewItemType(label: 'Note',     icon: Icons.notes,           color: Color(0xFFFF9500), type: ItemType.note),
  _NewItemType(label: 'SSH Key',  icon: Icons.key_outlined,    color: Color(0xFFBF5AF2), type: ItemType.sshKey),
];

// ── Dialog shell ─────────────────────────────────────────────────────────────

class NewItemDialog extends StatefulWidget {
  final PassItem? editItem;
  const NewItemDialog({super.key, this.editItem});

  @override
  State<NewItemDialog> createState() => _NewItemDialogState();
}

class _NewItemDialogState extends State<NewItemDialog> {
  _NewItemType? _selected;

  @override
  void initState() {
    super.initState();
    if (widget.editItem != null) {
      _selected = _newItemTypes.cast<_NewItemType?>().firstWhere(
        (t) => t!.type == widget.editItem!.type,
        orElse: () => null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ProtonifyColors>()!;
    final isEdit = widget.editItem != null;

    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 380,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutQuart,
          alignment: Alignment.topCenter,
          child: _selected == null
              ? _TypePicker(c: c, onPick: (t) => setState(() => _selected = t))
              : _CreationForm(
                  type: _selected!,
                  c: c,
                  editItem: widget.editItem,
                  onBack: isEdit ? null : () => setState(() => _selected = null),
                ),
        ),
      ),
    );
  }
}

// ── Type picker ───────────────────────────────────────────────────────────────

class _TypePicker extends StatelessWidget {
  final ProtonifyColors c;
  final void Function(_NewItemType) onPick;
  const _TypePicker({required this.c, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New item',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.onSurface)),
          const SizedBox(height: 4),
          Text('Choose a type', style: TextStyle(fontSize: 12, color: c.subtle)),
          const SizedBox(height: 16),
          ..._newItemTypes.map((t) => _TypeTile(type: t, c: c, onTap: () => onPick(t))),
        ],
      ),
    );
  }
}

class _TypeTile extends StatefulWidget {
  final _NewItemType type;
  final ProtonifyColors c;
  final VoidCallback onTap;
  const _TypeTile({required this.type, required this.c, required this.onTap});

  @override
  State<_TypeTile> createState() => _TypeTileState();
}

class _TypeTileState extends State<_TypeTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: _hovered ? widget.c.surfaceVariant.withValues(alpha: 0.7) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: widget.type.color, borderRadius: BorderRadius.circular(7)),
                child: Icon(widget.type.icon, size: 15, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(widget.type.label,
                  style: TextStyle(fontSize: 13, color: widget.c.onSurface)),
              const Spacer(),
              Icon(Icons.chevron_right, size: 16, color: widget.c.subtle),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Creation form ─────────────────────────────────────────────────────────────

class _CreationForm extends ConsumerStatefulWidget {
  final _NewItemType type;
  final ProtonifyColors c;
  final PassItem? editItem;
  final VoidCallback? onBack;
  const _CreationForm({required this.type, required this.c, this.editItem, this.onBack});

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

  bool get _isEdit => widget.editItem != null;

  @override
  void initState() {
    super.initState();
    final item = widget.editItem;
    if (item != null) {
      _title.text = item.title;
      _note.text = item.note;
      // Find the vault name from vaults list using vaultId
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
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _note, _email, _username, _password, _url,
                     _cardholderName, _cardNumber, _cvv, _expirationDate, _pin]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEdit && _selectedVault == null) {
      setState(() => _error = 'Please select a vault');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      final notifier = ref.read(appStateProvider.notifier);
      if (_isEdit) {
        final fields = <String, String>{};
        fields['title'] = _title.text.trim();
        fields['note'] = _note.text.trim();
        switch (widget.type.type) {
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
          case ItemType.note:
            break;
          default:
            break;
        }
        await notifier.updateItem(item: widget.editItem!, fields: fields);
      } else {
        switch (widget.type.type) {
          case ItemType.login:
            await notifier.createLogin(
              vaultName: _selectedVault!,
              title: _title.text.trim(),
              email: _email.text.trim(),
              username: _username.text.trim(),
              password: _password.text,
              url: _url.text.trim(),
            );
          case ItemType.note:
            await notifier.createNote(
              vaultName: _selectedVault!,
              title: _title.text.trim(),
              note: _note.text.trim(),
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
            );
          default:
            break;
        }
        ref.read(appStateProvider.notifier).loadVaults();
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vaults = ref.watch(appStateProvider).vaults;
    final c = widget.c;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header
            Row(
              children: [
                if (widget.onBack != null) ...[
                  GestureDetector(
                    onTap: widget.onBack,
                    child: Icon(Icons.arrow_back_ios_new, size: 14, color: c.subtle),
                  ),
                  const SizedBox(width: 10),
                ],
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(color: widget.type.color, borderRadius: BorderRadius.circular(6)),
                  child: Icon(widget.type.icon, size: 13, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text(_isEdit ? 'Edit ${widget.type.label}' : 'New ${widget.type.label}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: widget.c.onSurface)),
              ],
            ),
            const SizedBox(height: 20),
            // vault picker (only for new items)
            if (!_isEdit) ...[
              _FormLabel('Vault', c),
              const SizedBox(height: 6),
              _VaultDropdown(
                vaults: vaults,
                value: _selectedVault,
                c: c,
                onChanged: (v) => setState(() => _selectedVault = v),
              ),
              const SizedBox(height: 12),
            ],
            // title (all types)
            _FormLabel('Title', c),
            const SizedBox(height: 6),
            _Field(controller: _title, hint: 'Title', c: c,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
            // type-specific fields
            ..._typeFields(c),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFFF375F))),
            ],
            const SizedBox(height: 20),
            // actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _DialogButton(label: 'Cancel', c: c, onTap: () => Navigator.of(context).pop()),
                const SizedBox(width: 8),
                _DialogButton(
                  label: _submitting ? 'Saving…' : 'Save',
                  c: c,
                  primary: true,
                  onTap: _submitting ? null : _submit,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }

  List<Widget> _typeFields(ProtonifyColors c) {
    switch (widget.type.type) {
      case ItemType.login:
        return [
          const SizedBox(height: 12),
          _FormLabel('Email', c),
          const SizedBox(height: 6),
          _Field(controller: _email, hint: 'email@example.com', c: c, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _FormLabel('Username', c),
          const SizedBox(height: 6),
          _Field(controller: _username, hint: 'username', c: c),
          const SizedBox(height: 12),
          _FormLabel('Password', c),
          const SizedBox(height: 6),
          _Field(controller: _password, hint: '••••••••', c: c, obscure: true),
          const SizedBox(height: 12),
          _FormLabel('URL', c),
          const SizedBox(height: 6),
          _Field(controller: _url, hint: 'https://', c: c, keyboardType: TextInputType.url),
        ];
      case ItemType.note:
        return [
          const SizedBox(height: 12),
          _FormLabel('Note', c),
          const SizedBox(height: 6),
          _Field(controller: _note, hint: 'Note content', c: c, maxLines: 4),
        ];
      case ItemType.creditCard:
        return [
          const SizedBox(height: 12),
          _FormLabel('Cardholder name', c),
          const SizedBox(height: 6),
          _Field(controller: _cardholderName, hint: 'Name on card', c: c),
          const SizedBox(height: 12),
          _FormLabel('Card number', c),
          const SizedBox(height: 6),
          _Field(controller: _cardNumber, hint: '•••• •••• •••• ••••', c: c, keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _FormLabel('Expiry (YYYY-MM)', c),
              const SizedBox(height: 6),
              _Field(controller: _expirationDate, hint: '2027-12', c: c),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _FormLabel('CVV', c),
              const SizedBox(height: 6),
              _Field(controller: _cvv, hint: '•••', c: c, obscure: true, keyboardType: TextInputType.number),
            ])),
          ]),
          const SizedBox(height: 12),
          _FormLabel('PIN', c),
          const SizedBox(height: 6),
          _Field(controller: _pin, hint: '••••', c: c, obscure: true, keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          _FormLabel('Note', c),
          const SizedBox(height: 6),
          _Field(controller: _note, hint: 'Optional note', c: c, maxLines: 2),
        ];
      default:
        return [
          const SizedBox(height: 12),
          Text('Creation for this type is not yet supported.',
              style: TextStyle(fontSize: 12, color: widget.c.subtle)),
        ];
    }
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _FormLabel extends StatelessWidget {
  final String text;
  final ProtonifyColors c;
  const _FormLabel(this.text, this.c);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(fontSize: 11, color: c.subtle));
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ProtonifyColors c;
  final bool obscure;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.hint,
    required this.c,
    this.obscure = false,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      maxLines: obscure ? 1 : maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(fontSize: 13, color: c.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: c.subtle),
        filled: true,
        fillColor: c.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.accent.withValues(alpha: 0.6), width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFF375F), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFF375F), width: 1),
        ),
        errorStyle: const TextStyle(fontSize: 10),
      ),
    );
  }
}

class _VaultDropdown extends StatelessWidget {
  final List<Vault> vaults;
  final String? value;
  final ProtonifyColors c;
  final void Function(String?) onChanged;
  const _VaultDropdown({required this.vaults, required this.value, required this.c, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text('Select vault', style: TextStyle(fontSize: 13, color: c.subtle)),
          dropdownColor: c.surfaceVariant,
          style: TextStyle(fontSize: 13, color: c.onSurface),
          icon: Icon(Icons.expand_more, size: 16, color: c.subtle),
          items: vaults.map((v) => DropdownMenuItem(value: v.name, child: Text(v.name))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _DialogButton extends StatefulWidget {
  final String label;
  final ProtonifyColors c;
  final bool primary;
  final VoidCallback? onTap;
  const _DialogButton({required this.label, required this.c, this.primary = false, this.onTap});

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.primary
        ? (widget.onTap == null ? widget.c.accent.withValues(alpha: 0.4) : widget.c.accent)
        : Colors.transparent;
    final border = widget.primary ? BorderSide.none : BorderSide(color: widget.c.subtle.withValues(alpha: 0.3));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered && widget.onTap != null
                ? (widget.primary ? widget.c.accent.withValues(alpha: 0.85) : widget.c.surfaceVariant)
                : bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.fromBorderSide(border),
          ),
          child: Text(widget.label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.primary ? FontWeight.w600 : FontWeight.normal,
                  color: widget.primary ? Colors.white : widget.c.onSurface)),
        ),
      ),
    );
  }
}
