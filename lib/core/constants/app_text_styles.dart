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

  // TextStyle biasa tidak memuat file font tebal, jadi fontWeight-nya tidak
  // terlihat. Teks tebal harus lewat GoogleFonts seperti di bawah ini.
  static final cardTitle = _base(FontWeight.w700, 15, AppColors.textPrimary);
  static final amount = _base(FontWeight.w800, 16, AppColors.textPrimary);
  static final stat = _base(FontWeight.w800, 22, AppColors.textPrimary);
  static final label = _base(FontWeight.w600, 13, AppColors.textSecondary);
}
