import 'dart:convert';
import 'dart:io';
import 'models.dart';

enum SetupStatus { checking, cliNotFound, notLoggedIn, ready }

class PassService {
  static const _cli = '/Users/mike/.local/bin/pass-cli';

  /// Check if the CLI binary exists on disk.
  Future<bool> isCliInstalled() async {
    return File(_cli).exists();
  }

  /// Try a lightweight command to see if the user is logged in.
  /// Returns true if the CLI responds successfully (user is authenticated).
  Future<bool> isLoggedIn() async {
    try {
      final result = await Process.run(_cli, ['vault', 'list', '--output', 'json']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Run the full setup check and return the current status.
  Future<SetupStatus> checkSetup() async {
    if (!await isCliInstalled()) return SetupStatus.cliNotFound;
    if (!await isLoggedIn()) return SetupStatus.notLoggedIn;
    return SetupStatus.ready;
  }

  Future<List<Vault>> listVaults() async {
    final result = await _run(['vault', 'list', '--output', 'json']);
    final data = jsonDecode(result) as Map<String, dynamic>;
    final vaults = (data['vaults'] as List<dynamic>)
        .map((v) => Vault.fromJson(v as Map<String, dynamic>))
        .toList();
    return vaults;
  }

  Future<List<PassItem>> listItems(String vaultName) async {
    final result = await _run(['item', 'list', vaultName, '--output', 'json']);
    final data = jsonDecode(result) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>)
        .map((i) => PassItem.fromJson(i as Map<String, dynamic>))
        .toList();
    items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return items;
  }

  Future<void> createLogin({
    required String vaultName,
    required String title,
    String? email,
    String? username,
    String? password,
    String? url,
  }) async {
    await _run([
      'item', 'create', 'login',
      '--vault-name', vaultName,
      '--title', title,
      if (email != null && email.isNotEmpty) ...['--email', email],
      if (username != null && username.isNotEmpty) ...['--username', username],
      if (password != null && password.isNotEmpty) ...['--password', password],
      if (url != null && url.isNotEmpty) ...['--url', url],
    ]);
  }

  Future<void> createNote({
    required String vaultName,
    required String title,
    String? note,
  }) async {
    await _run([
      'item', 'create', 'note',
      '--vault-name', vaultName,
      '--title', title,
      if (note != null && note.isNotEmpty) ...['--note', note],
    ]);
  }

  Future<void> createCreditCard({
    required String vaultName,
    required String title,
    String? cardholderName,
    String? number,
    String? cvv,
    String? expirationDate,
    String? pin,
    String? note,
  }) async {
    await _run([
      'item', 'create', 'credit-card',
      '--vault-name', vaultName,
      '--title', title,
      if (cardholderName != null && cardholderName.isNotEmpty) ...['--cardholder-name', cardholderName],
      if (number != null && number.isNotEmpty) ...['--number', number],
      if (cvv != null && cvv.isNotEmpty) ...['--cvv', cvv],
      if (expirationDate != null && expirationDate.isNotEmpty) ...['--expiration-date', expirationDate],
      if (pin != null && pin.isNotEmpty) ...['--pin', pin],
      if (note != null && note.isNotEmpty) ...['--note', note],
    ]);
  }

  Future<void> updateItem({
    required String shareId,
    required String itemId,
    required Map<String, String> fields,
  }) async {
    await _run([
      'item', 'update',
      '--share-id', shareId,
      '--item-id', itemId,
      for (final entry in fields.entries) ...['--field', '${entry.key}=${entry.value}'],
    ]);
  }

  Future<void> trashItem({
    required String shareId,
    required String itemId,
  }) async {
    await _run([
      'item', 'trash',
      '--share-id', shareId,
      '--item-id', itemId,
    ]);
  }

  Future<void> untrashItem({
    required String shareId,
    required String itemId,
  }) async {
    await _run([
      'item', 'untrash',
      '--share-id', shareId,
      '--item-id', itemId,
    ]);
  }

  Future<void> deleteItem({
    required String shareId,
    required String itemId,
  }) async {
    await _run([
      'item', 'delete',
      '--share-id', shareId,
      '--item-id', itemId,
    ]);
  }

  Future<String> _run(List<String> args) async {
    final result = await Process.run(_cli, args);
    if (result.exitCode != 0) {
      throw Exception('pass-cli error: ${result.stderr}');
    }
    return result.stdout as String;
  }
}
