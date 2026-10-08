import '../services/language_service.dart';

class DateFormatter {
  static DateTime parseApiDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    try {
      if (dateValue is String) {
        var dateStr = dateValue.replaceAll(' ', 'T');
        if (!dateStr.contains('Z') && !dateStr.contains('+')) {
          dateStr += 'Z';
        }
        return DateTime.parse(dateStr).toLocal();
      }
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    final lang = LanguageService.instance;
    String short(String key, int count) =>
        lang.translate(key).replaceAll('{count}', '$count');

    if (difference.inMinutes < 1) {
      return lang.translate('just_now');
    } else if (difference.inHours < 1) {
      return short('time_minutes_short', difference.inMinutes);
    } else if (difference.inDays < 1) {
      return short('time_hours_short', difference.inHours);
    } else if (difference.inDays < 7) {
      return short('time_days_short', difference.inDays);
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
