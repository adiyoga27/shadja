import 'package:flutter/material.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/core/constants/app_text_styles.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.status,
  });

  final String label;
 final BadgeStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.label.copyWith(
          fontSize: 12,
          color: status.foreground,
        ),
      ),
    );
  }
}

enum BadgeStatus {
  success(AppColors.successBg, AppColors.success),
  warning(AppColors.warningBg, AppColors.warningText),
  info(AppColors.infoBg, AppColors.info),
  danger(AppColors.dangerBg, AppColors.danger),
  neutral(AppColors.surfaceAlt, AppColors.textSecondary);

  const BadgeStatus(this.background, this.foreground);

  final Color background;
  final Color foreground;
}