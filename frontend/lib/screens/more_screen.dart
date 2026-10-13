// lib/screens/more_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/section_chip.dart';
import '../core/widgets/page_header.dart';
import '../core/widgets/outline_danger_button.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text.dart';
import '../providers/auth_controller.dart';
import '../providers/user_provider.dart';
import 'package:go_router/go_router.dart';

/// "More" / "Khác" tab – profile and navigable rows.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                chip: SectionChip(label: 'Tài khoản'),
                title: 'Khác',
                subtitle: '',
              ),
              const SizedBox(height: 24),
              // Profile card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Gradient avatar with initial "M"
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.forestGreen, AppColors.sage]),
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        alignment: Alignment.center,
                        child: const Text('M', style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.fullName, style: AppText.heading(context, fontSize: 20)),
                            const SizedBox(height: 4),
                            Text(user.email, style: const TextStyle(color: AppColors.forestGreen)),
                          ],
                        ),
                      ),
                      // Plan pill "Pro"
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.mint.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Pro', style: TextStyle(color: AppColors.mint, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // List of rows
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 2,
                child: Column(
                  children: [
                    _ListRow(
                      icon: Icons.notifications, // bell
                      title: 'Thông báo',
                      subtitle: 'Quản lý cảnh báo',
                      onTap: () => context.go('/more/alerts'),
                    ),
                    const Divider(height: 1),
                    _ListRow(
                      icon: Icons.settings, // gear
                      title: 'Tùy chỉnh',
                      subtitle: 'Đơn vị, ngôn ngữ',
                      onTap: () => context.go('/more/settings'),
                    ),
                    const Divider(height: 1),
                    _ListRow(
                      icon: Icons.eco, // leaf
                      title: 'Lịch sử thu hoạch',
                      subtitle: 'Đã trồng 32 cây',
                      onTap: () => context.go('/more/harvest'),
                    ),
                    const Divider(height: 1),
                    _ListRow(
                      icon: Icons.help_center, // help circle
                      title: 'Trợ giúp & Hỗ trợ',
                      subtitle: 'Câu hỏi thường gặp và chat',
                      onTap: () => context.go('/more/help'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Logout button
              OutlineDangerButton(
                label: 'Đăng xuất',
                icon: Icons.logout,
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Xác nhận'),
                      content: const Text('Bạn có chắc muốn đăng xuất?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Đăng xuất')),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (!context.mounted) return;
                    context.go('/auth');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.mint.withValues(alpha: 0.2),
        child: Icon(icon, color: AppColors.mint),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
    );
  }
}
