import 'package:flutter/cupertino.dart';

import '../../models/device.dart';
import '../../providers/alert_center_provider.dart';

class AlertThresholdsScreen extends StatefulWidget {
  const AlertThresholdsScreen({
    super.key,
    required this.device,
    this.repository,
  });

  final Device device;
  final AlertRepository? repository;

  @override
  State<AlertThresholdsScreen> createState() => _AlertThresholdsScreenState();
}

class _AlertThresholdsScreenState extends State<AlertThresholdsScreen> {
  late final AlertRepository _repository;
  final _temperatureController = TextEditingController();
  final _waterController = TextEditingController();
  double _temperature = 30;
  double _water = 30;
  bool _temperatureEnabled = true;
  bool _waterEnabled = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiAlertRepository();
    _load();
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _waterController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _repository.loadSettings(widget.device.id);
      final temperature = (data['highTemperatureC'] as num?)?.toDouble();
      final water = (data['lowWaterLevelPercent'] as num?)?.toDouble();
      if (!mounted) return;
      setState(() {
        _temperatureEnabled = temperature != null;
        _waterEnabled = water != null;
        _temperature = temperature ?? 30;
        _water = water ?? 30;
        _temperatureController.text = _temperature.toStringAsFixed(1);
        _waterController.text = _water.toStringAsFixed(0);
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  void _resetRecommended() {
    setState(() {
      _temperatureEnabled = true;
      _waterEnabled = true;
      _temperature = 30;
      _water = 30;
      _temperatureController.text = '30.0';
      _waterController.text = '30';
      _error = null;
    });
  }

  Future<void> _save() async {
    final temperature = double.tryParse(_temperatureController.text);
    final water = double.tryParse(_waterController.text);
    if ((_temperatureEnabled &&
            (temperature == null || temperature <= 0 || temperature > 80)) ||
        (_waterEnabled && (water == null || water < 0 || water > 100))) {
      setState(() => _error = 'Ngưỡng phải là số hợp lệ; mực nước từ 0–100%.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repository.saveSettings(
        widget.device.id,
        highTemperatureC: _temperatureEnabled ? temperature : null,
        lowWaterLevelPercent: _waterEnabled ? water : null,
      );
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Đã lưu ngưỡng cảnh báo'),
          content: Text('Cài đặt cho ${widget.device.name} đã được cập nhật.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Xong'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: CupertinoNavigationBar(
      middle: const Text('Ngưỡng cảnh báo'),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _saving ? null : _save,
        child: _saving ? const CupertinoActivityIndicator() : const Text('Lưu'),
      ),
    ),
    child: SafeArea(
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              children: [
                Text(
                  widget.device.name,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Chỉ những cảm biến thiết bị hiện hỗ trợ mới được hiển thị.',
                  style: TextStyle(color: CupertinoColors.secondaryLabel),
                ),
                const SizedBox(height: 18),
                _ThresholdCard(
                  title: 'Nhiệt độ cao',
                  unit: '°C',
                  enabled: _temperatureEnabled,
                  value: _temperature,
                  minimum: 10,
                  maximum: 60,
                  controller: _temperatureController,
                  onEnabledChanged: (value) =>
                      setState(() => _temperatureEnabled = value),
                  onChanged: (value) {
                    setState(() => _temperature = value);
                    _temperatureController.text = value.toStringAsFixed(1);
                  },
                ),
                const SizedBox(height: 14),
                _ThresholdCard(
                  title: 'Mực nước thấp',
                  unit: '%',
                  enabled: _waterEnabled,
                  value: _water,
                  minimum: 0,
                  maximum: 100,
                  controller: _waterController,
                  onEnabledChanged: (value) =>
                      setState(() => _waterEnabled = value),
                  onChanged: (value) {
                    setState(() => _water = value);
                    _waterController.text = value.toStringAsFixed(0);
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: CupertinoColors.systemRed),
                  ),
                ],
                const SizedBox(height: 18),
                CupertinoButton(
                  onPressed: _resetRecommended,
                  child: const Text('Đặt lại khuyến nghị'),
                ),
              ],
            ),
    ),
  );
}

class _ThresholdCard extends StatelessWidget {
  const _ThresholdCard({
    required this.title,
    required this.unit,
    required this.enabled,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.controller,
    required this.onEnabledChanged,
    required this.onChanged,
  });

  final String title;
  final String unit;
  final bool enabled;
  final double value;
  final double minimum;
  final double maximum;
  final TextEditingController controller;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            CupertinoSwitch(value: enabled, onChanged: onEnabledChanged),
          ],
        ),
        if (enabled) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CupertinoSlider(
                  value: value.clamp(minimum, maximum),
                  min: minimum,
                  max: maximum,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 82,
                child: CupertinoTextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  suffix: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(unit),
                  ),
                  onChanged: (text) {
                    final parsed = double.tryParse(text);
                    if (parsed != null &&
                        parsed >= minimum &&
                        parsed <= maximum) {
                      onChanged(parsed);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
