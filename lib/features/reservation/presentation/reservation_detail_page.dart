import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/core/responsive/responsive_layout.dart';
import 'package:shadja/core/utils/formatters.dart';
import 'package:shadja/features/reservation/data/reservation_model.dart';
import 'package:shadja/features/reservation/presentation/reservation_provider.dart';
import 'package:shadja/shared/widgets/loading_state.dart';
import 'package:shadja/shared/widgets/status_badge.dart';

class ReservationDetailPage extends ConsumerWidget {
  const ReservationDetailPage({super.key, required this.reservationId});

  final int reservationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRes = ref.watch(reservationDetailProvider(reservationId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Reservasi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ResponsiveLayout(
        mobile: (_) => _body(context, asyncRes),
        tabletLandscape: (_) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: _body(context, asyncRes),
          ),
        ),
      ),
    );
  }

  Widget _body(
      BuildContext context, AsyncValue<ReservationModel> asyncRes) {
    return asyncRes.when(
      loading: () => const Center(child: LoadingState()),
      error: (e, _) => ErrorState(message: 'Gagal memuat: $e'),
      data: (res) => _buildDetail(context, res),
    );
  }

  Widget _buildDetail(BuildContext context, ReservationModel res) {
    final badge = _status(res.status);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.calendar_month,
                            size: 28, color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Meja ${res.restaurantTable?.tableNumber ?? "-"}',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${res.guestCount} tamu',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(label: badge.$2, status: badge.$1),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                      icon: Icons.calendar_month_outlined,
                      label: 'Tanggal',
                      value: Formatters.date(res.reservationTime)),
                  _InfoRow(
                      icon: Icons.access_time,
                      label: 'Jam',
                      value: Formatters.time(res.reservationTime)),
                  _InfoRow(
                      icon: Icons.group_outlined,
                      label: 'Jumlah Tamu',
                      value: '${res.guestCount} orang'),
                  _InfoRow(
                      icon: Icons.grid_view_outlined,
                      label: 'Kapasitas Meja',
                      value:
                          '${res.restaurantTable?.capacity ?? "-"} kursi'),
                  if (res.notes != null && res.notes!.isNotEmpty)
                    _InfoRow(
                        icon: Icons.note_outlined,
                        label: 'Catatan',
                        value: res.notes!),
                  if (res.createdAt != null)
                    _InfoRow(
                        icon: Icons.access_time,
                        label: 'Dibuat',
                        value: Formatters.dateTime(res.createdAt!)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go('/home/reservations'),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Kembali ke Daftar'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  (BadgeStatus, String) _status(String status) {
    switch (status) {
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
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textHint),
          const SizedBox(width: 8),
          Text('$label:',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
