import 'package:flutter/cupertino.dart';

import '../../../services/api_service.dart';
import '../../theme/cupertino_theme.dart';

class CupertinoSystemConfigScreen extends StatefulWidget {
  const CupertinoSystemConfigScreen({super.key});

  @override
  State<CupertinoSystemConfigScreen> createState() => _CupertinoSystemConfigScreenState();
}

class _CupertinoSystemConfigScreenState extends State<CupertinoSystemConfigScreen> {
  final _apiService = ApiService();
  double _highTemperatureC = 35;
  double _lowWaterLevelPercent = 20;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await _apiService.getAdminAlertDefaults();
      if (mounted) {
        setState(() {
          _highTemperatureC = (settings['highTemperatureC'] as num).toDouble();
          _lowWaterLevelPercent = (settings['lowWaterLevelPercent'] as num).toDouble();
          _loading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final settings = await _apiService.updateAdminAlertDefaults(_highTemperatureC, _lowWaterLevelPercent);
      if (mounted) {
        setState(() {
          _highTemperatureC = (settings['highTemperatureC'] as num).toDouble();
          _lowWaterLevelPercent = (settings['lowWaterLevelPercent'] as num).toDouble();
          _saving = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('Cấu hình'),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _saving ? null : _save,
            child: _saving ? const CupertinoActivityIndicator() : const Text('Lưu'),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          sliver: SliverList(delegate: SliverChildListDelegate([
            if (_loading)
              const Center(child: CupertinoActivityIndicator())
            else if (_error != null)
              CupertinoButton(onPressed: _load, child: Text(_error!))
            else ...[
              _slider(
                context,
                'Nhiệt độ cảnh báo mặc định',
                _highTemperatureC,
                20,
                50,
                '°C',
                (value) => setState(() => _highTemperatureC = value),
              ),
              const SizedBox(height: 12),
              _slider(
                context,
                'Mực nước cảnh báo mặc định',
                _lowWaterLevelPercent,
                0,
                100,
                '%',
                (value) => setState(() => _lowWaterLevelPercent = value),
              ),
              const SizedBox(height: 20),
              _notice(context, 'Thiết bị có ngưỡng riêng sẽ không bị thay đổi.'),
              const SizedBox(height: 10),
              _notice(context, 'Email, push, SMS và maintenance chưa được hỗ trợ.'),
            ],
          ])),
        ),
      ],
    );
  }

  Widget _slider(BuildContext context, String label, double value, double min, double max, String unit, ValueChanged<double> onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$label: ${value.toStringAsFixed(0)}$unit'),
        CupertinoSlider(value: value, min: min, max: max, activeColor: AerogreenCupertinoTheme.aerogreenPrimary, onChanged: onChanged),
      ]),
    );
  }

  Widget _notice(BuildContext context, String text) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: CupertinoColors.systemGrey5.resolveFrom(context),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text),
  );
}
