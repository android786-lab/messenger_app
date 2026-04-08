import 'package:intl/intl.dart';

class TimeFormatter {
  // Format timestamp for chat list (e.g., "2:30 PM" or "Yesterday")
  static String formatChatListTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('h:mm a').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(dateTime);
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  // Format timestamp for message bubble (e.g., "2:30 PM")
  static String formatMessageTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  // Format timestamp with date (e.g., "Dec 25, 2:30 PM")
  static String formatFullTime(DateTime dateTime) {
    return DateFormat('MMM d, h:mm a').format(dateTime);
  }
}
