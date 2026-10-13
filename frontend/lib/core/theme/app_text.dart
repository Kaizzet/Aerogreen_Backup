// lib/core/theme/app_text.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppText {
  // Serif headings (Fraunces or DM Serif Display)
  static TextStyle heading(BuildContext context, {FontWeight fontWeight = FontWeight.w600, double fontSize = 24}) {
    return GoogleFonts.dmSerifDisplay(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: AppColors.primaryText,
    );
  }

  // Body text – Plus Jakarta Sans
  static TextStyle body(BuildContext context, {FontWeight fontWeight = FontWeight.w400, double fontSize = 14}) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: AppColors.primaryText,
    );
  }

  // Small caps label (all caps, letter spacing)
  static TextStyle label(BuildContext context, {double fontSize = 12, FontWeight fontWeight = FontWeight.w500}) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: 1.2,
      color: AppColors.secondaryText,
    ).copyWith(textBaseline: TextBaseline.alphabetic);
  }
}
