import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import 'courses_service.dart';

/// Service for fetching progress data
class ProgressService {
  ProgressService._();

  static final ProgressService instance = ProgressService._();

  num _numFrom(dynamic value, [num fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value;
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) return parsed;
      final firstNumeric = RegExp(r'-?\d+(\.\d+)?').firstMatch(value);
      if (firstNumeric != null) {
        return num.tryParse(firstNumeric.group(0) ?? '') ?? fallback;
      }
    }
    return fallback;
  }

  DateTime? _dateFrom(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  List<Map<String, dynamic>> _extractEnrollments(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map<String, dynamic>) {
      final courses = data['courses'];
      if (courses is List) {
        return courses
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return [];
  }

  bool _isInSelectedPeriod(Map<String, dynamic> enrollment, String period) {
    if (period == 'all') return true;
    final now = DateTime.now();
    final date = _dateFrom(enrollment['last_accessed_at']) ??
        _dateFrom(enrollment['updated_at']) ??
        _dateFrom(enrollment['enrolled_at']);
    if (date == null) return true;
    final days = now.difference(date).inDays;
    if (period == 'weekly') return days <= 7;
    if (period == 'monthly') return days <= 30;
    return true;
  }

  Map<String, dynamic> _buildCourseBasedProgress({
    required List<Map<String, dynamic>> enrollments,
    required String period,
    Map<String, dynamic>? baseData,
  }) {
    final relevant = enrollments.where((e) => _isInSelectedPeriod(e, period));

    final withCourse = relevant.where((e) => e['course'] is Map).map((e) {
      final course = Map<String, dynamic>.from(e['course'] as Map);
      return {'enrollment': e, 'course': course};
    }).toList();

    int completedLessons = 0;
    int totalLessons = 0;
    double weightedHours = 0;
    int completedCourses = 0;
    double progressSum = 0;

    for (final item in withCourse) {
      final enrollment = item['enrollment'] as Map<String, dynamic>;
      final course = item['course'] as Map<String, dynamic>;

      final progress = _numFrom(enrollment['progress']).toDouble().clamp(0, 100);
      final courseTotalLessons = _numFrom(
        enrollment['total_lessons'] ?? course['lessons_count'],
      ).toInt();
      final courseCompletedLessons = _numFrom(
        enrollment['completed_lessons'],
      ).toInt();

      final durationHours = _numFrom(course['duration_hours']).toDouble();
      weightedHours += durationHours * (progress / 100.0);

      completedLessons += courseCompletedLessons;
      totalLessons += courseTotalLessons;
      if (progress >= 100) completedCourses++;
      progressSum += progress;
    }

    final totalCourses = withCourse.length;
    final avgProgress =
        totalCourses > 0 ? (progressSum / totalCourses).round() : 0;

    final sorted = [...withCourse]
      ..sort((a, b) {
        final pb =
            _numFrom((b['enrollment'] as Map<String, dynamic>)['progress']);
        final pa =
            _numFrom((a['enrollment'] as Map<String, dynamic>)['progress']);
        return pb.compareTo(pa);
      });

    final chartItems = sorted.take(7).map((item) {
      final enrollment = item['enrollment'] as Map<String, dynamic>;
      final course = item['course'] as Map<String, dynamic>;
      final title = course['title']?.toString() ?? 'Course';
      final label = title.length > 8 ? '${title.substring(0, 8)}…' : title;
      final value = _numFrom(enrollment['progress']).toInt().clamp(0, 100);
      return <String, dynamic>{
        'day': label,
        'value': value,
        'stripes': value < 40,
      };
    }).toList();

    final merged = <String, dynamic>{
      ...(baseData ?? {}),
      'statistics': {
        ...((baseData?['statistics'] as Map?)?.cast<String, dynamic>() ?? {}),
        'completed_lessons': completedLessons,
        'total_lessons': totalLessons,
        'total_hours': weightedHours.round(),
        'completed_courses': completedCourses,
        'active_courses': totalCourses,
      },
      'chart_data': {
        ...((baseData?['chart_data'] as Map?)?.cast<String, dynamic>() ?? {}),
        period: chartItems,
      },
      'enrollments': withCourse
          .map((e) => e['enrollment'] as Map<String, dynamic>)
          .toList(),
    };

    if (merged['user'] is Map<String, dynamic>) {
      final user = Map<String, dynamic>.from(merged['user'] as Map);
      user['overall_progress'] = avgProgress;
      merged['user'] = user;
    } else {
      merged['user'] = {'overall_progress': avgProgress};
    }

    return merged;
  }

  /// Fetch progress data for a specific period (weekly or monthly)
  Future<Map<String, dynamic>> getProgressData(String period) async {
    try {
      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📤 PROGRESS API REQUEST');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('Method: GET');
        print('URL: ${ApiEndpoints.progress(period)}');
        print('Period: $period');
        print('Require Auth: true');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      final progressFuture = ApiClient.instance.get(
        ApiEndpoints.progress(period),
        requireAuth: true,
      );
      final enrollmentsFuture = CoursesService.instance.getEnrollments(
        status: 'all',
        page: 1,
        perPage: 100,
      );

      Map<String, dynamic>? response;
      try {
        response = await progressFuture;
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Progress endpoint failed, fallback to enrollments: $e');
        }
      }
      final enrollmentsResponse = await enrollmentsFuture;
      final enrollments = _extractEnrollments(enrollmentsResponse);

      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📥 PROGRESS API RESPONSE');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('URL: ${ApiEndpoints.progress(period)}');
        try {
          final prettyJson =
              const JsonEncoder.withIndent('  ').convert(response);
          print('Response Body:');
          print(prettyJson);
        } catch (e) {
          print('Response: $response');
        }
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      if (response != null && response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final processedData = _buildCourseBasedProgress(
          enrollments: enrollments,
          period: period,
          baseData: Map<String, dynamic>.from(data),
        );

        // Process user avatar if exists
        if (processedData['user'] != null) {
          final user = processedData['user'] as Map<String, dynamic>?;
          if (user != null && user['avatar'] != null) {
            user['avatar'] = ApiEndpoints.getImageUrl(
              user['avatar']?.toString(),
            );
          }
        }

        // Process top students avatars if exists
        if (processedData['top_students'] != null) {
          final topStudents = processedData['top_students'] as List?;
          if (topStudents != null) {
            for (var student in topStudents) {
              if (student is Map<String, dynamic> &&
                  student['avatar'] != null) {
                student['avatar'] = ApiEndpoints.getImageUrl(
                  student['avatar']?.toString(),
                );
              }
            }
          }
        }

        if (kDebugMode) {
          print('✅ Progress data processed - Image URLs updated');
        }

        return processedData;
      } else {
        // Fallback mode: build progress completely from enrolled courses.
        final fallbackData = _buildCourseBasedProgress(
          enrollments: enrollments,
          period: period,
        );
        if (kDebugMode) {
          print('✅ Progress fallback generated from enrollments');
          print('  Enrollments used: ${enrollments.length}');
        }
        return fallbackData;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Progress API Error: $e');
      }
      rethrow;
    }
  }
}

