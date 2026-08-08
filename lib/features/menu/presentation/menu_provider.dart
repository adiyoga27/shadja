import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadja/features/menu/data/menu_model.dart';
import 'package:shadja/features/menu/data/menu_repository.dart';

class MenuState {
  const MenuState({
    this.categories = const [],
    this.isLoading = false,
    this.error,
    this.selectedCategoryId,
    this.searchQuery = '',
  });

  final List<MenuCategoryModel> categories;
  final bool isLoading;
  final String? error;
  final int? selectedCategoryId;
  final String searchQuery;

  MenuState copyWith({
    List<MenuCategoryModel>? categories,
    bool? isLoading,
    String? error,
    int? selectedCategoryId,
    bool clearSelection = false,
    String? searchQuery,
  }) {
    return MenuState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedCategoryId: clearSelection
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<MenuItemModel> get filteredItems {
    var items = <MenuItemModel>[];
    if (selectedCategoryId != null) {
      final cat = categories
          .where((c) => c.id == selectedCategoryId)
          .firstOrNull;
      if (cat != null) items = cat.menuItems;
    } else {
      for (final c in categories) {
        items = [...items, ...c.menuItems];
      }
    }
    if (searchQuery.isNotEmpty) {
      items = items
          .where((m) => m.name.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }
    return items;
  }
}

class MenuNotifier extends StateNotifier<MenuState> {
  MenuNotifier(this.repo) : super(const MenuState(isLoading: true));

  final MenuRepository repo;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final cats = await repo.fetchMenu();
      state = MenuState(
        categories: cats,
        selectedCategoryId: cats.isNotEmpty ? cats.first.id : null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void selectCategory(int? id) {
    state = state.copyWith(selectedCategoryId: id);
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }
}

final menuProvider = StateNotifierProvider<MenuNotifier, MenuState>(
  (ref) {
    final notifier = MenuNotifier(ref.read(menuRepositoryProvider));
    notifier.load();
    return notifier;
  },
);