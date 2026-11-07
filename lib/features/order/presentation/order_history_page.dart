import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/core/constants/app_text_styles.dart';
import 'package:shadja/core/responsive/responsive_layout.dart';
import 'package:shadja/core/utils/formatters.dart';
import 'package:shadja/features/order/data/order_model.dart';
import 'package:shadja/features/order/presentation/order_provider.dart';
import 'package:shadja/features/reservation/data/reservation_model.dart';
import 'package:shadja/features/reservation/presentation/reservation_provider.dart';
import 'package:shadja/shared/widgets/empty_state.dart';
import 'package:shadja/shared/widgets/loading_state.dart';
import 'package:shadja/shared/widgets/shell_drawer_button.dart';
import 'package:shadja/shared/widgets/status_badge.dart';
import 'package:shadja/shared/widgets/surface_card.dart';

const double _cardHeight = 136;

class OrderHistoryPage extends ConsumerStatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  ConsumerState<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends ConsumerState<OrderHistoryPage> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Order'),
        leading: const ShellDrawerButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Muat ulang',
            onPressed: () => ref.read(orderHistoryProvider.notifier).load(),
          ),
        ],
      ),
      body: ResponsiveLayout(
        mobile: (_) => _buildBody(state, wide: false),
        tabletLandscape: (_) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kListPageMaxWidth),
            child: _buildBody(state, wide: true),
          ),
        ),
      ),
    );
  }

  // Filter hasil pencarian: nomor order, pelanggan, atau nomor meja.
  List<OrderModel> _applySearch(List<OrderModel> orders, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return orders;
    final tables = ref.watch(tablesProvider).value ?? const <RestaurantTableModel>[];
    return orders.where((o) {
      final number = (o.orderNumber ?? '#${o.id}').toLowerCase();
      final customer = (o.customerName ?? '').toLowerCase();
      String? table;
      if (o.restaurantTableId != null) {
        String? tableNum;
        for (final t in tables) {
          if (t.id == o.restaurantTableId) {
            tableNum = t.tableNumber;
            break;
          }
        }
        table = (tableNum ?? '${o.restaurantTableId}').toLowerCase();
      }
      return number.contains(q) ||
          customer.contains(q) ||
          (table?.contains(q) ?? false);
    }).toList();
  }

  // Muat halaman berikutnya saat mendekati akhir daftar. Setelah gagal, tunggu
  // tombol "Coba lagi" agar scroll tidak mengulang request terus-menerus.
  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.extentAfter < 300 &&
        ref.read(orderHistoryProvider).loadMoreError == null) {
      ref.read(orderHistoryProvider.notifier).loadMore();
    }
    return false;
  }

  Widget _buildBody(OrderHistoryState state, {required bool wide}) {
    final search = _SearchField(
      controller: _searchCtrl,
      showClear: state.searchQuery.isNotEmpty,
      onChanged: ref.read(orderHistoryProvider.notifier).setSearch,
    );
    final tabs = _FilterTabs(
      current: state.filterStatus,
      currentCount: state.isLoading || state.error != null ? null : state.total,
      onChanged: ref.read(orderHistoryProvider.notifier).setFilter,
    );

    final dateFilter = state.filterStatus == 'all'
        ? _DateRangeFilter(
            range: state.dateRange,
            onChanged: ref.read(orderHistoryProvider.notifier).setDateRange,
          )
        : null;

    // Pencarian dan tab tetap tampil saat memuat, error, atau daftar kosong.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: wide
              ? Row(
                  children: [
                    SizedBox(width: 340, child: search),
                    const SizedBox(width: 16),
                    Expanded(child: tabs),
                    if (dateFilter != null) ...[
                      const SizedBox(width: 12),
                      dateFilter,
                    ],
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    search,
                    const SizedBox(height: 10),
                    tabs,
                    if (dateFilter != null) ...[
                      const SizedBox(height: 10),
                      dateFilter,
                    ],
                  ],
                ),
        ),
        Expanded(child: _buildContent(state)),
      ],
    );
  }

  Widget _buildContent(OrderHistoryState state) {
    if (state.isLoading) return const CardGridSkeleton(height: _cardHeight);
    if (state.error != null) {
      return ErrorState(
        message: state.error!,
        onRetry: () => ref.read(orderHistoryProvider.notifier).load(),
      );
    }
    final orders = _applySearch(state.orders, state.searchQuery);
    if (orders.isEmpty && !state.hasMore) {
      final searching = state.searchQuery.isNotEmpty;
      final dated = state.dateRange != null;
      return EmptyState(
        icon: Icons.assignment_outlined,
        title: searching || dated ? 'Order tidak ditemukan' : 'Belum ada order',
        subtitle: searching
            ? 'Coba kata kunci lain.'
            : dated
                ? 'Tidak ada order pada tanggal tersebut.'
                : 'Order yang dibuat akan muncul di sini.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(orderHistoryProvider.notifier).load(),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverGrid.builder(
                gridDelegate: cardGridDelegate(context, height: _cardHeight),
                itemCount: orders.length,
                itemBuilder: (_, index) => _OrderCard(order: orders[index]),
              ),
            ),
            if (state.hasMore)
              SliverToBoxAdapter(
                child: _LoadMoreFooter(
                  isLoading: state.isLoadingMore,
                  hasError: state.loadMoreError != null,
                  onPressed: () =>
                      ref.read(orderHistoryProvider.notifier).loadMore(),
                ),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.showClear,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool showClear;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Cari nomor order / pelanggan / meja…',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: showClear
            ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Hapus pencarian',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
        fillColor: AppColors.surface,
        isDense: true,
      ),
    );
  }
}

class _DateRangeFilter extends StatelessWidget {
  const _DateRangeFilter({required this.range, required this.onChanged});

  final DateTimeRange? range;
  final ValueChanged<DateTimeRange?> onChanged;

  String get _label {
    final r = range;
    if (r == null) return 'Pilih tanggal';
    final start = Formatters.date(r.start);
    final end = Formatters.date(r.end);
    return start == end ? start : '$start – $end';
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: range,
      helpText: 'Pilih rentang tanggal',
      cancelText: 'Batal',
      confirmText: 'Terapkan',
      saveText: 'Terapkan',
      fieldStartLabelText: 'Dari',
      fieldEndLabelText: 'Sampai',
      // Bawaannya layar penuh, terlalu besar untuk desktop.
      builder: (_, child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 640),
          child: child,
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final active = range != null;
    final color = active ? AppColors.primary : AppColors.textSecondary;
    return Material(
      color: active ? AppColors.primaryBg : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(color: active ? AppColors.primary : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 40,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => _pick(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 16, color: color),
                    const SizedBox(width: 8),
                    Text(_label, style: AppTextStyles.label.copyWith(color: color)),
                  ],
                ),
              ),
            ),
            if (active)
              IconButton(
                icon: Icon(Icons.close, size: 16, color: color),
                tooltip: 'Hapus filter tanggal',
                visualDensity: VisualDensity.compact,
                onPressed: () => onChanged(null),
              ),
          ],
        ),
      ),
    );
  }
}

// Tombol tetap ada karena filter/pencarian bisa membuat daftar terlalu pendek
// untuk di-scroll, sehingga pemuatan otomatis tidak pernah terpicu.
class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({
    required this.isLoading,
    required this.hasError,
    required this.onPressed,
  });

  final bool isLoading;
  final bool hasError;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Column(
      children: [
        if (hasError)
          const Text(
            'Gagal memuat order berikutnya',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        TextButton(
          onPressed: onPressed,
          child: Text(hasError ? 'Coba lagi' : 'Muat lebih banyak'),
        ),
      ],
    );
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.current,
    required this.currentCount,
    required this.onChanged,
  });

  final String current;

  /// Server hanya mengirim jumlah untuk tab yang sedang dibuka.
  final int? currentCount;
  final ValueChanged<String> onChanged;

  static const filters = [
    ('baru', 'Baru'),
    ('diproses', 'Diproses'),
    ('selesai', 'Selesai'),
    ('dibatalkan', 'Batal'),
    ('all', 'Semua'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final f = filters[index];
          final selected = current == f.$1;
          final count = selected ? currentCount : null;
          return Material(
            color: selected ? AppColors.primary : AppColors.surface,
            shape: StadiumBorder(
              side: BorderSide(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onChanged(f.$1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      f.$2,
                      style: AppTextStyles.label.copyWith(
                        color:
                            selected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '$count',
                        style: AppTextStyles.label.copyWith(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});
  final OrderModel order;

  (BadgeStatus, String) _statusBadge() {
    switch (order.orderStatus) {
      case 'selesai':
        return (BadgeStatus.success, 'Selesai');
      case 'diproses':
        return (BadgeStatus.warning, 'Diproses');
      case 'siap':
        return (BadgeStatus.info, 'Siap');
      case 'dibatalkan':
        return (BadgeStatus.danger, 'Dibatalkan');
      default:
        return (BadgeStatus.info, 'Baru');
    }
  }

  (IconData, String) _orderType() {
    switch (order.orderType) {
      case 'dine-in':
        return (Icons.restaurant, 'Dine-in');
      case 'pickup':
        return (Icons.takeout_dining_outlined, 'Take Away');
      case 'delivery':
        return (Icons.delivery_dining_outlined, 'Delivery');
      default:
        return (Icons.receipt_long, order.orderType);
    }
  }

  // Nomor meja diambil dari daftar meja (fallback: id meja).
  String? _tableNumber(WidgetRef ref) {
    if (order.restaurantTableId == null) return null;
    final tables = ref.watch(tablesProvider).value;
    if (tables != null) {
      for (final t in tables) {
        if (t.id == order.restaurantTableId) return t.tableNumber;
      }
    }
    return '${order.restaurantTableId}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badge = _statusBadge();
    final type = _orderType();
    final itemCount = order.orderItems.fold(0, (s, e) => s + e.quantity);
    final table = _tableNumber(ref);

    final details = [
      type.$2,
      if (table != null) 'Meja $table',
      '$itemCount item',
    ];

    return SurfaceCard(
      onTap: () => context.go('/home/orders/${order.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TintBox(
                color: badge.$1.background,
                child: Icon(type.$1, size: 22, color: badge.$1.foreground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber ?? 'Order #${order.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardTitle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.customerName ?? 'Walk-in',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(label: badge.$2, status: badge.$1),
            ],
          ),
          const Spacer(),
          Text(
            details.join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  order.createdAt != null
                      ? Formatters.dateTime(order.createdAt!)
                      : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Formatters.rupiah(order.total),
                style: AppTextStyles.amount,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
