// ============================================================
// cupertino_ticket_detail_screen.dart
// Màn hình chi tiết ticket của Admin (chat-style).
// Chức năng:
//   - Hiển thị thông tin user + status + priority
//   - Danh sách tin nhắn (user bên trái, admin bên phải)
//   - Ô nhập tin nhắn + nút Gửi
//   - Đổi status (Open → InProgress → Closed)
//   - Đổi priority (High/Medium/Low)
//   - Trả về data mới khi pop (để list refresh)
// ============================================================

import 'package:flutter/cupertino.dart';

import '../../theme/cupertino_theme.dart';
import '../../../services/api_service.dart';

class CupertinoTicketDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;

  const CupertinoTicketDetailScreen({
    super.key,
    required this.ticket,
  });

  @override
  State<CupertinoTicketDetailScreen> createState() =>
      _CupertinoTicketDetailScreenState();
}

class _CupertinoTicketDetailScreenState
    extends State<CupertinoTicketDetailScreen> {
  late Map<String, dynamic> _ticket;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _apiService = ApiService();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _ticket = Map<String, dynamic>.from(widget.ticket);
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Load tin nhắn từ ApiService
  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getAdminTicket(_ticket['id'].toString());
      final messages = (response['messages'] as List<dynamic>? ?? []).map((item) {
        final message = item as Map<String, dynamic>;
        return <String, dynamic>{
          'id': message['id'],
          'sender': message['isAdmin'] == true ? 'admin' : 'user',
          'text': message['message'],
          'time': message['createdAt'],
        };
      }).toList();
      if (!mounted) return;
      setState(() {
        _ticket = Map<String, dynamic>.from(response['ticket'] as Map);
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) _showToast('$error');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_ticket['id'] ?? 'Ticket'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: _showMoreActions,
          child: const Icon(CupertinoIcons.ellipsis_circle),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header: user info + badges
            _buildHeader(context),

            // Divider
            Container(
              height: 0.5,
              color: CupertinoColors.separator.resolveFrom(context),
            ),

            // Messages list
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator(radius: 14))
                  : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                physics: const BouncingScrollPhysics(),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _MessageBubble(
                    message: message,
                    userName: _ticket['userName'] ?? 'User',
                  );
                },
              ),
            ),

            // Input bar
            _buildInputBar(context),
          ],
        ),
      ),
    );
  }

  // ==================== HEADER ====================
  Widget _buildHeader(BuildContext context) {
    final status = _ticket['status'] as String? ?? 'open';
    final priority = _ticket['priority'] as String? ?? 'low';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Row(
        children: [
          // Avatar user
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.person_fill,
                color: CupertinoColors.systemBlue,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ticket['userName'] ?? 'Unknown',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _buildMiniBadge(
                      context,
                      label: _statusLabel(status),
                      color: _statusColor(status),
                    ),
                    const SizedBox(width: 6),
                    _buildMiniBadge(
                      context,
                      label: _priorityLabel(priority),
                      color: _priorityColor(priority),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(
      BuildContext context, {
        required String label,
        required Color color,
      }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ==================== INPUT BAR ====================
  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Text field
            Expanded(
              child: CupertinoTextField(
                controller: _messageController,
                placeholder: 'Nhập tin nhắn...',
                minLines: 1,
                maxLines: 4,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: CupertinoColors.secondarySystemBackground
                      .resolveFrom(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: CupertinoColors.separator.resolveFrom(context),
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),

            // Send button
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              onPressed: _sendMessage,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AerogreenCupertinoTheme.aerogreenPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.arrow_up,
                  color: CupertinoColors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ACTIONS HANDLERS ====================
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      await _apiService.replyToAdminTicket(_ticket['id'].toString(), text);
      _messageController.clear();
      await _loadMessages();
    } catch (error) {
      if (mounted) _showToast('$error');
    }
  }

  void _showMoreActions() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (actionContext) => CupertinoActionSheet(
        title: Text(_ticket['subject'] ?? ''),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(actionContext).pop();
              _changeStatus();
            },
            child: const Text('Đổi trạng thái'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(actionContext).pop();
              _changePriority();
            },
            child: const Text('Đổi độ ưu tiên'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(actionContext).pop(),
          child: const Text('Hủy'),
        ),
      ),
    );
  }

  void _changeStatus() {
    final current = _ticket['status'] as String? ?? 'open';
    final statuses = ['open', 'in_progress', 'closed'];
    final labels = ['Mới', 'Đang xử lý', 'Đã đóng'];

    showCupertinoModalPopup<void>(
      context: context,
      builder: (actionContext) => CupertinoActionSheet(
        title: const Text('Chọn trạng thái'),
        actions: List.generate(statuses.length, (i) {
          return CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.of(actionContext).pop();
              try {
                await _apiService.updateAdminTicketStatus(_ticket['id'].toString(), statuses[i]);
                await _loadMessages();
                if (mounted) _showToast('Đã đổi trạng thái: ${labels[i]}');
              } catch (error) {
                if (mounted) _showToast('$error');
              }
            },
            child: Text(
              labels[i],
              style: TextStyle(
                fontWeight: statuses[i] == current
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          );
        }),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(actionContext).pop(),
          child: const Text('Hủy'),
        ),
      ),
    );
  }

  void _changePriority() {
    final priorities = ['high', 'medium', 'low'];
    final labels = ['Cao', 'Trung bình', 'Thấp'];

    showCupertinoModalPopup<void>(
      context: context,
      builder: (actionContext) => CupertinoActionSheet(
        title: const Text('Chọn độ ưu tiên'),
        actions: List.generate(priorities.length, (i) {
          return CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.of(actionContext).pop();
              try {
                await _apiService.updateAdminTicketPriority(_ticket['id'].toString(), priorities[i]);
                await _loadMessages();
                if (mounted) _showToast('Đã đổi ưu tiên: ${labels[i]}');
              } catch (error) {
                if (mounted) _showToast('$error');
              }
            },
            child: Text(labels[i]),
          );
        }),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(actionContext).pop(),
          child: const Text('Hủy'),
        ),
      ),
    );
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

  // ==================== HELPERS ====================
  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return CupertinoColors.systemRed;
      case 'in_progress':
        return CupertinoColors.systemOrange;
      case 'closed':
        return AerogreenCupertinoTheme.aerogreenPrimary;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'MỚI';
      case 'in_progress':
        return 'ĐANG XỬ LÝ';
      case 'closed':
        return 'ĐÃ ĐÓNG';
      default:
        return 'KHÁC';
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'high':
        return CupertinoColors.systemRed;
      case 'medium':
        return CupertinoColors.systemOrange;
      case 'low':
        return CupertinoColors.systemBlue;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'high':
        return 'CAO';
      case 'medium':
        return 'TRUNG';
      case 'low':
        return 'THẤP';
      default:
        return '--';
    }
  }

}

// ============================================================
// Widget: Message Bubble
// User: bên trái (xám) | Admin: bên phải (xanh lá)
// ============================================================
class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final String userName;

  const _MessageBubble({
    required this.message,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = message['sender'] == 'admin';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
        isAdmin ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar user (bên trái)
          if (!isAdmin) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.person_fill,
                size: 13,
                color: CupertinoColors.systemBlue,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isAdmin
                    ? AerogreenCupertinoTheme.aerogreenPrimary
                    : CupertinoColors.secondarySystemBackground
                    .resolveFrom(context),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isAdmin ? 16 : 4),
                  bottomRight: Radius.circular(isAdmin ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender name
                  Text(
                    isAdmin ? 'Admin' : userName,
                    style: TextStyle(
                      color: isAdmin
                          ? CupertinoColors.white.withValues(alpha: 0.85)
                          : CupertinoColors.secondaryLabel
                          .resolveFrom(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Message text
                  Text(
                    message['text'] ?? '',
                    style: TextStyle(
                      color: isAdmin
                          ? CupertinoColors.white
                          : CupertinoColors.label.resolveFrom(context),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Timestamp
                  Text(
                    _formatTime(message['time']),
                    style: TextStyle(
                      color: isAdmin
                          ? CupertinoColors.white.withValues(alpha: 0.7)
                          : CupertinoColors.tertiaryLabel
                          .resolveFrom(context),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Avatar admin (bên phải)
          if (isAdmin) ...[
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AerogreenCupertinoTheme.aerogreenPrimary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.shield_lefthalf_fill,
                size: 13,
                color: CupertinoColors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')} • '
          '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
