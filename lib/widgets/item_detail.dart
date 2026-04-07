import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_state.dart';
import '../main.dart';
import '../models.dart';
import 'item_list.dart';

class ItemDetailPane extends ConsumerWidget {
  const ItemDetailPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<ProtonifyColors>()!;
    final state = ref.watch(appStateProvider);
    final item = state.selectedItem;

    if (item == null) {
      return Container(
        color: c.background,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 48, color: c.subtle),
              const SizedBox(height: 12),
              Text('Select an item',
                  style: TextStyle(color: c.subtle, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Container(
      color: c.background,
      child: _ItemDetail(item: item, c: c),
    );
  }
}

class _ItemDetail extends StatelessWidget {
  final PassItem item;
  final ProtonifyColors c;
  const _ItemDetail({required this.item, required this.c});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 64, 28, 28),
      children: [
        _Header(item: item, c: c),
        const SizedBox(height: 24),
        if (item.type == ItemType.login && item.login != null)
          _LoginFields(login: item.login!, c: c),
        if (item.type == ItemType.creditCard && item.creditCard != null)
          _CreditCardFields(card: item.creditCard!, c: c),
        if (item.type == ItemType.identity && item.identity != null)
          _IdentityFields(identity: item.identity!, c: c),
        if (item.note.isNotEmpty) ...[
          _SectionLabel('Notes', c),
          const SizedBox(height: 6),
          _NoteCard(note: item.note, c: c),
        ],
        if (item.extraFields.isNotEmpty) ...[
          _SectionLabel('Custom Fields', c),
          const SizedBox(height: 6),
          ...item.extraFields.map((f) => _FieldRow(
                label: f.name,
                value: f.value,
                c: c,
              )),
        ],
        const SizedBox(height: 24),
        _MetaRow('Created', _formatDate(item.createTime), c),
        _MetaRow('Modified', _formatDate(item.modifyTime), c),
      ],
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day} ${_month(d.month)} ${d.year}';
  }

  String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];
}

class _Header extends ConsumerWidget {
  final PassItem item;
  final ProtonifyColors c;
  const _Header({required this.item, required this.c});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _iconColor(item.type),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_iconData(item.type), size: 24, color: Colors.white),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: c.onSurface)),
              if (item.displayUrl.isNotEmpty)
                Text(item.displayUrl,
                    style: TextStyle(fontSize: 12, color: c.subtle),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.edit_outlined, size: 17, color: c.subtle),
          tooltip: 'Edit',
          onPressed: () => showDialog(
            context: context,
            builder: (_) => NewItemDialog(editItem: item),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(Icons.delete_outline, size: 18, color: c.subtle),
          tooltip: 'Move to Trash',
          onPressed: () => _confirmTrash(context, ref),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Future<void> _confirmTrash(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Move to Trash?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          '"${item.title}" will be moved to the trash. You can restore it later.',
          style: const TextStyle(color: Color(0xFFAEAEB2), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6D4AFF))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move to Trash',
                style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(appStateProvider.notifier).trashItem(item);
    }
  }

  Color _iconColor(ItemType t) => switch (t) {
        ItemType.login => const Color(0xFF4A6FFF),
        ItemType.note => const Color(0xFFFF9500),
        ItemType.creditCard => const Color(0xFF34C759),
        ItemType.identity => const Color(0xFFFF375F),
        ItemType.alias => const Color(0xFF5AC8FA),
        _ => const Color(0xFF6D4AFF),
      };

  IconData _iconData(ItemType t) => switch (t) {
        ItemType.login => Icons.language,
        ItemType.note => Icons.notes,
        ItemType.creditCard => Icons.credit_card,
        ItemType.identity => Icons.person_outline,
        ItemType.alias => Icons.alternate_email,
        _ => Icons.key_outlined,
      };
}

class _LoginFields extends StatelessWidget {
  final LoginContent login;
  final ProtonifyColors c;
  const _LoginFields({required this.login, required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Login Details', c),
        const SizedBox(height: 6),
        if (login.email.isNotEmpty)
          _FieldRow(label: 'Email / Username', value: login.email, c: c),
        if (login.username.isNotEmpty)
          _FieldRow(label: 'Username', value: login.username, c: c),
        _PasswordRow(password: login.password, c: c),
        if (login.urls.isNotEmpty)
          _FieldRow(label: 'Website', value: login.urls.first, c: c),
        if (login.totpUri.isNotEmpty)
          _FieldRow(label: 'TOTP URI', value: login.totpUri, c: c, obscure: false),
      ],
    );
  }
}

class _CreditCardFields extends StatelessWidget {
  final CreditCardContent card;
  final ProtonifyColors c;
  const _CreditCardFields({required this.card, required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Card Details', c),
        const SizedBox(height: 6),
        if (card.cardholderName.isNotEmpty)
          _FieldRow(label: 'Cardholder', value: card.cardholderName, c: c),
        if (card.number.isNotEmpty)
          _FieldRow(label: 'Card Number', value: card.number, c: c),
        if (card.expirationDate.isNotEmpty)
          _FieldRow(label: 'Expiry', value: card.expirationDate, c: c),
        if (card.verificationNumber.isNotEmpty)
          _FieldRow(label: 'CVV', value: card.verificationNumber, c: c),
        if (card.pin.isNotEmpty)
          _FieldRow(label: 'PIN', value: card.pin, c: c),
      ],
    );
  }
}

class _IdentityFields extends StatelessWidget {
  final IdentityContent identity;
  final ProtonifyColors c;
  const _IdentityFields({required this.identity, required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Personal', c),
        const SizedBox(height: 6),
        if (identity.fullName.isNotEmpty)
          _FieldRow(label: 'Full Name', value: identity.fullName, c: c),
        if (identity.email.isNotEmpty)
          _FieldRow(label: 'Email', value: identity.email, c: c),
        if (identity.phoneNumber.isNotEmpty)
          _FieldRow(label: 'Phone', value: identity.phoneNumber, c: c),
        if (identity.birthdate.isNotEmpty)
          _FieldRow(label: 'Birthdate', value: identity.birthdate, c: c),
        if (identity.gender.isNotEmpty)
          _FieldRow(label: 'Gender', value: identity.gender, c: c),
        ...identity.extraPersonalDetails.map((f) => _FieldRow(label: f.name, value: f.value, c: c)),
        if (_hasAddress(identity)) ...[
          _SectionLabel('Address', c),
          const SizedBox(height: 6),
          if (identity.streetAddress.isNotEmpty)
            _FieldRow(label: 'Street', value: identity.streetAddress, c: c),
          if (identity.city.isNotEmpty)
            _FieldRow(label: 'City', value: identity.city, c: c),
          if (identity.zipOrPostalCode.isNotEmpty)
            _FieldRow(label: 'Postal Code', value: identity.zipOrPostalCode, c: c),
          if (identity.stateOrProvince.isNotEmpty)
            _FieldRow(label: 'State / Province', value: identity.stateOrProvince, c: c),
          if (identity.countryOrRegion.isNotEmpty)
            _FieldRow(label: 'Country', value: identity.countryOrRegion, c: c),
          ...identity.extraAddressDetails.map((f) => _FieldRow(label: f.name, value: f.value, c: c)),
        ],
        if (_hasId(identity)) ...[
          _SectionLabel('IDs', c),
          const SizedBox(height: 6),
          if (identity.passportNumber.isNotEmpty)
            _FieldRow(label: 'Passport', value: identity.passportNumber, c: c),
          if (identity.licenseNumber.isNotEmpty)
            _FieldRow(label: 'License', value: identity.licenseNumber, c: c),
          if (identity.socialSecurityNumber.isNotEmpty)
            _FieldRow(label: 'SSN', value: identity.socialSecurityNumber, c: c),
        ],
        if (_hasWork(identity)) ...[
          _SectionLabel('Work', c),
          const SizedBox(height: 6),
          if (identity.organization.isNotEmpty)
            _FieldRow(label: 'Organization', value: identity.organization, c: c),
          if (identity.jobTitle.isNotEmpty)
            _FieldRow(label: 'Job Title', value: identity.jobTitle, c: c),
          if (identity.workEmail.isNotEmpty)
            _FieldRow(label: 'Work Email', value: identity.workEmail, c: c),
          ...identity.extraWorkDetails.map((f) => _FieldRow(label: f.name, value: f.value, c: c)),
        ],
        if (identity.extraContactDetails.isNotEmpty) ...[
          _SectionLabel('Contact Details', c),
          const SizedBox(height: 6),
          ...identity.extraContactDetails.map((f) => _FieldRow(label: f.name, value: f.value, c: c)),
        ],
      ],
    );
  }

  bool _hasAddress(IdentityContent id) =>
      id.streetAddress.isNotEmpty || id.city.isNotEmpty ||
      id.countryOrRegion.isNotEmpty || id.extraAddressDetails.isNotEmpty;

  bool _hasId(IdentityContent id) =>
      id.passportNumber.isNotEmpty || id.licenseNumber.isNotEmpty ||
      id.socialSecurityNumber.isNotEmpty;

  bool _hasWork(IdentityContent id) =>
      id.organization.isNotEmpty || id.jobTitle.isNotEmpty ||
      id.workEmail.isNotEmpty || id.extraWorkDetails.isNotEmpty;
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final ProtonifyColors c;
  const _SectionLabel(this.text, this.c);

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(),
        style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
            color: c.subtle));
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final String value;
  final ProtonifyColors c;
  final bool obscure;
  const _FieldRow(
      {required this.label,
      required this.value,
      required this.c,
      this.obscure = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 10, color: c.subtle)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 13, color: c.onSurface)),
              ],
            ),
          ),
          _CopyButton(value: value, c: c),
        ],
      ),
    );
  }
}

class _PasswordRow extends StatefulWidget {
  final String password;
  final ProtonifyColors c;
  const _PasswordRow({required this.password, required this.c});

  @override
  State<_PasswordRow> createState() => _PasswordRowState();
}

class _PasswordRowState extends State<_PasswordRow> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: widget.c.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Password',
                    style: TextStyle(fontSize: 10, color: widget.c.subtle)),
                const SizedBox(height: 2),
                Text(
                  _visible ? widget.password : '•' * widget.password.length.clamp(8, 16),
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.c.onSurface,
                    letterSpacing: _visible ? 0 : 2,
                    fontFamily: _visible ? null : 'monospace',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 16,
              color: widget.c.subtle,
            ),
            onPressed: () => setState(() => _visible = !_visible),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          _CopyButton(value: widget.password, c: widget.c),
        ],
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  final String value;
  final ProtonifyColors c;
  const _CopyButton({required this.value, required this.c});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _copied ? Icons.check : Icons.copy_outlined,
        size: 15,
        color: _copied ? const Color(0xFF34C759) : widget.c.subtle,
      ),
      onPressed: _copy,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final String note;
  final ProtonifyColors c;
  const _NoteCard({required this.note, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(note,
          style: TextStyle(fontSize: 13, color: c.onSurface)),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  final ProtonifyColors c;
  const _MetaRow(this.label, this.value, this.c);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: c.subtle)),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(fontSize: 11, color: c.subtle)),
        ],
      ),
    );
  }
}
