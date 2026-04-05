import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Cosmic Imprint + Color Emotional Analysis (`docs/wellness-analysis-backend-spec.md`).
class WellnessAnalysisService {
  WellnessAnalysisService._();

  static final WellnessAnalysisService instance = WellnessAnalysisService._();

  Map<String, dynamic>? _unwrap(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  void _ensureOk(Map<String, dynamic> response) {
    if (response['success'] == false) {
      throw Exception(
        response['message']?.toString() ?? 'Request failed',
      );
    }
  }

  /// Latest saved Cosmic Imprint, or empty map if none / not found.
  Future<Map<String, dynamic>> getLatestCosmicImprint() async {
    try {
      final res = await ApiClient.instance.get(
        ApiEndpoints.cosmicImprint,
        requireAuth: true,
      );
      if (res['success'] == false) return {};
      return _unwrap(res) ?? {};
    } catch (e) {
      if (kDebugMode) {
        print('WellnessAnalysisService.getLatestCosmicImprint: $e');
      }
      return {};
    }
  }

  Future<Map<String, dynamic>> createCosmicImprint(
      Map<String, dynamic> body) async {
    final res = await ApiClient.instance.post(
      ApiEndpoints.cosmicImprint,
      body: body,
      requireAuth: true,
    );
    _ensureOk(res);
    final data = _unwrap(res);
    if (data == null || data.isEmpty) {
      throw Exception('Empty cosmic imprint response');
    }
    return data;
  }

  Future<Map<String, dynamic>> getLatestColorEmotional() async {
    try {
      final res = await ApiClient.instance.get(
        ApiEndpoints.colorEmotionalAnalysis,
        requireAuth: true,
      );
      if (res['success'] == false) return {};
      return _unwrap(res) ?? {};
    } catch (e) {
      if (kDebugMode) {
        print('WellnessAnalysisService.getLatestColorEmotional: $e');
      }
      return {};
    }
  }

  Future<Map<String, dynamic>> createColorEmotional(
      Map<String, dynamic> body) async {
    final res = await ApiClient.instance.post(
      ApiEndpoints.colorEmotionalAnalysis,
      body: body,
      requireAuth: true,
    );
    _ensureOk(res);
    final data = _unwrap(res);
    if (data == null || data.isEmpty) {
      throw Exception('Empty color analysis response');
    }
    return data;
  }
}
