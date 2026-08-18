import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/core/responsive/responsive_layout.dart';
import 'package:shadja/core/utils/formatters.dart';
import 'package:shadja/features/cart/cart_provider.dart';
import 'package:shadja/features/cart/presentation/cart_panel.dart';
import 'package:shadja/features/menu/data/menu_model.dart';
import 'package:shadja/features/menu/presentation/menu_provider.dart';
import 'package:shadja/features/menu/presentation/widgets/menu_card.dart';
import 'package:shadja/shared/widgets/empty_state.dart';
import 'package:shadja/shared/widgets/loading_state.dart';
import 'package:shadja/shared/widgets/shell_drawer_button.dart';

class KasirPage extends ConsumerStatefulWidget {
  const KasirPage({super.key});

  @override
  ConsumerState<KasirPage> createState() => _KasirPageState();
}

class _KasirPageState extends ConsumerState<KasirPage> {
  final _searchCtrl = TextEditingController();
  OverlayEntry? _toastEntry;

  @override
  void dispose() {
    _toastEntry?.remove();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showTopToast(String message) {
    _toastEntry?.remove();
    final overlay = Overlay.of(context);
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight + 8;
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: top,
        left: 16,
        right: 16,
        child: IgnorePointer(
          child: Material(
            color: AppColors.textPrimary.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
            elevation: 6,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _toastEntry = entry;
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (entry.mounted) entry.remove();
      if (identical(_toastEntry, entry)) _toastEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _buildMobile,
      tabletLandscape: _buildTabletLandscape,
    );
  }

  // ---- Tablet landscape (default utama) ----
  Widget _buildTabletLandscape(BuildContext context) {
    final menu = ref.watch(menuProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir'),
        leading: const ShellDrawerButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.read(menuProvider.notifier).load(),
            tooltip: 'Muat ulang menu',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Menu section (left, ~65%)
            Expanded(
              flex: 65,
              child: _buildMenuBody(menu),
            ),
            const SizedBox(width: 16),
            // Cart panel (right, ~35%)
            Expanded(
              flex: 35,
              child: CartPanel(),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Mobile ----
  Widget _buildMobile(BuildContext context) {
    final menu = ref.watch(menuProvider);
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir'),
        leading: const ShellDrawerButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.read(menuProvider.notifier).load(),
            tooltip: 'Muat ulang menu',
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildMenuBody(menu),
          // Floating cart bar
          if (cart.totalQuantity > 0)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(
                child: Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  elevation: 6,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => context.go('/home/kasir/checkout'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          const Icon(Icons.shopping_cart_outlined,
                              color: Colors.white),
                          const SizedBox(width: 12),
                          Text(
                            '${cart.totalQuantity} item',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            Formatters.rupiah(cart.subtotal),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward,
                              color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuBody(MenuState menu) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => ref.read(menuProvider.notifier).setSearch(v),
            decoration: InputDecoration(
              hintText: 'Cari menu…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: menu.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        ref.read(menuProvider.notifier).clearSearch();
                      })
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Category tabs
        _CategoryTabs(menu: menu),
        const SizedBox(height: 8),
        // Grid
        Expanded(
          child: _buildGrid(menu),
        ),
      ],
    );
  }

  Widget _buildGrid(MenuState menu) {
    if (menu.isLoading) return _buildGridSkeleton();
    if (menu.error != null) {
      return ErrorState(
        message: menu.error!,
        onRetry: () => ref.read(menuProvider.notifier).load(),
      );
    }

    final items = menu.filteredItems;
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'Menu tidak ditemukan',
        subtitle: 'Coba kata kunci atau kategori lain.',
      );
    }

    final cols = isMobile(context) ? 2 : 3;
    final itemsToDisplay = items.where((m) => m.isActive).toList();

    return MasonryGridViewReduce(
      crossAxisCount: cols,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.82,
      itemCount: itemsToDisplay.length,
      itemBuilder: (context, index) {
        final item = itemsToDisplay[index];
        return MenuCard(
          item: item,
          quantityInCart:
              _qtyInCart(item),
          onTap: () => _addItem(item),
        );
      },
    );
  }

  void _addItem(MenuItemModel item) {
    ref.read(cartProvider.notifier).add(item);
    final mq = _qtyInCart(item);
    final msg = mq > 1 ? '${item.name} (×$mq)' : '${item.name} ditambahkan';
    _showTopToast(msg);
  }

  int _qtyInCart(MenuItemModel item) {
    final cart = ref.read(cartProvider);
    return cart.items
        .where((e) => e.menuItem.id == item.id)
        .fold(0, (sum, e) => sum + e.quantity);
  }

  Widget _buildGridSkeleton() {
    final cols = isMobile(context) ? 2 : 3;
    return MasonryGridViewReduce(
      crossAxisCount: cols,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.82,
      itemCount: 8,
      itemBuilder: (_, _) => const MenuCardSkeleton(),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.menu});

  final MenuState menu;

  @override
  Widget build(BuildContext context) {
    if (menu.categories.length <= 1) return const SizedBox.shrink();
    final allItems = [
      const _CategoryChip(id: null, name: 'Semua', selected: false),
      ...menu.categories.map(
        (c) => _CategoryChip(
          id: c.id,
          name: c.name,
          selected: menu.selectedCategoryId == c.id,
        ),
      ),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: allItems.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = allItems[index];
          return Consumer(builder: (context, ref, _) {
            final sel = ref.watch(menuProvider).selectedCategoryId;
            final selected = chip.id == null
                ? sel == null
                : sel == chip.id;
            return _CategoryChip(
              id: chip.id,
              name: chip.name,
              selected: selected,
              onTap: chip.id == null
                  ? () => ref.read(menuProvider.notifier).selectAll()
                  : () => ref
                      .read(menuProvider.notifier)
                      .selectCategory(chip.id),
            );
          });
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.id,
    required this.name,
    required this.selected,
    this.onTap,
  });

  final int? id;
  final String name;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Manual masonry-style grid using SliverGrid since we want consistent
/// children. Falls back to GridView.builder via this wrapper.
class MasonryGridViewReduce extends StatelessWidget {
  const MasonryGridViewReduce({
    super.key,
    required this.crossAxisCount,
    required this.itemCount,
    required this.itemBuilder,
    this.crossAxisSpacing = 12,
    this.mainAxisSpacing = 12,
    this.childAspectRatio = 1,
  });

  final int crossAxisCount;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}