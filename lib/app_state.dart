import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models.dart';
import 'pass_service.dart';

class AppState {
  final List<Vault> vaults;
  final List<PassItem> items;
  final PassItem? selectedItem;
  final ItemType? selectedCategory; // null = All
  final String searchQuery;
  final bool loadingVaults;
  final bool loadingItems;
  final String? error;

  const AppState({
    this.vaults = const [],
    this.items = const [],
    this.selectedItem,
    this.selectedCategory,
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
    if (searchQuery.isEmpty) return result;
    final q = searchQuery.toLowerCase();
    return result.where((i) {
      return i.title.toLowerCase().contains(q) ||
          i.displayUsername.toLowerCase().contains(q) ||
          i.displayUrl.toLowerCase().contains(q);
    }).toList();
  }

  AppState copyWith({
    List<Vault>? vaults,
    List<PassItem>? items,
    Object? selectedItem = _sentinel,
    Object? selectedCategory = _sentinel,
    String? searchQuery,
    bool? loadingVaults,
    bool? loadingItems,
    Object? error = _sentinel,
  }) {
    return AppState(
      vaults: vaults ?? this.vaults,
      items: items ?? this.items,
      selectedItem: selectedItem == _sentinel
          ? this.selectedItem
          : selectedItem as PassItem?,
      selectedCategory: selectedCategory == _sentinel
          ? this.selectedCategory
          : selectedCategory as ItemType?,
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
      // Load all vaults in parallel
      final results = await Future.wait(
        vaults.map((v) => _svc.listItems(v.name)),
      );
      final allItems = results.expand((list) => list).toList()
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      state = state.copyWith(items: allItems, loadingItems: false);
    } catch (e) {
      state = state.copyWith(loadingVaults: false, loadingItems: false, error: e.toString());
    }
  }

  void selectCategory(ItemType? category) {
    if (state.loadingItems) return;
    state = state.copyWith(selectedCategory: category, selectedItem: null);
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
  }) async {
    await _svc.createLogin(
      vaultName: vaultName,
      title: title,
      email: email,
      username: username,
      password: password,
      url: url,
    );
  }

  Future<void> createNote({
    required String vaultName,
    required String title,
    String? note,
  }) async {
    await _svc.createNote(vaultName: vaultName, title: title, note: note);
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
    await _svc.createCreditCard(
      vaultName: vaultName,
      title: title,
      cardholderName: cardholderName,
      number: number,
      cvv: cvv,
      expirationDate: expirationDate,
      pin: pin,
      note: note,
    );
  }
}

final appStateProvider =
    StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  return AppStateNotifier();
});
