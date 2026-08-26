import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/features/reservation/data/reservation_model.dart';
import 'package:shadja/features/reservation/presentation/reservation_provider.dart';

/// Slider horizontal untuk memilih meja (geser kiri-kanan).
///
/// - Status meja (terisi/kosong) di-refresh otomatis dari server tiap 20 detik
///   selama halaman terbuka, plus bisa di-refresh manual lewat ikon panah.
/// - Menampilkan indikator panah kiri/kanan bila daftar bisa digeser, dan
///   tombol panah untuk menggulir cepat.
class TableSlider extends ConsumerStatefulWidget {
  const TableSlider({
    super.key,
    required this.tables,
    required this.selectedId,
    required this.onSelect,
  });

  final List<RestaurantTableModel> tables;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  @override
  ConsumerState<TableSlider> createState() => _TableSliderState();
}

class _TableSliderState extends ConsumerState<TableSlider> {
  final _scrollCtrl = ScrollController();
  Timer? _refreshTimer;
  bool _canLeft = false;
  bool _canRight = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_updateArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
    // Auto-refresh status meja agar "terisi/kosong" selalu mutakhir.
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) ref.invalidate(tablesProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollCtrl.removeListener(_updateArrows);
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TableSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tables.length != widget.tables.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
    }
  }

  void _updateArrows() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    final canLeft = pos.pixels > 1;
    final canRight = pos.pixels < pos.maxScrollExtent - 1;
    if (canLeft != _canLeft || canRight != _canRight) {
      setState(() {
        _canLeft = canLeft;
        _canRight = canRight;
      });
    }
  }

  void _scrollBy(double delta) {
    _scrollCtrl.animateTo(
      (_scrollCtrl.offset + delta)
          .clamp(0, _scrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scrollable = _canLeft || _canRight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            SizedBox(
              height: 74,
              child: ListView.separated(
                controller: _scrollCtrl,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: widget.tables.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) => _buildCard(widget.tables[index]),
              ),
            ),
            if (_canRight)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: _ArrowButton(
                  icon: Icons.chevron_right,
                  onTap: () => _scrollBy(200),
                ),
              ),
            if (_canLeft)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: _ArrowButton(
                  icon: Icons.chevron_left,
                  onTap: () => _scrollBy(-200),
                ),
              ),
          ],
        ),
        if (scrollable) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.swipe, size: 14, color: AppColors.textHint),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'Geser ke kiri/kanan untuk lihat meja lain',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                tooltip: 'Perbarui status meja',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => ref.invalidate(tablesProvider),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCard(RestaurantTableModel t) {
    final selected = widget.selectedId == t.id;
    final occupied = t.status != 'kosong';
    return GestureDetector(
      onTap: () => widget.onSelect(t.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryBg
              : occupied
                  ? AppColors.surfaceAlt
                  : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.table_bar_outlined,
              size: 18,
              color: occupied && !selected
                  ? AppColors.textHint
                  : selected
                      ? AppColors.primary
                      : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              'Meja ${t.tableNumber}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: occupied && !selected
                    ? AppColors.textHint
                    : selected
                        ? AppColors.primary
                        : AppColors.textPrimary,
              ),
            ),
            Text(
              occupied ? 'Terisi' : '${t.capacity} kursi',
              style: TextStyle(
                fontSize: 11,
                fontWeight: occupied ? FontWeight.w600 : null,
                color: occupied && !selected
                    ? AppColors.danger
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.9),
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}