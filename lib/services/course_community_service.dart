import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Course wave community messages — synced with the API when available;
/// falls back to [SharedPreferences] (legacy / offline) using [localThreadId].
class CourseCommunityService {
  CourseCommunityService._();

  static final CourseCommunityService instance = CourseCommunityService._();

  static const _prefix = 'course_community_v2:';

  String _localKey(String threadId) => '$_prefix$threadId';

  Future<List<Map<String, dynamic>>> _readLocal(String threadId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey(threadId));
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
      if (kDebugMode) print('❌ CourseCommunityService._readLocal: $e');
      return [];
    }
  }

  Future<void> _writeLocal(
      String threadId, List<Map<String, dynamic>> msgs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localKey(threadId), jsonEncode(msgs));
    } catch (e) {
      if (kDebugMode) print('❌ CourseCommunityService._writeLocal: $e');
    }
  }

  List<Map<String, dynamic>> _parseMessagesFromResponse(
      Map<String, dynamic> response) {
    final data = response['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => _normalizeMessage(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    }
    if (data is Map) {
      final inner = data['messages'] ?? data['items'] ?? data['results'];
      if (inner is List) {
        return inner
            .whereType<Map>()
            .map((e) => _normalizeMessage(Map<String, dynamic>.from(e)))
            .toList(growable: false);
      }
    }
    return [];
  }

  Map<String, dynamic> _normalizeMessage(Map<String, dynamic> raw) {
    final user = raw['user'];
    String? nestedName;
    if (user is Map) {
      final u = Map<String, dynamic>.from(user);
      nestedName = u['name']?.toString() ??
          u['full_name']?.toString() ??
          u['fullName']?.toString() ??
          u['display_name']?.toString() ??
          u['displayName']?.toString() ??
          u['username']?.toString();
    }
    return <String, dynamic>{
      'id': raw['id']?.toString(),
      'text': raw['text']?.toString() ?? raw['body']?.toString() ?? '',
      'sender_name': raw['sender_name']?.toString() ??
          raw['senderName']?.toString() ??
          raw['name']?.toString() ??
          raw['full_name']?.toString() ??
          raw['fullName']?.toString() ??
          nestedName ??
          '',
      'sender_role': raw['sender_role']?.toString() ??
          raw['senderRole']?.toString() ??
          'student',
      'created_at': raw['created_at']?.toString() ?? raw['createdAt']?.toString(),
      'user_id': raw['user_id']?.toString() ?? raw['userId']?.toString(),
    };
  }

  /// Load messages for [courseId], optionally scoped by [waveId].
  /// [localThreadId] keys offline/legacy cache (e.g. [CourseWaveInfo.communityThreadId]).
  Future<List<Map<String, dynamic>>> listMessages(
    String courseId, {
    String? waveId,
    required String localThreadId,
  }) async {
    if (courseId.isEmpty) {
      return _readLocal(localThreadId);
    }

    try {
      final res = await ApiClient.instance.get(
        ApiEndpoints.courseCommunityMessages(courseId, waveId: waveId),
        requireAuth: true,
        logTag: 'CourseCommunity',
      );
      if (res['success'] == false) {
        throw ApiException(res['message']?.toString() ?? 'Request failed');
      }
      final list = _parseMessagesFromResponse(res);
      await _writeLocal(localThreadId, list);
      return list;
    } catch (e) {
      if (kDebugMode) {
        print(
            'CourseCommunityService.listMessages: API failed, using local ($e)');
      }
      return _readLocal(localThreadId);
    }
  }

  /// Post a message. Server should set author and role from the auth token.
  /// [localThreadId] is used for offline cache if the API fails.
  /// Returns `true` if the server accepted the message.
  Future<bool> addMessage(
    String courseId, {
    String? waveId,
    required String localThreadId,
    required String text,
    required String senderName,
    required String senderRole,
    String? senderUserId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    if (courseId.isEmpty) {
      await _addLocalOnly(
        localThreadId,
        trimmed: trimmed,
        senderName: senderName,
        senderRole: senderRole,
        senderUserId: senderUserId,
      );
      return false;
    }

    final body = <String, dynamic>{'text': trimmed};
    if (waveId != null && waveId.isNotEmpty) {
      body['wave_id'] = waveId;
    }

    try {
      final res = await ApiClient.instance.post(
        ApiEndpoints.courseCommunityMessages(courseId, waveId: waveId),
        body: body,
        requireAuth: true,
        logTag: 'CourseCommunity',
      );
      if (res['success'] == false) {
        throw ApiException(res['message']?.toString() ?? 'Request failed');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print(
            'CourseCommunityService.addMessage: API failed, appending local ($e)');
      }
    }

    await _addLocalOnly(
      localThreadId,
      trimmed: trimmed,
      senderName: senderName,
      senderRole: senderRole,
      senderUserId: senderUserId,
    );
    return false;
  }

  Future<void> _addLocalOnly(
    String localThreadId, {
    required String trimmed,
    required String senderName,
    required String senderRole,
    String? senderUserId,
  }) async {
    final msgs = await _readLocal(localThreadId);
    final msg = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'text': trimmed,
      'sender_name': senderName,
      'sender_role': senderRole,
      'created_at': DateTime.now().toIso8601String(),
      if (senderUserId != null && senderUserId.isNotEmpty)
        'user_id': senderUserId,
    };
    await _writeLocal(localThreadId, [...msgs, msg]);
  }
}
