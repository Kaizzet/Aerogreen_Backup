// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/status_pill.dart';
import '../core/widgets/info_row.dart';
import '../core/widgets/gauge_ring.dart';
import '../core/widgets/skeleton.dart'; // placeholder skeleton widget
import '../providers/data_providers.dart';
import '../providers/user_provider.dart';
import '../data/models.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text.dart';

/// Home tab UI that matches the design (Phase 4).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // Greeting based on hour of day.
  String _greeting() {
    final hour = TimeOfDay.now().hour;
    if (hour < 12) return 'Chào buổi sáng';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  // Compute health percent from sensor vs. plant ideal ranges.
  double _healthPercent(SensorReading reading, Plant plant) {
    double waterScore = (reading.waterLevel / 100).clamp(0.0, 1.0);
    double nutrientScore = (reading.nutrientLevel / 100).clamp(0.0, 1.0);
    double tempMid = (plant.tempMin + plant.tempMax) / 2;
    double tempRange = (plant.tempMax - plant.tempMin) / 2;
    double tempScore = 1 - ((reading.temperature - tempMid).abs() / tempRange);
    tempScore = tempScore.clamp(0.0, 1.0);
    return ((waterScore + nutrientScore + tempScore) / 3) * 100;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider);
    final activePlant = ref.watch(currentPlantProvider);
    final sensorAsync = ref.watch(sensorStreamProvider);
    final alerts = ref.watch(alertsProvider);

    return RefreshIndicator(
      onRefresh: () async => await Future.delayed(const Duration(seconds: 1)),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with greeting and avatar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.secondaryText),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Vườn của ${user.fullName.split(' ')[0]}',
                            style: AppText.heading(context, fontSize: 24),
                          ),
                        ],
                      ),
                      // Avatar with gradient and initial
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.transparent,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [AppColors.sage, AppColors.forestGreen]),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            user.fullName[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Hero card – loading skeleton while sensor data resolves
                  sensorAsync.when(
                    data: (sensor) {
                      final health = _healthPercent(sensor, activePlant.plant).round();
                      return _HeroCard(activePlant: activePlant, sensor: sensor, healthPercent: health);
                    },
                    loading: () => Skeleton(height: 180, borderRadius: 28),
                    error: (_, _) => const Text('Lỗi tải cảm biến'),
                  ),
                  const SizedBox(height: 24),
                  // Sensor card
                  sensorAsync.when(
                    data: (sensor) => _SensorCard(activePlant: activePlant, sensor: sensor),
                    loading: () => Skeleton(height: 140, borderRadius: 24),
                    error: (_, _) => const Text('Lỗi cảm biến'),
                  ),
                  const SizedBox(height: 24),
                  // Care schedule card
                  _CareScheduleCard(activePlant: activePlant),
                  const SizedBox(height: 24),
                  // Alerts card
                  _AlertsCard(alerts: alerts),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Hero card widget – shows plant progress & health.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.activePlant, required this.sensor, required this.healthPercent});

  final ActivePlant activePlant;
  final SensorReading sensor;
  final int healthPercent;

  @override
  Widget build(BuildContext context) {
    final plant = activePlant.plant;
    final progress = (activePlant.currentDay + 1) / (plant.durationWeeks * 7);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.sage, AppColors.forestGreen]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          // Top‑right health percent
          Positioned(
            right: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$healthPercent%', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const Text('KHỎE MẠNH', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Translucent chip
              Container(
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.auto_awesome, color: Colors.white70, size: 16),
                    SizedBox(width: 4),
                    Text('ĐANG TRỒNG', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Plant name with leaf icon
              Row(
                children: [
                  const Icon(Icons.eco, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Text(plant.name, style: const TextStyle(color: Colors.white, fontSize: 28, fontFamily: 'Fraunces', fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              Text('${plant.variety} · Ngày ${activePlant.currentDay + 1} / ${plant.durationWeeks * 7}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 16),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Nảy mầm', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('Sinh trưởng', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('Thu hoạch', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Sensor card widget with three gauge rings.
class _SensorCard extends StatelessWidget {
  const _SensorCard({required this.activePlant, required this.sensor});

  final ActivePlant activePlant;
  final SensorReading sensor;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Cảm biến Trực tiếp', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const StatusPill(label: '● Đã đồng bộ', color: AppColors.primaryText),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GaugeRing(
                  label: 'MỨC NƯỚC',
                  value: sensor.waterLevel,
                  unit: '%',
                  color: AppColors.forestGreen,
                  icon: Icons.opacity,
                ),
                GaugeRing(
                  label: 'MỨC DINH DƯỠNG',
                  value: sensor.nutrientLevel,
                  unit: '%',
                  color: const Color(0xFFF2A93B), // nutrient gauge orange
                  icon: Icons.science,
                ),
                GaugeRing(
                  label: 'NHIỆT ĐỘ',
                  value: sensor.temperature,
                  unit: '°C',
                  color: const Color(0xFFCDB59A), // temp gauge tan
                  icon: Icons.thermostat,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Care schedule card – reflects current control mode.
class _CareScheduleCard extends ConsumerWidget {
  const _CareScheduleCard({required this.activePlant});

  final ActivePlant activePlant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plant = activePlant.plant;
    final mode = ref.watch(controlModeProvider);
    final isSmart = mode == 'smart';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Lịch chăm sóc ${plant.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                StatusPill(
                  label: isSmart ? 'Tự động tối ưu' : 'Đã tạm dừng',
                  color: isSmart ? AppColors.forestGreen : AppColors.alertRed,
                ),
              ],
            ),
            const SizedBox(height: 12),
            InfoRow(label: 'CHU KỲ TƯỚI', value: '${plant.pumpMinutes} phút mỗi ${plant.pumpEveryMinutes} phút'),
            InfoRow(label: 'CHU KỲ DINH DƯỠNG', value: '${plant.nutrientMl}ml mỗi ${plant.nutrientEveryDays} ngày'),
            InfoRow(label: 'NHIỆT ĐỘ LÝ TƯỞNG', value: '${plant.tempMin.toInt()}–${plant.tempMax.toInt()}°C'),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Alerts card.
class _AlertsCard extends ConsumerWidget {
  const _AlertsCard({required this.alerts});

  final List<AppAlert> alerts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Cảnh Báo / Thông Báo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                Text('\${alerts.length} đang hoạt động', style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            if (alerts.isEmpty)
              const Center(child: Text('Mọi thứ đều ổn 🌿'))
            else
              ...alerts.map((a) => AlertRow(
                    alert: a,
                    onResolve: () async {
                      final confirmed = await showModalBottomSheet<bool>(
                        context: context,
                        builder: (_) => Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Xác nhận xử lý "${a.title}"?'),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Xác nhận'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Hủy'),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (confirmed == true) {
                        // In a real app we would update the sensor values; omitted here.
                      }
                    },
                  )),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Simple placeholder AlertRow (replace with real implementation if exists).
class AlertRow extends StatelessWidget {
  const AlertRow({required this.alert, required this.onResolve, super.key});

  final AppAlert alert;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final urgent = alert.type == 'warning';
    final bg = urgent ? const Color(0xFFFDE7DC) : const Color(0xFFDDEFE0);
    final pill = urgent ? const Color(0xFFF2A93B) : const Color(0xFF8FAF94);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(radius: 12, backgroundColor: bg, child: const Icon(Icons.notifications, size: 16, color: Colors.black)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(alert.message, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onResolve,
            style: OutlinedButton.styleFrom(
              backgroundColor: pill,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Xử lý ngay', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
