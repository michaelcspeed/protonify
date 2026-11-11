import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models.dart';
import 'pass_service.dart';

class AppState {
  final List<Vault> vaults;
  final List<Folder> folders;
  final List<PassItem> items;
  final PassItem? selectedItem;
  final ItemType? selectedCategory; // null = All
  final String? selectedFolderId;   // null = no folder filter
  final String searchQuery;
  final bool loadingVaults;
  final bool loadingItems;
  final String? error;

  const AppState({
    this.vaults = const [],
    this.folders = const [],
    this.items = const [],
    this.selectedItem,
    this.selectedCategory,
    this.selectedFolderId,
    this.searchQuery = '',
    this.loadingVaults = false,
    this.loadingItems = false,
    this.error,
  });

  List<PassItem> get filteredItems {
    var result = items;
    if (selectedCategory != null) {
      result = result.where((i) => i.type == selectedCategory).toList();
    }
    if (selectedFolderId != null) {
      result = result.where((i) => i.folderId == selectedFolderId).toList();
    }
    if (searchQuery.isEmpty) return result;
    final q = searchQuery.toLowerCase();
    return result.where((i) {
      return i.title.toLowerCase().contains(q) ||
          i.displayUsername.toLowerCase().contains(q) ||
          i.displayUrl.toLowerCase().contains(q);
    }).toList();
  }

  /// The vault the currently-selected folder belongs to, if any.
  Vault? get selectedFolderVault {
    if (selectedFolderId == null) return null;
    Folder? f;
    for (final x in folders) {
      if (x.id == selectedFolderId) { f = x; break; }
    }
    if (f == null) return null;
    for (final v in vaults) {
      if (v.shareId == f.shareId) return v;
    }
    return null;
  }

  AppState copyWith({
    List<Vault>? vaults,
    List<Folder>? folders,
    List<PassItem>? items,
    Object? selectedItem = _sentinel,
    Object? selectedCategory = _sentinel,
    Object? selectedFolderId = _sentinel,
    String? searchQuery,
    bool? loadingVaults,
    bool? loadingItems,
    Object? error = _sentinel,
  }) {
    return AppState(
      vaults: vaults ?? this.vaults,
      folders: folders ?? this.folders,
      items: items ?? this.items,
      selectedItem: selectedItem == _sentinel
          ? this.selectedItem
          : selectedItem as PassItem?,
      selectedCategory: selectedCategory == _sentinel
          ? this.selectedCategory
          : selectedCategory as ItemType?,
      selectedFolderId: selectedFolderId == _sentinel
          ? this.selectedFolderId
          : selectedFolderId as String?,
      searchQuery: searchQuery ?? this.searchQuery,
      loadingVaults: loadingVaults ?? this.loadingVaults,
      loadingItems: loadingItems ?? this.loadingItems,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

class AppStateNotifier extends StateNotifier<AppState> {
  final PassService _svc = PassService();

  AppStateNotifier() : super(const AppState());

  Future<void> loadVaults() async {
    state = state.copyWith(loadingVaults: true, error: null);
    try {
      final vaults = await _svc.listVaults();
      state = state.copyWith(vaults: vaults, loadingVaults: false, loadingItems: true);
      // Load items and folders for every vault in parallel.
      final itemResults = await Future.wait(
        vaults.map((v) => _svc.listItems(v.name)),
      );
      final folderResults = await Future.wait(
        vaults.map((v) async {
          try {
            return await _svc.listFolders(v.name);
          } catch (_) {
            return <Folder>[];
          }
        }),
      );
      final allItems = itemResults.expand((list) => list).toList()
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      final allFolders = folderResults.expand((list) => list).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      state = state.copyWith(
        items: allItems,
        folders: allFolders,
        loadingItems: false,
      );
    } catch (e) {
      state = state.copyWith(loadingVaults: false, loadingItems: false, error: e.toString());
    }
  }

  void selectCategory(ItemType? category) {
    if (state.loadingItems) return;
    state = state.copyWith(
      selectedCategory: category,
      selectedFolderId: null,
      selectedItem: null,
    );
  }

  void selectFolder(String? folderId) {
    if (state.loadingItems) return;
    state = state.copyWith(
      selectedFolderId: folderId,
      selectedCategory: null,
      selectedItem: null,
    );
  }

  void selectItem(PassItem? item) {
    if (state.loadingItems) return;
    state = state.copyWith(selectedItem: item);
  }

  void setSearch(String q) {
    state = state.copyWith(searchQuery: q);
  }

  Future<void> trashItem(PassItem item) async {
    await _svc.trashItem(shareId: item.shareId, itemId: item.id);
    final updated = state.items.where((i) => i.id != item.id).toList();
    state = state.copyWith(items: updated, selectedItem: null);
  }

  Future<void> untrashItem(PassItem item) async {
    await _svc.untrashItem(shareId: item.shareId, itemId: item.id);
    await loadVaults();
  }

  Future<void> deleteItem(PassItem item) async {
    await _svc.deleteItem(shareId: item.shareId, itemId: item.id);
    final updated = state.items.where((i) => i.id != item.id).toList();
    state = state.copyWith(items: updated, selectedItem: null);
  }

  Future<void> updateItem({
    required PassItem item,
    required Map<String, String> fields,
  }) async {
    await _svc.updateItem(
      shareId: item.shareId,
      itemId: item.id,
      fields: fields,
    );
    await loadVaults();
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
    await _svc.createLogin(
      vaultName: vaultName,
      title: title,
      email: email,
      username: username,
      password: password,
      url: url,
      folderId: folderId,
    );
  }

  Future<void> createNote({
    required String vaultName,
    required String title,
    String? note,
    String? folderId,
  }) async {
    await _svc.createNote(
      vaultName: vaultName,
      title: title,
      note: note,
      folderId: folderId,
    );
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
    await _svc.createWifi(
      vaultName: vaultName,
      title: title,
      ssid: ssid,
      password: password,
      security: security,
      note: note,
      folderId: folderId,
    );
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
    await _svc.createCreditCard(
      vaultName: vaultName,
      title: title,
      cardholderName: cardholderName,
      number: number,
      cvv: cvv,
      expirationDate: expirationDate,
      pin: pin,
      note: note,
      folderId: folderId,
    );
  }

  // ── Folder operations ───────────────────────────────────────────────────

  Future<void> createFolder({
    required String vaultName,
    required String name,
  }) async {
    await _svc.createFolder(vaultName: vaultName, name: name);
    await loadVaults();
  }

  Future<void> renameFolder({
    required Folder folder,
    required String newName,
  }) async {
    await _svc.renameFolder(
      shareId: folder.shareId,
      folderId: folder.id,
      name: newName,
    );
    await loadVaults();
  }

  Future<void> deleteFolder(Folder folder) async {
    await _svc.deleteFolder(shareId: folder.shareId, folderId: folder.id);
    if (state.selectedFolderId == folder.id) {
      state = state.copyWith(selectedFolderId: null);
    }
    await loadVaults();
  }

  Future<void> moveItemToFolder({
    required PassItem item,
    required String? folderId,
  }) async {
    await _svc.moveItemToFolder(
      shareId: item.shareId,
      itemId: item.id,
      folderId: folderId,
    );
    await loadVaults();
  }
}

final appStateProvider =
    StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  return AppStateNotifier();
});
