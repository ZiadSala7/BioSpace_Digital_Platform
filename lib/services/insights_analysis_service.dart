import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Cosmic Imprint + Color Emotional Analysis (`docs/integration-insights-backend-spec.md`).
class InsightsAnalysisService {
  InsightsAnalysisService._();

  static final InsightsAnalysisService instance = InsightsAnalysisService._();

  /// Accepts `data` when `success` is not false (many APIs omit `success` on 200).
  Map<String, dynamic>? _unwrap(Map<String, dynamic> response) {
    if (response['success'] == false) return null;
    final data = response['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  Future<Map<String, dynamic>> getCosmicImprint() async {
    try {
      final res = await ApiClient.instance.get(
        ApiEndpoints.cosmicImprint,
        requireAuth: true,
      );
      return _unwrap(res) ?? {};
    } catch (e) {
      if (kDebugMode) {
        print('InsightsAnalysisService.getCosmicImprint: $e');
      }
      return {};
    }
  }

  Future<Map<String, dynamic>> submitCosmicImprint(
    Map<String, dynamic> body,
  ) async {
    final res = await ApiClient.instance.post(
      ApiEndpoints.cosmicImprint,
      body: body,
      requireAuth: true,
    );
    final data = _unwrap(res);
    if (data == null) {
      throw Exception(
        res['message']?.toString() ?? 'Cosmic imprint request failed',
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> getColorEmotional() async {
    try {
      final res = await ApiClient.instance.get(
        ApiEndpoints.colorEmotionalAnalysis,
        requireAuth: true,
      );
      return _unwrap(res) ?? {};
    } catch (e) {
      if (kDebugMode) {
        print('InsightsAnalysisService.getColorEmotional: $e');
      }
      return {};
    }
  }

  Future<Map<String, dynamic>> submitColorEmotional(
    Map<String, dynamic> body,
  ) async {
    final res = await ApiClient.instance.post(
      ApiEndpoints.colorEmotionalAnalysis,
      body: body,
      requireAuth: true,
    );
    final data = _unwrap(res);
    if (data == null) {
      throw Exception(
        res['message']?.toString() ?? 'Color analysis request failed',
      );
    }
    return data;
  }
}
