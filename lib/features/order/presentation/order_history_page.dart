import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/core/responsive/responsive_layout.dart';
import 'package:shadja/core/utils/formatters.dart';
import 'package:shadja/features/order/data/order_model.dart';
import 'package:shadja/features/order/presentation/order_provider.dart';
import 'package:shadja/features/reservation/data/reservation_model.dart';
import 'package:shadja/features/reservation/presentation/reservation_provider.dart';
import 'package:shadja/shared/widgets/empty_state.dart';
import 'package:shadja/shared/widgets/loading_state.dart';
import 'package:shadja/shared/widgets/status_badge.dart';
import 'package:shadja/shared/widgets/shell_drawer_button.dart';

class OrderHistoryPage extends ConsumerStatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  ConsumerState<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends ConsumerState<OrderHistoryPage> {
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
            onPressed: () => ref.read(orderHistoryProvider.notifier).load(),
          ),
        ],
      ),
      body: ResponsiveLayout(
        mobile: (_) => _buildBody(state),
        tabletLandscape: (_) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _buildBody(state),
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

  Widget _buildBody(OrderHistoryState state) {
    if (state.isLoading) {
      return const Center(child: LoadingState());
    }
    if (state.error != null) {
      return ErrorState(
        message: state.error!,
        onRetry: () => ref.read(orderHistoryProvider.notifier).load(),
      );
    }
    final orders = _applySearch(state.filteredOrders, state.searchQuery);

    // Search + tab filter tetap tampil walau daftar order kosong.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            onChanged: (v) =>
                ref.read(orderHistoryProvider.notifier).setSearch(v),
            decoration: InputDecoration(
              hintText: 'Cari nomor order / pelanggan / meja…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: state.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => ref
                          .read(orderHistoryProvider.notifier)
                          .setSearch(''),
                    )
                  : null,
              isDense: true,
            ),
          ),
        ),
        _FilterTabs(
          current: state.filterStatus,
          onChanged: (s) =>
              ref.read(orderHistoryProvider.notifier).setFilter(s),
        ),
        Expanded(
          child: orders.isEmpty
              ? EmptyState(
                  icon: Icons.assignment_outlined,
                  title: state.searchQuery.isNotEmpty
                      ? 'Order tidak ditemukan'
                      : 'Belum ada order',
                  subtitle: state.searchQuery.isNotEmpty
                      ? 'Coba kata kunci lain.'
                      : 'Order yang dibuat akan muncul di sini.',
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(orderHistoryProvider.notifier).load(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _OrderTile(order: order);
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.current, required this.onChanged});

  final String current;
  final ValueChanged<String> onChanged;

  static const filters = [
    ('all', 'Semua'),
    ('baru', 'Baru'),
    ('diproses', 'Diproses'),
    ('selesai', 'Selesai'),
    ('dibatalkan', 'Batal'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final f = filters[index];
          final selected = current == f.$1;
          return Material(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(f.$1),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Text(
                  f.$2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrderTile extends ConsumerWidget {
  const _OrderTile({required this.order});
  final OrderModel order;

  (BadgeStatus, String) _statusBadge() {
    switch (order.orderStatus) {
      case 'selesai':
        return (BadgeStatus.success, 'Selesai');
      case 'diproses':
        return (BadgeStatus.warning, 'Diproses');
      case 'dibatalkan':
        return (BadgeStatus.danger, 'Dibatalkan');
      default:
        return (BadgeStatus.info, 'Baru');
    }
  }

  String _orderTypeLabel() {
    switch (order.orderType) {
      case 'dine-in':
        return 'Dine-in';
      case 'pickup':
        return 'Take Away';
      case 'delivery':
        return 'Delivery';
      default:
        return order.orderType;
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
    final itemCount = order.orderItems.fold(0, (s, e) => s + e.quantity);
    final table = _tableNumber(ref);

    final subtitleParts = [
      '$itemCount item',
      order.customerName ?? 'Walk-in',
      _orderTypeLabel(),
      if (table != null) 'Meja $table',
    ];

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/home/orders/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.receipt_long,
                    size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            order.orderNumber ?? 'Order #${order.id}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                            label: badge.$2, status: badge.$1),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitleParts.join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    if (order.createdAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        Formatters.dateTime(order.createdAt!),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textHint),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Formatters.rupiah(order.total),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}