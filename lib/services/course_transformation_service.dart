import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CourseTransformationService {
  CourseTransformationService._();

  static final CourseTransformationService instance =
      CourseTransformationService._();

  static const _prefix = 'course_transformation_v1:';

  String _key(String courseId) => '$_prefix$courseId';

  Future<Map<String, dynamic>> get(String courseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(courseId));
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {};
    } catch (e) {
      if (kDebugMode) print('❌ CourseTransformationService.get: $e');
      return {};
    }
  }

  Future<void> set(String courseId, Map<String, dynamic> value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(courseId), jsonEncode(value));
    } catch (e) {
      if (kDebugMode) print('❌ CourseTransformationService.set: $e');
    }
  }
}

