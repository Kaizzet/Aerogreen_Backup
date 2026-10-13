// ============================================================
// cupertino_admin_device_detail.dart
// Màn hình chi tiết device của Admin.
// Chức năng:
//   - Hiển thị thông tin device
//   - Sensor readings (nhiệt độ, độ ẩm, độ ẩm đất)
//   - Điều khiển bơm (bật/tắt)
//   - Lịch sử bơm
//   - Actions: Gán user, Xóa
// ============================================================

import 'package:flutter/cupertino.dart';

import '../../../services/api_service.dart';
import '../../theme/cupertino_theme.dart';

class CupertinoAdminDeviceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const CupertinoAdminDeviceDetailScreen({
    super.key,
    required this.device,
  });

  @override
  State<CupertinoAdminDeviceDetailScreen> createState() =>
      _CupertinoAdminDeviceDetailScreenState();
}

class _CupertinoAdminDeviceDetailScreenState
    extends State<CupertinoAdminDeviceDetailScreen> {
  final _apiService = ApiService();

  late Map<String, dynamic> _device;
  List<Map<String, dynamic>> _pumpHistory = [];
  bool _isLoading = true;
  bool _isPumping = false;

  @override
  void initState() {
    super.initState();
    // Copy device để không ảnh hưởng widget gốc
    _device = Map<String, dynamic>.from(widget.device);
    _isPumping = _device['isPumping'] as bool? ?? false;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getAdminDevice(_device['id'] as String);
      final device = Map<String, dynamic>.from(response['device'] as Map);
      final reading = response['latestReading'] as Map<String, dynamic>?;
      _device = {
        ..._device,
        ...device,
        'temperature': reading?['temperature'],
        'humidity': reading?['humidity'],
        'waterLevel': reading?['waterLevel'],
      };
      _isPumping = _device['isPumpOn'] == true;
      _pumpHistory = (response['pumpCommands'] as List<dynamic>? ?? []).map((item) {
        final command = item as Map<String, dynamic>;
        return <String, dynamic>{
          'id': command['id'],
          'time': command['issuedAt'],
          'duration': command['durationSeconds'] ?? 0,
          'isOn': command['isOn'],
          'trigger': command['source'] == 1 ? 'Tự động' : 'Thủ công',
        };
      }).toList();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_device['name'] ?? 'Chi tiết'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: _showMoreActions,
          child: const Icon(CupertinoIcons.ellipsis_circle),
        ),
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
              _buildSensorSection(context),
              const SizedBox(height: 24),
              _buildPumpControlSection(context),
              const SizedBox(height: 24),
              _buildInfoCard(context),
              const SizedBox(height: 24),
              _buildPumpHistorySection(context),
              const SizedBox(height: 24),
              _buildActionsSection(context),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== PROFILE HEADER ====================
  // Icon + tên + owner + badges
  Widget _buildProfileHeader(BuildContext context) {
    final isOnline = _device['isOnline'] as bool? ?? false;

    return Column(
      children: [
        // Icon device lớn
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: isOnline
                ? AerogreenCupertinoTheme.aerogreenPrimary
                : CupertinoColors.systemRed,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              CupertinoIcons.device_phone_portrait,
              color: CupertinoColors.white,
              size: 44,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Tên device
        Text(
          _device['name'] ?? 'Không tên',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: CupertinoColors.label.resolveFrom(context),
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),

        // Owner
        Text(
          _device['ownerEmail'] ?? 'Chưa gán',
          style: TextStyle(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),

        // Badges
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBadge(
              context,
              icon: isOnline
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.xmark_circle_fill,
              label: isOnline ? 'Online' : 'Offline',
              color: isOnline
                  ? AerogreenCupertinoTheme.aerogreenPrimary
                  : CupertinoColors.systemRed,
            ),
            if (_isPumping) ...[
              const SizedBox(width: 8),
              _buildBadge(
                context,
                icon: CupertinoIcons.cloud_fog_fill,
                label: 'Đang phun',
                color: CupertinoColors.systemTeal,
              ),
            ],
          ],
        ),
      ],
    );
  }

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

  // ==================== SENSOR SECTION ====================
  // 3 ô lớn: Nhiệt độ, Độ ẩm, Độ ẩm đất
  Widget _buildSensorSection(BuildContext context) {
    final temperature = _device['temperature'] as num?;
    final humidity = _device['humidity'] as num?;
    final waterLevel = _device['waterLevel'] as num?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, 'Cảm biến', 'Realtime'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SensorCard(
                icon: CupertinoIcons.thermometer,
                label: 'Nhiệt độ',
                value: temperature?.toStringAsFixed(1) ?? '--',
                unit: '°C',
                color: CupertinoColors.systemOrange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SensorCard(
                icon: CupertinoIcons.drop_fill,
                label: 'Độ ẩm',
                value: humidity?.toStringAsFixed(0) ?? '--',
                unit: '%',
                color: CupertinoColors.systemBlue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SensorCard(
                icon: CupertinoIcons.leaf_arrow_circlepath,
                label: 'Nước',
                value: waterLevel?.toStringAsFixed(0) ?? '--',
                unit: '%',
                color: AerogreenCupertinoTheme.aerogreenPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== PUMP CONTROL ====================
  // Nút bật/tắt bơm
  Widget _buildPumpControlSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, 'Điều khiển bơm', null),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isPumping
                ? CupertinoColors.systemTeal.withValues(alpha: 0.1)
                : CupertinoColors.secondarySystemBackground
                .resolveFrom(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isPumping
                  ? CupertinoColors.systemTeal
                  : CupertinoColors.separator.resolveFrom(context),
              width: _isPumping ? 1.5 : 0.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _isPumping
                          ? CupertinoColors.systemTeal.withValues(alpha: 0.2)
                          : CupertinoColors.tertiarySystemBackground
                          .resolveFrom(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isPumping
                          ? CupertinoIcons.cloud_fog_fill
                          : CupertinoIcons.cloud_fog,
                      color: _isPumping
                          ? CupertinoColors.systemTeal
                          : CupertinoColors.secondaryLabel
                          .resolveFrom(context),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isPumping ? 'Đang phun sương' : 'Bơm đang tắt',
                          style: TextStyle(
                            color: CupertinoColors.label.resolveFrom(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isPumping
                              ? 'Bơm đang hoạt động'
                              : 'Nhấn nút bên dưới để bật',
                          style: TextStyle(
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Nút Bật/Tắt
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(double.infinity, 48),
                onPressed: null,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: _isPumping
                        ? CupertinoColors.systemRed
                        : AerogreenCupertinoTheme.aerogreenPrimary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isPumping
                            ? CupertinoIcons.stop_fill
                            : CupertinoIcons.play_fill,
                        color: CupertinoColors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Trạng thái chỉ đọc',
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== INFO CARD ====================
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
            label: 'Device ID',
            value: _device['id'] ?? 'N/A',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            icon: CupertinoIcons.tag_fill,
            label: 'Tên thiết bị',
            value: _device['name'] ?? 'N/A',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            icon: CupertinoIcons.mail_solid,
            label: 'Owner',
            value: _device['ownerEmail'] ?? 'Chưa gán',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            icon: CupertinoIcons.calendar,
            label: 'Ngày tạo',
            value: _formatDate(_device['createdAt']),
          ),
        ],
      ),
    );
  }

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
            color: CupertinoColors.tertiarySystemBackground
                .resolveFrom(context),
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

  // ==================== PUMP HISTORY ====================
  Widget _buildPumpHistorySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, 'Lịch sử bơm', '${_pumpHistory.length} lần'),
        const SizedBox(height: 10),
        if (_pumpHistory.isEmpty)
          _emptyState(context)
        else
          ..._pumpHistory.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildHistoryTile(context, item),
          )),
      ],
    );
  }

  Widget _buildHistoryTile(BuildContext context, Map<String, dynamic> item) {
    final duration = item['duration'] as int? ?? 0;
    final trigger = item['trigger'] as String? ?? 'Thủ công';

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
              color: CupertinoColors.systemTeal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              CupertinoIcons.cloud_fog_fill,
              color: CupertinoColors.systemTeal,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$duration giây • $trigger',
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDateTime(item['time']),
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ACTIONS ====================
  Widget _buildActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildActionButton(
          context,
          icon: CupertinoIcons.person_crop_circle_badge_checkmark,
          label: _device['ownerId'] == null ? 'Gán cho user' : 'Đổi owner',
          color: CupertinoColors.systemBlue,
          onPressed: _assignDevice,
        ),
        if (_device['ownerId'] != null) ...[
          const SizedBox(height: 10),
          _buildActionButton(
            context,
            icon: CupertinoIcons.person_crop_circle_badge_xmark,
            label: 'Hủy gán owner',
            color: CupertinoColors.systemRed,
            onPressed: _unassignDevice,
          ),
        ],
      ],
    );
  }

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
  Widget _sectionHeader(BuildContext context, String title, String? trailing) {
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
        if (trailing != null)
          Text(
            trailing,
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            CupertinoIcons.cloud_fog,
            size: 32,
            color: CupertinoColors.tertiaryLabel.resolveFrom(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Chưa có lịch sử bơm.',
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

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

  String _formatDateTime(String? isoDate) {
    if (isoDate == null) return 'N/A';
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')} • '
          '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'N/A';
    }
  }

  // ==================== ACTIONS HANDLERS ====================
  void _showMoreActions() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (actionContext) => CupertinoActionSheet(
        title: Text(_device['name'] ?? ''),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(actionContext).pop();
              _assignDevice();
            },
            child: const Text('Gán cho user'),
          ),
          if (_device['ownerId'] != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.of(actionContext).pop();
                await _unassignDevice();
              },
              child: const Text('Hủy gán owner'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(actionContext).pop(),
          child: const Text('Hủy'),
        ),
      ),
    );
  }

  Future<void> _assignDevice() async {
    final response = await _apiService.getAdminUsers();
    if (!mounted) return;
    final users = response['items'] as List<dynamic>? ?? [];
    showCupertinoModalPopup<void>(
      context: context,
      builder: (actionContext) => CupertinoActionSheet(
        title: const Text('Chọn user để gán'),
        actions: users.map((item) {
          final user = item as Map<String, dynamic>;
          return CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.of(actionContext).pop();
              final updated = await _apiService.updateAdminDeviceOwner(
                _device['id'] as String,
                user['id'] as String,
              );
              if (!mounted) return;
              setState(() => _device = {..._device, ...updated});
              _showToast('Đã gán cho ${user['email']}');
            },
            child: Text(user['email'] as String? ?? ''),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(actionContext).pop(),
          child: const Text('Hủy'),
        ),
      ),
    );
  }

  Future<void> _unassignDevice() async {
    final updated = await _apiService.updateAdminDeviceOwner(
      _device['id'] as String,
      null,
    );
    if (!mounted) return;
    setState(() => _device = {..._device, ...updated});
    _showToast('Đã hủy gán owner');
  }

  void _showToast(String message) {
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

// ============================================================
// Widget con: Card hiển thị 1 giá trị cảm biến
// ============================================================
class _SensorCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _SensorCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
