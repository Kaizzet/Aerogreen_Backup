import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../widgets/admin_logout_button.dart';

import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../theme/cupertino_theme.dart';
import 'admin_quick_stats.dart';

class AdminOverviewTab extends StatefulWidget {
  const AdminOverviewTab({super.key});

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  final _apiService = ApiService();
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final overview = await _apiService.getAdminOverview();
      if (!mounted) return;
      setState(() {
        _stats = {
          'totalUsers': overview['users'],
          'totalDevices': overview['devices'],
          'onlineDevices': overview['onlineDevices'],
          'totalAlerts': overview['unresolvedAlerts'],
          'unresolvedAlerts': overview['unresolvedAlerts'],
          'openTickets': overview['openTickets'],
        };
        _error = null;
        _isLoading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CupertinoActivityIndicator(radius: 14),
      );
    }
    if (_error != null) {
      return Center(child: CupertinoButton(onPressed: _loadData, child: Text(_error!)));
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('Tổng quan'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                onPressed: _loadData,
                child: const Icon(CupertinoIcons.arrow_2_circlepath),
              ),
              const AdminLogoutButton(),
            ],
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: _loadData),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildGreeting(context),
              const SizedBox(height: 20),

              if (_stats != null) AdminQuickStats(stats: _stats!),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Chào buổi sáng'
        : hour < 18
        ? 'Chào buổi chiều'
        : 'Chào buổi tối';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                user?.fullName ?? 'Admin',
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AerogreenCupertinoTheme.aerogreenPrimary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            CupertinoIcons.shield_lefthalf_fill,
            color: CupertinoColors.white,
            size: 22,
          ),
        ),
      ],
    );
  }
}
