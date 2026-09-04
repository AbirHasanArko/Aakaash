import 'package:intl/intl.dart';

class DateFmt {
  DateFmt._();

  static String dayLabel(DateTime utc) =>
      DateFormat('EEE, d MMM').format(utc.toLocal());

  static String shortDay(DateTime utc) =>
      DateFormat('EEE').format(utc.toLocal());

  static String time(DateTime utc) =>
      DateFormat.jm().format(utc.toLocal());

  static String full(DateTime utc) =>
      DateFormat('EEEE, d MMM y').format(utc.toLocal());

  static String dateOnly(DateTime utc) =>
      DateFormat('d MMM').format(utc.toLocal());

  static String greetingForHour(int hour) {
    if (hour < 5) return 'Good night';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }
}
