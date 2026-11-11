import 'dart:convert';
import 'dart:io';
import 'models.dart';
export 'models.dart' show PasswordScore, PasswordStrength, Folder;

enum SetupStatus { checking, cliNotFound, notLoggedIn, locked, ready }

class SessionInfo {
  final bool hasLock;
  final String? username;
  final String? email;
  const SessionInfo({required this.hasLock, this.username, this.email});
}

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
    final info = await _tryGetSessionInfo();
    if (info == null) return SetupStatus.notLoggedIn;
    if (info.hasLock && !await isLoggedIn()) return SetupStatus.locked;
    if (!await isLoggedIn()) return SetupStatus.notLoggedIn;
    return SetupStatus.ready;
  }

  Future<SessionInfo?> _tryGetSessionInfo() async {
    final cli = await _findCli();
    if (cli == null) return null;
    try {
      final result = await Process.run(cli, ['info', '--output', 'json']);
      if (result.exitCode != 0) return null;
      final data = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      return SessionInfo(
        hasLock: data['session_has_lock'] as bool? ?? false,
        username: data['username'] as String?,
        email: data['email'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<SessionInfo?> getSessionInfo() => _tryGetSessionInfo();

  /// Lock the session immediately. Requires a lock to already exist.
  Future<void> lockSession() async {
    await _run(['session', 'lock']);
  }

  /// Unlock the session by writing [code] to the CLI's stdin.
  /// Throws if the code is wrong or the CLI refuses stdin.
  Future<void> unlockSession(String code) async {
    final cli = await _findCli();
    if (cli == null) {
      throw Exception('pass-cli not found');
    }
    final process = await Process.start(cli, ['session', 'unlock']);
    process.stdin.writeln(code);
    await process.stdin.flush();
    await process.stdin.close();
    final exitCode = await process.exitCode
        .timeout(const Duration(seconds: 10), onTimeout: () {
      process.kill();
      return -1;
    });
    if (exitCode != 0) {
      final err = await process.stderr.transform(utf8.decoder).join();
      throw Exception(err.trim().isEmpty ? 'Unlock failed' : err.trim());
    }
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
    final result = await _run([
      'item', 'list', vaultName,
      '--output', 'json',
      '--show-secrets',
    ]);
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
    String? folderId,
  }) async {
    await _run([
      'item', 'create', 'login',
      '--vault-name', vaultName,
      '--title', title,
      if (email != null && email.isNotEmpty) ...['--email', email],
      if (username != null && username.isNotEmpty) ...['--username', username],
      if (password != null && password.isNotEmpty) ...['--password', password],
      if (url != null && url.isNotEmpty) ...['--url', url],
      if (folderId != null && folderId.isNotEmpty) ...['--folder-id', folderId],
    ]);
  }

  Future<void> createNote({
    required String vaultName,
    required String title,
    String? note,
    String? folderId,
  }) async {
    await _run([
      'item', 'create', 'note',
      '--vault-name', vaultName,
      '--title', title,
      if (note != null && note.isNotEmpty) ...['--note', note],
      if (folderId != null && folderId.isNotEmpty) ...['--folder-id', folderId],
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
    String? folderId,
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
      if (folderId != null && folderId.isNotEmpty) ...['--folder-id', folderId],
    ]);
  }

  Future<void> createWifi({
    required String vaultName,
    required String title,
    String? ssid,
    String? password,
    String? security,
    String? note,
    String? folderId,
  }) async {
    await _run([
      'item', 'create', 'wifi',
      '--vault-name', vaultName,
      '--title', title,
      if (ssid != null && ssid.isNotEmpty) ...['--ssid', ssid],
      if (password != null && password.isNotEmpty) ...['--password', password],
      if (security != null && security.isNotEmpty) ...['--security', security],
      if (note != null && note.isNotEmpty) ...['--note', note],
      if (folderId != null && folderId.isNotEmpty) ...['--folder-id', folderId],
    ]);
  }

  // ── Folders ─────────────────────────────────────────────────────────────

  Future<List<Folder>> listFolders(String vaultName) async {
    final result = await _run([
      'folder', 'list', '--vault-name', vaultName, '--output', 'json',
    ]);
    final data = jsonDecode(result);
    if (data is! List) return [];
    return data
        .map((e) => Folder.fromFolderListJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createFolder({
    required String vaultName,
    required String name,
    String? parentId,
  }) async {
    await _run([
      'folder', 'create',
      '--vault-name', vaultName,
      '--name', name,
      if (parentId != null && parentId.isNotEmpty) ...['--parent-id', parentId],
    ]);
  }

  Future<void> renameFolder({
    required String shareId,
    required String folderId,
    required String name,
  }) async {
    await _run([
      'folder', 'update',
      '--share-id', shareId,
      '--folder-id', folderId,
      '--name', name,
    ]);
  }

  Future<void> deleteFolder({
    required String shareId,
    required String folderId,
  }) async {
    await _run([
      'folder', 'delete',
      '--share-id', shareId,
      '--folder-id', folderId,
    ]);
  }

  /// Move an item to a folder in its current vault, or to the vault root if
  /// [folderId] is null.
  Future<void> moveItemToFolder({
    required String shareId,
    required String itemId,
    required String? folderId,
  }) async {
    await _run([
      'item', 'move',
      '--from-share-id', shareId,
      '--item-id', itemId,
      if (folderId != null) ...['--to-folder-id', folderId]
      else ...['--to-share-root'],
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

  Future<String> generateTotp(String secretOrUri) async {
    final out = await _run(['totp', 'generate', '--output', 'json', secretOrUri]);
    final data = jsonDecode(out) as Map<String, dynamic>;
    return data['token'] as String? ?? '';
  }

  Future<String> generatePassword({
    int length = 20,
    bool uppercase = true,
    bool numbers = true,
    bool symbols = true,
  }) async {
    final out = await _run([
      'password', 'generate', 'random',
      '--length', '$length',
      '--uppercase', uppercase ? 'true' : 'false',
      '--numbers', numbers ? 'true' : 'false',
      '--symbols', symbols ? 'true' : 'false',
      '--output', 'json',
    ]);
    final data = jsonDecode(out) as Map<String, dynamic>;
    return data['password'] as String? ?? '';
  }

  Future<String> generatePassphrase({
    int count = 4,
    String separator = 'hyphens',
    bool capitalise = true,
    bool numbers = true,
  }) async {
    final out = await _run([
      'password', 'generate', 'passphrase',
      '--count', '$count',
      '--separator', separator,
      '--capitalise', capitalise ? 'true' : 'false',
      '--numbers', numbers ? 'true' : 'false',
      '--output', 'json',
    ]);
    final data = jsonDecode(out) as Map<String, dynamic>;
    return data['password'] as String? ?? '';
  }

  Future<PasswordScore?> scorePassword(String password) async {
    if (password.isEmpty) return null;
    try {
      final out = await _run(['password', 'score', '--output', 'json', password]);
      final data = jsonDecode(out) as Map<String, dynamic>;
      return PasswordScore.fromJson(data);
    } catch (_) {
      return null;
    }
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
