  import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../models/device.dart';
import '../../models/pump_schedule.dart';
import '../../services/api_service.dart';

enum SchedulePreset {
  seedlings('Cây giống', 10, 15),
  leafy('Rau lá', 20, 30),
  herbs('Thảo mộc', 15, 20),
  custom('Tùy chỉnh', 30, 30);

  final String label;
  final int defaultMistLength;
  final int defaultInterval;

  const SchedulePreset(
    this.label,
    this.defaultMistLength,
    this.defaultInterval,
  );
}

class CupertinoPumpSchedulesScreen extends StatefulWidget {
  final Device device;

  const CupertinoPumpSchedulesScreen({super.key, required this.device});

  @override
  State<CupertinoPumpSchedulesScreen> createState() =>
      _CupertinoPumpSchedulesScreenState();
}

class _CupertinoPumpSchedulesScreenState
    extends State<CupertinoPumpSchedulesScreen> {
  final ApiService _apiService = ApiService();
  List<PumpSchedule> _schedules = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final schedulesData = await _apiService.getPumpSchedules(
        widget.device.id,
      );
      setState(() {
        _schedules = schedulesData
            .map((data) => PumpSchedule.fromJson(data))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addSchedule() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      CupertinoPageRoute(
        builder: (_) => AddScheduleDialog(device: widget.device),
      ),
    );

    if (result != null && mounted) {
      await _loadSchedules();
    }
  }

  Future<void> _deleteSchedule(PumpSchedule schedule) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa lịch trình này?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.deletePumpSchedule(widget.device.id, schedule.id);
        if (mounted) await _loadSchedules();
      } catch (e) {
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Lỗi'),
              content: Text('Không thể xóa: $e'),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đã hiểu'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Lịch tưới - ${widget.device.name}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _isLoading ? null : _addSchedule,
              child: const Icon(CupertinoIcons.add),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _isLoading ? null : _loadSchedules,
              child: const Icon(CupertinoIcons.arrow_2_circlepath),
            ),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: _loadSchedules),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CupertinoActivityIndicator(radius: 14)),
              )
            else if (_errorMessage != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.exclamationmark_triangle,
                        size: 48,
                        color: CupertinoColors.systemOrange,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Không thể tải lịch trình',
                        style: TextStyle(
                          color: CupertinoColors.label.resolveFrom(context),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CupertinoButton.filled(
                        onPressed: _loadSchedules,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_schedules.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.calendar,
                        size: 48,
                        color: CupertinoColors.systemGrey2,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có lịch trình',
                        style: TextStyle(
                          color: CupertinoColors.label.resolveFrom(context),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Thêm lịch trình tưới tự động',
                        style: TextStyle(
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CupertinoButton.filled(
                        onPressed: _addSchedule,
                        child: const Text('Thêm lịch trình'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final schedule = _schedules[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ScheduleCard(
                        schedule: schedule,
                        onDelete: () => _deleteSchedule(schedule),
                      ),
                    );
                  }, childCount: _schedules.length),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final PumpSchedule schedule;
  final VoidCallback onDelete;

  const _ScheduleCard({required this.schedule, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    schedule.isEnabled
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.circle,
                    color: schedule.isEnabled
                        ? CupertinoColors.systemGreen
                        : CupertinoColors.systemGrey,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatTime(schedule.startTime),
                    style: TextStyle(
                      color: CupertinoColors.label.resolveFrom(context),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onDelete,
                child: const Icon(
                  CupertinoIcons.delete,
                  color: CupertinoColors.systemRed,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Thời gian phun: ${schedule.durationSeconds} giây',
            style: TextStyle(
              color: CupertinoColors.label.resolveFrom(context),
              fontSize: 15,
            ),
          ),
          if (schedule.intervalMinutes != null) ...[
            const SizedBox(height: 4),
            Text(
              'Lặp lại mỗi ${schedule.intervalMinutes} phút',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Ngày: ${_formatDays(schedule.weekdayMask)}',
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String timeString) {
    final parts = timeString.split(':');
    if (parts.length >= 2) {
      return '${parts[0]}:${parts[1]}';
    }
    return timeString;
  }

  String _formatDays(int mask) {
    const days = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
    final selected = [
      for (var day = 0; day < days.length; day++)
        if ((mask & (1 << day)) != 0) days[day],
    ];
    return selected.isEmpty ? 'chưa chọn ngày' : selected.join(', ');
  }
}

class AddScheduleDialog extends StatefulWidget {
  final Device device;

  const AddScheduleDialog({super.key, required this.device});

  @override
  State<AddScheduleDialog> createState() => _AddScheduleDialogState();
}

class _AddScheduleDialogState extends State<AddScheduleDialog> {
  final ApiService _apiService = ApiService();
  final _mistLengthController = TextEditingController(text: '30');
  final _intervalController = TextEditingController(text: '30');

  SchedulePreset _selectedPreset = SchedulePreset.custom;
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 12));
  final List<int> _selectedDays = [1, 2, 3, 4, 5];

  bool _isSaving = false;
  String? _errorMessage;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _mistLengthController.addListener(_onChanged);
    _intervalController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _mistLengthController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() => _hasUnsavedChanges = true);
  }

  void _applyPreset(SchedulePreset preset) {
    setState(() {
      _selectedPreset = preset;
      _mistLengthController.text = preset.defaultMistLength.toString();
      _intervalController.text = preset.defaultInterval.toString();
      _hasUnsavedChanges = true;
    });
  }

  String? _validateMistLength(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập thời gian phun';
    }
    final length = int.tryParse(value);
    if (length == null || length < 1 || length > 120) {
      return 'Thời gian phun từ 1-120 giây';
    }
    return null;
  }

  String? _validateInterval(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập khoảng cách';
    }
    final interval = int.tryParse(value);
    if (interval == null || interval < 1 || interval > 60) {
      return 'Khoảng cách từ 1-60 phút';
    }
    final mistLength = int.tryParse(_mistLengthController.text);
    if (mistLength != null && mistLength >= interval * 60) {
      return 'Thời gian phun phải nhỏ hơn khoảng cách';
    }
    return null;
  }

  String? _validateTimeWindow() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;

    if (endMinutes <= startMinutes && endMinutes < startMinutes + 60) {
      return 'Giờ kết thúc phải sau giờ bắt đầu (trừ khi qua đêm)';
    }
    return null;
  }

  String _getLiveSummary() {
    final mistLength = _mistLengthController.text;
    final interval = _intervalController.text;
    final days = _selectedDays
        .map((d) => ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'][d])
        .join(', ');

    return 'Phun $mistLength giây mỗi $interval phút, ${_startTime.format(context)}-${_endTime.format(context)}, $days';
  }

  Future<void> _save() async {
    final mistLengthError = _validateMistLength(_mistLengthController.text);
    final intervalError = _validateInterval(_intervalController.text);
    final timeWindowError = _validateTimeWindow();

    if (mistLengthError != null ||
        intervalError != null ||
        timeWindowError != null) {
      setState(() {
        _errorMessage = mistLengthError ?? intervalError ?? timeWindowError;
      });
      return;
    }

    if (_selectedDays.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng chọn ít nhất một ngày');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final startTimeStr = DateTime(
        now.year,
        now.month,
        now.day,
        _startTime.hour,
        _startTime.minute,
      ).toIso8601String();
      final endTimeStr = DateTime(
        now.year,
        now.month,
        now.day,
        _endTime.hour,
        _endTime.minute,
      ).toIso8601String();

      await _apiService.createPumpSchedule(
        widget.device.id,
        startTimeStr,
        int.parse(_mistLengthController.text),
        _selectedDays,
        intervalMinutes: int.parse(_intervalController.text),
        endTime: endTimeStr,
      );

      if (mounted) {
        HapticFeedback.lightImpact();
        showCupertinoDialog(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('Đã lưu'),
            content: const Text('Đã lưu vào thiết bị'),
            actions: [
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).pop(true);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Không thể lưu: $e';
        });
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final shouldDiscard = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Chưa lưu'),
        content: const Text(
          'Bạn có thay đổi chưa được lưu. Bạn có muốn rời đi?',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Giữ lại'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Bỏ thay đổi'),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_hasUnsavedChanges) return;
        final navigator = Navigator.of(context);
        if (await _onWillPop()) {
          navigator.pop();
        }
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Thêm lịch trình'),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const CupertinoActivityIndicator(radius: 12)
                : const Text('Lưu'),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                sliver: SliverList.list(
                  children: [
                    // Preset chips
                    const Text(
                      'Mẫu cài đặt',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: SchedulePreset.values.map((preset) {
                        return CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          color: _selectedPreset == preset
                              ? CupertinoColors.activeBlue
                              : CupertinoColors.secondarySystemBackground
                                    .resolveFrom(context),
                          borderRadius: BorderRadius.circular(20),
                          onPressed: () => _applyPreset(preset),
                          child: Text(
                            preset.label,
                            style: TextStyle(
                              color: _selectedPreset == preset
                                  ? CupertinoColors.white
                                  : CupertinoColors.label.resolveFrom(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Mist length
                    _ScheduleField(
                      label: 'Thời gian phun (giây)',
                      controller: _mistLengthController,
                      keyboardType: TextInputType.number,
                      placeholder: '1-120',
                      errorText: _validateMistLength(
                        _mistLengthController.text,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Interval
                    _ScheduleField(
                      label: 'Khoảng cách (phút)',
                      controller: _intervalController,
                      keyboardType: TextInputType.number,
                      placeholder: '1-60',
                      errorText: _validateInterval(_intervalController.text),
                    ),
                    const SizedBox(height: 16),

                    // Active hours
                    const Text(
                      'Khung giờ hoạt động',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeButton(
                            label: 'Bắt đầu',
                            time: _startTime,
                            onTap: () => _selectTime(true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TimeButton(
                            label: 'Kết thúc',
                            time: _endTime,
                            onTap: () => _selectTime(false),
                          ),
                        ),
                      ],
                    ),
                    if (_validateTimeWindow() != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _validateTimeWindow()!,
                        style: const TextStyle(
                          color: CupertinoColors.systemRed,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Days of week
                    const Text(
                      'Ngày lặp lại',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(7, (index) {
                        final dayNames = [
                          'CN',
                          'T2',
                          'T3',
                          'T4',
                          'T5',
                          'T6',
                          'T7',
                        ];
                        return CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          color: _selectedDays.contains(index)
                              ? CupertinoColors.activeBlue
                              : CupertinoColors.secondarySystemBackground
                                    .resolveFrom(context),
                          borderRadius: BorderRadius.circular(20),
                          onPressed: () {
                            setState(() {
                              if (_selectedDays.contains(index)) {
                                _selectedDays.remove(index);
                              } else {
                                _selectedDays.add(index);
                              }
                              _hasUnsavedChanges = true;
                            });
                          },
                          child: Text(
                            dayNames[index],
                            style: TextStyle(
                              color: _selectedDays.contains(index)
                                  ? CupertinoColors.white
                                  : CupertinoColors.label.resolveFrom(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),

                    // Live summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6.resolveFrom(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.info_circle,
                            size: 16,
                            color: CupertinoColors.secondaryLabel,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getLiveSummary(),
                              style: TextStyle(
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemRed.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.xmark_circle_fill,
                              size: 16,
                              color: CupertinoColors.systemRed,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: CupertinoColors.systemRed,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: _save,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectTime(bool isStart) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        height: 216,
        padding: const EdgeInsets.only(top: 6),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            initialDateTime: isStart ? _startTime : _endTime,
            onDateTimeChanged: (DateTime newTime) {
              setState(() {
                if (isStart) {
                  _startTime = newTime;
                } else {
                  _endTime = newTime;
                }
                _hasUnsavedChanges = true;
              });
            },
          ),
        ),
      ),
    );
  }
}

class _ScheduleField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String placeholder;
  final String? errorText;

  const _ScheduleField({
    required this.label,
    required this.controller,
    this.keyboardType,
    required this.placeholder,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 7),
        child: Text(
          label,
          style: TextStyle(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      CupertinoTextField(
        controller: controller,
        keyboardType: keyboardType,
        placeholder: placeholder,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: errorText != null
                ? CupertinoColors.systemRed.resolveFrom(context)
                : CupertinoColors.separator.resolveFrom(context),
          ),
        ),
      ),
      if (errorText != null) ...[
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            errorText!,
            style: const TextStyle(
              color: CupertinoColors.systemRed,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ],
  );
}

class _TimeButton extends StatelessWidget {
  final String label;
  final DateTime time;
  final VoidCallback onTap;

  const _TimeButton({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: CupertinoColors.label.resolveFrom(context),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

extension on DateTime {
  String format(BuildContext context) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}
