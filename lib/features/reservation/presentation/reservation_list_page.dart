import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/core/constants/app_text_styles.dart';
import 'package:shadja/core/responsive/responsive_layout.dart';
import 'package:shadja/core/utils/formatters.dart';
import 'package:shadja/features/reservation/data/reservation_model.dart';
import 'package:shadja/features/reservation/presentation/reservation_provider.dart';
import 'package:shadja/shared/widgets/empty_state.dart';
import 'package:shadja/shared/widgets/loading_state.dart';
import 'package:shadja/shared/widgets/shell_drawer_button.dart';
import 'package:shadja/shared/widgets/status_badge.dart';
import 'package:shadja/shared/widgets/surface_card.dart';

const double _occupiedCardHeight = 92;
const double _reservationCardHeight = 92;

class ReservationGroup {
  const ReservationGroup(this.label, this.reservations);

  final String label;
  final List<ReservationModel> reservations;
}

/// Mengelompokkan per hari: yang akan datang dulu (terdekat di atas), lalu
/// hari-hari yang sudah lewat (terbaru di atas) dalam satu grup "Sebelumnya".
List<ReservationGroup> groupReservations(
  List<ReservationModel> reservations,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final sorted = List<ReservationModel>.from(reservations)
    ..sort((a, b) => a.reservationTime.compareTo(b.reservationTime));

  final byDay = <DateTime, List<ReservationModel>>{};
  final past = <ReservationModel>[];
  for (final r in sorted) {
    final t = r.reservationTime;
    final day = DateTime(t.year, t.month, t.day);
    if (day.isBefore(today)) {
      past.insert(0, r);
    } else {
      byDay.putIfAbsent(day, () => []).add(r);
    }
  }

  String label(DateTime day) {
    final diff = DateTime.utc(day.year, day.month, day.day)
        .difference(DateTime.utc(today.year, today.month, today.day))
        .inDays;
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Besok';
    return Formatters.weekdayDate(day);
  }

  return [
    for (final entry in byDay.entries)
      ReservationGroup(label(entry.key), entry.value),
    if (past.isNotEmpty) ReservationGroup('Sebelumnya', past),
  ];
}

class ReservationListPage extends ConsumerWidget {
  const ReservationListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reservationListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservasi'),
        leading: const ShellDrawerButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Muat ulang',
            onPressed: () => ref.read(reservationListProvider.notifier).load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.go('/home/reservations/new'),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Reservasi Baru'),
      ),
      body: ResponsiveLayout(
        mobile: (_) => _buildBody(context, ref, state),
        tabletLandscape: (_) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kListPageMaxWidth),
            child: _buildBody(context, ref, state),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, ReservationListState state) {
    if (state.isLoading) {
      return const CardGridSkeleton(height: _reservationCardHeight);
    }
    if (state.error != null) {
      return ErrorState(
        message: state.error!,
        onRetry: () => ref.read(reservationListProvider.notifier).load(),
      );
    }
    final occupied = state.occupiedTables;
    final list = state.reservations;
    if (occupied.isEmpty && list.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy,
        title: 'Belum ada reservasi',
        subtitle: 'Buat reservasi meja untuk pelanggan Anda.',
      );
    }

    final now = DateTime.now();
    final groups = groupReservations(list, now);

    return RefreshIndicator(
      onRefresh: () => ref.read(reservationListProvider.notifier).load(),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _SummaryRow(
                occupied: occupied.length,
                reservations: list,
                now: now,
              ),
            ),
          ),
          if (occupied.isNotEmpty) ...[
            _sectionHeader('Meja Terisi', occupied.length),
            _sectionGrid(
              gridDelegate:
                  cardGridDelegate(context, height: _occupiedCardHeight),
              itemCount: occupied.length,
              itemBuilder: (_, i) => _OccupiedCard(table: occupied[i]),
            ),
          ],
          for (final group in groups) ...[
            _sectionHeader(group.label, group.reservations.length),
            _sectionGrid(
              gridDelegate:
                  cardGridDelegate(context, height: _reservationCardHeight),
              itemCount: group.reservations.length,
              itemBuilder: (_, i) =>
                  _ReservationCard(reservation: group.reservations[i]),
            ),
          ],
          if (groups.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Belum ada reservasi.',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ),
          // Ruang agar kartu terakhir tidak tertutup tombol Reservasi Baru.
          const SliverPadding(padding: EdgeInsets.only(bottom: 96)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, int count) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
        sliver: SliverToBoxAdapter(
          child: _SectionHeader(title: title, count: count),
        ),
      );

  Widget _sectionGrid({
    required SliverGridDelegate gridDelegate,
    required int itemCount,
    required NullableIndexedWidgetBuilder itemBuilder,
  }) =>
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid.builder(
          gridDelegate: gridDelegate,
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        ),
      );
}

/// Ringkasan cepat untuk kasir. Reservasi batal/selesai tidak dihitung.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.occupied,
    required this.reservations,
    required this.now,
  });

  final int occupied;
  final List<ReservationModel> reservations;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final active = reservations.where(
      (r) => r.status != 'cancelled' && r.status != 'selesai',
    );
    final today = active.where((r) {
      final t = r.reservationTime;
      return t.year == now.year && t.month == now.month && t.day == now.day;
    }).length;
    final upcoming = active.where((r) => r.reservationTime.isAfter(now)).length;

    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            icon: Icons.table_bar_outlined,
            label: 'Meja terisi',
            value: occupied,
            status: BadgeStatus.danger,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            icon: Icons.today_outlined,
            label: 'Hari ini',
            value: today,
            status: BadgeStatus.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            icon: Icons.event_outlined,
            label: 'Akan datang',
            value: upcoming,
            status: BadgeStatus.info,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.status,
  });

  final IconData icon;
  final String label;
  final int value;
  final BadgeStatus status;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: [
          if (!isMobile(context)) ...[
            TintBox(
              color: status.background,
              size: 40,
              child: Icon(icon, size: 20, color: status.foreground),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value', style: AppTextStyles.stat),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.cardTitle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: AppTextStyles.label.copyWith(color: AppColors.textHint),
        ),
      ],
    );
  }
}

/// Meja yang sedang dipakai pelanggan (order dine-in aktif):
/// menampilkan nomor meja, nomor invoice, dan nama pemesan.
class _OccupiedCard extends StatelessWidget {
  const _OccupiedCard({required this.table});

  final OccupiedTableModel table;

  (BadgeStatus, String) _status() {
    switch (table.orderStatus) {
      case 'diproses':
        return (BadgeStatus.warning, 'Diproses');
      case 'siap':
        return (BadgeStatus.success, 'Siap');
      default:
        return (BadgeStatus.info, 'Baru');
    }
  }

  @override
  Widget build(BuildContext context) {
    final badge = _status();
    return SurfaceCard(
      onTap: () => context.go('/home/orders/${table.orderId}'),
      child: _CardRow(
        leading: TintBox(
          color: badge.$1.background,
          size: 56,
          child: Text(
            table.tableNumber,
            style: AppTextStyles.stat.copyWith(
              fontSize: 20,
              color: badge.$1.foreground,
            ),
          ),
        ),
        title: table.customerName,
        subtitle: table.orderNumber,
        badge: StatusBadge(label: badge.$2, status: badge.$1),
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({required this.reservation});
  final ReservationModel reservation;

  (BadgeStatus, String) _status() {
    switch (reservation.status) {
      case 'confirmed':
        return (BadgeStatus.success, 'Dikonfirmasi');
      case 'selesai':
        return (BadgeStatus.neutral, 'Selesai');
      case 'cancelled':
        return (BadgeStatus.danger, 'Dibatalkan');
      default:
        return (BadgeStatus.warning, 'Pending');
    }
  }

  @override
  Widget build(BuildContext context) {
    final badge = _status();
    final time = reservation.reservationTime;
    final notes = reservation.notes;
    return SurfaceCard(
      onTap: () => context.go('/home/reservations/${reservation.id}'),
      child: _CardRow(
        leading: TintBox(
          color: badge.$1.background,
          size: 56,
          child: Text(
            Formatters.time(time),
            style: AppTextStyles.stat.copyWith(
              fontSize: 15,
              color: badge.$1.foreground,
            ),
          ),
        ),
        title: 'Meja ${reservation.restaurantTable?.tableNumber ?? "-"}',
        subtitle: '${Formatters.date(time)} • ${reservation.guestCount} tamu',
        note: notes != null && notes.isNotEmpty ? notes : null,
        badge: StatusBadge(label: badge.$2, status: badge.$1),
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.note,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget badge;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardTitle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  badge,
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              if (note != null)
                Text(
                  note!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
