import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/core/utils/formatters.dart';
import 'package:shadja/features/menu/data/menu_model.dart';

class MenuCard extends StatelessWidget {
  const MenuCard({
    super.key,
    required this.item,
    this.onTap,
    this.quantityInCart,
  });

  final MenuItemModel item;
  final VoidCallback? onTap;
  final int? quantityInCart;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: item.image != null && item.image!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.image!,
                            fit: BoxFit.cover,
                            placeholder: (c, u) => Container(
                              color: AppColors.surfaceAlt,
                            ),
                            errorWidget: (c, u, e) => Container(
                              color: AppColors.surfaceAlt,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined,
                                  size: 28, color: AppColors.textHint),
                            ),
                          )
                        : Container(
                            color: AppColors.surfaceAlt,
                            alignment: Alignment.center,
                            child: const Icon(Icons.restaurant_menu,
                                size: 30, color: AppColors.textHint),
                          ),
                  ),
                  if (quantityInCart != null && quantityInCart! > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '$quantityInCart',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.rupiah(item.price),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}