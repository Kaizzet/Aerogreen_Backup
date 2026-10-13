import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../../models/support_ticket.dart';
import '../../services/api_service.dart';
import '../theme/cupertino_theme.dart';

class CupertinoTicketDetailScreen extends StatefulWidget {
  final SupportTicket initialTicket;
  final ApiService? apiService;

  const CupertinoTicketDetailScreen({
    super.key,
    required this.initialTicket,
    this.apiService,
  });

  @override
  State<CupertinoTicketDetailScreen> createState() =>
      _CupertinoTicketDetailScreenState();
}

class _CupertinoTicketDetailScreenState
    extends State<CupertinoTicketDetailScreen> {
  late final ApiService _apiService;
  late SupportTicket _ticket;
  final _replyController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _ticket = widget.initialTicket;
    _loadTicketDetail();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTicketDetail() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getMyTicket(_ticket.id);
      if (!mounted) return;
      setState(() {
        _ticket = SupportTicket.fromJson(data);
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _isSending) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSending = true);

    try {
      final newMsgData = await _apiService.replyToMyTicket(_ticket.id, text);
      final newMsg = SupportTicketMessage.fromJson(newMsgData);
      if (!mounted) return;

      final updatedMessages = List<SupportTicketMessage>.from(_ticket.messages)..add(newMsg);
      setState(() {
        _ticket = _ticket.copyWith(
          messages: updatedMessages,
          messagesCount: updatedMessages.length,
          lastMessage: text,
          updatedAt: DateTime.now().toUtc().toIso8601String(),
        );
        _replyController.clear();
        _isSending = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return CupertinoColors.systemOrange;
      case 'in_progress':
        return CupertinoColors.systemBlue;
      case 'resolved':
      case 'closed':
        return CupertinoColors.systemGreen;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      return DateFormat('HH:mm dd/MM/yyyy').format(date);
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(_ticket.status);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Ticket #${_ticket.id}'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _loadTicketDetail,
          child: const Icon(CupertinoIcons.arrow_2_circlepath, size: 20),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeaderCard(statusColor),
            Expanded(
              child: _ticket.messages.isEmpty
                  ? Center(
                      child: Text(
                        _isLoading ? 'Đang tải tin nhắn...' : 'Chưa có tin nhắn nào',
                        style: const TextStyle(color: CupertinoColors.secondaryLabel),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _ticket.messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageItem(_ticket.messages[index]);
                      },
                    ),
            ),
            _buildReplyBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Color statusColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.systemGrey5.resolveFrom(context),
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _ticket.subject,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _ticket.statusDisplay,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _ticket.category,
                  style: const TextStyle(
                    fontSize: 11,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Tạo: ${_formatDate(_ticket.createdAt)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
          if (_ticket.deviceId != null || _ticket.deviceName != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(CupertinoIcons.cube_box,
                    size: 13, color: CupertinoColors.secondaryLabel),
                const SizedBox(width: 4),
                Text(
                  'Thiết bị: ${_ticket.deviceName ?? _ticket.deviceId} | FW: ${_ticket.firmwareVersion ?? "v1.0"}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageItem(SupportTicketMessage msg) {
    final isMe = !msg.isStaff;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AerogreenCupertinoTheme.aerogreenPrimary,
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.person_crop_circle_badge_checkmark,
                  size: 18, color: CupertinoColors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  msg.authorName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: CupertinoColors.secondaryLabel,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? AerogreenCupertinoTheme.aerogreenPrimary
                        : CupertinoColors.secondarySystemBackground
                            .resolveFrom(context),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    msg.body,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe
                          ? CupertinoColors.white
                          : CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(msg.createdAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: CupertinoColors.tertiaryLabel,
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildReplyBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        border: Border(
          top: BorderSide(
            color: CupertinoColors.systemGrey5.resolveFrom(context),
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: CupertinoTextField(
                controller: _replyController,
                placeholder: 'Nhập phản hồi cho kỹ thuật viên...',
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                minLines: 1,
                maxLines: 4,
                decoration: BoxDecoration(
                  color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _isSending ? null : _sendReply, minimumSize: Size(40, 40),
              child: _isSending
                  ? const CupertinoActivityIndicator(radius: 10)
                  : const Icon(CupertinoIcons.arrow_up_circle_fill,
                      size: 34, color: AerogreenCupertinoTheme.aerogreenPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
