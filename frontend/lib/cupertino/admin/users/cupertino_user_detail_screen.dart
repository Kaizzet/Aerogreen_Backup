// ============================================================
// cupertino_user_detail_screen.dart
// Màn hình chi tiết user của Admin.
// Chức năng:
//   - Hiển thị thông tin đầy đủ của user
//   - Danh sách devices thuộc user
//   - Danh sách tickets của user
//   - Actions: Khóa/Mở khóa, Reset password, Xóa
//
// Callback:
//   - onUserUpdated: được gọi khi user bị thay đổi (khóa/mở/xóa)
//     → truyền Map<String, dynamic> data mới về cho UsersScreen
//     → UsersScreen cập nhật lại _allUsers
// ============================================================

import 'package:flutter/cupertino.dart';

import '../../../services/api_service.dart';
import '../../theme/cupertino_theme.dart';

class CupertinoUserDetailScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  // Callback thông báo cho UsersScreen khi user có thay đổi.
  // Truyền data mới (đã update) để list có thể refresh.
  final ValueChanged<Map<String, dynamic>>? onUserUpdated;

  const CupertinoUserDetailScreen({
    super.key,
    required this.user,
    this.onUserUpdated,
  });

  @override
  State<CupertinoUserDetailScreen> createState() =>
      _CupertinoUserDetailScreenState();
}

class _CupertinoUserDetailScreenState extends State<CupertinoUserDetailScreen> {
  final _apiService = ApiService();

  // _user là bản copy của widget.user. Mọi thay đổi diễn ra ở đây,
  // sau đó được "đẩy" về UsersScreen qua callback onUserUpdated.
  late Map<String, dynamic> _user;

  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _tickets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Tạo bản copy độc lập để không ảnh hưởng widget.user gốc
    _user = Map<String, dynamic>.from(widget.user);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getAdminUser(_user['id'] as String);
      final user = Map<String, dynamic>.from(response['user'] as Map);
      final roles = (user['roles'] as List<dynamic>? ?? []).cast<String>();
      _user = {
        ..._user,
        ...user,
        'role': roles.contains('Admin') ? 'admin' : 'user',
      };
      _devices = (response['devices'] as List<dynamic>? ?? [])
          .map((device) => Map<String, dynamic>.from(device as Map))
          .toList();
      _tickets = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_user['fullName'] ?? 'Chi tiết'),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator(radius: 14))
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProfileHeader(context),
                    const SizedBox(height: 24),
                    _buildInfoCard(context),
                    const SizedBox(height: 24),
                    _buildDevicesSection(context),
                    const SizedBox(height: 24),
                    _buildTicketsSection(context),
                    const SizedBox(height: 24),
                    _buildActionsSection(context),
                  ],
                ),
              ),
      ),
    );
  }

  // ==================== PROFILE HEADER ====================
  // Avatar lớn + tên + email + badges (role, status)
  Widget _buildProfileHeader(BuildContext context) {
    final role = _user['role'] as String? ?? 'user';
    final isAdmin = role == 'admin';
    final isLocked = _user['isLocked'] as bool? ?? false;

    return Column(
      children: [
        // Avatar lớn (màu xanh lá cho admin, xanh dương cho user)
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: isAdmin
                ? AerogreenCupertinoTheme.aerogreenPrimary
                : CupertinoColors.systemBlue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              isAdmin
                  ? CupertinoIcons.shield_lefthalf_fill
                  : CupertinoIcons.person_fill,
              color: CupertinoColors.white,
              size: 44,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Tên user
        Text(
          _user['fullName'] ?? 'Không tên',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: CupertinoColors.label.resolveFrom(context),
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),

        // Email
        Text(
          _user['email'] ?? '',
          style: TextStyle(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),

        // Badges: Admin (nếu có) + Trạng thái
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isAdmin) ...[
              _buildBadge(
                context,
                icon: CupertinoIcons.shield_lefthalf_fill,
                label: 'ADMIN',
                color: AerogreenCupertinoTheme.aerogreenPrimary,
              ),
              const SizedBox(width: 8),
            ],
            _buildBadge(
              context,
              icon: isLocked
                  ? CupertinoIcons.lock_fill
                  : CupertinoIcons.checkmark_circle_fill,
              label: isLocked ? 'Đã khóa' : 'Hoạt động',
              color: isLocked
                  ? CupertinoColors.systemRed
                  : AerogreenCupertinoTheme.aerogreenPrimary,
            ),
          ],
        ),
      ],
    );
  }

  // Widget badge nhỏ (dùng cho ADMIN / Hoạt động / Đã khóa)
  Widget _buildBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== INFO CARD ====================
  // Card chứa thông tin cơ bản: ID, Email, Ngày tham gia, Số thiết bị
  Widget _buildInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            context,
            icon: CupertinoIcons.person_fill,
            label: 'ID',
            value: _user['id'] ?? 'N/A',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            icon: CupertinoIcons.mail_solid,
            label: 'Email',
            value: _user['email'] ?? 'N/A',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            icon: CupertinoIcons.calendar,
            label: 'Ngày tham gia',
            value: _formatDate(_user['joinedAt']),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            icon: CupertinoIcons.device_phone_portrait,
            label: 'Số thiết bị',
            value: '${_devices.length} thiết bị',
          ),
        ],
      ),
    );
  }

  // Row thông tin: icon + label + value
  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: CupertinoColors.tertiarySystemBackground.resolveFrom(
              context,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 15,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== DEVICES SECTION ====================
  // Hiển thị tối đa 5 devices của user
  Widget _buildDevicesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, 'Thiết bị', '${_devices.length}'),
        const SizedBox(height: 10),
        if (_devices.isEmpty)
          _emptyState(
            context,
            icon: CupertinoIcons.device_phone_portrait,
            message: 'Chưa có thiết bị nào.',
          )
        else
          ..._devices
              .take(5)
              .map(
                (device) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildDeviceTile(context, device),
                ),
              ),
      ],
    );
  }

  // Card device: tên + status (online/offline)
  Widget _buildDeviceTile(BuildContext context, Map<String, dynamic> device) {
    final isOnline = device['isOnline'] as bool? ?? false;
    final color = isOnline
        ? AerogreenCupertinoTheme.aerogreenPrimary
        : CupertinoColors.systemRed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              CupertinoIcons.device_phone_portrait,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device['name'] ?? '',
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TICKETS SECTION ====================
  // Hiển thị tối đa 3 tickets của user
  Widget _buildTicketsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, 'Support Tickets', '${_tickets.length}'),
        const SizedBox(height: 10),
        if (_tickets.isEmpty)
          _emptyState(
            context,
            icon: CupertinoIcons.chat_bubble_2,
            message: 'Không có ticket nào.',
          )
        else
          ..._tickets
              .take(3)
              .map(
                (ticket) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildTicketTile(context, ticket),
                ),
              ),
      ],
    );
  }

  // Card ticket: subject + status
  Widget _buildTicketTile(BuildContext context, Map<String, dynamic> ticket) {
    final status = ticket['status'] as String? ?? 'open';
    final color = status == 'open'
        ? CupertinoColors.systemRed
        : status == 'in_progress'
        ? CupertinoColors.systemOrange
        : AerogreenCupertinoTheme.aerogreenPrimary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              CupertinoIcons.chat_bubble_2_fill,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket['subject'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status == 'open'
                      ? 'Mới'
                      : status == 'in_progress'
                      ? 'Đang xử lý'
                      : 'Đã đóng',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ACTIONS SECTION ====================
  // Các nút hành động được API hỗ trợ.
  Widget _buildActionsSection(BuildContext context) {
    final isLocked = _user['isLocked'] as bool? ?? false;
    final isAdmin = _user['role'] == 'admin';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildActionButton(
          context,
          icon: isAdmin
              ? CupertinoIcons.person_fill
              : CupertinoIcons.shield_lefthalf_fill,
          label: isAdmin ? 'Chuyển thành người dùng' : 'Cấp quyền Admin',
          color: isAdmin
              ? CupertinoColors.systemOrange
              : AerogreenCupertinoTheme.aerogreenPrimary,
          onPressed: _toggleRole,
        ),
        if (!isAdmin) const SizedBox(height: 12),
        // Nút Khóa/Mở khóa (ẩn nếu là admin)
        if (!isAdmin)
          _buildActionButton(
            context,
            icon: isLocked
                ? CupertinoIcons.lock_open_fill
                : CupertinoIcons.lock_fill,
            label: isLocked ? 'Mở khóa tài khoản' : 'Khóa tài khoản',
            color: isLocked
                ? AerogreenCupertinoTheme.aerogreenPrimary
                : CupertinoColors.systemOrange,
            onPressed: _toggleLock,
          ),
      ],
    );
  }

  // Nút action button lớn (full width)
  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(double.infinity, 48),
      onPressed: onPressed,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== HELPERS ====================
  // Header section: title + count badge
  Widget _sectionHeader(BuildContext context, String title, String count) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: CupertinoColors.label.resolveFrom(context),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemBackground.resolveFrom(
              context,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            count,
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // Empty state cho section (không có data)
  Widget _emptyState(
    BuildContext context, {
    required IconData icon,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 32,
            color: CupertinoColors.tertiaryLabel.resolveFrom(context),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // Format ISO date → dd/MM/yyyy
  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'N/A';
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return 'N/A';
    }
  }

  // ==================== ACTIONS HANDLERS ====================
  // Khóa / Mở khóa tài khoản
  Future<void> _toggleLock() async {
    final isLocked = _user['isLocked'] as bool? ?? false;
    try {
      await _apiService.updateAdminUserLock(_user['id'] as String, !isLocked);
      if (!mounted) return;
      setState(() => _user['isLocked'] = !isLocked);
      widget.onUserUpdated?.call(Map<String, dynamic>.from(_user));
      _showMessage(!isLocked ? 'Đã khóa tài khoản' : 'Đã mở khóa tài khoản');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  Future<void> _toggleRole() async {
    final newRole = _user['role'] == 'admin' ? 'User' : 'Admin';
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Xác nhận thay đổi quyền'),
        content: Text('Chuyển ${_user['email']} thành $newRole?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: newRole == 'User',
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final user = await _apiService.updateAdminUserRole(
        _user['id'] as String,
        newRole,
      );
      final roles = (user['roles'] as List<dynamic>? ?? []).cast<String>();
      if (!mounted) return;
      setState(() => _user = {
            ..._user,
            ...user,
            'role': roles.contains('Admin') ? 'admin' : 'user',
          });
      widget.onUserUpdated?.call(Map<String, dynamic>.from(_user));
      _showMessage('Đã cập nhật quyền');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  // Dialog thông báo đơn giản
  void _showMessage(String message) {
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
