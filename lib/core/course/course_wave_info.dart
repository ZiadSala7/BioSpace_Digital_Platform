/// Wave / cohort fields on course API payloads (snake_case or camelCase).
class CourseWaveInfo {
  const CourseWaveInfo({
    required this.startDate,
    required this.endDate,
    required this.bookedSeats,
    required this.availableSeats,
    required this.statusRaw,
    required this.totalCapacity,
    this.userOnWaitlist = false,
    this.waitlistPriorityRank,
    this.waitlistSignupsOpen = true,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final int bookedSeats;
  /// Null when the API did not send a seat count (treat as unknown).
  final int? availableSeats;
  /// Lowercased, trimmed; empty if absent.
  final String statusRaw;
  /// Booked + available when both are known; else legacy capacity when present.
  final int? totalCapacity;

  /// User has an active waitlist spot (next-wave priority). From API flags.
  final bool userOnWaitlist;

  /// 1-based rank for next-wave enrollment (أولوية). Null if unknown.
  final int? waitlistPriorityRank;

  /// If false, app must not offer joining the waitlist.
  final bool waitlistSignupsOpen;

  static CourseWaveInfo fromMap(Map<String, dynamic> course) {
    DateTime? parseD(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    int parseI(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    int? parsePositiveInt(dynamic v) {
      if (v == null) return null;
      final n = parseI(v);
      return n > 0 ? n : null;
    }

    bool truthy(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v.toString().trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }

    final start = parseD(course['start_date'] ?? course['startDate']);
    final end = parseD(course['end_date'] ?? course['endDate']);

    final hasAvailKey = course.containsKey('available_seats') ||
        course.containsKey('availableSeats');
    final available = hasAvailKey
        ? parseI(course['available_seats'] ?? course['availableSeats'])
        : null;

    final booked = parseI(
      course['booked_seats'] ??
          course['bookedSeats'] ??
          course['seats_booked'] ??
          course['enrolled_count'] ??
          course['students_count'] ??
          course['booked'] ??
          course['enrollments_count'],
    );

    final statusSource = course['status'] ?? course['enrollment_status'];
    final statusRaw = statusSource?.toString().trim().toLowerCase() ?? '';

    final legacyTotal = parseI(
      course['total_seats'] ??
          course['seats_total'] ??
          course['capacity'] ??
          course['max_students'] ??
          course['seats'] ??
          course['maxSeats'],
    );

    int? total;
    if (available != null && (booked > 0 || available > 0 || statusRaw.isNotEmpty)) {
      total = (booked + available).clamp(0, 1 << 30);
    } else if (legacyTotal > 0) {
      total = legacyTotal;
    }

    Map<String, dynamic>? waitNested;
    if (course['waitlist'] is Map) {
      waitNested = Map<String, dynamic>.from(course['waitlist'] as Map);
    }

    bool userOnWaitlist = truthy(course['user_on_waitlist']) ||
        truthy(course['on_waitlist']);
    if (!userOnWaitlist && waitNested != null) {
      userOnWaitlist =
          truthy(waitNested['active']) || truthy(waitNested['joined']);
    }

    int? priorityRank = parsePositiveInt(
          course['waitlist_position'] ??
              course['waitlist_rank'] ??
              course['enrollment_priority_rank'] ??
              course['priority_rank'],
        ) ??
        (waitNested != null
            ? parsePositiveInt(
                waitNested['position'] ??
                    waitNested['rank'] ??
                    waitNested['priority_rank'],
              )
            : null);

    final waitlistBlocked = truthy(course['waitlist_disabled']) ||
        truthy(course['waitlist_closed']) ||
        (waitNested != null &&
            (truthy(waitNested['disabled']) || truthy(waitNested['closed'])));

    final waitlistSignupsOpen = !waitlistBlocked;

    return CourseWaveInfo(
      startDate: start,
      endDate: end,
      bookedSeats: booked,
      availableSeats: available,
      statusRaw: statusRaw,
      totalCapacity: total,
      userOnWaitlist: userOnWaitlist,
      waitlistPriorityRank: priorityRank,
      waitlistSignupsOpen: waitlistSignupsOpen,
    );
  }

  /// Backend wave id when present (for waitlist `wave_id` body).
  static String? waveIdFromCourse(Map<String, dynamic> course) {
    for (final k in ['wave_id', 'waveId', 'course_wave_id', 'courseWaveId']) {
      final v = course[k]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  /// Stable id for per-wave local data (e.g. community). Prefer backend `wave_id` when present.
  static String communityThreadId(Map<String, dynamic> course) {
    for (final k in ['wave_id', 'waveId', 'course_wave_id', 'courseWaveId']) {
      final v = course[k]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    final id =
        course['id']?.toString() ?? course['courseId']?.toString() ?? '';
    final sd = course['start_date'] ?? course['startDate'];
    final s = sd?.toString().trim();
    if (s != null && s.isNotEmpty) return '$id|$s';
    return id;
  }

  int get remainingSeats {
    if (availableSeats != null) return availableSeats!.clamp(0, 1 << 30);
    if (totalCapacity != null && totalCapacity! > 0) {
      return (totalCapacity! - bookedSeats).clamp(0, totalCapacity!);
    }
    return 0;
  }

  double get seatProgress {
    if (totalCapacity == null || totalCapacity! <= 0) return 0;
    return (bookedSeats / totalCapacity!).clamp(0.0, 1.0);
  }

  /// Open badge / UI: explicit status wins; otherwise infer from seats.
  bool get displayAsOpen {
    if (statusRaw.isNotEmpty) return statusRaw == 'open';
    if (totalCapacity != null && totalCapacity! > 0) return remainingSeats > 0;
    return true;
  }

  /// New enrollment / cart / checkout allowed for this wave.
  bool get canEnroll {
    if (statusRaw.isNotEmpty && statusRaw != 'open') return false;
    if (availableSeats != null) return availableSeats! > 0;
    if (totalCapacity != null && totalCapacity! > 0) return remainingSeats > 0;
    return true;
  }

  /// Show “join waitlist” when this wave is not enrollable and server allows signups.
  bool get canJoinWaitlist =>
      !canEnroll && waitlistSignupsOpen && !userOnWaitlist;

  bool get hasSeatMetrics => totalCapacity != null && totalCapacity! > 0;

  bool get hasSchedule => startDate != null || endDate != null;
}
