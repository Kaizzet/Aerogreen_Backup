// lib/core/widgets/section_chip.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// A small pill used as a section label.
class SectionChip extends StatelessWidget {
  const SectionChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.mintChip,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppText.label(context).copyWith(color: AppColors.primaryText),
      ),
    );
  }
}
