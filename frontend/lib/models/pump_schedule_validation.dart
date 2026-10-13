/// Shared validation used by the production Cupertino schedule form.
class PumpScheduleValidation {
  static String? mistLength(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập thời gian phun';
    final length = int.tryParse(value);
    return length == null || length < 1 || length > 120
        ? 'Thời gian phun từ 1-120 giây'
        : null;
  }

  static String? interval(String? value, String mistValue) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập khoảng cách';
    final interval = int.tryParse(value);
    if (interval == null || interval < 1 || interval > 60) {
      return 'Khoảng cách từ 1-60 phút';
    }
    final mist = int.tryParse(mistValue);
    return mist != null && mist >= interval * 60
        ? 'Thời gian phun phải nhỏ hơn khoảng cách'
        : null;
  }

  static String? timeWindow(DateTime start, DateTime end) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    // Preserve the current form behavior; overnight support needs a product decision.
    return endMinutes <= startMinutes && endMinutes < startMinutes + 60
        ? 'Giờ kết thúc phải sau giờ bắt đầu (trừ khi qua đêm)'
        : null;
  }
}
