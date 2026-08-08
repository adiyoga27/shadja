import 'package:flutter/material.dart';
import 'package:shadja/core/constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.status,
  });

  final String label;
 final BadgeStatus status;

  Color get _bg {
    switch (status) {
      case BadgeStatus.success:
        return AppColors.successBg;
      case BadgeStatus.warning:
        return AppColors.warningBg;
      case BadgeStatus.info:
        return AppColors.infoBg;
      case BadgeStatus.danger:
        return AppColors.dangerBg;
      case BadgeStatus.neutral:
        return AppColors.surfaceAlt;
    }
  }

  Color get _fg {
    switch (status) {
      case BadgeStatus.success:
        return AppColors.success;
      case BadgeStatus.warning:
        return AppColors.warning;
      case BadgeStatus.info:
        return AppColors.info;
      case BadgeStatus.danger:
        return AppColors.danger;
      case BadgeStatus.neutral:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _fg,
        ),
      ),
    );
  }
}

enum BadgeStatus { success, warning, info, danger, neutral }