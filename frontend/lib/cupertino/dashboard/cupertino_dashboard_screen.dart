import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../models/device.dart';
import '../../models/device_overview.dart';
import '../../models/pump_command.dart';
import '../../models/pump_schedule.dart';
import '../../providers/alert_center_provider.dart';
import '../../screens/alerts/alerts_screen.dart';
import '../devices/cupertino_devices_screen.dart';
import '../devices/cupertino_device_detail_screen.dart';
import '../profile/cupertino_profile_screen.dart';
import '../tickets/cupertino_create_ticket_screen.dart';
import '../../screens/pumps/pump_schedules_screen.dart';
import '../../services/api_service.dart';
import '../theme/cupertino_theme.dart';
import 'farm_health_card.dart';

class CupertinoDashboardScreen extends StatefulWidget {
  const CupertinoDashboardScreen({super.key});

  @override
  State<CupertinoDashboardScreen> createState() =>
      _CupertinoDashboardScreenState();
}

class _CupertinoDashboardScreenState extends State<CupertinoDashboardScreen> {
  final ApiService _apiService = ApiService();
  List<DeviceOverview> _devices = const [];
  Map<String, _DeviceControlsState> _deviceControls = const {};
  bool _isLoading = true;
  bool _isFetching = false;
  bool _hasLoaded = false;
  String? _errorMessage;
  String? _refreshError;
  int _selectedTab = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _loadDashboardData(showLoading: false),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardData({bool showLoading = true}) async {
    if (_isFetching) return;
    _isFetching = true;
    if (mounted) {
      setState(() {
        _isLoading = showLoading && !_hasLoaded;
        if (showLoading) _refreshError = null;
        _errorMessage = null;
      });
    }

    try {
      final data = await _apiService.getDashboardOverview();
      final devices = data
          .map((item) => DeviceOverview.fromJson(item as Map<String, dynamic>))
          .toList();
      final controls = await Future.wait(devices.map(_loadDeviceControls));
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _deviceControls = {
          for (var index = 0; index < devices.length; index++)
            devices[index].id: controls[index],
        };
        _isLoading = false;
        _hasLoaded = true;
        _refreshError = null;
      });
      final alertCenter = _maybeAlertCenter(context);
      if (alertCenter != null) {
        unawaited(
          alertCenter.loadDevices(
            devices
                .map(
                  (device) => Device(
                    id: device.id,
                    name: device.name,
                    isOnline: device.isOnline,
                    lastSeenAt: device.lastSeenAt,
                    createdAt: DateTime.now().toUtc().toIso8601String(),
                  ),
                )
                .toList(),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (_hasLoaded) {
          _refreshError = error.toString();
        } else {
          _errorMessage = error.toString();
        }
      });
    } finally {
      _isFetching = false;
    }
  }

  Future<_DeviceControlsState> _loadDeviceControls(
    DeviceOverview device,
  ) async {
    try {
      final results = await Future.wait([
        _apiService.getPumpSchedules(device.id),
        _apiService.getPumpCommands(device.id, pageSize: 1),
      ]);
      final schedules = (results[0] as List<dynamic>)
          .map((item) => PumpSchedule.fromJson(item as Map<String, dynamic>))
          .toList();
      final commandsData = results[1] as Map<String, dynamic>;
      final commandItems = commandsData['items'] as List<dynamic>? ?? [];
      final latestCommand = commandItems.isEmpty
          ? null
          : PumpCommand.fromJson(commandItems.first as Map<String, dynamic>);
      final command = latestCommand;
      final acknowledgement = command?.acknowledgedAt == null
          ? null
          : DateTime.tryParse(command!.acknowledgedAt!);
      final pumpIsOn =
          command != null &&
          command.status == 'Acknowledged' &&
          command.acknowledgedIsOn == true &&
          acknowledgement != null &&
          acknowledgement
              .add(Duration(seconds: command.durationSeconds))
              .isAfter(DateTime.now().toUtc());

      return _DeviceControlsState(schedules: schedules, isPumping: pumpIsOn);
    } catch (_) {
      return _DeviceControlsState(schedules: const [], isPumping: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 1024;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isDesktop) _buildSidebar(context),
                Expanded(child: _buildContent(context, isDesktop)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDesktop) {
    if (_selectedTab == 1) {
      const devices = CupertinoDevicesScreen();
      if (isDesktop) return devices;
      return Column(
        children: [
          const Expanded(child: devices),
          _buildBottomBar(context),
        ],
      );
    }
    if (_selectedTab == 2) {
      final alerts = AlertsScreen(devices: _alertDevices);
      if (isDesktop) return alerts;
      return Column(
        children: [
          Expanded(child: alerts),
          _buildBottomBar(context),
        ],
      );
    }
    if (_selectedTab == 3) {
      const profile = CupertinoProfileScreen();
      if (isDesktop) return profile;
      return Column(
        children: [
          const Expanded(child: profile),
          _buildBottomBar(context),
        ],
      );
    }
    final summary = FarmHealthSummary.fromDevices(_devices);
    final content = CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('Aerogreen'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                onPressed: () => Navigator.of(context).push<void>(
                  CupertinoPageRoute(
                    builder: (_) => const CupertinoCreateTicketScreen(),
                  ),
                ),
                child: const Icon(CupertinoIcons.chat_bubble_2),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                onPressed: _loadDashboardData,
                child: const Icon(CupertinoIcons.arrow_2_circlepath),
              ),
            ],
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: _loadDashboardData),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 32 : 20,
            8,
            isDesktop ? 32 : 20,
            32,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildGreeting(context),
              const SizedBox(height: 20),
              if (_isLoading)
                const _DashboardSkeleton()
              else if (_errorMessage != null)
                _ErrorPanel(
                  message: _errorMessage!,
                  onRetry: () => _loadDashboardData(),
                )
              else ...[
                FarmHealthCard(summary: summary, onAddDevice: _createDevice),
                if (_refreshError != null) ...[
                  const SizedBox(height: 10),
                  _RefreshError(message: _refreshError!),
                ],
                if (_devices.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildHealthMetrics(context, summary),
                ],
                if (summary.issues.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildAttentionList(context, summary.issues),
                ],
                const SizedBox(height: 26),
                _sectionHeader(
                  context,
                  'Thiết bị',
                  '${_devices.length} thiết bị',
                ),
                const SizedBox(height: 12),
                _buildDeviceGrid(context, isDesktop),
                const SizedBox(height: 22),
                _buildInsightCard(context),
                if (_devices.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _sectionHeader(context, 'Tác vụ nhanh', null),
                  const SizedBox(height: 12),
                  _buildQuickActions(context),
                ],
              ],
            ]),
          ),
        ),
      ],
    );
    if (isDesktop) return content;
    return Column(
      children: [
        Expanded(child: content),
        _buildBottomBar(context),
      ],
    );
  }

  List<Device> get _alertDevices => _devices
      .map(
        (device) => Device(
          id: device.id,
          name: device.name,
          isOnline: device.isOnline,
          lastSeenAt: device.lastSeenAt,
          createdAt: DateTime.now().toUtc().toIso8601String(),
        ),
      )
      .toList();

  Widget _buildGreeting(BuildContext context) {
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
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Nông trại đang trong tầm tay.',
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AerogreenCupertinoTheme.aerogreenPrimary.withValues(
              alpha: 0.14,
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            CupertinoIcons.person_fill,
            color: AerogreenCupertinoTheme.aerogreenPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildHealthMetrics(BuildContext context, FarmHealthSummary summary) {
    final onlineCount = _devices.where((device) => device.isOnline).length;
    final temperatures = _devices
        .map((device) => device.latestReading?.temperature)
        .whereType<double>()
        .toList();
    final averageTemperature = temperatures.isEmpty
        ? '--'
        : '${(temperatures.reduce((a, b) => a + b) / temperatures.length).toStringAsFixed(1)}°';
    return Row(
      children: [
        _SummaryMetric(
          value: '$onlineCount/${_devices.length}',
          label: 'Thiết bị online',
        ),
        _SummaryMetric(value: '${summary.issues.length}', label: 'Cần chú ý'),
        _SummaryMetric(value: averageTemperature, label: 'Nhiệt độ TB'),
      ],
    );
  }

  Widget _buildAttentionList(
    BuildContext context,
    List<FarmHealthIssue> issues,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, 'Cần chú ý', '${issues.length} vấn đề'),
        const SizedBox(height: 8),
        ...issues.map(
          (issue) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  issue.icon,
                  color: issue.isCritical
                      ? CupertinoColors.systemRed
                      : CupertinoColors.systemOrange,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.device.name,
                        style: TextStyle(
                          color: CupertinoColors.label.resolveFrom(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        issue.message,
                        style: TextStyle(
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  onPressed: () => _openDevice(issue.device),
                  child: const Text('Xem'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceGrid(BuildContext context, bool isDesktop) {
    final columns = isDesktop
        ? 3
        : MediaQuery.sizeOf(context).width >= 600
        ? 2
        : 1;
    final gridDevices = _devices;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: gridDevices.length + 1,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: columns == 1 ? 1.45 : 1.12,
      ),
      itemBuilder: (context, index) {
        if (index == gridDevices.length) {
          return _AddDeviceTile(onTap: _createDevice);
        }
        final device = gridDevices[index];
        final controls =
            _deviceControls[device.id] ??
            const _DeviceControlsState(schedules: [], isPumping: false);
        return _DeviceCard(
          device: device,
          isPumping: controls.isPumping,
          isAutomatic: controls.isAutomatic,
          onTap: () => _openDevice(device),
          onLongPress: () => _showDeviceActions(device),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: CupertinoIcons.drop_fill,
            label: 'Bơm nhanh',
            color: CupertinoColors.systemBlue,
            onPressed: () async {
              final device = await _chooseDevice(
                'Chọn thiết bị để điều khiển bơm',
              );
              if (device != null) await _togglePump(device);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAction(
            icon: CupertinoIcons.calendar,
            label: 'Lịch tưới',
            color: CupertinoColors.systemOrange,
            onPressed: () async {
              final device = await _chooseDevice('Chọn thiết bị để xem lịch');
              if (device != null) await _openSchedules(device);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _createDevice() async {
    final controller = TextEditingController();
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Thêm thiết bị'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            autofocus: true,
            placeholder: 'Tên thiết bị',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Hủy'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;

    try {
      await _apiService.createDevice(name.trim());
      await _loadDashboardData(showLoading: false);
    } catch (error) {
      if (mounted) _showMessage('Không thể thêm thiết bị: $error');
    }
  }

  Future<void> _openDevice(DeviceOverview overview) async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => CupertinoDeviceDetailScreen(
          device: Device(
            id: overview.id,
            name: overview.name,
            isOnline: overview.isOnline,
            lastSeenAt: overview.lastSeenAt,
            createdAt: DateTime.now().toUtc().toIso8601String(),
          ),
        ),
      ),
    );
    if (mounted) await _loadDashboardData(showLoading: false);
  }

  Future<void> _openSchedules(DeviceOverview overview) async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => PumpSchedulesScreen(
          device: Device(
            id: overview.id,
            name: overview.name,
            isOnline: overview.isOnline,
            lastSeenAt: overview.lastSeenAt,
            createdAt: DateTime.now().toUtc().toIso8601String(),
          ),
        ),
      ),
    );
    if (mounted) await _loadDashboardData(showLoading: false);
  }

  Future<DeviceOverview?> _chooseDevice(String title) async {
    if (_devices.length == 1) return _devices.single;
    return showCupertinoModalPopup<DeviceOverview>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(title),
        actions: _devices
            .map(
              (device) => CupertinoActionSheetAction(
                onPressed: () => Navigator.of(context).pop(device),
                child: Text(device.name),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
      ),
    );
  }

  Future<void> _showDeviceActions(DeviceOverview device) async {
    final controls =
        _deviceControls[device.id] ??
        const _DeviceControlsState(schedules: [], isPumping: false);
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(device.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _openDevice(device);
            },
            child: const Text('Mở thiết bị'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              if (controls.isAutomatic) {
                _setManualMode(device, controls);
              } else {
                _openSchedules(device);
              }
            },
            child: Text(
              controls.isAutomatic
                  ? 'Chuyển sang thủ công'
                  : 'Thiết lập tự động',
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _togglePump(device);
            },
            child: Text(controls.isPumping ? 'Tắt bơm' : 'Bật bơm 60 giây'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ),
    );
  }

  Future<void> _setManualMode(
    DeviceOverview device,
    _DeviceControlsState controls,
  ) async {
    final enabledSchedules = controls.schedules
        .where((schedule) => schedule.isEnabled)
        .toList();
    if (enabledSchedules.isEmpty) return;
    try {
      for (final schedule in enabledSchedules) {
        await _apiService.updatePumpSchedule(
          device.id,
          schedule,
          isEnabled: false,
        );
      }
      await _loadDashboardData(showLoading: false);
    } catch (error) {
      if (mounted) _showMessage('Không thể chuyển sang thủ công: $error');
    }
  }

  Future<void> _togglePump(DeviceOverview device) async {
    final controls =
        _deviceControls[device.id] ??
        const _DeviceControlsState(schedules: [], isPumping: false);
    try {
      await _apiService.sendPumpCommand(
        device.id,
        ApiService.generatePumpCommandId(),
        !controls.isPumping,
        controls.isPumping ? null : 60,
      );
      await _loadDashboardData(showLoading: false);
    } catch (error) {
      if (mounted) _showMessage('Không thể điều khiển bơm: $error');
    }
  }

  void _showMessage(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(BuildContext context) {
    final tips = [
      ('Bể chứa', 'Kiểm tra mực dung dịch trong bể trước mỗi chu kỳ tưới.'),
      ('Đầu phun', 'Làm sạch đầu phun định kỳ để giữ sương phun đồng đều.'),
      (
        'Dung dịch',
        'Làm mới dung dịch dinh dưỡng theo lịch chăm sóc của vườn.',
      ),
    ];
    final dayOfYear = DateTime.now()
        .difference(DateTime(DateTime.now().year))
        .inDays;
    final tip = tips[dayOfYear % tips.length];
    return _Surface(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: CupertinoColors.systemYellow.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.lightbulb_fill,
              color: CupertinoColors.systemYellow,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.$1,
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip.$2,
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, String? trailing) =>
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: CupertinoColors.label.resolveFrom(context),
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontSize: 13,
              ),
            ),
        ],
      );

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 248,
      padding: const EdgeInsets.fromLTRB(20, 28, 16, 20),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        border: Border(
          right: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.leaf_arrow_circlepath,
                color: AerogreenCupertinoTheme.aerogreenPrimary,
              ),
              const SizedBox(width: 10),
              Text(
                'Aerogreen',
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          _SidebarItem(
            icon: CupertinoIcons.house_fill,
            label: 'Tổng quan',
            selected: _selectedTab == 0,
            onTap: () => setState(() => _selectedTab = 0),
          ),
          _SidebarItem(
            icon: CupertinoIcons.square_grid_2x2,
            label: 'Thiết bị',
            selected: _selectedTab == 1,
            onTap: () => setState(() => _selectedTab = 1),
          ),
          _SidebarItem(
            icon: CupertinoIcons.bell_fill,
            label: 'Cảnh báo',
            selected: _selectedTab == 2,
            onTap: () => setState(() => _selectedTab = 2),
          ),
          _SidebarItem(
            icon: CupertinoIcons.person_fill,
            label: 'Tài khoản',
            selected: _selectedTab == 3,
            onTap: () => setState(() => _selectedTab = 3),
          ),
          const Spacer(),
          Text(
            'TRẠNG THÁI HỆ THỐNG',
            style: TextStyle(
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                CupertinoIcons.checkmark_circle_fill,
                color: AerogreenCupertinoTheme.aerogreenPrimary,
                size: 17,
              ),
              const SizedBox(width: 8),
              Text(
                'Dịch vụ đang hoạt động',
                style: TextStyle(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground
            .resolveFrom(context)
            .withValues(alpha: 0.94),
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
          ),
        ),
      ),
      padding: const EdgeInsets.only(bottom: 8, top: 6),
      child: Row(
        children: [
          Expanded(
            child: _BottomItem(
              icon: CupertinoIcons.house_fill,
              label: 'Trang chủ',
              selected: _selectedTab == 0,
              onTap: () => setState(() => _selectedTab = 0),
            ),
          ),
          Expanded(
            child: _BottomItem(
              icon: CupertinoIcons.square_grid_2x2,
              label: 'Thiết bị',
              selected: _selectedTab == 1,
              onTap: () => setState(() => _selectedTab = 1),
            ),
          ),
          Expanded(
            child: _BottomItem(
              icon: CupertinoIcons.bell,
              badgeCount:
                  _maybeAlertCenter(context, listen: true)?.unreadCount ?? 0,
              label: 'Cảnh báo',
              selected: _selectedTab == 2,
              onTap: () => setState(() => _selectedTab = 2),
            ),
          ),
          Expanded(
            child: _BottomItem(
              icon: CupertinoIcons.person,
              label: 'Tài khoản',
              selected: _selectedTab == 3,
              onTap: () => setState(() => _selectedTab = 3),
            ),
          ),
        ],
      ),
    );
  }
}

AlertCenterProvider? _maybeAlertCenter(
  BuildContext context, {
  bool listen = false,
}) {
  try {
    return Provider.of<AlertCenterProvider>(context, listen: listen);
  } on ProviderNotFoundException {
    return null;
  }
}

class _DeviceControlsState {
  final List<PumpSchedule> schedules;
  final bool isPumping;

  const _DeviceControlsState({
    required this.schedules,
    required this.isPumping,
  });

  bool get isAutomatic => schedules.any((schedule) => schedule.isEnabled);
}

class _Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Surface({required this.child, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: CupertinoColors.black.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    padding: padding,
    child: child,
  );
}

class _DeviceCard extends StatelessWidget {
  final DeviceOverview device;
  final bool isPumping;
  final bool isAutomatic;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _DeviceCard({
    required this.device,
    required this.isPumping,
    required this.isAutomatic,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final reading = device.latestReading;
    final statusColor = device.isOnline
        ? AerogreenCupertinoTheme.aerogreenPrimary
        : CupertinoColors.systemRed;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: _Surface(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  device.isOnline ? 'Đang hoạt động' : 'Mất kết nối',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _ModeBadge(isAutomatic: isAutomatic),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              device.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: CupertinoColors.label.resolveFrom(context),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Reading(
                    icon: CupertinoIcons.thermometer,
                    value: reading?.temperature == null
                        ? '-- °C'
                        : '${reading!.temperature!.toStringAsFixed(1)} °C',
                    color: CupertinoColors.systemOrange,
                  ),
                ),
                Expanded(
                  child: _Reading(
                    icon: CupertinoIcons.drop_fill,
                    value: reading?.humidity == null
                        ? '-- %'
                        : '${reading!.humidity!.toStringAsFixed(0)} %',
                    color: CupertinoColors.systemBlue,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Icon(
                  isPumping
                      ? CupertinoIcons.cloud_fog_fill
                      : CupertinoIcons.cloud_fog,
                  size: 16,
                  color: isPumping
                      ? CupertinoColors.systemTeal
                      : CupertinoColors.tertiaryLabel.resolveFrom(context),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    isPumping ? 'Đang phun sương' : 'Không phun sương',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                      fontSize: 12,
                    ),
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
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

class _ModeBadge extends StatelessWidget {
  final bool isAutomatic;

  const _ModeBadge({required this.isAutomatic});

  @override
  Widget build(BuildContext context) {
    final color = isAutomatic
        ? AerogreenCupertinoTheme.aerogreenPrimary
        : CupertinoColors.systemIndigo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isAutomatic ? 'Tự động' : 'Thủ công',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AddDeviceTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddDeviceTile({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AerogreenCupertinoTheme.aerogreenPrimary.withValues(
            alpha: 0.45,
          ),
          width: 1.3,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.add_circled,
            color: AerogreenCupertinoTheme.aerogreenPrimary,
            size: 30,
          ),
          const SizedBox(height: 9),
          Text(
            'Thêm thiết bị',
            style: TextStyle(
              color: CupertinoColors.label.resolveFrom(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: onPressed,
    child: _Surface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: CupertinoColors.label.resolveFrom(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Reading extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _Reading({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 5),
      Text(
        value,
        style: TextStyle(
          color: CupertinoColors.label.resolveFrom(context),
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _SummaryMetric extends StatelessWidget {
  final String value;
  final String label;

  const _SummaryMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: CupertinoColors.label.resolveFrom(context),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
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

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    alignment: Alignment.centerLeft,
    onPressed: onTap,
    child: Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: selected
              ? AerogreenCupertinoTheme.aerogreenPrimary
              : CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: selected
                ? AerogreenCupertinoTheme.aerogreenPrimary
                : CupertinoColors.label.resolveFrom(context),
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    ),
  );
}

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  const _BottomItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) => CupertinoButton(
    // Các mục được chia đều bề rộng nên đệm ngang phải nhỏ, nếu không thanh
    // điều hướng sẽ tràn trên màn hình hẹp.
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    minimumSize: const Size(44, 44),
    onPressed: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              icon,
              size: 21,
              color: selected
                  ? AerogreenCupertinoTheme.aerogreenPrimary
                  : CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            if (badgeCount > 0)
              Positioned(
                right: -9,
                top: -7,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: const BoxDecoration(
                    color: CupertinoColors.systemRed,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            color: selected
                ? AerogreenCupertinoTheme.aerogreenPrimary
                : CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ],
    ),
  );
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: CupertinoColors.systemGrey5.resolveFrom(context),
    highlightColor: CupertinoColors.systemGrey6.resolveFrom(context),
    child: Column(
      children: [
        Container(
          height: 116,
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: List.generate(
            2,
            (index) => Expanded(
              child: Container(
                height: 174,
                margin: EdgeInsets.only(right: index == 0 ? 12 : 0),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _RefreshError extends StatelessWidget {
  final String message;

  const _RefreshError({required this.message});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(
        CupertinoIcons.exclamationmark_circle,
        size: 15,
        color: CupertinoColors.systemOrange,
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          'Không thể làm mới: $message',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: CupertinoColors.systemOrange,
            fontSize: 11,
          ),
        ),
      ),
    ],
  );
}

class _ErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorPanel({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => _Surface(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const Icon(
          CupertinoIcons.exclamationmark_triangle,
          color: CupertinoColors.systemOrange,
          size: 30,
        ),
        const SizedBox(height: 12),
        Text(
          'Không thể tải dữ liệu',
          style: TextStyle(
            color: CupertinoColors.label.resolveFrom(context),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        CupertinoButton.filled(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          onPressed: onRetry,
          child: const Text('Thử lại'),
        ),
      ],
    ),
  );
}
