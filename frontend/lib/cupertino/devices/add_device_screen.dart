import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../models/device.dart';
import '../../services/api_service.dart';

enum AddDeviceStep { prepare, findDevice, wifi, connecting, nameAndPlace, done }

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final ApiService _apiService = ApiService();

  AddDeviceStep _currentStep = AddDeviceStep.prepare;
  int _currentStepIndex = 0;

  // Step 2: Find device
  String? _deviceId;
  bool _isScanning = false;
  bool _isScanningBle = false;
  List<String> _nearbyDevices = [];

  // Step 3: Wi-Fi
  String _selectedNetwork = '';
  final _wifiPasswordController = TextEditingController();
  bool _is5GHz = false;
  final List<String> _networks = ['Wi-Fi Home', 'IOTAgri-Setup', 'Guest Network'];

  // Step 4: Connecting
  ConnectionStage _connectionStage = ConnectionStage.connectingToDevice;
  String? _connectionError;
  Timer? _connectionTimeoutTimer;

  // Step 5: Name and place
  final _deviceNameController = TextEditingController(text: 'Tháp 1');
  final _locationController = TextEditingController();
  String? _cropType;
  final List<String> _cropTypes = [
    'Rau lá',
    'Cây giống',
    'Thảo mộc',
    'Hoa',
    'Khác',
  ];

  bool _isSaving = false;
  String? _errorMessage;
  Device? _createdDevice;

  @override
  void dispose() {
    _wifiPasswordController.dispose();
    _deviceNameController.dispose();
    _locationController.dispose();
    _connectionTimeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _scanQR() async {
    setState(() => _isScanning = true);
    // Simulate QR scan
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _deviceId = 'ESP32-12345678';
        _isScanning = false;
        _nextStep();
      });
    }
  }

  Future<void> _scanBLE() async {
    setState(() => _isScanningBle = true);
    // Simulate BLE scan
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      setState(() {
        _nearbyDevices = ['ESP32-ABC123', 'ESP32-XYZ789'];
        _isScanningBle = false;
      });
    }
  }

  void _selectDevice(String deviceId) {
    setState(() {
      _deviceId = deviceId;
      _nextStep();
    });
  }

  void _useClaimCode() {
    setState(() {
      _currentStep = AddDeviceStep.findDevice;
      _currentStepIndex = 1;
    });
  }

  void _selectNetwork(String network) {
    setState(() {
      _selectedNetwork = network;
      _is5GHz = network.contains('5G');
    });
  }

  void _connectToWifi() {
    if (_selectedNetwork.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng chọn mạng Wi-Fi');
      return;
    }
    if (_wifiPasswordController.text.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập mật khẩu Wi-Fi');
      return;
    }
    if (_is5GHz) {
      setState(() => _errorMessage = 'Thiết bị chỉ hỗ trợ mạng 2.4 GHz');
      return;
    }

    setState(() {
      _errorMessage = null;
      _currentStep = AddDeviceStep.connecting;
      _currentStepIndex = 3;
      _connectionStage = ConnectionStage.connectingToDevice;
      _startConnectionTimeout();
    });
  }

  void _startConnectionTimeout() {
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = Timer(const Duration(seconds: 60), () {
      if (mounted) {
        setState(() {
          _connectionError = 'Timeout. Vui lòng reset thiết bị và thử lại.';
          _connectionStage = ConnectionStage.failed;
        });
      }
    });
  }

  void _simulateConnection() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _connectionStage = ConnectionStage.connectingToWifi);
      }
    });

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _connectionStage = ConnectionStage.registeringAccount);
      }
    });

    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) {
        _connectionTimeoutTimer?.cancel();
        setState(() {
          _connectionStage = ConnectionStage.completed;
          _nextStep();
        });
      }
    });
  }

  void _retryConnection() {
    setState(() {
      _connectionError = null;
      _connectionStage = ConnectionStage.connectingToDevice;
      _currentStep = AddDeviceStep.wifi;
      _currentStepIndex = 2;
    });
  }

  Future<void> _saveDevice() async {
    if (_deviceNameController.text.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập tên thiết bị');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.createDevice(
        _deviceNameController.text,
      );
      if (!mounted) return;

      setState(() {
        _createdDevice = Device.fromJson(response);
        _isSaving = false;
        _currentStep = AddDeviceStep.done;
        _currentStepIndex = 5;
      });
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('already claimed')) {
          errorMsg = 'Thiết bị này đã được đăng ký. Liên hệ hỗ trợ.';
        }
        setState(() {
          _isSaving = false;
          _errorMessage = errorMsg;
        });
      }
    }
  }

  void _nextStep() {
    if (_currentStepIndex < 5) {
      setState(() {
        _currentStepIndex++;
        _currentStep = AddDeviceStep.values[_currentStepIndex];
      });

      if (_currentStep == AddDeviceStep.connecting) {
        _simulateConnection();
      }
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
        _currentStep = AddDeviceStep.values[_currentStepIndex];
        _errorMessage = null;
      });
    }
  }

  void _cancel() {
    if (_currentStepIndex > 0) {
      showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Hủy thêm thiết bị'),
          content: const Text('Bạn có chắc muốn hủy?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Tiếp tục'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(context).pop(true);
                Navigator.of(context).pop();
              },
              child: const Text('Hủy'),
            ),
          ],
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: _currentStepIndex > 0
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _previousStep,
                child: const Text('Quay lại'),
              )
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _cancel,
                child: const Text('Hủy'),
              ),
        middle: const Text('Thêm thiết bị'),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(),
            Expanded(child: _buildCurrentStep()),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: List.generate(6, (index) {
              final isCompleted = index < _currentStepIndex;
              final isCurrent = index == _currentStepIndex;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index < 5 ? 8 : 0),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? CupertinoColors.activeBlue
                          : isCurrent
                          ? CupertinoColors.activeBlue
                          : CupertinoColors.separator,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ProgressLabel(
                index: 0,
                currentIndex: _currentStepIndex,
                label: 'Chuẩn bị',
              ),
              _ProgressLabel(
                index: 1,
                currentIndex: _currentStepIndex,
                label: 'Tìm thiết bị',
              ),
              _ProgressLabel(
                index: 2,
                currentIndex: _currentStepIndex,
                label: 'Wi-Fi',
              ),
              _ProgressLabel(
                index: 3,
                currentIndex: _currentStepIndex,
                label: 'Kết nối',
              ),
              _ProgressLabel(
                index: 4,
                currentIndex: _currentStepIndex,
                label: 'Đặt tên',
              ),
              _ProgressLabel(
                index: 5,
                currentIndex: _currentStepIndex,
                label: 'Hoàn tất',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case AddDeviceStep.prepare:
        return _PrepareStep(onNext: _nextStep);
      case AddDeviceStep.findDevice:
        return _FindDeviceStep(
          onScanQR: _scanQR,
          onScanBLE: _scanBLE,
          onSelectDevice: _selectDevice,
          onUseClaimCode: _useClaimCode,
          deviceId: _deviceId,
          isScanning: _isScanning,
          isScanningBle: _isScanningBle,
          nearbyDevices: _nearbyDevices,
          isWeb: kIsWeb,
        );
      case AddDeviceStep.wifi:
        return _WifiStep(
          networks: _networks,
          selectedNetwork: _selectedNetwork,
          passwordController: _wifiPasswordController,
          is5GHz: _is5GHz,
          onNetworkSelect: _selectNetwork,
          onConnect: _connectToWifi,
          errorMessage: _errorMessage,
        );
      case AddDeviceStep.connecting:
        return _ConnectingStep(
          stage: _connectionStage,
          error: _connectionError,
          onRetry: _retryConnection,
        );
      case AddDeviceStep.nameAndPlace:
        return _NameAndPlaceStep(
          nameController: _deviceNameController,
          locationController: _locationController,
          cropType: _cropType,
          cropTypes: _cropTypes,
          onCropTypeSelect: (type) => setState(() => _cropType = type),
          onSave: _saveDevice,
          isSaving: _isSaving,
          errorMessage: _errorMessage,
        );
      case AddDeviceStep.done:
        return _DoneStep(
          device: _createdDevice,
          onOpenDevice: () {
            Navigator.of(context).pop(_createdDevice);
          },
          onSetupSchedule: () {
            Navigator.of(context).pop(_createdDevice);
          },
        );
    }
  }
}

class _ProgressLabel extends StatelessWidget {
  final int index;
  final int currentIndex;
  final String label;

  const _ProgressLabel({
    required this.index,
    required this.currentIndex,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    final isCompleted = index < currentIndex;
    return Text(
      label,
      style: TextStyle(
        color: isActive || isCompleted
            ? CupertinoColors.activeBlue
            : CupertinoColors.secondaryLabel,
        fontSize: 11,
        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

class _PrepareStep extends StatelessWidget {
  final VoidCallback onNext;

  const _PrepareStep({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.lightbulb_fill,
            size: 64,
            color: CupertinoColors.systemYellow,
          ),
          const SizedBox(height: 24),
          Text(
            'Chuẩn bị thêm thiết bị',
            style: TextStyle(
              color: CupertinoColors.label.resolveFrom(context),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Đảm bảo thiết bị ESP32 đã được bật điện và sẵn sàng kết nối.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CupertinoColors.secondaryLabel,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 24),
          _PermissionItem(
            icon: CupertinoIcons.camera,
            text: 'Quyền camera để quét mã QR',
          ),
          const SizedBox(height: 12),
          _PermissionItem(
            icon: CupertinoIcons.bluetooth,
            text: 'Quyền Bluetooth để tìm thiết bị gần',
          ),
          const SizedBox(height: 12),
          _PermissionItem(
            icon: CupertinoIcons.wifi,
            text: 'Quyền vị trí để phát hiện thiết bị',
          ),
          const SizedBox(height: 32),
          CupertinoButton.filled(
            onPressed: onNext,
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
  }
}

class _PermissionItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PermissionItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: CupertinoColors.systemBlue, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: CupertinoColors.label.resolveFrom(context),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _FindDeviceStep extends StatelessWidget {
  final VoidCallback onScanQR;
  final VoidCallback onScanBLE;
  final ValueChanged<String> onSelectDevice;
  final VoidCallback onUseClaimCode;
  final String? deviceId;
  final bool isScanning;
  final bool isScanningBle;
  final List<String> nearbyDevices;
  final bool isWeb;

  const _FindDeviceStep({
    required this.onScanQR,
    required this.onScanBLE,
    required this.onSelectDevice,
    required this.onUseClaimCode,
    required this.deviceId,
    required this.isScanning,
    required this.isScanningBle,
    required this.nearbyDevices,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.qrcode,
                  size: 64,
                  color: CupertinoColors.systemBlue,
                ),
                const SizedBox(height: 24),
                Text(
                  'Tìm thiết bị',
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Quét mã QR trên thiết bị hoặc tìm thiết bị gần qua Bluetooth',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 32),
                if (!isWeb) ...[
                  CupertinoButton.filled(
                    onPressed: isScanning ? null : onScanQR,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isScanning)
                          const CupertinoActivityIndicator(
                            color: CupertinoColors.white,
                            radius: 10,
                          )
                        else
                          const Icon(CupertinoIcons.qrcode_viewfinder),
                        const SizedBox(width: 8),
                        const Text('Quét mã QR'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton(
                    onPressed: isScanningBle ? null : onScanBLE,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isScanningBle)
                          const CupertinoActivityIndicator(radius: 10)
                        else
                          const Icon(CupertinoIcons.bluetooth),
                        const SizedBox(width: 8),
                        const Text('Tìm thiết bị gần'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (nearbyDevices.isNotEmpty) ...[
                    const Text(
                      'Thiết bị gần:',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...nearbyDevices.map(
                      (device) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: CupertinoButton(
                          padding: const EdgeInsets.all(12),
                          color: CupertinoColors.secondarySystemBackground
                              .resolveFrom(context),
                          onPressed: () => onSelectDevice(device),
                          child: Text(device),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    height: 1,
                    color: CupertinoColors.separator.resolveFrom(context),
                  ),
                  const SizedBox(height: 24),
                  CupertinoButton(
                    onPressed: onUseClaimCode,
                    child: const Text('Sử dụng mã cấp thiết bị'),
                  ),
                ] else ...[
                  CupertinoButton.filled(
                    onPressed: onUseClaimCode,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: const Text('Nhập mã cấp thiết bị'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Hãy thiết lập trên điện thoại cho lần kết nối đầu tiên.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WifiStep extends StatelessWidget {
  final List<String> networks;
  final String selectedNetwork;
  final TextEditingController passwordController;
  final bool is5GHz;
  final ValueChanged<String> onNetworkSelect;
  final VoidCallback onConnect;
  final String? errorMessage;

  const _WifiStep({
    required this.networks,
    required this.selectedNetwork,
    required this.passwordController,
    required this.is5GHz,
    required this.onNetworkSelect,
    required this.onConnect,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                const Icon(
                  CupertinoIcons.wifi,
                  size: 64,
                  color: CupertinoColors.systemBlue,
                ),
                const SizedBox(height: 24),
                Text(
                  'Kết nối Wi-Fi',
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Chọn mạng Wi-Fi nông trại và nhập mật khẩu',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Danh sách mạng:',
                  style: TextStyle(
                    color: CupertinoColors.label,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...networks.map(
                  (network) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CupertinoButton(
                      padding: const EdgeInsets.all(14),
                      color: selectedNetwork == network
                          ? CupertinoColors.activeBlue
                          : CupertinoColors.secondarySystemBackground
                                .resolveFrom(context),
                      onPressed: () => onNetworkSelect(network),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.wifi,
                            color: selectedNetwork == network
                                ? CupertinoColors.white
                                : CupertinoColors.label.resolveFrom(context),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              network,
                              style: TextStyle(
                                color: selectedNetwork == network
                                    ? CupertinoColors.white
                                    : CupertinoColors.label.resolveFrom(
                                        context,
                                      ),
                              ),
                            ),
                          ),
                          if (network.contains('5G'))
                            const Icon(
                              CupertinoIcons.exclamationmark_triangle,
                              color: CupertinoColors.systemOrange,
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                CupertinoTextField(
                  controller: passwordController,
                  placeholder: 'Mật khẩu Wi-Fi',
                  obscureText: true,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CupertinoColors.secondarySystemBackground
                        .resolveFrom(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                if (is5GHz) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemOrange.withValues(
                        alpha: 0.1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          color: CupertinoColors.systemOrange,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cần mạng 2.4 GHz',
                            style: TextStyle(
                              color: CupertinoColors.systemOrange,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: CupertinoColors.systemRed,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          CupertinoButton.filled(
            onPressed: onConnect,
            child: const Text('Kết nối'),
          ),
        ],
      ),
    );
  }
}

enum ConnectionStage {
  connectingToDevice,
  connectingToWifi,
  registeringAccount,
  completed,
  failed,
}

class _ConnectingStep extends StatelessWidget {
  final ConnectionStage stage;
  final String? error;
  final VoidCallback onRetry;

  const _ConnectingStep({
    required this.stage,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (stage == ConnectionStage.failed) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 64,
              color: CupertinoColors.systemRed,
            ),
            const SizedBox(height: 24),
            Text(
              'Kết nối thất bại',
              style: TextStyle(
                color: CupertinoColors.label.resolveFrom(context),
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              error ?? 'Không thể kết nối thiết bị',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 32),
            CupertinoButton.filled(
              onPressed: onRetry,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    final stageText = switch (stage) {
      ConnectionStage.connectingToDevice => 'Đang kết nối thiết bị...',
      ConnectionStage.connectingToWifi => 'Đang vào Wi-Fi...',
      ConnectionStage.registeringAccount => 'Đang đăng ký tài khoản...',
      ConnectionStage.completed => 'Hoàn tất!',
      ConnectionStage.failed => '',
    };

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CupertinoActivityIndicator(radius: 24),
          const SizedBox(height: 32),
          Text(
            stageText,
            style: TextStyle(
              color: CupertinoColors.label.resolveFrom(context),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (stage == ConnectionStage.completed) ...[
            const SizedBox(height: 16),
            const Icon(
              CupertinoIcons.checkmark_circle_fill,
              size: 48,
              color: CupertinoColors.systemGreen,
            ),
          ],
        ],
      ),
    );
  }
}

class _NameAndPlaceStep extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController locationController;
  final String? cropType;
  final List<String> cropTypes;
  final ValueChanged<String?> onCropTypeSelect;
  final VoidCallback onSave;
  final bool isSaving;
  final String? errorMessage;

  const _NameAndPlaceStep({
    required this.nameController,
    required this.locationController,
    required this.cropType,
    required this.cropTypes,
    required this.onCropTypeSelect,
    required this.onSave,
    required this.isSaving,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    CupertinoIcons.tag_fill,
                    size: 48,
                    color: CupertinoColors.systemBlue,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Đặt tên thiết bị',
                    style: TextStyle(
                      color: CupertinoColors.label.resolveFrom(context),
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Tên thiết bị',
                    style: TextStyle(
                      color: CupertinoColors.label,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: nameController,
                    placeholder: 'Tháp 1',
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: CupertinoColors.secondarySystemBackground
                          .resolveFrom(context),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Vị trí (tùy chọn)',
                    style: TextStyle(
                      color: CupertinoColors.label,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: locationController,
                    placeholder: 'Nhà kính, sân sau...',
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: CupertinoColors.secondarySystemBackground
                          .resolveFrom(context),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Loại cây trồng (tùy chọn)',
                    style: TextStyle(
                      color: CupertinoColors.label,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: cropTypes.map((type) {
                      return CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        color: cropType == type
                            ? CupertinoColors.activeBlue
                            : CupertinoColors.secondarySystemBackground
                                  .resolveFrom(context),
                        borderRadius: BorderRadius.circular(20),
                        onPressed: () =>
                            onCropTypeSelect(cropType == type ? null : type),
                        child: Text(
                          type,
                          style: TextStyle(
                            color: cropType == type
                                ? CupertinoColors.white
                                : CupertinoColors.label.resolveFrom(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: CupertinoColors.systemRed,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          CupertinoButton.filled(
            onPressed: isSaving ? null : onSave,
            child: isSaving
                ? const CupertinoActivityIndicator(
                    color: CupertinoColors.white,
                    radius: 10,
                  )
                : const Text('Lưu thiết bị'),
          ),
        ],
      ),
    );
  }
}

class _DoneStep extends StatelessWidget {
  final Device? device;
  final VoidCallback onOpenDevice;
  final VoidCallback onSetupSchedule;

  const _DoneStep({
    required this.device,
    required this.onOpenDevice,
    required this.onSetupSchedule,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.checkmark_circle_fill,
            size: 80,
            color: CupertinoColors.systemGreen,
          ),
          const SizedBox(height: 32),
          Text(
            '${device?.name ?? 'Thiết bị'} đã online',
            style: TextStyle(
              color: CupertinoColors.label.resolveFrom(context),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 48),
          CupertinoButton.filled(
            onPressed: onSetupSchedule,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: const Text('Cài lịch phun'),
          ),
          const SizedBox(height: 12),
          CupertinoButton(
            onPressed: onOpenDevice,
            child: const Text('Mở thiết bị'),
          ),
        ],
      ),
    );
  }
}
