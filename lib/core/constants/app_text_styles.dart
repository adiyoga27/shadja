import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle _base(FontWeight weight, double size, Color color) =>
      GoogleFonts.plusJakartaSans(
        fontWeight: weight,
        fontSize: size,
        color: color,
      );

  static TextStyle theme({TextStyle? base}) {
    if (base == null) return GoogleFonts.plusJakartaSans();
    final color = base.color ?? AppColors.textPrimary;
    return GoogleFonts.plusJakartaSans().copyWith(
      fontSize: base.fontSize,
      fontWeight: base.fontWeight,
      color: color,
    );
  }

  static final heading = _base(FontWeight.bold, 24, AppColors.textPrimary);
  static final title = _base(FontWeight.w700, 20, AppColors.textPrimary);
  static final subtitle = _base(FontWeight.w600, 16, AppColors.textPrimary);
  static final body = _base(FontWeight.normal, 14, AppColors.textPrimary);
  static final caption = _base(FontWeight.normal, 13, AppColors.textSecondary);
  static final small = _base(FontWeight.normal, 12, AppColors.textSecondary);
}