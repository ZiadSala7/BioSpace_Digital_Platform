import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CourseCommunityService {
  CourseCommunityService._();

  static final CourseCommunityService instance = CourseCommunityService._();

  static const _prefix = 'course_community_v2:';

  String _key(String threadId) => '$_prefix$threadId';

  /// Per-wave thread id (compute with `CourseWaveInfo.communityThreadId` from the course map).
  Future<List<Map<String, dynamic>>> listMessages(String threadId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(threadId));
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

  Future<void> _saveMessages(String threadId, List<Map<String, dynamic>> msgs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(threadId), jsonEncode(msgs));
    } catch (e) {
      if (kDebugMode) print('❌ CourseCommunityService._saveMessages: $e');
    }
  }

  Future<void> addMessage(
    String threadId, {
    required String text,
    required String senderName,
    required String senderRole, // 'student' | 'instructor'
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final msgs = await listMessages(threadId);
    final msg = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'text': trimmed,
      'sender_name': senderName,
      'sender_role': senderRole,
      'created_at': DateTime.now().toIso8601String(),
    };
    final updated = [...msgs, msg];
    await _saveMessages(threadId, updated);
  }
}

