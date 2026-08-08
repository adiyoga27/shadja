import 'package:flutter/material.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/shared/widgets/shimmer.dart';

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message = 'Memuat…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// Skeleton placeholder for a menu card grid.
class MenuCardSkeleton extends StatelessWidget {
  const MenuCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Shimmer(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.shimmerBase,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  width: double.infinity,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Shimmer(
              child: Container(
                height: 14,
                width: double.infinity,
                color: AppColors.shimmerBase,
              ),
            ),
            const SizedBox(height: 6),
            Shimmer(
              child: Container(
                height: 12,
                width: 80,
                color: AppColors.shimmerBase,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen error widget.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.warning_outlined,
                size: 34,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.rotate_right, size: 18),
                label: const Text('Coba lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}