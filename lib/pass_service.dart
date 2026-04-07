import 'dart:convert';
import 'dart:io';
import 'models.dart';

enum SetupStatus { checking, cliNotFound, notLoggedIn, ready }

class PassService {
  static String? _resolvedCli;

  static final _searchPaths = [
    '${Platform.environment['HOME']}/.local/bin/pass-cli',
    '/opt/homebrew/bin/pass-cli',
    '/usr/local/bin/pass-cli',
  ];

  static Future<String?> _findCli() async {
    if (_resolvedCli != null) return _resolvedCli;
    for (final path in _searchPaths) {
      if (await File(path).exists()) {
        _resolvedCli = path;
        return path;
      }
    }
    // Fall back to `which` for non-standard locations
    try {
      final result = await Process.run('which', ['pass-cli']);
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim();
        if (path.isNotEmpty) {
          _resolvedCli = path;
          return path;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Check if the CLI binary can be found anywhere.
  Future<bool> isCliInstalled() async {
    return await _findCli() != null;
  }

  /// Try a lightweight command to see if the user is logged in.
  Future<bool> isLoggedIn() async {
    final cli = await _findCli();
    if (cli == null) return false;
    try {
      final result = await Process.run(cli, ['vault', 'list', '--output', 'json']);
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
    final cli = await _findCli();
    if (cli == null) {
      throw Exception('pass-cli not found. Please install the Proton Pass CLI.');
    }
    final result = await Process.run(cli, args);
    if (result.exitCode != 0) {
      throw Exception('pass-cli error: ${result.stderr}');
    }
    return result.stdout as String;
  }
}
