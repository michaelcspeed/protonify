// Renders the main screen with fake vault data at several window sizes and
// themes, and writes PNGs to $SNAPSHOT_DIR. Used to eyeball layout changes
// without a real pass-cli session. Skipped unless SNAPSHOT_DIR is set:
//
//   SNAPSHOT_DIR=/tmp/shots flutter test test/ui_snapshot_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:protonify/app_state.dart';
import 'package:protonify/main.dart';
import 'package:protonify/models.dart';
import 'package:protonify/pass_service.dart';
import 'package:protonify/setup_state.dart';
import 'package:protonify/theme.dart';

final _dir = Platform.environment['SNAPSHOT_DIR'];
final _shotKey = GlobalKey();

class _FakeApp extends AppStateNotifier {
  _FakeApp(AppState s) {
    state = s;
  }
  @override
  Future<void> loadVaults() async {}
}

class _FakeSetup extends SetupStateNotifier {
  _FakeSetup() {
    state = SetupStatus.ready;
  }
  @override
  Future<void> check() async {}
}

PassItem _item(String id, String title, Map<String, dynamic> inner,
        {String share = 's1', String? folder, String note = ''}) =>
    PassItem.fromJson({
      'id': id,
      'share_id': share,
      'vault_id': 'v-$share',
      'folder_id': folder,
      'create_time': '2025-03-14T10:00:00Z',
      'modify_time': '2026-10-02T10:00:00Z',
      'content': {'title': title, 'note': note, 'content': inner},
    });

Map<String, dynamic> _login(String email, String url, [String pw = 'hunter2-Correct-Horse']) =>
    {
      'Login': {
        'email': email,
        'username': '',
        'password': pw,
        'urls': [url],
        'totp_uri': '',
      }
    };

final _items = [
  _item('1', 'GitHub', _login('mike@example.com', 'https://github.com'), folder: 'f1'),
  _item('2', 'Amazon', _login('shopping@example.com', 'https://amazon.de')),
  _item('3', 'Bank of Somewhere', _login('m.speed', 'https://bank.example.com'),
      note: 'Security question: first pet → "Biscuit"'),
  _item('4', 'Home Wi-Fi', {
    'Wifi': {'ssid': 'Speednet-5G', 'password': 'pa55word!', 'security': 'WPA2'}
  }),
  _item('5', 'Visa Debit', {
    'CreditCard': {
      'cardholder_name': 'Mike Speed',
      'number': '4111111111111111',
      'expiration_date': '2028-04',
      'verification_number': '123',
      'pin': '9876',
      'card_type': 'Visa',
    }
  }),
  _item('6', 'Server notes', {'Note': {}},
      note: 'Hetzner box: root login disabled.\nUse deploy key in 1Password… I mean here.'),
  _item('7', 'Figma', _login('design@example.com', 'https://figma.com'), share: 's2', folder: 'f2'),
  _item('8', 'Linear', _login('mike@work.example', 'https://linear.app'), share: 's2', folder: 'f2'),
  _item('9', 'Notion', _login('mike@work.example', 'https://notion.so'), share: 's2'),
  _item('10', 'Very long title for an item that keeps going and going', _login(
      'an.extremely.long.email.address@subdomain.example.com', 'https://example.com/a/very/long/path')),
  _item('11', 'Alias for newsletters', {'Alias': {}}),
  _item('12', 'Passport', {
    'Identity': {'full_name': 'Mike Speed', 'email': 'mike@example.com', 'passport_number': 'X1234567'}
  }),
]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

AppState _state({PassItem? selected}) => AppState(
      vaults: const [
        Vault(name: 'Personal', vaultId: 'v-s1', shareId: 's1'),
        Vault(name: 'Work', vaultId: 'v-s2', shareId: 's2'),
      ],
      folders: const [
        Folder(id: 'f1', shareId: 's1', name: 'Dev'),
        Folder(id: 'f2', shareId: 's2', name: 'Design tools'),
      ],
      items: _items,
      selectedItem: selected,
    );

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      final f = File(p);
      if (f.existsSync()) {
        final bytes = f.readAsBytesSync();
        loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      }
    }
    await loader.load();
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      '${Platform.environment['HOME']}/flutter';
  const sf = '/System/Library/Fonts/SFNS.ttf';
  const mono = '/System/Library/Fonts/SFNSMono.ttf';
  for (final fam in ['Roboto', '.AppleSystemUIFont', 'SF Pro Text', 'Inter']) {
    await load(fam, [sf]);
  }
  for (final fam in ['Menlo', 'monospace', 'SF Mono', 'SF Mono, Menlo, monospace']) {
    await load(fam, [mono]);
  }
  await load('MaterialIcons',
      ['$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}

void main() {
  if (_dir == null) {
    test('snapshots (skipped: set SNAPSHOT_DIR)', () {}, skip: true);
    return;
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
  });

  final sizes = <String, Size>{
    'narrow': const Size(520, 700),
    'medium': const Size(860, 620),
    'wide': const Size(1360, 860),
  };

  for (final mode in [ThemeMode.dark, ThemeMode.light]) {
    for (final e in sizes.entries) {
      for (final sel in [false, true]) {
        final name = '${mode.name}-${e.key}${sel ? '-detail' : ''}';
        testWidgets(name, (tester) async {
          tester.view.physicalSize = e.value * 2;
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);

          final selected = sel ? _items.firstWhere((i) => i.id == '3') : null;
          await tester.pumpWidget(ProviderScope(
            overrides: [
              appStateProvider.overrideWith((ref) => _FakeApp(_state(selected: selected))),
              setupProvider.overrideWith((ref) => _FakeSetup()),
              themeModeProvider.overrideWith((ref) => ThemeModeNotifier(mode)),
            ],
            child: RepaintBoundary(key: _shotKey, child: const ProtonifyApp()),
          ));
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 500));

          await expectLater(
            find.byKey(_shotKey),
            matchesGoldenFile(Uri.file('$_dir/$name.png')),
          );
        });
      }
    }
  }

  // Interaction states.
  Future<void> pumpApp(WidgetTester tester, Size size, ThemeMode mode, {PassItem? selected, String search = ''}) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final s = _state(selected: selected);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appStateProvider.overrideWith((ref) => _FakeApp(AppState(
              vaults: s.vaults, folders: s.folders, items: s.items,
              selectedItem: selected, searchQuery: search))),
        setupProvider.overrideWith((ref) => _FakeSetup()),
        themeModeProvider.overrideWith((ref) => ThemeModeNotifier(mode)),
      ],
      child: RepaintBoundary(key: _shotKey, child: const ProtonifyApp()),
    ));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pump(); // let tap-triggered animations start
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(find.byKey(_shotKey), matchesGoldenFile(Uri.file('$_dir/$name.png')));
  }

  testWidgets('x-sidebar-overlay', (tester) async {
    await pumpApp(tester, const Size(860, 620), ThemeMode.dark);
    await tester.tap(find.byTooltip('Show sidebar  ⌃⌘S'));
    await shot(tester, 'x-dark-medium-sidebar-overlay');
  });

  testWidgets('x-new-item', (tester) async {
    await pumpApp(tester, const Size(1100, 760), ThemeMode.light);
    await tester.tap(find.byTooltip('New item  ⌘N'));
    await shot(tester, 'x-light-new-item-picker');
    await tester.tap(find.text('Login').last);
    await shot(tester, 'x-light-new-login-form');
  });

  testWidgets('x-new-item-narrow', (tester) async {
    await pumpApp(tester, const Size(460, 600), ThemeMode.dark);
    await tester.tap(find.byTooltip('New item  ⌘N'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Card').last);
    await shot(tester, 'x-dark-narrow-new-card-form');
  });

  testWidgets('x-settings', (tester) async {
    await pumpApp(tester, const Size(1100, 760), ThemeMode.dark);
    await tester.tap(find.byTooltip('Settings  ⌘,'));
    await shot(tester, 'x-dark-settings');
  });

  testWidgets('x-no-results', (tester) async {
    await pumpApp(tester, const Size(1100, 760), ThemeMode.light, search: 'zzz');
    await shot(tester, 'x-light-no-results');
  });

  testWidgets('x-card-detail', (tester) async {
    await pumpApp(tester, const Size(1100, 760), ThemeMode.dark,
        selected: _items.firstWhere((i) => i.id == '5'));
    await shot(tester, 'x-dark-card-detail');
  });

  testWidgets('x-tiny', (tester) async {
    await pumpApp(tester, const Size(420, 460), ThemeMode.light,
        selected: _items.firstWhere((i) => i.id == '10'));
    await shot(tester, 'x-light-tiny-detail');
  });
}
