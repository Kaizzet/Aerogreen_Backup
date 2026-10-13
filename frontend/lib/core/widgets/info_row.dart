// lib/core/widgets/info_row.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A labeled info row with an icon, uppercase label, and value.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  static IconData _defaultIcon(String label) {
    final l = label.toUpperCase();
    if (l.contains('TƯỚI') || l.contains('NƯỚC')) return Icons.opacity;
    if (l.contains('DINH') || l.contains('DƯỠNG')) return Icons.science;
    if (l.contains('NHIỆT')) return Icons.thermostat;
    return Icons.info_outline;
  }

  @override
  Widget build(BuildContext context) {
    final ic = icon ?? _defaultIcon(label);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.rowBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(ic, size: 16, color: AppColors.forestGreen),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.1,
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
