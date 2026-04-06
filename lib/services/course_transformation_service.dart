import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Per-user, per-course transformation (before/after, sliders, score).
/// Syncs with `GET` / `PUT` / `POST` …/courses/:id/transformation — see
/// `docs/course-transformation-backend-spec.md`.
/// Always caches in [SharedPreferences] so the UI works offline.
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
    if (response['success'] == false) return null;
    final data = response['data'];
    if (data == null) return null;
    if (data is! Map) return null;
    final m = Map<String, dynamic>.from(data);
    final nested = m['transformation'];
    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }
    return m;
  }

  /// Normalizes score alias from API (`transformation_score`).
  Map<String, dynamic> _normalizeForUi(Map<String, dynamic> raw) {
    final out = Map<String, dynamic>.from(raw);
    if (!out.containsKey('score') || out['score'] == null) {
      final alt = out['transformation_score'];
      if (alt != null) out['score'] = alt;
    }
    return out;
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
        final normalized = _normalizeForUi(remote);
        await _writeLocal(courseId, normalized);
        return normalized;
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
    final normalizedValue = _normalizeForUi(value);
    await _writeLocal(courseId, normalizedValue);
    if (courseId.isEmpty) return false;

    try {
      final res = await ApiClient.instance.put(
        ApiEndpoints.courseTransformation(courseId),
        body: normalizedValue,
        requireAuth: true,
      );
      if (res['success'] == false) return false;
      final remote = _unwrapData(res);
      if (remote != null && remote.isNotEmpty) {
        await _writeLocal(courseId, _normalizeForUi(remote));
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('CourseTransformationService.set PUT failed, trying POST ($e)');
      }
      try {
        final res = await ApiClient.instance.post(
          ApiEndpoints.courseTransformation(courseId),
          body: normalizedValue,
          requireAuth: true,
        );
        if (res['success'] == false) return false;
        final remote = _unwrapData(res);
        if (remote != null && remote.isNotEmpty) {
          await _writeLocal(courseId, _normalizeForUi(remote));
        }
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
