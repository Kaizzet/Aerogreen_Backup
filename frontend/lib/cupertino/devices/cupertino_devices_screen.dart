import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../../models/device.dart';
import '../../services/api_service.dart';
import 'add_device_screen.dart';
import 'cupertino_device_detail_screen.dart';
import 'cupertino_provisioning_code_screen.dart';

class CupertinoDevicesScreen extends StatefulWidget {
  final ApiService? apiService;

  const CupertinoDevicesScreen({super.key, this.apiService});

  @override
  State<CupertinoDevicesScreen> createState() => _CupertinoDevicesScreenState();
}

class _CupertinoDevicesScreenState extends State<CupertinoDevicesScreen> {
  late final ApiService _apiService;
  List<Device> _devices = const [];
  bool _isLoading = true;
  final bool _isCreating = false;
  String? _deletingDeviceId;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadDevices();
  }

  Future<void> _loadDevices({bool showLoading = true}) async {
    if (mounted) {
      setState(() {
        if (showLoading) _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await _apiService.getDevices();
      if (!mounted) return;
      setState(() {
        _devices = response
            .map((item) => Device.fromJson(item as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _createAndProvisionDevice() async {
    final result = await Navigator.of(context).push<Device>(
      CupertinoPageRoute(
        builder: (_) => const AddDeviceScreen(),
      ),
    );
    if (result != null && mounted) {
      await _loadDevices(showLoading: false);
    }
  }

  Future<void> _deleteDevice(Device device) async {
    final shouldDelete = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Xóa thiết bị?'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Bạn có chắc muốn xóa "${device.name}"? Thao tác này không thể hoàn tác.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    setState(() => _deletingDeviceId = device.id);
    try {
      await _apiService.deleteDevice(device.id);
      if (mounted) await _loadDevices(showLoading: false);
    } catch (error) {
      if (mounted) _showError('Không thể xóa thiết bị: $error');
    } finally {
      if (mounted) setState(() => _deletingDeviceId = null);
    }
  }

  Future<void> _openDevice(Device device) async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => CupertinoDeviceDetailScreen(
          device: device,
          apiService: _apiService,
        ),
      ),
    );
    if (mounted) await _loadDevices(showLoading: false);
  }

  Future<void> _openProvisioning(Device device) async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => CupertinoProvisioningCodeScreen(
          device: device,
          apiService: _apiService,
        ),
      ),
    );
    if (mounted) await _loadDevices(showLoading: false);
  }

  void _showError(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Không thể hoàn tất'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSearch = _devices.length > 6;
    final filtered = _devices
        .where(
          (device) =>
              device.name.toLowerCase().contains(
                _searchQuery.trim().toLowerCase(),
              ) ||
              (device.location?.toLowerCase().contains(
                    _searchQuery.trim().toLowerCase(),
                  ) ??
                  false),
        )
        .toList();
    final hasNoResults = hasSearch && filtered.isEmpty;

    return CupertinoPageScaffold(
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: const Text('Thiết bị'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _isCreating ? null : _createAndProvisionDevice,
                child: _isCreating
                    ? const CupertinoActivityIndicator()
                    : const Icon(CupertinoIcons.add),
              ),
            ),
            CupertinoSliverRefreshControl(onRefresh: () => _loadDevices()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
              sliver: SliverList.list(
                children: [
                  if (_isLoading)
                    const _DevicesLoadingState()
                  else if (_errorMessage != null)
                    _DevicesErrorState(
                      message: _errorMessage!,
                      onRetry: _loadDevices,
                    )
                  else if (_devices.isEmpty)
                    _DevicesEmptyState(onAdd: _createAndProvisionDevice)
                  else ...[
                    if (hasSearch) ...[
                      CupertinoSearchTextField(
                        placeholder: 'Tìm theo tên hoặc vị trí',
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (hasNoResults)
                      const Padding(
                        padding: EdgeInsets.only(top: 32),
                        child: Center(child: Text('Không tìm thấy thiết bị.')),
                      )
                    else
                      for (final device in filtered) ...[
                        _DeviceRow(
                          device: device,
                          onOpen: () => _openDevice(device),
                          onProvision: () => _openProvisioning(device),
                          onDelete: () => _deleteDevice(device),
                          isDeleting: _deletingDeviceId == device.id,
                        ),
                        const SizedBox(height: 10),
                      ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final Device device;
  final VoidCallback onOpen;
  final VoidCallback onProvision;
  final VoidCallback onDelete;
  final bool isDeleting;

  const _DeviceRow({
    required this.device,
    required this.onOpen,
    required this.onProvision,
    required this.onDelete,
    required this.isDeleting,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = device.isOnline
        ? const Color(0xFF248A4B)
        : CupertinoColors.systemGrey;
    final lastSeen = DateTime.tryParse(device.lastSeenAt ?? '');
    final location = device.location ?? 'Vị trí chưa gán';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 12, 12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onOpen,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: CupertinoColors.label.resolveFrom(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastSeen == null
                            ? 'Chưa có kết nối · $location'
                            : 'Lần cuối ${DateFormat('dd/MM HH:mm').format(lastSeen.toLocal())} · $location',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(isOnline: device.isOnline),
                const SizedBox(width: 5),
                const Icon(
                  CupertinoIcons.chevron_right,
                  color: CupertinoColors.tertiaryLabel,
                  size: 14,
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: onProvision,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.qrcode, size: 17),
                    SizedBox(width: 7),
                    Text('Thiết lập thiết bị'),
                  ],
                ),
              ),
              Semantics(
                label: 'Xóa thiết bị',
                button: true,
                child: CupertinoButton(
                  padding: const EdgeInsets.all(10),
                  minimumSize: const Size(40, 40),
                  onPressed: isDeleting ? null : onDelete,
                  child: isDeleting
                      ? const CupertinoActivityIndicator(radius: 9)
                      : const Icon(
                          CupertinoIcons.delete,
                          color: CupertinoColors.systemRed,
                          size: 18,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isOnline;

  const _StatusChip({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final color = isOnline
        ? const Color(0xFF248A4B)
        : CupertinoColors.systemGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isOnline ? 'Online' : 'Offline',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DevicesEmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _DevicesEmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 380,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.device_phone_portrait,
            color: CupertinoColors.systemGrey2,
            size: 48,
          ),
          const SizedBox(height: 14),
          Text(
            'Chưa có thiết bị nào',
            style: TextStyle(
              color: CupertinoColors.label.resolveFrom(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tạo thiết bị để bắt đầu thiết lập kết nối.',
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          CupertinoButton.filled(
            onPressed: onAdd,
            child: const Text('Thêm thiết bị'),
          ),
        ],
      ),
    ),
  );
}

class _DevicesLoadingState extends StatelessWidget {
  const _DevicesLoadingState();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 280,
    child: Center(child: CupertinoActivityIndicator(radius: 14)),
  );
}

class _DevicesErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _DevicesErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 320,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: CupertinoColors.systemOrange,
            size: 34,
          ),
          const SizedBox(height: 12),
          const Text('Không thể tải danh sách thiết bị.'),
          const SizedBox(height: 6),
          Text(
            message,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CupertinoColors.secondaryLabel,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          CupertinoButton.filled(
            onPressed: onRetry,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );
}
