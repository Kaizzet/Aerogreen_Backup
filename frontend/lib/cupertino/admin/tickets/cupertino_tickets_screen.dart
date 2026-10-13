// ============================================================
// cupertino_tickets_screen.dart
// Màn hình Support Tickets của Admin.
// Chức năng:
//   - Hiển thị danh sách tickets
//   - Search theo subject hoặc tên user
//   - Filter: All / Open / InProgress / Closed
//   - Tap → mở chi tiết (chat-style)
//   - Long-press → action sheet (đổi status, đổi priority)
// ============================================================

import 'package:flutter/cupertino.dart';
import '../widgets/admin_logout_button.dart';

import '../../../services/api_service.dart';
import 'cupertino_ticket_detail_screen.dart';
import 'widgets/ticket_filter_chips.dart';
import 'widgets/ticket_list_tile.dart';

class CupertinoTicketsScreen extends StatefulWidget {
  const CupertinoTicketsScreen({super.key});

  @override
  State<CupertinoTicketsScreen> createState() => _CupertinoTicketsScreenState();
}

class _CupertinoTicketsScreenState extends State<CupertinoTicketsScreen> {
  final _apiService = ApiService();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _allTickets = [];
  List<Map<String, dynamic>> _filteredTickets = [];

  TicketFilter _selectedFilter = TicketFilter.all;
  String _searchQuery = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Load tickets từ ApiService
  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getAdminTickets();
      final tickets = (response['items'] as List<dynamic>? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _allTickets = tickets;
        _error = null;
        _isLoading = false;
      });
      _applyFilter();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _isLoading = false;
      });
    }
  }

  // Áp filter + search
  void _applyFilter() {
    List<Map<String, dynamic>> result = List.from(_allTickets);

    // Filter theo tab
    switch (_selectedFilter) {
      case TicketFilter.all:
        break;
      case TicketFilter.open:
        result = result.where((t) => t['status'] == 'open').toList();
        break;
      case TicketFilter.inProgress:
        result = result.where((t) => t['status'] == 'in_progress').toList();
        break;
      case TicketFilter.closed:
        result = result.where((t) => t['status'] == 'closed').toList();
        break;
    }

    // Filter theo search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((t) {
        final subject = (t['subject'] as String? ?? '').toLowerCase();
        final userName = (t['userName'] as String? ?? '').toLowerCase();
        final userEmail = (t['userEmail'] as String? ?? '').toLowerCase();
        return subject.contains(query) ||
            userName.contains(query) ||
            userEmail.contains(query);
      }).toList();
    }

    setState(() => _filteredTickets = result);
  }

  // Đếm số ticket cho mỗi filter chip
  Map<TicketFilter, int> _getCounts() {
    return {
      TicketFilter.all: _allTickets.length,
      TicketFilter.open:
      _allTickets.where((t) => t['status'] == 'open').length,
      TicketFilter.inProgress:
      _allTickets.where((t) => t['status'] == 'in_progress').length,
      TicketFilter.closed:
      _allTickets.where((t) => t['status'] == 'closed').length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Navigation bar
        CupertinoSliverNavigationBar(
          largeTitle: const Text('Support Tickets'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                onPressed: _loadTickets,
                child: const Icon(CupertinoIcons.arrow_2_circlepath),
              ),
              const AdminLogoutButton(),
            ],
          ),
        ),

        // Pull to refresh
        CupertinoSliverRefreshControl(onRefresh: _loadTickets),

        // Search bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: CupertinoSearchTextField(
              controller: _searchController,
              placeholder: 'Tìm theo subject hoặc user...',
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
            child: TicketFilterChips(
              selected: _selectedFilter,
              counts: _getCounts(),
              onChanged: (filter) {
                setState(() => _selectedFilter = filter);
                _applyFilter();
              },
            ),
          ),
        ),

        // Content
        if (_isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CupertinoActivityIndicator(radius: 14),
            ),
          )
        else if (_error != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CupertinoButton(onPressed: _loadTickets, child: Text(_error!))),
          )
        else if (_filteredTickets.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(context),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final ticket = _filteredTickets[index];

                  // ValueKey để rebuild khi status thay đổi
                  final key = ValueKey(
                    'ticket_${ticket['id']}_${ticket['status']}',
                  );

                  return Padding(
                    key: key,
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TicketListTile(
                      ticket: ticket,
                      onTap: () => _openTicketDetail(ticket),
                      onLongPress: () => _showTicketActions(ticket),
                    ),
                  );
                },
                childCount: _filteredTickets.length,
              ),
            ),
          ),
      ],
    );
  }

  // Empty state
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.chat_bubble_2,
              size: 64,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
            const SizedBox(height: 16),
            Text(
              'Không tìm thấy ticket',
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
                  : 'Chưa có ticket nào trong hệ thống.',
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

  // Mở chi tiết ticket
  Future<void> _openTicketDetail(Map<String, dynamic> ticket) async {
    await Navigator.of(context).push<Map<String, dynamic>>(
      CupertinoPageRoute(
        builder: (_) => CupertinoTicketDetailScreen(ticket: ticket),
      ),
    );

    // Nếu Detail trả về data mới → update list
    if (mounted) await _loadTickets();
  }

  // Action sheet khi long-press ticket
  Future<void> _showTicketActions(Map<String, dynamic> ticket) async {
    final status = ticket['status'] as String? ?? 'open';

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (actionContext) => CupertinoActionSheet(
        title: Text(ticket['subject'] ?? ''),
        message: Text('User: ${ticket['userName'] ?? ''}'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(actionContext).pop();
              _openTicketDetail(ticket);
            },
            child: const Text('Xem chi tiết'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(actionContext).pop();
              _changeStatus(ticket);
            },
            child: Text(_statusActionLabel(status)),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(actionContext).pop();
              _changePriority(ticket);
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

  String _statusActionLabel(String status) {
    switch (status) {
      case 'open':
        return 'Đánh dấu đang xử lý';
      case 'in_progress':
        return 'Đóng ticket';
      case 'closed':
        return 'Mở lại ticket';
      default:
        return 'Đổi trạng thái';
    }
  }

  // Đổi status (từ action sheet)
  Future<void> _changeStatus(Map<String, dynamic> ticket) async {
    final current = ticket['status'] as String? ?? 'open';
    String newStatus;
    String label;

    switch (current) {
      case 'open':
        newStatus = 'in_progress';
        label = 'Đã chuyển sang Đang xử lý';
        break;
      case 'in_progress':
        newStatus = 'closed';
        label = 'Đã đóng ticket';
        break;
      case 'closed':
        newStatus = 'open';
        label = 'Đã mở lại ticket';
        break;
      default:
        return;
    }

    try {
      await _apiService.updateAdminTicketStatus(ticket['id'].toString(), newStatus);
      if (!mounted) return;
      await _loadTickets();
      if (mounted) _showToast(label);
    } catch (error) {
      if (mounted) _showToast('$error');
    }
  }

  // Đổi priority (từ action sheet)
  void _changePriority(Map<String, dynamic> ticket) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (actionContext) => CupertinoActionSheet(
        title: const Text('Chọn độ ưu tiên'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.of(actionContext).pop();
              await _updatePriority(ticket, 'high');
            },
            child: const Text('Cao'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.of(actionContext).pop();
              await _updatePriority(ticket, 'medium');
            },
            child: const Text('Trung bình'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.of(actionContext).pop();
              await _updatePriority(ticket, 'low');
            },
            child: const Text('Thấp'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(actionContext).pop(),
          child: const Text('Hủy'),
        ),
      ),
    );
  }

  Future<void> _updatePriority(Map<String, dynamic> ticket, String priority) async {
    try {
      await _apiService.updateAdminTicketPriority(ticket['id'].toString(), priority);
      if (!mounted) return;
      await _loadTickets();
    } catch (error) {
      if (mounted) _showToast('$error');
    }
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
