import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'course_wave_info.dart';

/// Locale-aware formatting for wave start/end dates (list + detail screens).
abstract final class CourseWaveScheduleFormat {
  static String _dash(BuildContext context) {
    return '—';
  }

  /// One date, medium style (e.g. Apr 5, 2026 / localized Arabic).
  static String single(BuildContext context, DateTime? d) {
    if (d == null) return _dash(context);
    final loc = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMd(loc).format(d.toLocal());
  }

  /// Compact single line for grid cards (same year drops duplicate year on start).
  static String rangeCompactLine(BuildContext context, CourseWaveInfo wave) {
    final s = wave.startDate;
    final e = wave.endDate;
    final loc = Localizations.localeOf(context).toLanguageTag();
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    if (s == null && e == null) return _dash(context);
    if (s != null && e == null) {
      return isAr
          ? 'يبدأ ${DateFormat.yMMMd(loc).format(s.toLocal())}'
          : 'Starts ${DateFormat.yMMMd(loc).format(s.toLocal())}';
    }
    if (s == null && e != null) {
      return isAr
          ? 'ينتهي ${DateFormat.yMMMd(loc).format(e.toLocal())}'
          : 'Ends ${DateFormat.yMMMd(loc).format(e.toLocal())}';
    }

    final start = s!.toLocal();
    final end = e!.toLocal();
    if (start.year == end.year) {
      final md = DateFormat.MMMd(loc);
      final y = DateFormat.y(loc).format(end);
      return '${md.format(start)} – ${md.format(end)}, $y';
    }
    final full = DateFormat.yMMMd(loc);
    return '${full.format(start)} – ${full.format(end)}';
  }
}
