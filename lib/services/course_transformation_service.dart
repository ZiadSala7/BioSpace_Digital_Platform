import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Per-course transformation (before/after, sliders, score).
/// Syncs with `GET/PUT …/courses/:id/transformation` when the API exists;
/// always caches in [SharedPreferences] so the UI works offline.
class CourseTransformationService {
  CourseTransformationService._();

  static final CourseTransformationService instance =
      CourseTransformationService._();

  static const _prefix = 'course_transformation_v1:';

  String _key(String courseId) => '$_prefix$courseId';

  Future<Map<String, dynamic>> _readLocal(String courseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(courseId));
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {};
    } catch (e) {
      if (kDebugMode) print('❌ CourseTransformationService._readLocal: $e');
      return {};
    }
  }

  Future<void> _writeLocal(
      String courseId, Map<String, dynamic> value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(courseId), jsonEncode(value));
    } catch (e) {
      if (kDebugMode) print('❌ CourseTransformationService._writeLocal: $e');
    }
  }

  Map<String, dynamic>? _unwrapData(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  /// Load transformation: prefers server, falls back to local cache.
  Future<Map<String, dynamic>> get(String courseId) async {
    final local = await _readLocal(courseId);
    if (courseId.isEmpty) return local;

    try {
      final res = await ApiClient.instance.get(
        ApiEndpoints.courseTransformation(courseId),
        requireAuth: true,
      );
      final remote = _unwrapData(res);
      if (remote != null && remote.isNotEmpty) {
        await _writeLocal(courseId, remote);
        return remote;
      }
    } catch (e) {
      if (kDebugMode) {
        print('CourseTransformationService.get: API unavailable, using cache ($e)');
      }
    }
    return local;
  }

  /// Save locally, then sync to server. Returns `true` if the server accepted
  /// the write (or returned success); `false` if only local was saved.
  Future<bool> set(String courseId, Map<String, dynamic> value) async {
    await _writeLocal(courseId, value);
    if (courseId.isEmpty) return false;

    try {
      final res = await ApiClient.instance.put(
        ApiEndpoints.courseTransformation(courseId),
        body: value,
        requireAuth: true,
      );
      if (res['success'] == false) return false;
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('CourseTransformationService.set PUT failed, trying POST ($e)');
      }
      try {
        final res = await ApiClient.instance.post(
          ApiEndpoints.courseTransformation(courseId),
          body: value,
          requireAuth: true,
        );
        if (res['success'] == false) return false;
        return true;
      } catch (e2) {
        if (kDebugMode) {
          print('CourseTransformationService.set: saved locally only ($e2)');
        }
        return false;
      }
    }
  }
}
