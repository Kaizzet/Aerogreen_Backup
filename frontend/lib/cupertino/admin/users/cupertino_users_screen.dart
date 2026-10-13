// ============================================================
// cupertino_users_screen.dart
// Màn hình Quản lý người dùng của Admin.
// Chức năng:
//   - Hiển thị danh sách users
//   - Search theo tên/email
//   - Filter theo trạng thái (All/Active/Locked/Admin)
//   - Tap vào user → mở chi tiết
//   - Long-press → action sheet (khóa/mở khóa, reset, xóa)
//
// Đồng bộ state:
//   - Khi mở Detail, truyền callback onUserUpdated
//   - Detail gọi callback khi user thay đổi → update _allUsers
//   - KHÔNG gọi _loadUsers() sau khi pop (tránh reset)
//
// 🐛 FIX BUG:
//   - Thêm ValueKey cho UserListTile dựa trên isLocked + index
//   - Khi isLocked thay đổi → key thay đổi → Flutter tự rebuild widget
// ============================================================

import 'package:flutter/cupertino.dart';
import '../widgets/admin_logout_button.dart';

import '../../../services/api_service.dart';
import 'cupertino_user_detail_screen.dart';
import 'widgets/user_filter_chips.dart';
import 'widgets/user_list_tile.dart';

class CupertinoUsersScreen extends StatefulWidget {
  const CupertinoUsersScreen({super.key});

  @override
  State<CupertinoUsersScreen> createState() => _CupertinoUsersScreenState();
}

class _CupertinoUsersScreenState extends State<CupertinoUsersScreen> {
  final _apiService = ApiService();
  final _searchController = TextEditingController();

  // _allUsers: dữ liệu gốc (không bị filter)
  // _filteredUsers: dữ liệu đã áp filter + search để hiển thị
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];

  UserFilter _selectedFilter = UserFilter.all;
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getAdminUsers(),
        _apiService.getAdminDevices(),
      ]);
      final devices =
          (results[1]['items'] as List<dynamic>? ?? []);
      _allUsers =
          (results[0]['items'] as List<dynamic>? ?? [])
              .map((item) {
                final user = item as Map<String, dynamic>;
                final roles = (user['roles'] as List<dynamic>? ?? []);
                return <String, dynamic>{
                  ...user,
                  'role': roles.any((r) => r == 'Admin') ? 'admin' : 'user',
                  'isLocked': user['isLocked'] == true,
                  'deviceCount': devices
                      .where(
                        (device) =>
                            (device as Map<String, dynamic>)['ownerId'] ==
                            user['id'],
                      )
                      .length,
                  'joinedAt': '',
                };
              })
              .toList();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _applyFilter();
        });
      }
    }
  }

  // Áp dụng filter theo tab + search query
  void _applyFilter() {
    List<Map<String, dynamic>> result = List.from(_allUsers);

    // Filter theo tab
    switch (_selectedFilter) {
      case UserFilter.all:
        break;
      case UserFilter.active:
        result = result.where((u) => u['isLocked'] != true).toList();
        break;
      case UserFilter.locked:
        result = result.where((u) => u['isLocked'] == true).toList();
        break;
      case UserFilter.admin:
        result = result.where((u) => u['role'] == 'admin').toList();
        break;
    }

    // Filter theo search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((u) {
        final name = (u['fullName'] as String? ?? '').toLowerCase();
        final email = (u['email'] as String? ?? '').toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    }

    setState(() => _filteredUsers = result);
  }

  // Đếm số user cho từng filter chip
  Map<UserFilter, int> _getCounts() {
    return {
      UserFilter.all: _allUsers.length,
      UserFilter.active: _allUsers.where((u) => u['isLocked'] != true).length,
      UserFilter.locked: _allUsers.where((u) => u['isLocked'] == true).length,
      UserFilter.admin: _allUsers.where((u) => u['role'] == 'admin').length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Navigation bar
        CupertinoSliverNavigationBar(
          largeTitle: const Text('Người dùng'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                onPressed: _loadUsers,
                child: const Icon(CupertinoIcons.arrow_2_circlepath),
              ),
              const AdminLogoutButton(),
            ],
          ),
        ),

        // Pull to refresh
        CupertinoSliverRefreshControl(onRefresh: _loadUsers),

        // Search bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: CupertinoSearchTextField(
              controller: _searchController,
              placeholder: 'Tìm theo tên hoặc email...',
              onChanged: (value) {
                _searchQuery = value;
                _applyFilter();
              },
            ),
          ),
        ),

        // Filter chips
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: UserFilterChips(
              selected: _selectedFilter,
              counts: _getCounts(),
              onChanged: (filter) {
                setState(() => _selectedFilter = filter);
                _applyFilter();
              },
            ),
          ),
        ),

        // Content: loading / empty / list
        if (_isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CupertinoActivityIndicator(radius: 14)),
          )
        else if (_filteredUsers.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(context),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final user = _filteredUsers[index];

                // 🐛 FIX BUG: ValueKey dựa trên id + isLocked
                // Khi isLocked thay đổi → key khác → Flutter rebuild
                final isLocked = user['isLocked'] == true;
                final key = ValueKey(
                  'user_${user['id']}_${isLocked ? 'locked' : 'active'}',
                );

                return Padding(
                  key: key,
                  padding: const EdgeInsets.only(bottom: 8),
                  child: UserListTile(
                    user: user,
                    onTap: () => _openUserDetail(user),
                    onLongPress: () => _showUserActions(user),
                  ),
                );
              }, childCount: _filteredUsers.length),
            ),
          ),
      ],
    );
  }

  // Empty state khi không có user nào
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.person_2,
              size: 64,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
            const SizedBox(height: 16),
            Text(
              'Không tìm thấy người dùng',
              style: TextStyle(
                color: CupertinoColors.label.resolveFrom(context),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Thử tìm với từ khóa khác.'
                  : 'Chưa có người dùng nào trong hệ thống.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Mở màn hình chi tiết user
  // Truyền callback onUserUpdated để nhận data mới khi user thay đổi
  Future<void> _openUserDetail(Map<String, dynamic> user) async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute(
        builder: (_) => CupertinoUserDetailScreen(
          user: user,
          // 🔥 Callback: nhận data mới từ Detail và update _allUsers
          onUserUpdated: (updatedUser) {
            final index = _allUsers.indexWhere(
              (u) => u['id'] == updatedUser['id'],
            );
            if (index != -1) {
              setState(() {
                // Replace user cũ bằng data mới (copy để tránh reference)
                _allUsers[index] = Map<String, dynamic>.from(updatedUser);
              });
              // Apply lại filter để UI refresh
              _applyFilter();
            }
          },
        ),
      ),
    );
    // KHÔNG gọi _loadUsers() ở đây — sẽ reset data về gốc
  }

  // Action sheet khi long-press user
  Future<void> _showUserActions(Map<String, dynamic> user) async {
    final isLocked = user['isLocked'] as bool? ?? false;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (actionContext) => CupertinoActionSheet(
        title: Text(user['fullName'] ?? ''),
        message: Text(user['email'] ?? ''),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(actionContext).pop();
              _openUserDetail(user);
            },
            child: const Text('Xem chi tiết'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.of(actionContext).pop();
              await _toggleLock(user);
            },
            child: Text(isLocked ? 'Mở khóa tài khoản' : 'Khóa tài khoản'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(actionContext).pop(),
          child: const Text('Hủy'),
        ),
      ),
    );
  }

  // Khóa / Mở khóa tài khoản (từ long-press action sheet)
  Future<void> _toggleLock(Map<String, dynamic> user) async {
    final isLocked = user['isLocked'] as bool? ?? false;
    try {
      await _apiService.updateAdminUserLock(user['id'] as String, !isLocked);
      if (!mounted) return;
      await _loadUsers();
      _showToast(
        !isLocked ? 'Đã khóa tài khoản' : 'Đã mở khóa tài khoản',
        color: !isLocked
            ? CupertinoColors.systemRed
            : CupertinoColors.systemGreen,
      );
    } catch (error) {
      if (mounted) {
        _showToast(error.toString(), color: CupertinoColors.systemRed);
      }
    }
  }

  // Dialog thông báo đơn giản (toast-like)
  void _showToast(String message, {required Color color}) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
