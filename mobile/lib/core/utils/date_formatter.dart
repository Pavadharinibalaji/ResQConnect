class DateFormatter {
  DateFormatter._();

  static String formatUptime(double seconds) {
    if (seconds < 60) {
      return '${seconds.toStringAsFixed(1)}s';
    }
    final int minutes = (seconds / 60).floor();
    final double remainingSeconds = seconds % 60;
    if (minutes < 60) {
      return '${minutes}m ${remainingSeconds.toStringAsFixed(0)}s';
    }
    final int hours = (minutes / 60).floor();
    final int remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }

  static String formatIsoString(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }
}
