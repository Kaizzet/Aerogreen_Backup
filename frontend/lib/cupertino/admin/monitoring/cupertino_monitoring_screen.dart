import 'package:flutter/cupertino.dart';

import '../../../services/api_service.dart';
import '../../theme/cupertino_theme.dart';

class CupertinoMonitoringScreen extends StatefulWidget {
  const CupertinoMonitoringScreen({super.key});

  @override
  State<CupertinoMonitoringScreen> createState() => _CupertinoMonitoringScreenState();
}

class _CupertinoMonitoringScreenState extends State<CupertinoMonitoringScreen> {
  final _apiService = ApiService();
  Map<String, dynamic>? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await _apiService.getAdminSystemStatus();
      if (mounted) {
        setState(() {
          _status = status;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('Giám sát'),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 44),
            onPressed: _loadStatus,
            child: const Icon(CupertinoIcons.arrow_2_circlepath),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: _loadStatus),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (status == null)
                Center(child: CupertinoButton(onPressed: _loadStatus, child: Text(_error ?? 'Đang tải...')))
              else ...[
                _StatusCard(
                  title: 'API',
                  status: status['api'] as String? ?? 'unavailable',
                  detail: 'Trạng thái: ${status['status'] ?? 'unavailable'}',
                  icon: CupertinoIcons.desktopcomputer,
                ),
                const SizedBox(height: 12),
                _StatusCard(
                  title: 'PostgreSQL',
                  status: status['database'] as String? ?? 'unavailable',
                  detail: 'Latest ingestion: ${_formatTime(status['latestIngestionAt'] as String?)}',
                  icon: CupertinoIcons.archivebox_fill,
                ),
                const SizedBox(height: 12),
                _StatusCard(
                  title: 'MQTT',
                  status: status['mqtt'] as String? ?? 'unavailable',
                  detail: status['mqtt'] == 'connected' ? 'Connected' : 'Unavailable',
                  icon: CupertinoIcons.antenna_radiowaves_left_right,
                ),
                const SizedBox(height: 12),
                _StatusCard(
                  title: 'Devices',
                  status: status['database'] == 'healthy' ? 'healthy' : 'unavailable',
                  detail: '${status['onlineDevices'] ?? '—'} online / ${status['totalDevices'] ?? '—'} total',
                  icon: CupertinoIcons.device_phone_portrait,
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  String _formatTime(String? value) {
    if (value == null) return 'Unavailable';
    final time = DateTime.tryParse(value)?.toLocal();
    return time == null ? 'Unavailable' : time.toString();
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String status;
  final String detail;
  final IconData icon;

  const _StatusCard({required this.title, required this.status, required this.detail, required this.icon});

  @override
  Widget build(BuildContext context) {
    final healthy = status == 'healthy' || status == 'connected';
    final color = healthy ? AerogreenCupertinoTheme.aerogreenPrimary : CupertinoColors.systemRed;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(detail, style: const TextStyle(fontSize: 12)),
        ])),
        Text(healthy ? 'Healthy' : 'Degraded', style: TextStyle(color: color)),
      ]),
    );
  }
}
