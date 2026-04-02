import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartService {
  CartService._();

  static final CartService instance = CartService._();

  static const _storageKey = 'cart_items_v1';

  final ValueNotifier<List<Map<String, dynamic>>> items =
      ValueNotifier<List<Map<String, dynamic>>>(const []);

  bool _loaded = false;

  ValueListenable<int> get count => items.map((v) => v.length);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        items.value = decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
    } catch (e) {
      if (kDebugMode) print('❌ CartService load error: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(items.value));
    } catch (e) {
      if (kDebugMode) print('❌ CartService persist error: $e');
    }
  }

  bool containsCourse(String courseId) {
    return items.value.any((c) => (c['id']?.toString() ?? '') == courseId);
  }

  double totalPrice() {
    double sum = 0;
    for (final c in items.value) {
      final price = c['price'];
      if (price is num) {
        sum += price.toDouble();
      } else if (price is String) {
        sum += (num.tryParse(price)?.toDouble() ?? 0);
      }
    }
    return sum;
  }

  Map<String, dynamic> _compactCourse(Map<String, dynamic> course) {
    // Keep only what's needed for cart + checkout UI.
    final id = course['id']?.toString() ?? '';
    final title = course['title']?.toString() ?? '';
    final thumbnail = course['thumbnail']?.toString() ?? '';
    final price = course['price'];
    final isFree = course['is_free'] == true || course['isFree'] == true;
    final instructor = course['instructor'];
    final category = course['category'];

    return {
      'id': id,
      'title': title,
      'thumbnail': thumbnail,
      'price': isFree ? 0 : (price ?? 0),
      'is_free': isFree,
      if (instructor != null) 'instructor': instructor,
      if (category != null) 'category': category,
      // Seats (optional, if present)
      if (course['capacity'] != null) 'capacity': course['capacity'],
      if (course['max_students'] != null) 'max_students': course['max_students'],
      if (course['total_seats'] != null) 'total_seats': course['total_seats'],
      if (course['enrolled_count'] != null) 'enrolled_count': course['enrolled_count'],
      if (course['students_count'] != null) 'students_count': course['students_count'],
    };
  }

  Future<bool> addCourse(Map<String, dynamic> course) async {
    await ensureLoaded();
    final id = course['id']?.toString() ?? '';
    if (id.isEmpty) return false;
    if (containsCourse(id)) return false;
    items.value = [...items.value, _compactCourse(course)];
    await _persist();
    return true;
  }

  Future<void> removeCourse(String courseId) async {
    await ensureLoaded();
    items.value = items.value
        .where((c) => (c['id']?.toString() ?? '') != courseId)
        .toList(growable: false);
    await _persist();
  }

  Future<void> clear() async {
    await ensureLoaded();
    items.value = const [];
    await _persist();
  }
}

extension _ValueListenableMap<T> on ValueListenable<T> {
  ValueListenable<R> map<R>(R Function(T value) mapper) {
    return _MappedValueListenable<T, R>(this, mapper);
  }
}

class _MappedValueListenable<T, R> extends ValueNotifier<R> {
  _MappedValueListenable(this._source, this._mapper) : super(_mapper(_source.value)) {
    _source.addListener(_onSourceChanged);
  }

  final ValueListenable<T> _source;
  final R Function(T value) _mapper;

  void _onSourceChanged() {
    value = _mapper(_source.value);
  }

  @override
  void dispose() {
    _source.removeListener(_onSourceChanged);
    super.dispose();
  }
}

