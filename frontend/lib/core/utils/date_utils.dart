/**
 * Date Utility Functions
 * 
 * Single Responsibility: Date/Time helper functions
 */

class DateTimeUtils {
  /// Parse timestamp from various formats
  static DateTime parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    
    if (timestamp is DateTime) {
      return timestamp;
    }
    
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return DateTime.now();
      }
    }
    
    // Handle Firestore Timestamp format
    if (timestamp is Map) {
      if (timestamp.containsKey('_seconds')) {
        final seconds = timestamp['_seconds'] as int;
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
      if (timestamp.containsKey('seconds')) {
        final seconds = timestamp['seconds'] as int;
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }
    
    return DateTime.now();
  }

  /// Format date for display (e.g., "15 Jan")
  static String formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  /// Format time for display (e.g., "14:00")
  static String formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Format date and time (e.g., "15/1 14:00")
  static String formatDateTime(DateTime date) {
    return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Get next N days starting from today
  static List<DateTime> getNextDays(int count) {
    final today = DateTime.now();
    return List.generate(count, (index) {
      return DateTime(today.year, today.month, today.day + index);
    });
  }

  /// Check if date is in the past
  static bool isPast(DateTime date) {
    return date.isBefore(DateTime.now());
  }

  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }

  /// Get hour from DateTime
  static int getHour(DateTime date) {
    return date.hour;
  }

  /// Create DateTime for a specific day and hour
  static DateTime createDateTime(DateTime day, int hour) {
    return DateTime(day.year, day.month, day.day, hour);
  }
}

