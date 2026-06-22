/// Shared date utility helpers for the LiFe App.
class AppDateUtils {
  AppDateUtils._();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Formats an ISO date string (e.g. `"2025-06-22"`) to a human-readable
  /// form like `"Jun 22, 2025"`. Returns [rawDate] unchanged on parse failure.
  static String formatDate(String rawDate) {
    try {
      final parsed = DateTime.parse(rawDate);
      return '${_months[parsed.month - 1]} ${parsed.day.toString().padLeft(2, '0')}, ${parsed.year}';
    } catch (_) {
      return rawDate;
    }
  }
}
