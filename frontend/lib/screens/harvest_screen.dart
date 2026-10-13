// lib/screens/harvest_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/page_header.dart';
import '../core/widgets/section_chip.dart';
import '../core/theme/app_colors.dart';

/// Simple model for a past harvest.
class HarvestRecord {
  final String plantName;
  final DateTime startDate;
  final DateTime harvestDate;
  final String yield; // e.g., "2 kg"

  const HarvestRecord({required this.plantName, required this.startDate, required this.harvestDate, required this.yield});
}

/// Mock harvest data.
final List<HarvestRecord> mockHarvests = [
  HarvestRecord(
    plantName: 'Xà lách',
    startDate: DateTime(2023, 4, 1),
    harvestDate: DateTime(2023, 5, 12),
    yield: '1.5 kg',
  ),
  HarvestRecord(
    plantName: 'Húng quế',
    startDate: DateTime(2023, 6, 10),
    harvestDate: DateTime(2023, 7, 25),
    yield: '0.8 kg',
  ),
];

/// Harvest history screen.
class HarvestScreen extends ConsumerWidget {
  const HarvestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              PageHeader(
                chip: SectionChip(label: 'Lịch sử thu hoạch'),
                title: 'Nhật ký thu hoạch',
                subtitle: '',
              ),
            ],
          ),
        ),
      ),
      // List of records
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 16.0, left: 20, right: 20),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: mockHarvests.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final h = mockHarvests[index];
            return ListTile(
              leading: const Icon(Icons.eco, color: AppColors.mint),
              title: Text('${h.plantName} – ${h.yield}'),
              subtitle: Text('Bắt đầu: ${h.startDate.day}/${h.startDate.month}/${h.startDate.year}\nThu hoạch: ${h.harvestDate.day}/${h.harvestDate.month}/${h.harvestDate.year}'),
            );
          },
        ),
      ),
    );
  }
}
