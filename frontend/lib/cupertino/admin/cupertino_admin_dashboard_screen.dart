// ============================================================
// cupertino_admin_dashboard_screen.dart
// Màn hình chính của Admin Panel.
// Chịu trách nhiệm:
//   - Layout responsive (mobile bottom bar / desktop sidebar)
//   - Điều hướng giữa 8 tab chính
//   - Tab "Khác" mở ActionSheet cho các tab phụ (mobile)
//   - Xử lý đăng xuất
// ============================================================

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../theme/cupertino_theme.dart';
import 'dashboard/admin_overview_tab.dart';
import 'users/cupertino_users_screen.dart';
import 'devices/cupertino_admin_devices_screen.dart';
import 'tickets/cupertino_tickets_screen.dart';
import 'monitoring/cupertino_monitoring_screen.dart';
import 'logs/cupertino_logs_screen.dart';
import 'config/cupertino_system_config_screen.dart';
import 'reports/cupertino_reports_screen.dart';

// ==================== MAIN WIDGET ====================
class CupertinoAdminDashboardScreen extends StatefulWidget {
  const CupertinoAdminDashboardScreen({super.key});

  @override
  State<CupertinoAdminDashboardScreen> createState() =>
      _CupertinoAdminDashboardScreenState();
}

class _CupertinoAdminDashboardScreenState
    extends State<CupertinoAdminDashboardScreen> {
  // Tab hiện tại:
  // 0 = Tổng quan, 1 = Users, 2 = Devices, 3 = Tickets,
  // 4 = Monitoring, 5 = Logs, 6 = Config, 7 = Reports
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 1024;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isDesktop) _buildSidebar(context),
                Expanded(child: _buildContent(context, isDesktop)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ==================== CONTENT BUILDER ====================
  Widget _buildContent(BuildContext context, bool isDesktop) {
    // Danh sách các tab chính (index 0-7)
    final Widget content = _getTabContent(_selectedTab);

    return _wrapWithBottomBar(context, isDesktop, content);
  }

  Widget _getTabContent(int tab) {
    switch (tab) {
      case 0:
        return const AdminOverviewTab();
      case 1:
        return const CupertinoUsersScreen();
      case 2:
        return const CupertinoAdminDevicesScreen();
      case 3:
        return const CupertinoTicketsScreen();
      case 4:
        return const CupertinoMonitoringScreen();
      case 5:
        return const CupertinoLogsScreen();
      case 6:
        return const CupertinoSystemConfigScreen();
      case 7:
        return const CupertinoReportsScreen();
      default:
        return const AdminOverviewTab();
    }
  }

  // ==================== WRAP WITH BOTTOM BAR ====================
  Widget _wrapWithBottomBar(
      BuildContext context,
      bool isDesktop,
      Widget content,
      ) {
    if (isDesktop) return content;
    return Column(
      children: [
        Expanded(child: content),
        _buildBottomBar(context),
      ],
    );
  }

  // ==================== SIDEBAR (DESKTOP) ====================
  Widget _buildSidebar(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Container(
      width: 248,
      padding: const EdgeInsets.fromLTRB(20, 28, 16, 20),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        border: Border(
          right: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                CupertinoIcons.shield_lefthalf_fill,
                color: AerogreenCupertinoTheme.aerogreenPrimary,
              ),
              const SizedBox(width: 10),
              Text(
                'Admin Panel',
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Scrollable menu
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SidebarItem(
                    icon: CupertinoIcons.house_fill,
                    label: 'Tổng quan',
                    selected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                  _SidebarItem(
                    icon: CupertinoIcons.person_2_fill,
                    label: 'Người dùng',
                    selected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                  _SidebarItem(
                    icon: CupertinoIcons.device_phone_portrait,
                    label: 'Thiết bị',
                    selected: _selectedTab == 2,
                    onTap: () => setState(() => _selectedTab = 2),
                  ),
                  _SidebarItem(
                    icon: CupertinoIcons.chat_bubble_2_fill,
                    label: 'Tickets',
                    selected: _selectedTab == 3,
                    onTap: () => setState(() => _selectedTab = 3),
                  ),
                  _SidebarItem(
                    icon: CupertinoIcons.chart_bar_alt_fill,
                    label: 'Giám sát',
                    selected: _selectedTab == 4,
                    onTap: () => setState(() => _selectedTab = 4),
                  ),
                  _SidebarItem(
                    icon: CupertinoIcons.doc_text_fill,
                    label: 'Nhật ký',
                    selected: _selectedTab == 5,
                    onTap: () => setState(() => _selectedTab = 5),
                  ),
                  _SidebarItem(
                    icon: CupertinoIcons.settings,
                    label: 'Cấu hình',
                    selected: _selectedTab == 6,
                    onTap: () => setState(() => _selectedTab = 6),
                  ),
                  _SidebarItem(
                    icon: CupertinoIcons.graph_square_fill,
                    label: 'Báo cáo',
                    selected: _selectedTab == 7,
                    onTap: () => setState(() => _selectedTab = 7),
                  ),
                ],
              ),
            ),
          ),

          // User info + logout
          Text(
            'ĐĂNG NHẬP VỚI',
            style: TextStyle(
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            user?.email ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            onPressed: () => _confirmLogout(context),
            child: Row(
              children: const [
                Icon(
                  CupertinoIcons.square_arrow_right,
                  size: 17,
                  color: CupertinoColors.systemRed,
                ),
                SizedBox(width: 8),
                Text(
                  'Đăng xuất',
                  style: TextStyle(color: CupertinoColors.systemRed),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BOTTOM BAR (MOBILE) ====================
  Widget _buildBottomBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground
            .resolveFrom(context)
            .withValues(alpha: 0.94),
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
          ),
        ),
      ),
      padding: const EdgeInsets.only(bottom: 8, top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BottomItem(
            icon: CupertinoIcons.house_fill,
            label: 'Tổng quan',
            selected: _selectedTab == 0,
            onTap: () => setState(() => _selectedTab = 0),
          ),
          _BottomItem(
            icon: CupertinoIcons.person_2_fill,
            label: 'Users',
            selected: _selectedTab == 1,
            onTap: () => setState(() => _selectedTab = 1),
          ),
          _BottomItem(
            icon: CupertinoIcons.device_phone_portrait,
            label: 'Thiết bị',
            selected: _selectedTab == 2,
            onTap: () => setState(() => _selectedTab = 2),
          ),
          _BottomItem(
            icon: CupertinoIcons.chat_bubble_2_fill,
            label: 'Tickets',
            selected: _selectedTab == 3,
            onTap: () => setState(() => _selectedTab = 3),
          ),
          // Tab "Khác" — mở ActionSheet
          _BottomItem(
            icon: CupertinoIcons.ellipsis_circle_fill,
            label: 'Khác',
            selected: _selectedTab >= 4,
            onTap: _showMoreOptions,
          ),
        ],
      ),
    );
  }

  // ==================== ACTION SHEET "KHÁC" ====================
  void _showMoreOptions() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (actionContext) => CupertinoActionSheet(
        title: const Text('Tùy chọn khác'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(actionContext).pop();
              setState(() => _selectedTab = 4);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.chart_bar_alt_fill,
                  size: 18,
                  color: CupertinoColors.systemBlue,
                ),
                SizedBox(width: 8),
                Text('Giám sát hệ thống'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(actionContext).pop();
              setState(() => _selectedTab = 5);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.doc_text_fill,
                  size: 18,
                  color: CupertinoColors.systemOrange,
                ),
                SizedBox(width: 8),
                Text('Nhật ký hoạt động'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(actionContext).pop();
              setState(() => _selectedTab = 6);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.settings,
                  size: 18,
                  color: CupertinoColors.systemGrey,
                ),
                SizedBox(width: 8),
                Text('Cấu hình hệ thống'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(actionContext).pop();
              setState(() => _selectedTab = 7);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.graph_square_fill,
                  size: 18,
                  color: CupertinoColors.systemPurple,
                ),
                SizedBox(width: 8),
                Text('Báo cáo & Thống kê'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(actionContext).pop(),
          child: const Text('Hủy'),
        ),
      ),
    );
  }

  // ==================== LOGOUT CONFIRMATION ====================
  void _confirmLogout(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Đăng xuất'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Bạn có chắc muốn đăng xuất khỏi Admin Panel?'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Hủy'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<AuthProvider>().logout();
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}

// ==================== SIDEBAR ITEM ====================
class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    alignment: Alignment.centerLeft,
    onPressed: onTap,
    child: Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: selected
              ? AerogreenCupertinoTheme.aerogreenPrimary
              : CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: selected
                ? AerogreenCupertinoTheme.aerogreenPrimary
                : CupertinoColors.label.resolveFrom(context),
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    ),
  );
}

// ==================== BOTTOM ITEM ====================
class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    minimumSize: const Size(44, 44),
    onPressed: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 21,
          color: selected
              ? AerogreenCupertinoTheme.aerogreenPrimary
              : CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: selected
                ? AerogreenCupertinoTheme.aerogreenPrimary
                : CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ],
    ),
  );
}