import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/core/responsive/responsive_layout.dart';
import 'package:shadja/core/utils/formatters.dart';
import 'package:shadja/features/reservation/data/reservation_model.dart';
import 'package:shadja/features/reservation/presentation/reservation_provider.dart';
import 'package:shadja/shared/widgets/empty_state.dart';
import 'package:shadja/shared/widgets/loading_state.dart';
import 'package:shadja/shared/widgets/status_badge.dart';
import 'package:shadja/shared/widgets/shell_drawer_button.dart';

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
            onPressed: () => ref.read(reservationListProvider.notifier).load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/home/reservations/new'),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Reservasi Baru'),
      ),
      body: ResponsiveLayout(
        mobile: (_) => _buildBody(context, ref, state),
        tabletLandscape: (_) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _buildBody(context, ref, state),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, ReservationListState state) {
    if (state.isLoading) return const Center(child: LoadingState());
    if (state.error != null) {
      return ErrorState(
        message: state.error!,
        onRetry: () => ref.read(reservationListProvider.notifier).load(),
      );
    }
    final list = state.reservations;
    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy,
        title: 'Belum ada reservasi',
        subtitle: 'Buat reservasi meja untuk pelanggan Anda.',
      );
    }
    // urutkan terdekat dulu
    final sorted = List<ReservationModel>.from(list)
      ..sort((a, b) => a.reservationTime.compareTo(b.reservationTime));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final r = sorted[index];
        return _ReservationTile(reservation: r);
      },
    );
  }
}

class _ReservationTile extends StatelessWidget {
  const _ReservationTile({required this.reservation});
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
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () =>
            context.go('/home/reservations/${reservation.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primaryBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      reservation.restaurantTable?.tableNumber ?? '-',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Meja ${reservation.restaurantTable?.tableNumber ?? "-"}',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(label: badge.$2, status: badge.$1),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${Formatters.dateTime(reservation.reservationTime)} • ${reservation.guestCount} tamu',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    if (reservation.notes != null &&
                        reservation.notes!.isNotEmpty)
                      Text(
                        reservation.notes!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textHint),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textHint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}