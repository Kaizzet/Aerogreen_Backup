// lib/core/widgets/page_header.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'section_chip.dart';

/// Header used at the top of each screen.
class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    required this.subtitle,
    this.section,
    this.chip,
    super.key,
  });

  /// Optional text label for the section; if `chip` is provided, this is ignored.
  final String? section;

  /// Optional widget to display as a leading chip (e.g., SectionChip).
  final Widget? chip;

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chip != null) chip! else if (section != null) SectionChip(label: section!),
        const SizedBox(height: 8),
        Text(
          title,
          style: AppText.heading(context, fontSize: 24),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppText.label(context).copyWith(color: AppColors.secondaryText),
        ),
      ],
    );
  }
}
