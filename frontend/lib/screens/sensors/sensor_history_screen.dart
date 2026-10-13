import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../../cupertino/theme/cupertino_theme.dart';
import '../../models/device.dart';
import '../../models/history_data.dart';
import '../../services/history_export_presenter.dart';
import '../../services/history_export_service.dart';
import '../../services/history_repository.dart';

class SensorHistoryScreen extends StatefulWidget {
  const SensorHistoryScreen({
    super.key,
    required this.device,
    this.sensor,
    this.repository,
    this.exportService = const HistoryExportService(),
  });

  final Device device;
  final String? sensor;
  final HistoryRepository? repository;
  final HistoryExportService exportService;

  @override
  State<SensorHistoryScreen> createState() => _SensorHistoryScreenState();
}

class _SensorHistoryScreenState extends State<SensorHistoryScreen> {
  late final HistoryRepository _repository;
  List<HistorySample> _samples = const [];
  List<PumpHistoryEvent> _pumpEvents = const [];
  Map<String, dynamic> _alertSettings = const {};
  Set<HistorySensor> _selectedSensors = {HistorySensor.temperature};
  HistoryRange _range = HistoryRange.day;
  late DateTime _customFrom;
  late DateTime _customTo;
  bool _showPumpEvents = true;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiHistoryRepository();
    final initial = _sensorFromKey(widget.sensor);
    if (initial != null) _selectedSensors = {initial};
    _customTo = DateTime.now();
    _customFrom = _customTo.subtract(const Duration(days: 7));
    _loadHistory();
  }

  HistoryWindow get _window {
    final now = DateTime.now();
    final duration = _range.duration;
    return duration == null
        ? HistoryWindow(from: _customFrom, to: _customTo)
        : HistoryWindow(from: now.subtract(duration), to: now);
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final window = _window;
    try {
      final results = await Future.wait([
        _repository.loadSamples(
          deviceId: widget.device.id,
          window: window,
          downsample: _range.isDownsampled || window.rangeHours > 48,
        ),
        _repository.loadPumpEvents(deviceId: widget.device.id, window: window),
        _repository.loadAlertSettings(widget.device.id),
      ]);
      if (!mounted) return;
      setState(() {
        _samples = results[0] as List<HistorySample>;
        _pumpEvents = results[1] as List<PumpHistoryEvent>;
        _alertSettings = results[2] as Map<String, dynamic>;
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

  HistorySensor? _sensorFromKey(String? key) => switch (key) {
    'temperature' => HistorySensor.temperature,
    'solutionTemperature' ||
    'solution_temperature' => HistorySensor.solutionTemperature,
    'humidity' => HistorySensor.humidity,
    'tds' => HistorySensor.tds,
    'ph' => HistorySensor.ph,
    'waterLevel' || 'water_level' => HistorySensor.waterLevel,
    _ => null,
  };

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: CupertinoNavigationBar(
      middle: Text('Lịch sử · ${widget.device.name}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(38, 38),
            onPressed: _showFilterSheet,
            child: const Icon(CupertinoIcons.slider_horizontal_3),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(38, 38),
            onPressed: _samples.isEmpty ? null : _showExportSheet,
            child: const Icon(CupertinoIcons.share),
          ),
        ],
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: _loadHistory),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
            sliver: SliverList.list(
              children: [
                _buildSensorChips(),
                const SizedBox(height: 12),
                _buildRangeSelector(),
                const SizedBox(height: 18),
                if (_isLoading)
                  const _HistorySkeleton()
                else if (_errorMessage != null)
                  _HistoryError(message: _errorMessage!, onRetry: _loadHistory)
                else if (_samples.isEmpty)
                  _HistoryEmpty(
                    isNewDevice:
                        DateTime.tryParse(widget.device.createdAt)?.isAfter(
                          DateTime.now().subtract(const Duration(hours: 24)),
                        ) ??
                        false,
                    onChangeRange: _showFilterSheet,
                  )
                else
                  _buildHistoryContent(),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildSensorChips() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final sensor in HistorySensor.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _SelectionChip(
              label: sensor.label,
              selected: _selectedSensors.contains(sensor),
              color: _sensorColor(sensor),
              onTap: () {
                setState(() {
                  if (_selectedSensors.contains(sensor)) {
                    if (_selectedSensors.length > 1) {
                      _selectedSensors = {..._selectedSensors}..remove(sensor);
                    }
                  } else {
                    _selectedSensors = {..._selectedSensors, sensor};
                  }
                });
              },
            ),
          ),
      ],
    ),
  );

  Widget _buildRangeSelector() => Row(
    children: [
      for (final range in HistoryRange.values)
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: range == HistoryRange.custom ? 0 : 6,
            ),
            child: _SelectionChip(
              label: range.label,
              selected: _range == range,
              onTap: () async {
                if (range == HistoryRange.custom && !await _pickCustomRange()) {
                  return;
                }
                setState(() => _range = range);
                await _loadHistory();
              },
            ),
          ),
        ),
    ],
  );

  Widget _buildHistoryContent() {
    final primary = _selectedSensors.first;
    final hasVisibleValues = _samples.any(
      (sample) => _selectedSensors.any(sample.values.containsKey),
    );
    if (!hasVisibleValues) {
      return _HistoryEmpty(isNewDevice: false, onChangeRange: _showFilterSheet);
    }
    final statistics = HistoryStatistics.fromSamples(_samples, primary);
    final content = <Widget>[
      if (_range.isDownsampled || _window.rangeHours > 48) ...[
        const _InfoBanner(
          icon: CupertinoIcons.chart_bar,
          text: 'Hiển thị trung bình theo giờ',
        ),
        const SizedBox(height: 12),
      ],
      _HistoryChart(
        samples: _samples,
        sensors: _selectedSensors,
        alertSettings: _alertSettings,
        window: _window,
      ),
      if (_showPumpEvents) ...[
        const SizedBox(height: 8),
        _PumpEventStrip(events: _pumpEvents, window: _window),
      ],
      const SizedBox(height: 16),
      if (statistics != null)
        _StatisticsCard(sensor: primary, statistics: statistics),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760 || statistics == null) {
          return Column(children: content);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: content.take(content.length - 1).toList(),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: _StatisticsCard(sensor: primary, statistics: statistics),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showFilterSheet() async {
    var sensors = {..._selectedSensors};
    var range = _range;
    var showPumpEvents = _showPumpEvents;
    final applied = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (popupContext) => StatefulBuilder(
        builder: (context, setPopupState) => CupertinoActionSheet(
          title: const Text('Bộ lọc lịch sử'),
          message: Column(
            children: [
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sensor in HistorySensor.values)
                    _SelectionChip(
                      label: sensor.label,
                      selected: sensors.contains(sensor),
                      color: _sensorColor(sensor),
                      onTap: () => setPopupState(() {
                        if (sensors.contains(sensor)) {
                          if (sensors.length > 1) sensors.remove(sensor);
                        } else {
                          sensors.add(sensor);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in HistoryRange.values)
                    _SelectionChip(
                      label: option.label,
                      selected: range == option,
                      onTap: () => setPopupState(() => range = option),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(child: Text('Hiển thị sự kiện bơm')),
                  CupertinoSwitch(
                    value: showPumpEvents,
                    onChanged: (value) =>
                        setPopupState(() => showPumpEvents = value),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                setPopupState(() {
                  sensors = {HistorySensor.temperature};
                  range = HistoryRange.day;
                  showPumpEvents = true;
                });
              },
              child: const Text('Đặt lại'),
            ),
            CupertinoActionSheetAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(popupContext).pop(true),
              child: const Text('Áp dụng'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(popupContext).pop(false),
            child: const Text('Hủy'),
          ),
        ),
      ),
    );
    if (applied != true || !mounted) return;
    if (range == HistoryRange.custom && !await _pickCustomRange()) return;
    setState(() {
      _selectedSensors = sensors;
      _range = range;
      _showPumpEvents = showPumpEvents;
    });
    await _loadHistory();
  }

  Future<bool> _pickCustomRange() async {
    final from = await _pickDate('Từ ngày', _customFrom);
    if (from == null || !mounted) return false;
    final to = await _pickDate('Đến ngày', _customTo);
    if (to == null || !mounted) return false;
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59);
    if (!end.isAfter(from) || end.difference(from) > const Duration(days: 31)) {
      await _showMessage('Khoảng tùy chọn phải từ 1 đến 31 ngày.');
      return false;
    }
    _customFrom = DateTime(from.year, from.month, from.day);
    _customTo = end;
    return true;
  }

  Future<DateTime?> _pickDate(String title, DateTime initial) {
    var value = initial;
    return showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (popupContext) => Container(
        height: 330,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(popupContext).pop(),
                    child: const Text('Hủy'),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.of(popupContext).pop(value),
                    child: const Text('Xong'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initial,
                  minimumDate: DateTime.now().subtract(
                    const Duration(days: 366),
                  ),
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (date) => value = date,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showExportSheet() async {
    var format = HistoryExportFormat.csv;
    var sensors = {..._selectedSensors};
    var generating = false;
    String? error;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => StatefulBuilder(
        builder: (context, setPopupState) => CupertinoActionSheet(
          title: const Text('Xuất dữ liệu'),
          message: Column(
            children: [
              Text(
                '${DateFormat('dd/MM/yyyy').format(_window.from)} – ${DateFormat('dd/MM/yyyy').format(_window.to)}',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sensor in HistorySensor.values)
                    _SelectionChip(
                      label: sensor.label,
                      selected: sensors.contains(sensor),
                      onTap: generating
                          ? null
                          : () => setPopupState(() {
                              if (sensors.contains(sensor)) {
                                if (sensors.length > 1) sensors.remove(sensor);
                              } else {
                                sensors.add(sensor);
                              }
                            }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              CupertinoSlidingSegmentedControl<HistoryExportFormat>(
                groupValue: format,
                children: const {
                  HistoryExportFormat.csv: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 22),
                    child: Text('CSV'),
                  ),
                  HistoryExportFormat.pdf: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 22),
                    child: Text('PDF'),
                  ),
                },
                onValueChanged: (value) {
                  if (!generating && value != null) {
                    setPopupState(() => format = value);
                  }
                },
              ),
              if (generating) ...[
                const SizedBox(height: 14),
                const CupertinoActivityIndicator(),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: const TextStyle(color: CupertinoColors.systemRed),
                ),
              ],
            ],
          ),
          actions: [
            CupertinoActionSheetAction(
              isDefaultAction: true,
              onPressed: generating
                  ? () {}
                  : () async {
                      setPopupState(() {
                        generating = true;
                        error = null;
                      });
                      try {
                        final file = await widget.exportService.generate(
                          format: format,
                          deviceName: widget.device.name,
                          window: _window,
                          sensors: sensors,
                          samples: _samples,
                          pumpEvents: _showPumpEvents ? _pumpEvents : const [],
                        );
                        await presentHistoryExport(file);
                        if (popupContext.mounted) {
                          Navigator.of(popupContext).pop();
                        }
                      } catch (_) {
                        if (!popupContext.mounted) return;
                        setPopupState(() {
                          generating = false;
                          error = 'Không thể tạo tệp. Hãy thử khoảng ngắn hơn.';
                        });
                      }
                    },
              child: Text(error == null ? 'Tạo tệp' : 'Thử lại'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: generating
                ? () {}
                : () => Navigator.of(popupContext).pop(),
            child: const Text('Hủy'),
          ),
        ),
      ),
    );
  }

  Future<void> _showMessage(String message) => showCupertinoDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Đã hiểu'),
        ),
      ],
    ),
  );
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart({
    required this.samples,
    required this.sensors,
    required this.alertSettings,
    required this.window,
  });

  final List<HistorySample> samples;
  final Set<HistorySensor> sensors;
  final Map<String, dynamic> alertSettings;
  final HistoryWindow window;

  @override
  Widget build(BuildContext context) {
    final allValues = samples
        .expand((sample) => sensors.map((sensor) => sample.values[sensor]))
        .whereType<double>()
        .toList();
    final dataMin = allValues.reduce(math.min);
    final dataMax = allValues.reduce(math.max);
    final padding = math.max(1.0, (dataMax - dataMin) * 0.15);
    var minY = dataMin - padding;
    var maxY = dataMax + padding;
    final primary = sensors.first;
    final threshold = switch (primary) {
      HistorySensor.temperature =>
        (alertSettings['highTemperatureC'] as num?)?.toDouble(),
      HistorySensor.waterLevel =>
        (alertSettings['lowWaterLevelPercent'] as num?)?.toDouble(),
      _ => null,
    };
    if (threshold != null) {
      minY = math.min(minY, threshold - padding);
      maxY = math.max(maxY, threshold + padding);
    }
    final minX = window.from.millisecondsSinceEpoch.toDouble();
    final maxX = window.to.millisecondsSinceEpoch.toDouble();
    final axisFormat = window.rangeHours <= 30
        ? DateFormat('HH:mm')
        : DateFormat('dd/MM');
    return _Surface(
      child: SizedBox(
        height: 330,
        child: LineChart(
          LineChartData(
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: CupertinoColors.separator.resolveFrom(context),
                strokeWidth: 0.5,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  getTitlesWidget: (value, _) => Text(
                    value.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: (maxX - minX) / 4,
                  getTitlesWidget: (value, _) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      axisFormat.format(
                        DateTime.fromMillisecondsSinceEpoch(value.toInt()),
                      ),
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
                ),
              ),
            ),
            rangeAnnotations: threshold == null
                ? const RangeAnnotations()
                : RangeAnnotations(
                    horizontalRangeAnnotations: [
                      HorizontalRangeAnnotation(
                        y1: primary == HistorySensor.waterLevel
                            ? minY
                            : threshold,
                        y2: primary == HistorySensor.waterLevel
                            ? threshold
                            : maxY,
                        color: CupertinoColors.systemRed.withValues(
                          alpha: 0.08,
                        ),
                      ),
                    ],
                  ),
            extraLinesData: threshold == null
                ? const ExtraLinesData()
                : ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: threshold,
                        color: CupertinoColors.systemRed,
                        strokeWidth: 1,
                        dashArray: [5, 4],
                      ),
                    ],
                  ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots
                    .map(
                      (spot) => LineTooltipItem(
                        '${DateFormat('dd/MM HH:mm').format(DateTime.fromMillisecondsSinceEpoch(spot.x.toInt()))}\n${spot.y.toStringAsFixed(2)}',
                        TextStyle(
                          color: spot.bar.color ?? CupertinoColors.white,
                          fontSize: 11,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            lineBarsData: [
              for (final sensor in sensors)
                LineChartBarData(
                  spots: [
                    for (final sample in samples)
                      if (sample.values[sensor] case final value?)
                        FlSpot(
                          sample.recordedAt.millisecondsSinceEpoch.toDouble(),
                          value,
                        ),
                  ],
                  isCurved: true,
                  color: _sensorColor(sensor),
                  barWidth: 2.4,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: sensors.length == 1,
                    color: _sensorColor(sensor).withValues(alpha: 0.08),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PumpEventStrip extends StatelessWidget {
  const _PumpEventStrip({required this.events, required this.window});

  final List<PumpHistoryEvent> events;
  final HistoryWindow window;

  @override
  Widget build(BuildContext context) => _Surface(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              CupertinoIcons.drop_fill,
              size: 15,
              color: CupertinoColors.systemBlue,
            ),
            const SizedBox(width: 6),
            Text(
              'Sự kiện bơm · ${events.length}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 18,
          width: double.infinity,
          child: CustomPaint(
            painter: _PumpEventPainter(events: events, window: window),
          ),
        ),
      ],
    ),
  );
}

class _PumpEventPainter extends CustomPainter {
  const _PumpEventPainter({required this.events, required this.window});

  final List<PumpHistoryEvent> events;
  final HistoryWindow window;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = Paint()
      ..color = CupertinoColors.systemGrey4
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      baseline,
    );
    final total = window.to.difference(window.from).inMilliseconds;
    if (total <= 0) return;
    for (final event in events) {
      final elapsed = event.at.difference(window.from).inMilliseconds;
      final x = (elapsed / total).clamp(0.0, 1.0) * size.width;
      final paint = Paint()
        ..color = event.isOn
            ? CupertinoColors.systemBlue
            : CupertinoColors.systemGrey;
      canvas.drawCircle(Offset(x, size.height / 2), 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PumpEventPainter oldDelegate) =>
      oldDelegate.events != events || oldDelegate.window != window;
}

class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({required this.sensor, required this.statistics});

  final HistorySensor sensor;
  final HistoryStatistics statistics;

  @override
  Widget build(BuildContext context) => _Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sensor.label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _Metric(
              label: 'Thấp nhất',
              value: statistics.minimum,
              sensor: sensor,
            ),
            _Metric(
              label: 'Trung bình',
              value: statistics.average,
              sensor: sensor,
            ),
            _Metric(
              label: 'Cao nhất',
              value: statistics.maximum,
              sensor: sensor,
            ),
          ],
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.sensor,
  });

  final String label;
  final double value;
  final HistorySensor sensor;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          '${value.toStringAsFixed(sensor == HistorySensor.ph ? 2 : 1)}${sensor.unit}',
          style: TextStyle(
            color: _sensorColor(sensor),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: CupertinoColors.secondaryLabel,
            fontSize: 10,
          ),
        ),
      ],
    ),
  );
}

class _SelectionChip extends StatelessWidget {
  const _SelectionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AerogreenCupertinoTheme.aerogreenPrimary;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 34),
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.14)
              : CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? accent
                : CupertinoColors.separator.resolveFrom(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? accent
                : CupertinoColors.secondaryLabel.resolveFrom(context),
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: CupertinoColors.systemBlue),
      const SizedBox(width: 8),
      Text(
        text,
        style: const TextStyle(
          color: CupertinoColors.secondaryLabel,
          fontSize: 12,
        ),
      ),
    ],
  );
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final height in [330.0, 86.0]) ...[
        Container(
          height: height,
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey5.resolveFrom(context),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(height: 14),
      ],
    ],
  );
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _Surface(
    child: Column(
      children: [
        const Icon(
          CupertinoIcons.exclamationmark_triangle,
          color: CupertinoColors.systemOrange,
          size: 32,
        ),
        const SizedBox(height: 10),
        const Text('Không thể tải lịch sử'),
        const SizedBox(height: 5),
        Text(
          message,
          maxLines: 3,
          textAlign: TextAlign.center,
          style: const TextStyle(color: CupertinoColors.secondaryLabel),
        ),
        const SizedBox(height: 14),
        CupertinoButton.filled(
          onPressed: onRetry,
          child: const Text('Thử lại'),
        ),
      ],
    ),
  );
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty({required this.isNewDevice, required this.onChangeRange});

  final bool isNewDevice;
  final VoidCallback onChangeRange;

  @override
  Widget build(BuildContext context) => _Surface(
    child: Column(
      children: [
        const Icon(
          CupertinoIcons.chart_bar_alt_fill,
          size: 34,
          color: CupertinoColors.systemGrey,
        ),
        const SizedBox(height: 10),
        Text(
          isNewDevice
              ? 'Thiết bị mới chưa có đủ dữ liệu'
              : 'Không có dữ liệu trong khoảng này',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        CupertinoButton(
          onPressed: onChangeRange,
          child: const Text('Đổi khoảng thời gian'),
        ),
      ],
    ),
  );
}

Color _sensorColor(HistorySensor sensor) => switch (sensor) {
  HistorySensor.temperature => CupertinoColors.systemOrange,
  HistorySensor.solutionTemperature => CupertinoColors.systemRed,
  HistorySensor.humidity => CupertinoColors.systemBlue,
  HistorySensor.tds => CupertinoColors.systemIndigo,
  HistorySensor.ph => CupertinoColors.systemPurple,
  HistorySensor.waterLevel => CupertinoColors.systemTeal,
};
