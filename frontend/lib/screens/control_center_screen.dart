// lib/screens/control_center_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/section_chip.dart';
import '../core/widgets/page_header.dart';
import '../core/widgets/info_row.dart';
import '../core/widgets/gradient_button.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text.dart';
import '../providers/data_providers.dart';

/// Control Center tab – matches Phase 6 design.
class ControlCenterScreen extends ConsumerWidget {
  const ControlCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(controlModeProvider);
    final isSmart = mode == 'smart';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const PageHeader(
                chip: SectionChip(label: 'Thiết bị'),
                title: 'Trung tâm Điều khiển',
                subtitle: 'Để Aerogreen tự động vận hành, hoặc tự tay điều chỉnh.',
              ),
              const SizedBox(height: 24),
              // Mode toggle (smart / manual)
              _ModeToggle(isSmart: isSmart),
              const SizedBox(height: 24),
              // Content depending on mode
              Expanded(
                child: isSmart ? const _SmartModeCard() : const _ManualModeSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Segmented control for smart / manual mode.
class _ModeToggle extends ConsumerWidget {
  const _ModeToggle({required this.isSmart});
  final bool isSmart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.sage.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          // Smart segment
          Expanded(
            child: GestureDetector(
              onTap: () => ref.read(controlModeProvider.notifier).state = 'smart',
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: isSmart ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: isSmart
                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                      : null,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.auto_awesome, size: 16, color: AppColors.forestGreen),
                    SizedBox(width: 4),
                    Text('Thông minh', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
          // Manual segment
          Expanded(
            child: GestureDetector(
              onTap: () => ref.read(controlModeProvider.notifier).state = 'manual',
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: !isSmart ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: !isSmart
                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                      : null,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.tune, size: 16, color: AppColors.forestGreen),
                    SizedBox(width: 4),
                    Text('Thủ công', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Smart mode UI.
class _SmartModeCard extends ConsumerWidget {
  const _SmartModeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activePlant = ref.watch(currentPlantProvider);
    final plant = activePlant.plant;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 4,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFFDDEFE0), Colors.white]),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon tile
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.forestGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 12),
            Text('Đang chạy chu kỳ thông minh cho ${plant.name}',
                style: AppText.heading(context, fontSize: 20)),
            const SizedBox(height: 8),
            Text('Aerogreen đang tự động chăm sóc cây theo chu kỳ được tối ưu cho ${plant.variety.toLowerCase()} ${plant.name.toLowerCase()}.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
            const SizedBox(height: 16),
            // Info rows – translucent background
            Container(
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Column(
                children: [
                  InfoRow(label: 'CHU KỲ TƯỚI', value: '${plant.pumpMinutes} phút mỗi ${plant.pumpEveryMinutes} phút'),
                  const Divider(height: 1, thickness: 1, color: Colors.white24),
                  InfoRow(label: 'CHU KỲ DINH DƯỠNG', value: '${plant.nutrientMl}ml mỗi ${plant.nutrientEveryDays} ngày'),
                  const Divider(height: 1, thickness: 1, color: Colors.white24),
                  InfoRow(label: 'NHIỆT ĐỘ LÝ TƯỞNG', value: '${plant.tempMin}–${plant.tempMax}°C'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Manual mode UI – pump, nutrient spray, footnote.
class _ManualModeSection extends ConsumerWidget {
  const _ManualModeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pumpRunning = ref.watch(pumpRunningProvider);
    final nutrientDuration = ref.watch(nutrientDurationProvider);

    return SingleChildScrollView(
      child: Column(
        children: [
          // Pump card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.opacity, size: 28, color: AppColors.forestGreen),
                      SizedBox(width: 8),
                      Text('Máy Bơm Nước', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(pumpRunning ? 'Đang chạy' : 'Chờ', style: TextStyle(color: pumpRunning ? AppColors.forestGreen : Colors.grey)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ref.read(pumpRunningProvider.notifier).state = !pumpRunning;
                      },
                      icon: Icon(pumpRunning ? Icons.stop : Icons.play_arrow),
                      label: Text(pumpRunning ? 'Dừng' : '⏻ Bắt đầu'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pumpRunning ? Colors.redAccent : AppColors.forestGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Nutrient spray card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.science, size: 28, color: Color(0xFFF2A93B)),
                      SizedBox(width: 8),
                      Text('Phun Dinh Dưỡng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Điều chỉnh thời gian phun sương', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${nutrientDuration.toInt()}s', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Text(''),
                    ],
                  ),
                  Slider(
                    min: 5,
                    max: 90,
                    divisions: 17,
                    value: nutrientDuration,
                    activeColor: AppColors.forestGreen,
                    inactiveColor: Colors.grey[300],
                    label: '${nutrientDuration.toInt()}s',
                    onChanged: (v) => ref.read(nutrientDurationProvider.notifier).state = v,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('5 giây'),
                      Text('Khuyến nghị 30 giây'),
                      Text('90 giây'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GradientButton(
                    label: 'Phun Ngay',
                    onPressed: () async {
                      // Simple mock – show a SnackBar and pretend a short progress.
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đang phun...')),
                      );
                      await Future.delayed(const Duration(seconds: 1));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Hoàn thành!')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Footnote
          const Center(
            child: Text(
              'Chế độ thủ công sẽ tạm dừng chu kỳ Thông minh. Bạn có thể chuyển lại bất cứ lúc nào.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
