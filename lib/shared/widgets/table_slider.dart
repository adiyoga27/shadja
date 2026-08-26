import 'package:flutter/material.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/features/reservation/data/reservation_model.dart';

/// Slider horizontal untuk memilih meja (geser kiri-kanan).
class TableSlider extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tables.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final t = tables[index];
          final selected = selectedId == t.id;
          final occupied = t.status != 'kosong';
          return GestureDetector(
            onTap: () => onSelect(t.id),
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
                    selected
                        ? Icons.check_circle
                        : Icons.table_bar_outlined,
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
        },
      ),
    );
  }
}