import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../../models/support_ticket.dart';
import '../../services/api_service.dart';
import '../theme/cupertino_theme.dart';
import 'cupertino_create_ticket_screen.dart';
import 'cupertino_ticket_detail_screen.dart';

class CupertinoSupportTicketsScreen extends StatefulWidget {
  final ApiService? apiService;

  const CupertinoSupportTicketsScreen({super.key, this.apiService});

  @override
  State<CupertinoSupportTicketsScreen> createState() =>
      _CupertinoSupportTicketsScreenState();
}

class _CupertinoSupportTicketsScreenState
    extends State<CupertinoSupportTicketsScreen> {
  late final ApiService _apiService;
  List<SupportTicket> _tickets = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'open', 'in_progress', 'resolved'

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    try {
      final list = await _apiService.getMyTickets(
        status: _selectedFilter == 'all' ? null : _selectedFilter,
      );
      if (!mounted) return;
      setState(() {
        _tickets = list
            .map((item) => SupportTicket.fromJson(item))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<SupportTicket> get _filteredTickets {
    if (_selectedFilter == 'all') return _tickets;
    if (_selectedFilter == 'open') {
      return _tickets.where((t) => t.isOpen).toList();
    }
    if (_selectedFilter == 'in_progress') {
      return _tickets.where((t) => t.isInProgress).toList();
    }
    if (_selectedFilter == 'resolved') {
      return _tickets.where((t) => t.isResolved).toList();
    }
    return _tickets;
  }

  Future<void> _openCreateTicket() async {
    final result = await Navigator.of(context).push<dynamic>(
      CupertinoPageRoute(
        builder: (_) => CupertinoCreateTicketScreen(apiService: _apiService),
      ),
    );

    if (result != null && mounted) {
      await _loadTickets();
      if (result is Map<String, dynamic> && mounted) {
        final newTicket = SupportTicket.fromJson(result);
        Navigator.of(context).push<void>(
          CupertinoPageRoute(
            builder: (_) => CupertinoTicketDetailScreen(
              initialTicket: newTicket,
              apiService: _apiService,
            ),
          ),
        );
      }
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
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTickets;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Hỗ trợ kỹ thuật'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _openCreateTicket,
          child: const Icon(CupertinoIcons.add, size: 22),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<String>(
                  groupValue: _selectedFilter,
                  children: const {
                    'all': Text('Tất cả', style: TextStyle(fontSize: 12)),
                    'open': Text('Đang mở', style: TextStyle(fontSize: 12)),
                    'in_progress': Text('Xử lý', style: TextStyle(fontSize: 12)),
                    'resolved': Text('Đã xong', style: TextStyle(fontSize: 12)),
                  },
                  onValueChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedFilter = val);
                      _loadTickets();
                    }
                  },
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator(radius: 14))
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            CupertinoSliverRefreshControl(
                              onRefresh: _loadTickets,
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final ticket = filtered[index];
                                    return _buildTicketCard(ticket);
                                  },
                                  childCount: filtered.length,
                                ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AerogreenCupertinoTheme.aerogreenPrimary
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.chat_bubble_2,
                size: 36,
                color: AerogreenCupertinoTheme.aerogreenPrimary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có yêu cầu hỗ trợ nào',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nếu bạn gặp sự cố về thiết bị, cảm biến hoặc cần hướng dẫn kỹ thuật, hãy tạo yêu cầu để được hỗ trợ.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: _openCreateTicket,
              child: const Text('Tạo ticket mới'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard(SupportTicket ticket) {
    final statusColor = _getStatusColor(ticket.status);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push<void>(
          CupertinoPageRoute(
            builder: (_) => CupertinoTicketDetailScreen(
              initialTicket: ticket,
              apiService: _apiService,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    ticket.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    ticket.statusDisplay,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (ticket.lastMessage != null && ticket.lastMessage!.isNotEmpty) ...[
              Text(
                ticket.lastMessage!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey5.resolveFrom(context),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ticket.category,
                    style: const TextStyle(
                      fontSize: 10,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ),
                if (ticket.deviceName != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey5.resolveFrom(context),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ticket.deviceName!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  _formatDate(ticket.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: CupertinoColors.tertiaryLabel,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 13,
                  color: CupertinoColors.tertiaryLabel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
