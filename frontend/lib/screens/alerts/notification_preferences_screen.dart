import 'package:flutter/cupertino.dart';

import '../../models/notification_preferences.dart';
import '../../services/notification_preferences_store.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key, this.store});

  final NotificationPreferencesStore? store;

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  late final NotificationPreferencesStore _store;
  NotificationPreferences _preferences = const NotificationPreferences();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? NotificationPreferencesStore();
    _load();
  }

  Future<void> _load() async {
    final value = await _store.load();
    if (mounted) {
      setState(() {
        _preferences = value;
        _loading = false;
      });
    }
  }

  Future<void> _save(NotificationPreferences value) async {
    setState(() => _preferences = value);
    await _store.save(value);
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: const CupertinoNavigationBar(
      middle: Text('Tùy chọn thông báo'),
    ),
    child: SafeArea(
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              children: [
                _section([
                  _toggleRow(
                    'Thông báo',
                    'Bật hoặc tắt toàn bộ thông báo',
                    _preferences.enabled,
                    (value) => _save(_preferences.copyWith(enabled: value)),
                  ),
                ]),
                const SizedBox(height: 18),
                const Text(
                  'MỨC ĐỘ',
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _section([
                  _toggleRow(
                    'Nghiêm trọng',
                    'Lỗi bơm, hết nước, mất kết nối',
                    _preferences.critical,
                    (value) => _save(_preferences.copyWith(critical: value)),
                  ),
                  _divider(),
                  _toggleRow(
                    'Cảnh báo',
                    'Chỉ số cảm biến ngoài ngưỡng',
                    _preferences.warning,
                    (value) => _save(_preferences.copyWith(warning: value)),
                  ),
                  _divider(),
                  _toggleRow(
                    'Thông tin',
                    'Đã lưu lịch, online lại, cập nhật firmware',
                    _preferences.info,
                    (value) => _save(_preferences.copyWith(info: value)),
                  ),
                ]),
                const SizedBox(height: 18),
                _section([
                  _toggleRow(
                    'Giờ yên tĩnh',
                    _quietLabel,
                    _preferences.quietHoursEnabled,
                    (value) =>
                        _save(_preferences.copyWith(quietHoursEnabled: value)),
                  ),
                  if (_preferences.quietHoursEnabled) ...[
                    _divider(),
                    _timeRow(
                      'Bắt đầu',
                      _preferences.quietStartMinutes,
                      (value) => _save(
                        _preferences.copyWith(quietStartMinutes: value),
                      ),
                    ),
                    _divider(),
                    _timeRow(
                      'Kết thúc',
                      _preferences.quietEndMinutes,
                      (value) =>
                          _save(_preferences.copyWith(quietEndMinutes: value)),
                    ),
                  ],
                ]),
                const SizedBox(height: 10),
                const Text(
                  'Cảnh báo nghiêm trọng bỏ qua giờ yên tĩnh.',
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
    ),
  );

  String get _quietLabel =>
      '${_formatMinutes(_preferences.quietStartMinutes)} – ${_formatMinutes(_preferences.quietEndMinutes)}';

  Widget _section(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(children: children),
  );

  Widget _toggleRow(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: CupertinoColors.secondaryLabel,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        CupertinoSwitch(value: value, onChanged: onChanged),
      ],
    ),
  );

  Widget _timeRow(String title, int value, ValueChanged<int> onChanged) =>
      CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        onPressed: () => _pickTime(value, onChanged),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
            Text(_formatMinutes(value)),
            const SizedBox(width: 6),
            const Icon(CupertinoIcons.chevron_right, size: 15),
          ],
        ),
      );

  Future<void> _pickTime(int initial, ValueChanged<int> onChanged) async {
    var date = DateTime(2020, 1, 1, initial ~/ 60, initial % 60);
    final result = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (popupContext) => Container(
        height: 280,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: CupertinoButton(
                  onPressed: () => Navigator.of(popupContext).pop(date),
                  child: const Text('Xong'),
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: date,
                  onDateTimeChanged: (value) => date = value,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null) onChanged(result.hour * 60 + result.minute);
  }

  Widget _divider() => Container(
    height: 0.5,
    margin: const EdgeInsets.only(left: 16),
    color: CupertinoColors.separator.resolveFrom(context),
  );

  String _formatMinutes(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
}
