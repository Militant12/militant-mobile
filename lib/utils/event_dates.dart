import '../services/language_service.dart';

/// Dates des événements, telles que l'API les envoie
/// (« 2026-11-06 19:00:00 », heure locale de l'événement).
abstract final class EventDates {
  static const _days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];
  static const _months = [
    'january',
    'february',
    'march',
    'april',
    'may',
    'june',
    'july',
    'august',
    'september',
    'october',
    'november',
    'december',
  ];

  static DateTime? parse(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString().replaceAll(' ', 'T'));
  }

  /// « Jeudi 6 novembre ».
  static String day(DateTime date) {
    final lang = LanguageService.instance;
    return '${lang.translate(_days[date.weekday - 1])} ${date.day} '
        '${lang.translate(_months[date.month - 1])}';
  }

  /// « NOV ».
  static String monthShort(DateTime date) {
    const keys = [
      'month_jan',
      'month_feb',
      'month_mar',
      'month_apr',
      'month_may',
      'month_jun',
      'month_jul',
      'month_aug',
      'month_sep',
      'month_oct',
      'month_nov',
      'month_dec',
    ];
    return LanguageService.instance.translate(keys[date.month - 1]);
  }

  /// « 19:00 ».
  static String time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';

  /// Même jour calendaire, pour regrouper l'agenda par jour.
  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
