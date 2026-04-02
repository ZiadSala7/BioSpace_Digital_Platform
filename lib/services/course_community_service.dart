import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CourseCommunityService {
  CourseCommunityService._();

  static final CourseCommunityService instance = CourseCommunityService._();

  static const _prefix = 'course_community_v1:';

  String _key(String courseId) => '$_prefix$courseId';

  Future<List<Map<String, dynamic>>> listMessages(String courseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(courseId));
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ CourseCommunityService.listMessages: $e');
      return [];
    }
  }

  Future<void> _saveMessages(String courseId, List<Map<String, dynamic>> msgs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(courseId), jsonEncode(msgs));
    } catch (e) {
      if (kDebugMode) print('❌ CourseCommunityService._saveMessages: $e');
    }
  }

  Future<void> addMessage(
    String courseId, {
    required String text,
    required String senderName,
    required String senderRole, // 'student' | 'instructor'
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final msgs = await listMessages(courseId);
    final msg = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'text': trimmed,
      'sender_name': senderName,
      'sender_role': senderRole,
      'created_at': DateTime.now().toIso8601String(),
    };
    final updated = [...msgs, msg];
    await _saveMessages(courseId, updated);
  }
}

