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

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}min';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}j';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
