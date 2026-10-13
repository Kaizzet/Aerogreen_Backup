// ============================================================
// cupertino_logs_screen.dart
// Màn hình Nhật ký hoạt động (System Logs).
// Chức năng:
//   - Danh sách logs với severity (info/warning/error/critical)
//   - Filter theo severity
//   - Tap log → xem chi tiết
// ============================================================

import 'package:flutter/cupertino.dart';

import '../../../services/api_service.dart';
import '../../theme/cupertino_theme.dart';

enum LogFilter { all, user, device, ticket }

class CupertinoLogsScreen extends StatefulWidget {
  const CupertinoLogsScreen({super.key});

  @override
  State<CupertinoLogsScreen> createState() => _CupertinoLogsScreenState();
}

class _CupertinoLogsScreenState extends State<CupertinoLogsScreen> {
  final _apiService = ApiService();

  List<Map<String, dynamic>> _allLogs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  LogFilter _selectedFilter = LogFilter.all;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getAdminAuditLogs();
      _allLogs = (response['items'] as List<dynamic>? ?? []).map((item) {
        final log = item as Map<String, dynamic>;
        return <String, dynamic>{
          ...log,
          'type': 'admin',
          'severity': 'info',
          'message': log['action'] ?? '',
          'detail': '${log['previousValue'] ?? ''} ${log['newValue'] ?? ''}'
              .trim(),
          'userId': log['actorUserId'],
          'deviceId': log['targetType'] == 'device' ? log['targetId'] : null,
          'createdAt': log['createdAt'],
        };
      }).toList();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _applyFilter();
        });
      }
    }
  }

  void _applyFilter() {
    if (_selectedFilter == LogFilter.all) {
      setState(() => _filteredLogs = List.from(_allLogs));
      return;
    }

    final filterName = _selectedFilter.name;
    setState(() {
       _filteredLogs = _allLogs
           .where((log) => log['targetType'] == filterName)
           .toList();
    });
  }

  Map<LogFilter, int> _getCounts() {
    return {
      LogFilter.all: _allLogs.length,
      LogFilter.user: _allLogs.where((l) => l['targetType'] == 'user').length,
      LogFilter.device: _allLogs.where((l) => l['targetType'] == 'device').length,
      LogFilter.ticket: _allLogs.where((l) => l['targetType'] == 'ticket').length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('Nhật ký'),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 44),
            onPressed: _loadLogs,
            child: const Icon(CupertinoIcons.arrow_2_circlepath),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: _loadLogs),

        // Filter chips
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
            child: _buildFilterChips(context),
          ),
        ),

        // Content
        if (_isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CupertinoActivityIndicator(radius: 14)),
          )
        else if (_filteredLogs.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(context),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final log = _filteredLogs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LogTile(log: log, onTap: () => _showLogDetail(log)),
                );
              }, childCount: _filteredLogs.length),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final counts = _getCounts();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildChip(
            context,
            LogFilter.all,
            'Tất cả',
            counts[LogFilter.all] ?? 0,
          ),
          const SizedBox(width: 8),
          _buildChip(
            context,
             LogFilter.user,
             'Users',
             counts[LogFilter.user] ?? 0,
          ),
          const SizedBox(width: 8),
          _buildChip(
            context,
             LogFilter.device,
             'Devices',
             counts[LogFilter.device] ?? 0,
          ),
          const SizedBox(width: 8),
          _buildChip(
            context,
             LogFilter.ticket,
             'Tickets',
             counts[LogFilter.ticket] ?? 0,
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context,
    LogFilter filter,
    String label,
    int count,
  ) {
    final isSelected = _selectedFilter == filter;
    final color = isSelected
        ? AerogreenCupertinoTheme.aerogreenPrimary
        : CupertinoColors.secondaryLabel.resolveFrom(context);

    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = filter);
        _applyFilter();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AerogreenCupertinoTheme.aerogreenPrimary
              : CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? CupertinoColors.white
                    : CupertinoColors.label.resolveFrom(context),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? CupertinoColors.white.withValues(alpha: 0.25)
                    : CupertinoColors.tertiaryLabel
                          .resolveFrom(context)
                          .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? CupertinoColors.white : color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.doc_text,
              size: 64,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
            const SizedBox(height: 16),
            Text(
              'Không có log nào',
              style: TextStyle(
                color: CupertinoColors.label.resolveFrom(context),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Chọn filter khác để xem log.',
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

  void _showLogDetail(Map<String, dynamic> log) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(_severityLabel(log['severity'])),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(log['message'] ?? ''),
              const SizedBox(height: 12),
              Text(
                'Type: ${log['type'] ?? 'N/A'}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                'Detail: ${log['detail'] ?? 'N/A'}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                'Time: ${_formatDateTime(log['createdAt'])}',
                style: const TextStyle(fontSize: 12),
              ),
              if (log['userId'] != null)
                Text(
                  'User: ${log['userId']}',
                  style: const TextStyle(fontSize: 12),
                ),
              if (log['deviceId'] != null)
                Text(
                  'Device: ${log['deviceId']}',
                  style: const TextStyle(fontSize: 12),
                ),
            ],
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

  String _severityLabel(String? severity) {
    switch (severity) {
      case 'info':
        return 'Thông tin';
      case 'warning':
        return 'Cảnh báo';
      case 'error':
        return 'Lỗi';
      case 'critical':
        return 'Nghiêm trọng';
      default:
        return 'Log';
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
}

// ============================================================
// Widget con: Log Tile
// ============================================================
class _LogTile extends StatelessWidget {
  final Map<String, dynamic> log;
  final VoidCallback onTap;

  const _LogTile({required this.log, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final severity = log['severity'] as String? ?? 'info';
    final color = _severityColor(severity);
    final icon = _severityIcon(severity);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: color, width: 3)),
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
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type badge + time
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          (log['type'] ?? 'log').toString().toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(log['createdAt']),
                        style: TextStyle(
                          color: CupertinoColors.tertiaryLabel.resolveFrom(
                            context,
                          ),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Message
                  Text(
                    log['message'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: CupertinoColors.label.resolveFrom(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'info':
        return CupertinoColors.systemBlue;
      case 'warning':
        return CupertinoColors.systemOrange;
      case 'error':
        return CupertinoColors.systemRed;
      case 'critical':
        return CupertinoColors.systemPurple;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  IconData _severityIcon(String severity) {
    switch (severity) {
      case 'info':
        return CupertinoIcons.info_circle_fill;
      case 'warning':
        return CupertinoIcons.exclamationmark_triangle_fill;
      case 'error':
        return CupertinoIcons.exclamationmark_circle_fill;
      case 'critical':
        return CupertinoIcons.exclamationmark_octagon_fill;
      default:
        return CupertinoIcons.doc_text;
    }
  }

  String _formatTime(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final dt = DateTime.parse(isoDate);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}p trước';
      if (diff.inHours < 24) return '${diff.inHours}h trước';
      return '${diff.inDays}d trước';
    } catch (_) {
      return '';
    }
  }
}
