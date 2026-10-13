import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../cupertino/devices/cupertino_device_detail_screen.dart';
import '../../models/device.dart';
import '../../models/device_alert.dart';
import '../../providers/alert_center_provider.dart';
import 'alert_thresholds_screen.dart';
import 'notification_preferences_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, this.device, this.devices = const []});

  final Device? device;
  final List<Device> devices;

  List<Device> get targetDevices => device == null ? devices : [device!];

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AlertCenterProvider>();
      provider.requestPermission();
      if (widget.targetDevices.isNotEmpty) {
        _loadAlerts(provider);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Consumer<AlertCenterProvider>(
    builder: (context, provider, _) {
      final items = _itemsFor(provider);
      final today = items.where(_isToday).toList();
      final earlier = items.where((item) => !_isToday(item)).toList();
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(
            widget.device == null
                ? 'Cảnh báo'
                : 'Cảnh báo · ${widget.device!.name}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.device != null)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(38, 38),
                  onPressed: () => Navigator.of(context).push<void>(
                    CupertinoPageRoute(
                      builder: (_) =>
                          AlertThresholdsScreen(device: widget.device!),
                    ),
                  ),
                  child: const Icon(CupertinoIcons.slider_horizontal_3),
                ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(38, 38),
                onPressed: () => Navigator.of(context).push<void>(
                  CupertinoPageRoute(
                    builder: (_) => const NotificationPreferencesScreen(),
                  ),
                ),
                child: const Icon(CupertinoIcons.gear),
              ),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () => _loadAlerts(provider),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                sliver: SliverList.list(
                  children: [
                    _filterBar(provider),
                    const SizedBox(height: 12),
                    if (provider.unreadCount > 0)
                      Align(
                        alignment: Alignment.centerRight,
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          onPressed: provider.markAllRead,
                          child: const Text('Đánh dấu tất cả đã đọc'),
                        ),
                      ),
                    if (provider.isLoading && provider.items.isEmpty)
                      const _AlertsSkeleton()
                    else if (provider.errorMessage != null &&
                        provider.items.isEmpty)
                      _AlertsError(
                        message: provider.errorMessage!,
                        onRetry: () => _loadAlerts(provider),
                      )
                    else if (items.isEmpty)
                      const _AlertsEmpty()
                    else ...[
                      if (today.isNotEmpty)
                        _AlertGroup(
                          title: 'Hôm nay',
                          items: today,
                          provider: provider,
                        ),
                      if (earlier.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _AlertGroup(
                          title: 'Trước đó',
                          items: earlier,
                          provider: provider,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  List<AlertItem> _itemsFor(AlertCenterProvider provider) {
    final filtered = provider.filteredItems;
    if (widget.device == null) return filtered;
    return filtered
        .where((item) => item.device.id == widget.device!.id)
        .toList();
  }

  Future<void> _loadAlerts(AlertCenterProvider provider) => provider
      .loadDevices(widget.targetDevices, replaceAll: widget.device == null);

  bool _isToday(AlertItem item) {
    final date = DateTime.tryParse(item.alert.triggeredAt)?.toLocal();
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _filterBar(AlertCenterProvider provider) =>
      CupertinoSlidingSegmentedControl<AlertListFilter>(
        groupValue: provider.filter,
        children: const {
          AlertListFilter.all: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text('Tất cả'),
          ),
          AlertListFilter.critical: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text('Nghiêm trọng'),
          ),
          AlertListFilter.unread: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text('Chưa đọc'),
          ),
        },
        onValueChanged: (value) {
          if (value != null) provider.setFilter(value);
        },
      );
}

class _AlertGroup extends StatelessWidget {
  const _AlertGroup({
    required this.title,
    required this.items,
    required this.provider,
  });

  final String title;
  final List<AlertItem> items;
  final AlertCenterProvider provider;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            color: CupertinoColors.secondaryLabel,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              Dismissible(
                key: ValueKey(items[index].alert.id),
                direction: provider.isRead(items[index].alert.id)
                    ? DismissDirection.none
                    : DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  await provider.markRead(items[index].alert.id);
                  return false;
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 18),
                  color: CupertinoColors.systemBlue,
                  child: const Icon(
                    CupertinoIcons.checkmark_alt,
                    color: CupertinoColors.white,
                  ),
                ),
                child: _AlertRow(item: items[index], provider: provider),
              ),
              if (index < items.length - 1)
                Container(
                  height: 0.5,
                  margin: const EdgeInsets.only(left: 58),
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
            ],
          ],
        ),
      ),
    ],
  );
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.item, required this.provider});

  final AlertItem item;
  final AlertCenterProvider provider;

  @override
  Widget build(BuildContext context) {
    final read = provider.isRead(item.alert.id);
    final resolved = item.alert.resolvedAt != null;
    final color = _severityColor(item.alert.severity);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      onPressed: () async {
        await provider.markRead(item.alert.id);
        if (!context.mounted) return;
        await Navigator.of(context).push<void>(
          CupertinoPageRoute(builder: (_) => AlertDetailScreen(item: item)),
        );
      },
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(_severityIcon(item.alert.severity), color: color, size: 27),
              if (!read)
                const Positioned(
                  right: -2,
                  top: -2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBlue,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(width: 8, height: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.alert.title,
                        style: TextStyle(
                          color: CupertinoColors.label.resolveFrom(context),
                          fontWeight: read ? FontWeight.w500 : FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      resolved ? 'Đã xử lý' : 'Đang xảy ra',
                      style: TextStyle(
                        color: resolved ? CupertinoColors.systemGreen : color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.device.name} · ${item.alert.message}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 14,
            color: CupertinoColors.tertiaryLabel,
          ),
        ],
      ),
    );
  }
}

class AlertDetailScreen extends StatelessWidget {
  const AlertDetailScreen({super.key, required this.item});

  final AlertItem item;

  @override
  Widget build(BuildContext context) {
    final alert = item.alert;
    final triggered = DateTime.tryParse(alert.triggeredAt)?.toLocal();
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Chi tiết cảnh báo'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(
              _severityIcon(alert.severity),
              color: _severityColor(alert.severity),
              size: 48,
            ),
            const SizedBox(height: 14),
            Text(
              alert.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              alert.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CupertinoColors.secondaryLabel,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            _DetailRow(label: 'Thiết bị', value: item.device.name),
            _DetailRow(
              label: 'Thời gian',
              value: triggered == null
                  ? alert.triggeredAt
                  : '${triggered.day.toString().padLeft(2, '0')}/${triggered.month.toString().padLeft(2, '0')}/${triggered.year} ${triggered.hour.toString().padLeft(2, '0')}:${triggered.minute.toString().padLeft(2, '0')}',
            ),
            _DetailRow(
              label: 'Trạng thái',
              value: alert.resolvedAt == null ? 'Active' : 'Resolved',
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: () => Navigator.of(context).push<void>(
                CupertinoPageRoute(
                  builder: (_) => CupertinoDeviceDetailScreen(
                    device: item.device,
                    initialSensor: alert.sensorKey,
                  ),
                ),
              ),
              child: const Text('Đi tới thiết bị'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: const BoxDecoration(
      border: Border(
        bottom: BorderSide(color: CupertinoColors.separator, width: 0.5),
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: CupertinoColors.secondaryLabel),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _AlertsSkeleton extends StatelessWidget {
  const _AlertsSkeleton();

  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(
      4,
      (_) => Container(
        height: 78,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey5.resolveFrom(context),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
  );
}

class _AlertsEmpty extends StatelessWidget {
  const _AlertsEmpty();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 90),
    child: Column(
      children: [
        Icon(
          CupertinoIcons.checkmark_shield_fill,
          size: 48,
          color: CupertinoColors.systemGreen,
        ),
        SizedBox(height: 14),
        Text(
          'Mọi thứ yên tĩnh',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 5),
        Text(
          'Không có cảnh báo phù hợp với bộ lọc.',
          style: TextStyle(color: CupertinoColors.secondaryLabel),
        ),
      ],
    ),
  );
}

class _AlertsError extends StatelessWidget {
  const _AlertsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 70),
    child: Column(
      children: [
        const Icon(
          CupertinoIcons.exclamationmark_triangle,
          size: 38,
          color: CupertinoColors.systemOrange,
        ),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 14),
        CupertinoButton.filled(
          onPressed: onRetry,
          child: const Text('Thử lại'),
        ),
      ],
    ),
  );
}

Color _severityColor(AlertLevel level) => switch (level) {
  AlertLevel.critical => CupertinoColors.systemRed,
  AlertLevel.warning => CupertinoColors.systemOrange,
  AlertLevel.info => CupertinoColors.systemBlue,
};

IconData _severityIcon(AlertLevel level) => switch (level) {
  AlertLevel.critical => CupertinoIcons.exclamationmark_octagon_fill,
  AlertLevel.warning => CupertinoIcons.exclamationmark_triangle_fill,
  AlertLevel.info => CupertinoIcons.info_circle_fill,
};
