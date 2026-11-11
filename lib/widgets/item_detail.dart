import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../models.dart';
import '../pass_service.dart';
import '../theme.dart';
import 'item_list.dart';
import 'ui.dart';

class ItemDetailPane extends ConsumerWidget {
  /// Leave room for traffic lights (single-pane layout).
  final bool leadingInset;

  /// Shows a back button (single-pane layout).
  final VoidCallback? onBack;

  const ItemDetailPane({super.key, this.leadingInset = false, this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final item = ref.watch(appStateProvider.select((s) => s.selectedItem));

    return Material(
      color: c.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaneHeader(
            border: item != null,
            padding: EdgeInsets.only(left: leadingInset ? kTrafficLightInset : 12, right: 12),
            child: Row(
              children: [
                if (onBack != null)
                  AppIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back  esc', onPressed: onBack),
                const Spacer(),
                if (item != null) _HeaderActions(item: item),
              ],
            ),
          ),
          Expanded(
            child: item == null
                ? const _NoSelection()
                : _ItemDetail(key: ValueKey(item.id), item: item),
          ),
        ],
      ),
    );
  }
}

class _NoSelection extends StatelessWidget {
  const _NoSelection();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.shield_outlined, size: 26, color: c.accentText),
          ),
          const SizedBox(height: 14),
          Text('No item selected',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface)),
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text('Pick one from the list, or press', style: TextStyle(fontSize: 12.5, color: c.subtle)),
              const KeyHint('⌘N'),
              Text('to add one.', style: TextStyle(fontSize: 12.5, color: c.subtle)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Header actions ──────────────────────────────────────────────────────────

String? _launchableUrl(PassItem item) {
  final raw = item.displayUrl.trim();
  if (raw.isEmpty) return null;
  return raw.contains('://') ? raw : 'https://$raw';
}

Future<void> _openUrl(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url)).catchError((_) => false);
  if (!ok && context.mounted) showToast(context, 'Couldn’t open $url', error: true);
}

class _HeaderActions extends ConsumerWidget {
  final PassItem item;
  const _HeaderActions({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final url = _launchableUrl(item);
    final narrow = MediaQuery.sizeOf(context).width < 420;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (url != null) ...[
          AppIconButton(
            icon: Icons.open_in_new_rounded,
            tooltip: 'Open website',
            size: 17,
            onPressed: () => _openUrl(context, url),
          ),
          const SizedBox(width: 4),
        ],
        if (narrow)
          AppIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Edit',
            size: 17,
            onPressed: () => _edit(context),
          )
        else
          AppButton(label: 'Edit', icon: Icons.edit_outlined, dense: true, onPressed: () => _edit(context)),
        const SizedBox(width: 4),
        Builder(
          builder: (btnContext) => AppIconButton(
            icon: Icons.more_horiz_rounded,
            tooltip: 'More',
            onPressed: () async {
              final box = btnContext.findRenderObject() as RenderBox;
              final pos = box.localToGlobal(Offset(0, box.size.height + 4));
              final v = await showMenu<String>(
                context: context,
                position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + box.size.width, pos.dy),
                items: [
                  _menuItem('move', Icons.drive_file_move_outline, 'Move to folder…', c.onSurface),
                  _menuItem('trash', Icons.delete_outline_rounded, 'Move to trash…', c.danger),
                ],
              );
              if (!context.mounted) return;
              if (v == 'move') _showFolderPicker(context, ref, item);
              if (v == 'trash') _confirmTrash(context, ref, item);
            },
          ),
        ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, Color color) =>
      PopupMenuItem(
        value: value,
        height: 36,
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: color)),
        ]),
      );

  void _edit(BuildContext context) =>
      showDialog(context: context, builder: (_) => NewItemDialog(editItem: item));
}

Future<void> _showFolderPicker(BuildContext context, WidgetRef ref, PassItem item) async {
  final state = ref.read(appStateProvider);
  // Only folders in the same vault as this item are valid destinations.
  final folders = state.folders.where((f) => f.shareId == item.shareId).toList();

  final choice = await showDialog<_FolderChoice>(
    context: context,
    builder: (ctx) => AppDialog(
      title: 'Move to folder',
      width: 340,
      actions: [AppButton(label: 'Cancel', onPressed: () => Navigator.of(ctx).pop())],
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.5),
        child: ListView(
          shrinkWrap: true,
          children: [
            _FolderChoiceTile(
              label: 'No folder',
              icon: Icons.inbox_outlined,
              selected: item.folderId == null,
              onTap: () => Navigator.of(ctx).pop(const _FolderChoice.none()),
            ),
            for (final f in folders)
              _FolderChoiceTile(
                label: f.name,
                icon: Icons.folder_outlined,
                selected: item.folderId == f.id,
                onTap: () => Navigator.of(ctx).pop(_FolderChoice(f.id)),
              ),
            if (folders.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Text('This vault has no folders yet. Create one from the sidebar.',
                    style: TextStyle(fontSize: 12, color: ctx.c.subtle)),
              ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || choice.folderId == item.folderId || !context.mounted) return;
  final toastCtx = Navigator.of(context).context;
  try {
    await ref.read(appStateProvider.notifier).moveItemToFolder(item: item, folderId: choice.folderId);
    if (toastCtx.mounted) {
      final name = choice.folderId == null
          ? null
          : folders.firstWhere((f) => f.id == choice.folderId).name;
      showToast(toastCtx, name == null ? 'Removed from folder' : 'Moved to $name');
    }
  } catch (e) {
    if (toastCtx.mounted) showToast(toastCtx, friendlyError(e), error: true);
  }
}

Future<void> _confirmTrash(BuildContext context, WidgetRef ref, PassItem item) async {
  final ok = await confirm(
    context,
    title: 'Move “${item.title}” to trash?',
    message: 'You can restore it from the trash in Proton Pass.',
    confirmLabel: 'Move to trash',
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  final notifier = ref.read(appStateProvider.notifier);
  // This widget disappears once the item is gone; toast from the navigator.
  final toastCtx = Navigator.of(context).context;
  try {
    await notifier.trashItem(item);
    if (toastCtx.mounted) {
      showToast(
        toastCtx,
        '“${item.title}” moved to trash',
        icon: Icons.delete_outline_rounded,
        actionLabel: 'Undo',
        onAction: () => notifier.untrashItem(item).catchError((_) {}),
      );
    }
  } catch (e) {
    if (toastCtx.mounted) showToast(toastCtx, friendlyError(e), error: true);
  }
}

// ── Detail body ─────────────────────────────────────────────────────────────

class _ItemDetail extends ConsumerWidget {
  final PassItem item;
  const _ItemDetail({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final state = ref.watch(appStateProvider);
    final kind = kindOf(item.type);

    final vault = state.vaults.where((v) => v.shareId == item.shareId).firstOrNull;
    final folder = item.folderId == null
        ? null
        : state.folders.where((f) => f.id == item.folderId).firstOrNull;
    final crumbs = [kind.label, if (vault != null) vault.name, if (folder != null) folder.name];

    return LayoutBuilder(builder: (context, box) {
      final hPad = box.maxWidth < 480 ? 16.0 : 32.0;
      return Scrollbar(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      KindChip(kind: kind, size: 44),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title.isEmpty ? 'Untitled' : item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                                color: c.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(crumbs.join('  ·  '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: c.subtle)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ..._sections(context),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      _DateLabel('Modified', item.modifyTime),
                      Text('·', style: TextStyle(fontSize: 11.5, color: c.faint)),
                      _DateLabel('Created', item.createTime),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  List<Widget> _sections(BuildContext context) {
    final out = <Widget>[];
    void section(String? title, List<Widget> rows) {
      if (rows.isEmpty) return;
      out.add(_Section(title: title, children: rows));
    }

    switch (item.type) {
      case ItemType.login:
        final l = item.login;
        if (l != null) {
          section(null, [
            if (l.email.isNotEmpty) _FieldRow(label: 'Email', value: l.email),
            if (l.username.isNotEmpty) _FieldRow(label: 'Username', value: l.username),
            if (l.password.isNotEmpty) _FieldRow(label: 'Password', value: l.password, secret: true, mono: true),
            if (l.totpUri.isNotEmpty) _OtpFieldRow(label: '2FA code', uri: l.totpUri),
            if (l.urls.length == 1) _FieldRow(label: 'Website', value: l.urls.first, link: true),
          ]);
          if (l.urls.length > 1) {
            section('Websites', [
              for (final u in l.urls) _FieldRow(label: 'Website', value: u, link: true),
            ]);
          }
        }
      case ItemType.creditCard:
        final card = item.creditCard;
        if (card != null) {
          section(null, [
            if (card.cardholderName.isNotEmpty) _FieldRow(label: 'Cardholder', value: card.cardholderName),
            if (card.number.isNotEmpty)
              _FieldRow(label: 'Card number', value: card.number, secret: true, mono: true,
                  masked: _maskCard(card.number)),
            if (card.expirationDate.isNotEmpty) _FieldRow(label: 'Expires', value: card.expirationDate),
            if (card.verificationNumber.isNotEmpty)
              _FieldRow(label: 'Security code', value: card.verificationNumber, secret: true, mono: true),
            if (card.pin.isNotEmpty) _FieldRow(label: 'PIN', value: card.pin, secret: true, mono: true),
          ]);
        }
      case ItemType.wifi:
        final w = item.wifi;
        if (w != null) {
          section(null, [
            _FieldRow(label: 'Network name', value: w.ssid),
            if (w.password.isNotEmpty) _FieldRow(label: 'Password', value: w.password, secret: true, mono: true),
            if (w.security.isNotEmpty) _FieldRow(label: 'Security', value: _securityLabel(w.security), copyable: false),
          ]);
        }
      case ItemType.identity:
        final id = item.identity;
        if (id != null) {
          section('Personal', [
            if (id.fullName.isNotEmpty) _FieldRow(label: 'Full name', value: id.fullName),
            if (id.email.isNotEmpty) _FieldRow(label: 'Email', value: id.email),
            if (id.phoneNumber.isNotEmpty) _FieldRow(label: 'Phone', value: id.phoneNumber),
            if (id.birthdate.isNotEmpty) _FieldRow(label: 'Birthdate', value: id.birthdate),
            if (id.gender.isNotEmpty) _FieldRow(label: 'Gender', value: id.gender),
            ...id.extraPersonalDetails.map(_extra),
          ]);
          section('Address', [
            if (id.streetAddress.isNotEmpty) _FieldRow(label: 'Street', value: id.streetAddress),
            if (id.city.isNotEmpty) _FieldRow(label: 'City', value: id.city),
            if (id.zipOrPostalCode.isNotEmpty) _FieldRow(label: 'Postal code', value: id.zipOrPostalCode),
            if (id.stateOrProvince.isNotEmpty) _FieldRow(label: 'State / province', value: id.stateOrProvince),
            if (id.countryOrRegion.isNotEmpty) _FieldRow(label: 'Country', value: id.countryOrRegion),
            ...id.extraAddressDetails.map(_extra),
          ]);
          section('Documents', [
            if (id.passportNumber.isNotEmpty) _FieldRow(label: 'Passport', value: id.passportNumber, secret: true),
            if (id.licenseNumber.isNotEmpty) _FieldRow(label: 'Driving licence', value: id.licenseNumber, secret: true),
            if (id.socialSecurityNumber.isNotEmpty)
              _FieldRow(label: 'Social security number', value: id.socialSecurityNumber, secret: true),
          ]);
          section('Work', [
            if (id.organization.isNotEmpty) _FieldRow(label: 'Organization', value: id.organization),
            if (id.jobTitle.isNotEmpty) _FieldRow(label: 'Job title', value: id.jobTitle),
            if (id.workEmail.isNotEmpty) _FieldRow(label: 'Work email', value: id.workEmail),
            ...id.extraWorkDetails.map(_extra),
          ]);
          section('Contact', id.extraContactDetails.map(_extra).toList());
        }
      default:
        break;
    }

    if (item.note.isNotEmpty) {
      out.add(_Section(
        title: item.type == ItemType.note ? null : 'Note',
        children: [_NoteBody(note: item.note)],
      ));
    }
    section('Custom fields', item.extraFields.map(_extra).toList());
    return out;
  }

  Widget _extra(ExtraField f) => f.type == ExtraFieldType.totp
      ? _OtpFieldRow(label: f.name, uri: f.value)
      : _FieldRow(label: f.name, value: f.value, secret: f.type == ExtraFieldType.hidden);

  static String _maskCard(String n) {
    final digits = n.replaceAll(' ', '');
    return digits.length >= 4 ? '••••  ••••  ••••  ${digits.substring(digits.length - 4)}' : '••••';
  }

  static String _securityLabel(String s) => switch (s) {
        'wpa3' => 'WPA3',
        'wpa2' => 'WPA2',
        'wpa' => 'WPA',
        'wep' => 'WEP',
        'open' => 'Open',
        'none' => 'None',
        _ => s.toUpperCase(),
      };

}

/// "Modified 3 days ago", with the exact date on hover.
class _DateLabel extends StatelessWidget {
  final String label;
  final DateTime date;
  const _DateLabel(this.label, this.date);

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String relative(DateTime d, [DateTime? now]) {
    now ??= DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final days = today.difference(day).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 7) return '$days days ago';
    if (days < 30) {
      final w = days ~/ 7;
      return w == 1 ? 'a week ago' : '$w weeks ago';
    }
    final months = (now.year - d.year) * 12 + now.month - d.month - (now.day < d.day ? 1 : 0);
    if (months < 12) return months <= 1 ? 'a month ago' : '$months months ago';
    final years = months ~/ 12;
    return years == 1 ? 'a year ago' : '$years years ago';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: '${date.day} ${_months[date.month - 1]} ${date.year}',
      child: Text('$label ${relative(date)}', style: TextStyle(fontSize: 11.5, color: c.faint)),
    );
  }
}

/// A titled card of rows separated by hairlines.
class _Section extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  const _Section({this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) SectionLabel(title!),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, color: c.border, indent: 14),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One field. Click anywhere on the row to copy; secrets are masked until
/// revealed and auto-clear from the clipboard.
class _FieldRow extends StatefulWidget {
  final String label;
  final String value;
  final bool secret;
  final bool mono;
  final bool link;
  final bool copyable;
  final String? masked;
  const _FieldRow({
    required this.label,
    required this.value,
    this.secret = false,
    this.mono = false,
    this.link = false,
    this.copyable = true,
    this.masked,
  });

  @override
  State<_FieldRow> createState() => _FieldRowState();
}

class _FieldRowState extends State<_FieldRow> {
  bool _revealed = false;

  void _copy() => copyToClipboard(context, widget.value, label: widget.label, secret: widget.secret);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final hidden = widget.secret && !_revealed;
    final shown = hidden ? (widget.masked ?? '•' * widget.value.length.clamp(8, 14)) : widget.value;

    return HoverBuilder(
      cursor: widget.copyable ? SystemMouseCursors.click : MouseCursor.defer,
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.copyable ? _copy : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          color: hovered && widget.copyable ? c.surfaceVariant.withValues(alpha: 0.45) : Colors.transparent,
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label, style: TextStyle(fontSize: 11.5, color: c.subtle)),
                    const SizedBox(height: 3),
                    Text(
                      shown,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.3,
                        color: widget.link ? c.accentText : c.onSurface,
                        fontFamily: widget.mono && !hidden ? 'Menlo' : null,
                        letterSpacing: hidden ? 1.5 : 0,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.secret)
                AppIconButton(
                  icon: _revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  tooltip: _revealed ? 'Hide' : 'Reveal',
                  size: 16,
                  onPressed: () => setState(() => _revealed = !_revealed),
                ),
              if (widget.link)
                AppIconButton(
                  icon: Icons.open_in_new_rounded,
                  tooltip: 'Open',
                  size: 16,
                  onPressed: () => _openUrl(
                      context, widget.value.contains('://') ? widget.value : 'https://${widget.value}'),
                ),
              if (widget.copyable)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 100),
                  opacity: hovered ? 1 : 0.55,
                  child: AppIconButton(
                    icon: Icons.content_copy_rounded,
                    tooltip: 'Copy',
                    size: 15,
                    onPressed: _copy,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteBody extends StatelessWidget {
  final String note;
  const _NoteBody({required this.note});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: SelectableText(note, style: TextStyle(fontSize: 13.5, height: 1.5, color: c.onSurface)),
    );
  }
}

// ── TOTP ────────────────────────────────────────────────────────────────────

int _totpPeriodFromUri(String uri) {
  if (!uri.startsWith('otpauth://')) return 30;
  try {
    return int.tryParse(Uri.parse(uri).queryParameters['period'] ?? '') ?? 30;
  } catch (_) {
    return 30;
  }
}

class _OtpFieldRow extends StatefulWidget {
  final String label;
  final String uri;
  const _OtpFieldRow({required this.label, required this.uri});

  @override
  State<_OtpFieldRow> createState() => _OtpFieldRowState();
}

class _OtpFieldRowState extends State<_OtpFieldRow> {
  final PassService _svc = PassService();
  String? _code;
  Timer? _ticker;
  late int _period;
  int _remaining = 30;

  @override
  void initState() {
    super.initState();
    _period = _totpPeriodFromUri(widget.uri);
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

  void _copy() {
    if (_code == null) return;
    copyToClipboard(context, _code!, label: widget.label, secret: true);
  }

  String _formatted(String code) {
    if (code.length == 6) return '${code.substring(0, 3)} ${code.substring(3)}';
    if (code.length == 8) return '${code.substring(0, 4)} ${code.substring(4)}';
    return code;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final progress = _remaining / _period;
    final ringColor = _remaining <= 5 ? c.danger : c.accent;

    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _copy,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          color: hovered ? c.surfaceVariant.withValues(alpha: 0.45) : Colors.transparent,
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label, style: TextStyle(fontSize: 11.5, color: c.subtle)),
                    const SizedBox(height: 3),
                    Text(
                      _code == null ? '••• •••' : _formatted(_code!),
                      style: TextStyle(
                        fontSize: 17,
                        fontFamily: 'Menlo',
                        fontWeight: FontWeight.w600,
                        color: _remaining <= 5 ? c.danger : c.onSurface,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 24,
                height: 24,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 2,
                      backgroundColor: c.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation(ringColor),
                    ),
                    Text('$_remaining', style: TextStyle(fontSize: 9.5, color: c.subtle)),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 100),
                opacity: hovered ? 1 : 0.55,
                child: AppIconButton(
                  icon: Icons.content_copy_rounded,
                  tooltip: 'Copy',
                  size: 15,
                  onPressed: _copy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Folder picker bits ──────────────────────────────────────────────────────

class _FolderChoice {
  final String? folderId;
  const _FolderChoice(this.folderId);
  const _FolderChoice.none() : folderId = null;
}

class _FolderChoiceTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _FolderChoiceTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 34,
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? c.accentSoft
                : hovered
                    ? c.surfaceVariant
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: selected ? c.accentText : c.subtle),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? c.accentText : c.onSurface)),
            ),
            if (selected) Icon(Icons.check_rounded, size: 16, color: c.accentText),
          ]),
        ),
      ),
    );
  }
}
