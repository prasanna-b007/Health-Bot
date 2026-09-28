/// Time formatting and the time-of-day logic behind the home screen greeting.
///
/// Kept in one place because the greeting, the ambient tint and the history
/// timestamps all key off the same reading of "now", and they looked
/// incoherent when each screen decided for itself where evening began.
library;

enum DayPart { morning, afternoon, evening, night }

class Moment {
  const Moment._();

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static DayPart partOfDay(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 12) return DayPart.morning;
    if (h >= 12 && h < 17) return DayPart.afternoon;
    if (h >= 17 && h < 22) return DayPart.evening;
    return DayPart.night;
  }

  /// "Good evening" / "Still up" — the night greeting deliberately
  /// acknowledges the hour rather than pretending it is evening, because
  /// someone opening a triage app at 3am is in a different situation from
  /// someone opening it after dinner.
  static String greetingFor(DateTime now) => switch (partOfDay(now)) {
    DayPart.morning => 'Good morning',
    DayPart.afternoon => 'Good afternoon',
    DayPart.evening => 'Good evening',
    DayPart.night => 'Still up',
  };

  /// A one-line prompt under the greeting, tuned to the hour. Sleep is part of
  /// recovery, so the late-night line says so instead of offering a tip.
  static String noteFor(DateTime now) => switch (partOfDay(now)) {
    DayPart.morning => 'How are you feeling this morning?',
    DayPart.afternoon => 'How are you feeling?',
    DayPart.evening => 'How has today been?',
    DayPart.night => 'Rest matters. What is keeping you up?',
  };

  /// 24-hour clock, zero-padded. Tabular figures in the mono face keep the
  /// colon from shifting as the minute changes.
  static String clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// "1 Sep 2026"
  static String date(DateTime t) =>
      '${t.day} ${_months[t.month - 1]} ${t.year}';

  /// "01.09.26" — the compact stamp used in instrument chrome.
  static String stamp(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${(t.year % 100).toString().padLeft(2, '0')}';

  /// "Today, 22:41" / "Yesterday" / "4 days ago" / "12 Aug".
  ///
  /// Recent entries are described in relative terms because that is how people
  /// recall a symptom ("that was Tuesday"); anything past a week gets a real
  /// date, where relative counting stops being useful.
  static String relative(DateTime t, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final day = DateTime(t.year, t.month, t.day);
    final today = DateTime(ref.year, ref.month, ref.day);
    final diff = today.difference(day).inDays;

    if (diff <= 0) return 'Today, ${clock(t)}';
    if (diff == 1) return 'Yesterday, ${clock(t)}';
    if (diff < 7) return '$diff days ago';
    if (t.year == ref.year) return '${t.day} ${_months[t.month - 1]}';
    return date(t);
  }
}
