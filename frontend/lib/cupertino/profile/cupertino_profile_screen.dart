import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../screens/alerts/notification_preferences_screen.dart';
import '../theme/cupertino_theme.dart';
import '../tickets/cupertino_support_tickets_screen.dart';
import 'cupertino_change_password_screen.dart';
import 'cupertino_profile_edit_screen.dart';

class CupertinoProfileScreen extends StatefulWidget {
  const CupertinoProfileScreen({super.key});

  @override
  State<CupertinoProfileScreen> createState() => _CupertinoProfileScreenState();
}

class _CupertinoProfileScreenState extends State<CupertinoProfileScreen> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshProfile());
  }

  Future<void> _refreshProfile() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);
    await context.read<AuthProvider>().loadProfile();
    if (mounted) setState(() => _isRefreshing = false);
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Đăng xuất'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Bạn có chắc muốn đăng xuất khỏi tài khoản này?'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await context.read<AuthProvider>().logout();
  }

  void _showAboutDialog() {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Về Aerogreen'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Hệ thống quản lý nông nghiệp khí canh thông minh Aerogreen.\n\n'
            'Phiên bản: 1.0.0 (Build 1)\n'
            'Bản quyền © 2026 Aerogreen Team.\n'
            'Phát triển với Flutter & ESP32 IoT.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final settings = Provider.of<AppSettingsProvider?>(context);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('Tài khoản'),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 44),
            onPressed: _isRefreshing ? null : _refreshProfile,
            child: const Icon(CupertinoIcons.arrow_2_circlepath),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildProfileHeader(context, user),
              const SizedBox(height: 24),

              _buildSectionTitle('TÀI KHOẢN'),
              const SizedBox(height: 8),
              _buildCardContainer([
                _buildActionRow(
                  context,
                  icon: CupertinoIcons.person_crop_circle,
                  title: 'Hồ sơ cá nhân',
                  subtitle: user?.fullName.isNotEmpty == true
                      ? user!.fullName
                      : 'Chưa cập nhật tên',
                  onTap: () {
                    Navigator.of(context).push<void>(
                      CupertinoPageRoute(
                        builder: (_) => const CupertinoProfileEditScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                _buildActionRow(
                  context,
                  icon: CupertinoIcons.lock_shield,
                  title: 'Đổi mật khẩu',
                  subtitle: 'Bảo mật tài khoản',
                  onTap: () {
                    Navigator.of(context).push<void>(
                      CupertinoPageRoute(
                        builder: (_) => const CupertinoChangePasswordScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                _buildActionRow(
                  context,
                  icon: CupertinoIcons.bell,
                  title: 'Tùy chọn thông báo',
                  subtitle: 'Cài đặt cảnh báo & giờ yên tĩnh',
                  onTap: () {
                    Navigator.of(context).push<void>(
                      CupertinoPageRoute(
                        builder: (_) => const NotificationPreferencesScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                _buildActionRow(
                  context,
                  icon: CupertinoIcons.question_circle,
                  title: 'Hỗ trợ khách hàng',
                  subtitle: 'Gửi ticket & trao đổi kỹ thuật',
                  onTap: () {
                    Navigator.of(context).push<void>(
                      CupertinoPageRoute(
                        builder: (_) => const CupertinoSupportTicketsScreen(),
                      ),
                    );
                  },
                ),
              ]),

              const SizedBox(height: 24),
              _buildSectionTitle('CÀI ĐẶT ỨNG DỤNG'),
              const SizedBox(height: 8),
              _buildCardContainer([
                // Language
                _buildWidgetRow(
                  context,
                  icon: CupertinoIcons.globe,
                  title: 'Ngôn ngữ',
                  trailing: CupertinoSlidingSegmentedControl<String>(
                    groupValue: settings?.locale.languageCode ?? 'vi',
                    children: const {
                      'vi': Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Text('Tiếng Việt', style: TextStyle(fontSize: 12)),
                      ),
                      'en': Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Text('English', style: TextStyle(fontSize: 12)),
                      ),
                    },
                    onValueChanged: (val) {
                      if (val != null) {
                        settings?.setLocale(Locale(val));
                      }
                    },
                  ),
                ),
                _buildDivider(),
                // Temperature Units
                _buildWidgetRow(
                  context,
                  icon: CupertinoIcons.thermometer,
                  title: 'Đơn vị nhiệt độ',
                  trailing: CupertinoSlidingSegmentedControl<TemperatureUnit>(
                    groupValue: settings?.temperatureUnit ?? TemperatureUnit.celsius,
                    children: const {
                      TemperatureUnit.celsius: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Text('°C', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      TemperatureUnit.fahrenheit: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Text('°F', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    },
                    onValueChanged: (val) {
                      if (val != null) {
                        settings?.setTemperatureUnit(val);
                      }
                    },
                  ),
                ),
                _buildDivider(),
                // Theme Mode
                _buildWidgetRow(
                  context,
                  icon: CupertinoIcons.moon,
                  title: 'Giao diện',
                  trailing: CupertinoSlidingSegmentedControl<AppThemeMode>(
                    groupValue: settings?.themeMode ?? AppThemeMode.system,
                    children: const {
                      AppThemeMode.system: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text('Hệ thống', style: TextStyle(fontSize: 11)),
                      ),
                      AppThemeMode.light: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text('Sáng', style: TextStyle(fontSize: 11)),
                      ),
                      AppThemeMode.dark: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text('Tối', style: TextStyle(fontSize: 11)),
                      ),
                    },
                    onValueChanged: (val) {
                      if (val != null) {
                        settings?.setThemeMode(val);
                      }
                    },
                  ),
                ),
              ]),

              const SizedBox(height: 24),
              _buildSectionTitle('THÔNG TIN'),
              const SizedBox(height: 8),
              _buildCardContainer([
                _buildActionRow(
                  context,
                  icon: CupertinoIcons.info_circle,
                  title: 'Phiên bản & Giới thiệu',
                  subtitle: '1.0.0 (Build 1)',
                  onTap: _showAboutDialog,
                ),
              ]),

              const SizedBox(height: 32),
              _buildLogoutButton(context),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(BuildContext context, User? user) {
    final fullName = (user?.fullName ?? '').trim();
    final isAdmin = user?.isAdmin ?? false;
    final initial = fullName.isEmpty
        ? '?'
        : fullName.substring(0, 1).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AerogreenCupertinoTheme.aerogreenPrimary,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isEmpty ? 'Chưa cập nhật tên' : fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (isAdmin
                            ? AerogreenCupertinoTheme.aerogreenTertiary
                            : AerogreenCupertinoTheme.aerogreenPrimary)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isAdmin ? 'Quản trị viên' : 'Người dùng',
                    style: TextStyle(
                      color: isAdmin
                          ? AerogreenCupertinoTheme.aerogreenTertiary
                          : AerogreenCupertinoTheme.aerogreenPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Text(
          title,
          style: const TextStyle(
            color: CupertinoColors.tertiaryLabel,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      );

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildActionRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AerogreenCupertinoTheme.aerogreenPrimary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: CupertinoColors.tertiaryLabel,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWidgetRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 340) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 22, color: AerogreenCupertinoTheme.aerogreenPrimary),
                    const SizedBox(width: 14),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: trailing,
                ),
              ],
            );
          }
          return Row(
            children: [
              Icon(icon, size: 22, color: AerogreenCupertinoTheme.aerogreenPrimary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
              trailing,
            ],
          );
        },
      ),
    );
  }

  Widget _buildDivider() => Padding(
        padding: const EdgeInsets.only(left: 52, right: 16),
        child: Container(
          height: 1,
          color: CupertinoColors.systemGrey5.resolveFrom(context),
        ),
      );

  Widget _buildLogoutButton(BuildContext context) {
    return CupertinoButton(
      color: CupertinoColors.destructiveRed.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.symmetric(vertical: 14),
      onPressed: _confirmLogout,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.square_arrow_right,
            color: CupertinoColors.destructiveRed,
            size: 20,
          ),
          SizedBox(width: 8),
          Text(
            'Đăng xuất',
            style: TextStyle(
              color: CupertinoColors.destructiveRed,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
