// lib/core/widgets/floating_pill_nav_bar.dart

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A floating bottom navigation bar with a pill‑shaped background for the selected
/// tab. It mirrors the design described in Phase 3.
class FloatingPillNavBar extends StatelessWidget {
  const FloatingPillNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final void Function(int) onTap;

  static const _icons = [
    Icons.home_outlined,
    Icons.spa_outlined,
    Icons.tune_outlined,
    Icons.grid_view_outlined,
  ];

  static const _labels = [
    'Trang chủ',
    'Chọn Giống',
    'Điều khiển',
    'Khác',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_icons.length, (index) {
              final selected = index == currentIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _icons[index],
                          color: selected ? AppColors.forestGreen : AppColors.primaryText,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _labels[index],
                          style: TextStyle(
                            fontSize: 12,
                            color: selected ? AppColors.forestGreen : AppColors.primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
