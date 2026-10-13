import 'package:flutter/cupertino.dart';

import '../../models/device.dart';
import '../../services/api_service.dart';

class CupertinoCreateTicketScreen extends StatefulWidget {
  final ApiService? apiService;
  final Device? preselectedDevice;

  const CupertinoCreateTicketScreen({
    super.key,
    this.apiService,
    this.preselectedDevice,
  });

  @override
  State<CupertinoCreateTicketScreen> createState() =>
      _CupertinoCreateTicketScreenState();
}

class _CupertinoCreateTicketScreenState
    extends State<CupertinoCreateTicketScreen> {
  late final ApiService _apiService;
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  final List<String> _categories = const [
    'Kỹ thuật',
    'Phần cứng & Thiết bị',
    'Lịch phun & Bơm',
    'Cảm biến',
    'Tài khoản',
    'Khác',
  ];
  String _selectedCategory = 'Kỹ thuật';

  List<Device> _devices = [];
  Device? _selectedDevice;
  bool _isLoadingDevices = false;
  bool _hasPhotoAttached = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _selectedDevice = widget.preselectedDevice;
    _loadDevices();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoadingDevices = true);
    try {
      final list = await _apiService.getDevices();
      final devices = list
          .map((item) => Device.fromJson(item as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        if (_selectedDevice != null) {
          final match = devices.where((d) => d.id == _selectedDevice!.id);
          if (match.isNotEmpty) _selectedDevice = match.first;
        }
        _isLoadingDevices = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingDevices = false);
    }
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();

    if (subject.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập tiêu đề yêu cầu.');
      return;
    }
    if (message.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập nội dung chi tiết.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final ticketData = await _apiService.createSupportTicket(
        subject,
        message,
        category: _selectedCategory,
        deviceId: _selectedDevice?.id,
        deviceName: _selectedDevice?.name,
        firmwareVersion: _selectedDevice != null ? 'v1.0.4' : null,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      Navigator.of(context).pop(ticketData);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _showCategoryPicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: const Text('Chọn danh mục vấn đề'),
        actions: _categories.map((cat) {
          return CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _selectedCategory = cat);
              Navigator.of(popupContext).pop();
            },
            child: Text(cat),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(popupContext).pop(),
          child: const Text('Hủy'),
        ),
      ),
    );
  }

  void _showDevicePicker() {
    if (_devices.isEmpty) {
      showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Không có thiết bị'),
          content: const Text('Tài khoản của bạn hiện chưa có thiết bị nào.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
      return;
    }

    showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: const Text('Chọn thiết bị liên quan'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _selectedDevice = null);
              Navigator.of(popupContext).pop();
            },
            child: const Text('Không đính kèm thiết bị'),
          ),
          ..._devices.map((device) {
            return CupertinoActionSheetAction(
              onPressed: () {
                setState(() => _selectedDevice = device);
                Navigator.of(popupContext).pop();
              },
              child: Text('${device.name} (${device.id})'),
            );
          }),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(popupContext).pop(),
          child: const Text('Hủy'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Tạo yêu cầu hỗ trợ'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const CupertinoActivityIndicator(radius: 8)
              : const Text('Gửi', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.exclamationmark_circle,
                        color: CupertinoColors.systemRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: CupertinoColors.systemRed,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Tiêu đề',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 6),
            CupertinoTextField(
              controller: _subjectController,
              maxLength: 200,
              placeholder: 'Ví dụ: Cảm biến pH hiển thị sai số...',
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Danh mục',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _showCategoryPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedCategory,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    const Icon(CupertinoIcons.chevron_down,
                        size: 16, color: CupertinoColors.secondaryLabel),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Thiết bị liên quan (Tùy chọn)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _showDevicePicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedDevice != null
                          ? CupertinoIcons.cube_box
                          : CupertinoIcons.cube_box_fill,
                      size: 18,
                      color: CupertinoColors.secondaryLabel,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedDevice != null
                            ? '${_selectedDevice!.name} (${_selectedDevice!.id})'
                            : (_isLoadingDevices
                                ? 'Đang tải danh sách thiết bị...'
                                : 'Không đính kèm thiết bị'),
                        style: TextStyle(
                          fontSize: 15,
                          color: _selectedDevice != null
                              ? CupertinoColors.label.resolveFrom(context)
                              : CupertinoColors.secondaryLabel.resolveFrom(context),
                        ),
                      ),
                    ),
                    const Icon(CupertinoIcons.chevron_down,
                        size: 16, color: CupertinoColors.secondaryLabel),
                  ],
                ),
              ),
            ),
            if (_selectedDevice != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6.resolveFrom(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.info_circle,
                        size: 14, color: CupertinoColors.secondaryLabel),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tự động đính kèm ID: ${_selectedDevice!.id} | Firmware: v1.0.4',
                        style: const TextStyle(
                          fontSize: 11,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            const Text(
              'Mô tả chi tiết',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 6),
            CupertinoTextField(
              controller: _messageController,
              maxLength: 4000,
              minLines: 5,
              maxLines: 8,
              placeholder: 'Mô tả chi tiết vấn đề bạn đang gặp phải để kỹ thuật viên hỗ trợ nhanh nhất...',
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Hình ảnh đính kèm (Tùy chọn)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                setState(() => _hasPhotoAttached = !_hasPhotoAttached);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _hasPhotoAttached
                        ? CupertinoColors.activeGreen
                        : CupertinoColors.systemGrey4.resolveFrom(context),
                    width: _hasPhotoAttached ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _hasPhotoAttached
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.camera,
                      size: 20,
                      color: _hasPhotoAttached
                          ? CupertinoColors.activeGreen
                          : CupertinoColors.secondaryLabel,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _hasPhotoAttached
                          ? 'Đã đính kèm ảnh lỗi (nhấn để gỡ)'
                          : 'Nhấn để chụp / chọn ảnh lỗi',
                      style: TextStyle(
                        fontSize: 14,
                        color: _hasPhotoAttached
                            ? CupertinoColors.activeGreen
                            : CupertinoColors.secondaryLabel,
                        fontWeight: _hasPhotoAttached ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            CupertinoButton.filled(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                  : const Text('Gửi yêu cầu hỗ trợ'),
            ),
          ],
        ),
      ),
    );
  }
}
