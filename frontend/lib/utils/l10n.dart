import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../providers/app_settings_provider.dart';

class AppL10n {
  static const Map<String, Map<String, String>> _localizedValues = {
    'vi': {
      // General
      'app_name': 'Aerogreen',
      'save': 'Lưu',
      'cancel': 'Hủy',
      'confirm': 'Xác nhận',
      'ok': 'OK',
      'close': 'Đóng',
      'retry': 'Thử lại',
      'error': 'Đã có lỗi xảy ra',
      'offline_banner': 'Bạn đang offline. Hiển thị dữ liệu gần nhất.',

      // Home & Dashboard
      'greeting': 'Xin chào',
      'welcome_aerogreen': 'Chào mừng đến Aerogreen',
      'add_device': 'Thêm thiết bị',
      'farm_healthy': 'Tất cả tháp đều hoạt động tối ưu',
      'farm_attention': 'Cần chú ý',
      'farm_critical': 'Cảnh báo nghiêm trọng',
      'online_devices': 'Thiết bị trực tuyến',
      'average_temp': 'Nhiệt độ TB',
      'average_humidity': 'Độ ẩm TB',

      // Device Detail & Pumps
      'device_detail': 'Chi tiết thiết bị',
      'sensors': 'Cảm biến',
      'pump_control': 'Điều khiển bơm',
      'auto_mode': 'Tự động',
      'manual_mode': 'Thủ công',
      'pump_running': 'Bơm đang chạy',
      'pump_stopped': 'Bơm đang tắt',
      'sending_command': 'Đang gửi lệnh…',
      'stop_pump': 'Dừng',
      'start_pump': 'BẬT BƠM',
      'next_spray_in': 'Lần phun tiếp theo sau',
      'no_schedule_active': 'Không có lịch phun được kích hoạt',
      'schedule_continues_offline': 'Lịch tự động vẫn tiếp tục chạy khi thiết bị ngoại tuyến.',
      'not_available_offline': 'Không khả dụng khi ngoại tuyến',

      // Account & Profile
      'account': 'Tài khoản',
      'personal_profile': 'Hồ sơ cá nhân',
      'change_password': 'Đổi mật khẩu',
      'notification_prefs': 'Tùy chọn thông báo',
      'customer_support': 'Hỗ trợ khách hàng',
      'language': 'Ngôn ngữ',
      'temperature_units': 'Đơn vị nhiệt độ',
      'theme': 'Giao diện',
      'about_version': 'Phiên bản & Giới thiệu',
      'logout': 'Đăng xuất',
      'logout_confirm': 'Bạn có chắc muốn đăng xuất khỏi tài khoản này?',

      // Support
      'support_tickets': 'Hỗ trợ kỹ thuật',
      'create_ticket': 'Tạo yêu cầu hỗ trợ',
      'all': 'Tất cả',
      'open': 'Đang mở',
      'in_progress': 'Đang xử lý',
      'resolved': 'Đã giải quyết',
      'no_tickets': 'Chưa có yêu cầu hỗ trợ nào',
      'send_reply': 'Gửi phản hồi',
    },
    'en': {
      // General
      'app_name': 'Aerogreen',
      'save': 'Save',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'ok': 'OK',
      'close': 'Close',
      'retry': 'Retry',
      'error': 'An error occurred',
      'offline_banner': 'You are offline. Showing latest cached data.',

      // Home & Dashboard
      'greeting': 'Welcome',
      'welcome_aerogreen': 'Welcome to Aerogreen',
      'add_device': 'Add Device',
      'farm_healthy': 'All towers are operating optimally',
      'farm_attention': 'Needs Attention',
      'farm_critical': 'Critical Alert',
      'online_devices': 'Online Devices',
      'average_temp': 'Avg Temp',
      'average_humidity': 'Avg Humidity',

      // Device Detail & Pumps
      'device_detail': 'Device Detail',
      'sensors': 'Sensors',
      'pump_control': 'Pump Control',
      'auto_mode': 'Auto',
      'manual_mode': 'Manual',
      'pump_running': 'Pump running',
      'pump_stopped': 'Pump stopped',
      'sending_command': 'Sending command…',
      'stop_pump': 'Stop',
      'start_pump': 'START PUMP',
      'next_spray_in': 'Next misting in',
      'no_schedule_active': 'No active misting schedule',
      'schedule_continues_offline': 'Saved schedules continue automatically while offline.',
      'not_available_offline': 'Unavailable while offline',

      // Account & Profile
      'account': 'Account',
      'personal_profile': 'Personal Profile',
      'change_password': 'Change Password',
      'notification_prefs': 'Notification Preferences',
      'customer_support': 'Customer Support',
      'language': 'Language',
      'temperature_units': 'Temperature Units',
      'theme': 'Theme',
      'about_version': 'About & Version',
      'logout': 'Log Out',
      'logout_confirm': 'Are you sure you want to log out?',

      // Support
      'support_tickets': 'Support Tickets',
      'create_ticket': 'Create Support Ticket',
      'all': 'All',
      'open': 'Open',
      'in_progress': 'In Progress',
      'resolved': 'Resolved',
      'no_tickets': 'No support tickets yet',
      'send_reply': 'Send reply',
    },
  };

  static String tr(BuildContext context, String key) {
    try {
      final settings = Provider.of<AppSettingsProvider>(context, listen: true);
      final lang = settings.locale.languageCode;
      return _localizedValues[lang]?[key] ?? _localizedValues['vi']?[key] ?? key;
    } catch (_) {
      return _localizedValues['vi']?[key] ?? key;
    }
  }

  static String get(String lang, String key) {
    return _localizedValues[lang]?[key] ?? _localizedValues['vi']?[key] ?? key;
  }
}

extension AppL10nExtension on BuildContext {
  String tr(String key) => AppL10n.tr(this, key);
}
