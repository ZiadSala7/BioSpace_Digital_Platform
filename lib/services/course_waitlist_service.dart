import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Join / leave course waitlist when the current wave is full or closed.
/// See `docs/waitlist-backend-spec.md`.
class CourseWaitlistService {
  CourseWaitlistService._();

  static final CourseWaitlistService instance = CourseWaitlistService._();

  Map<String, dynamic> _unwrapData(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  void _ensureSuccess(Map<String, dynamic> response) {
    if (response['success'] == false) {
      throw Exception(
        response['message']?.toString() ?? 'Waitlist request failed',
      );
    }
  }

  /// Join waitlist. Returns fields to merge onto the course map (flags, position).
  Future<Map<String, dynamic>> join(
    String courseId, {
    String? waveId,
  }) async {
    final body = <String, dynamic>{};
    if (waveId != null && waveId.isNotEmpty) {
      body['wave_id'] = waveId;
    }
    try {
      final res = await ApiClient.instance.post(
        ApiEndpoints.courseWaitlist(courseId),
        body: body.isEmpty ? null : body,
        requireAuth: true,
      );
      _ensureSuccess(res);
      final patch = _unwrapData(res);
      if (patch.isEmpty) {
        return {
          'user_on_waitlist': true,
          'on_waitlist': true,
        };
      }
      return patch;
    } on ApiException catch (e) {
      if (kDebugMode) {
        print('CourseWaitlistService.join: $e');
      }
      rethrow;
    }
  }

  /// Leave waitlist. Returns fields to merge onto the course map.
  Future<Map<String, dynamic>> leave(
    String courseId, {
    String? waveId,
  }) async {
    try {
      final res = await ApiClient.instance.delete(
        ApiEndpoints.courseWaitlist(courseId, waveId: waveId),
        requireAuth: true,
      );
      _ensureSuccess(res);
      final patch = _unwrapData(res);
      if (patch.isEmpty) {
        return {
          'user_on_waitlist': false,
          'on_waitlist': false,
          'waitlist_position': null,
          'waitlist_rank': null,
          'enrollment_priority_rank': null,
        };
      }
      return patch;
    } on ApiException catch (e) {
      if (kDebugMode) {
        print('CourseWaitlistService.leave: $e');
      }
      rethrow;
    }
  }
}
