// lib/screens/alerts_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/page_header.dart';
import '../core/widgets/section_chip.dart';
import '../core/theme/app_colors.dart';
import '../providers/settings_provider.dart';

/// Alerts management screen – toggles for low water, low nutrient, temperature alert, harvest reminder.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                chip: SectionChip(label: 'Thông báo'),
                title: 'Cài đặt Cảnh báo',
                subtitle: '',
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('Cảnh báo nước thấp'),
                value: settings.lowWaterAlert,
                onChanged: (value) => notifier.update(lowWaterAlert: value),
              ),
              SwitchListTile(
                title: const Text('Cảnh báo dinh dưỡng thấp'),
                value: settings.lowNutrientAlert,
                onChanged: (value) => notifier.update(lowNutrientAlert: value),
              ),
              SwitchListTile(
                title: const Text('Cảnh báo nhiệt độ'),
                value: settings.temperatureAlert,
                onChanged: (value) => notifier.update(temperatureAlert: value),
              ),
              SwitchListTile(
                title: const Text('Nhắc nhở thu hoạch'),
                value: settings.harvestReminder,
                onChanged: (value) => notifier.update(harvestReminder: value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
