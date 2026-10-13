// lib/screens/plant_picker_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/section_chip.dart';
import '../core/widgets/page_header.dart';
import '../core/widgets/gradient_button.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text.dart';
import '../data/models.dart';
import '../data/mock_data.dart';
import '../providers/data_providers.dart';

/// Plant Picker tab – matches the design in Phase 5.
class PlantPickerScreen extends ConsumerWidget {
  const PlantPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activePlant = ref.watch(currentPlantProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page header
              const PageHeader(
                chip: SectionChip(label: 'Chọn Giống Cây'),
                title: 'Chọn Giống Cây',
                subtitle: 'Chọn cây — hệ thống sẽ tự động điều chỉnh ánh sáng, nước và dinh dưỡng.',
              ),
              const SizedBox(height: 24),
              // 2‑column grid of plant cards
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: mockPlants.length,
                  itemBuilder: (context, index) {
                    final plant = mockPlants[index];
                    final isCurrent = plant.id == activePlant.plant.id;
                    return _PlantCard(
                      plant: plant,
                      isCurrent: isCurrent,
                      onStart: isCurrent
                          ? null
                          : () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Xác nhận'),
                                  content: Text('Bạn sẽ thay thế "${activePlant.plant.name}" bằng "${plant.name}". Tiếp tục?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Hủy'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Đồng ý'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                // Reset active plant state.
                                ref.read(currentPlantProvider.notifier).state = ActivePlant(
                                  plant: plant,
                                  startDate: DateTime.now(),
                                  currentDay: 1,
                                );
                                // Show feedback.
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Bắt đầu trồng ${plant.name}')), // Vietnamese message
                                  );
                                }
                              }
                            },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Individual plant card widget.
class _PlantCard extends StatelessWidget {
  const _PlantCard({
    required this.plant,
    required this.isCurrent,
    this.onStart,
  });

  final Plant plant;
  final bool isCurrent;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Illustration area with pastel tint.
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                color: plant.tintColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                plant.illustration,
                style: const TextStyle(fontSize: 36),
              ),
            ),
            const SizedBox(height: 8),
            // Plant name and variety.
            Text(
              plant.name,
              style: AppText.heading(context, fontSize: 18),
            ),
            Text(
              plant.variety,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            // Meta row – duration & difficulty.
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${plant.durationWeeks} tuần', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 12),
                const Icon(Icons.emoji_nature, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(plant.difficulty, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            // Scheduling lines.
            Row(
              children: [
                const Icon(Icons.opacity, size: 16, color: AppColors.forestGreen),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('Bơm ${plant.pumpMinutes} phút mỗi ${plant.pumpEveryMinutes} phút', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.science, size: 16, color: Color(0xFFF2A93B)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('Bổ sung ${plant.nutrientMl}ml mỗi ${plant.nutrientEveryDays} ngày', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.thermostat, size: 16, color: Color(0xFFCDB59A)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('${plant.tempMin}–${plant.tempMax}°C', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const Spacer(),
            // Action button.
            SizedBox(
              width: double.infinity,
              child: isCurrent
                  ? ElevatedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check),
                      label: const Text('✓ Đang trồng'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.forestGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    )
                  : GradientButton(
                      label: 'Bắt Đầu Trồng',
                      onPressed: onStart,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
