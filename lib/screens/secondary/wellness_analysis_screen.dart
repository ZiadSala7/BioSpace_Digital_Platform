import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/design/app_colors.dart';
import '../../services/wellness_analysis_service.dart';

/// Cosmic Imprint + Color Emotional Analysis (see `docs/wellness-analysis-backend-spec.md`).
class WellnessAnalysisScreen extends StatefulWidget {
  const WellnessAnalysisScreen({super.key});

  @override
  State<WellnessAnalysisScreen> createState() => _WellnessAnalysisScreenState();
}

class _WellnessAnalysisScreenState extends State<WellnessAnalysisScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  DateTime? _birthDate;
  TimeOfDay? _birthTime;
  final _placeController = TextEditingController();
  bool _cosmicLoading = false;
  Map<String, dynamic>? _cosmicResult;

  final List<String> _selectedHex = [];
  final _colorNotesController = TextEditingController();
  bool _colorLoading = false;
  Map<String, dynamic>? _colorResult;

  static const _paletteHex = <String>[
    '#E53935',
    '#FB8C00',
    '#FDD835',
    '#C0CA33',
    '#43A047',
    '#00897B',
    '#00ACC1',
    '#1E88E5',
    '#3949AB',
    '#5E35B1',
    '#8E24AA',
    '#D81B60',
    '#6D4C41',
    '#546E7A',
    '#212121',
    '#ECEFF1',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final c = await WellnessAnalysisService.instance.getLatestCosmicImprint();
    final ce = await WellnessAnalysisService.instance.getLatestColorEmotional();
    if (!mounted) return;
    setState(() {
      if (c.isNotEmpty) _cosmicResult = c;
      if (ce.isNotEmpty) _colorResult = ce;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _placeController.dispose();
    _colorNotesController.dispose();
    super.dispose();
  }

  Color _parseHex(String hex) {
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) {
      return Color(int.parse('FF$h', radix: 16));
    }
    if (h.length == 8) {
      return Color(int.parse(h, radix: 16));
    }
    return AppColors.primary;
  }

  void _togglePalette(String hex) {
    setState(() {
      if (_selectedHex.contains(hex)) {
        _selectedHex.remove(hex);
      } else if (_selectedHex.length < 7) {
        _selectedHex.add(hex);
      }
    });
  }

  Future<void> _runCosmic(bool isAr) async {
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr ? 'اختر تاريخ الميلاد' : 'Pick your birth date',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _cosmicLoading = true);
    try {
      final body = <String, dynamic>{
        'birth_date': DateFormat('yyyy-MM-dd').format(_birthDate!),
        'locale': isAr ? 'ar' : 'en',
      };
      if (_birthTime != null) {
        final t = _birthTime!;
        body['birth_time'] =
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      }
      final place = _placeController.text.trim();
      if (place.isNotEmpty) {
        body['birth_place_label'] = place;
      }

      final data =
          await WellnessAnalysisService.instance.createCosmicImprint(body);
      if (!mounted) return;
      setState(() => _cosmicResult = data);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr ? 'تم تحديث البصمة الكونية' : 'Cosmic imprint updated',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.cairo()),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _cosmicLoading = false);
    }
  }

  Future<void> _runColor(bool isAr) async {
    if (_selectedHex.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr ? 'اختر 3 ألوان على الأقل' : 'Pick at least 3 colors',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _colorLoading = true);
    try {
      final body = <String, dynamic>{
        'colors': List<String>.from(_selectedHex),
        'locale': isAr ? 'ar' : 'en',
        'context': 'app_wellness',
      };
      final notes = _colorNotesController.text.trim();
      if (notes.isNotEmpty) body['notes'] = notes;

      final data =
          await WellnessAnalysisService.instance.createColorEmotional(body);
      if (!mounted) return;
      setState(() => _colorResult = data);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr ? 'تم تحليل الألوان' : 'Color analysis complete',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.cairo()),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _colorLoading = false);
    }
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.65)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  String _pickLocalized(Map<String, dynamic> m, String key, bool isAr) {
    final ar = m['${key}_ar']?.toString();
    final en = m['${key}_en']?.toString();
    final raw = m[key]?.toString();
    if (isAr) return ar ?? en ?? raw ?? '';
    return en ?? ar ?? raw ?? '';
  }

  Widget _buildCosmicResult(Map<String, dynamic> data, bool isAr) {
    final title = _pickLocalized(data, 'imprint_label', isAr).isNotEmpty
        ? _pickLocalized(data, 'imprint_label', isAr)
        : (data['imprint_key']?.toString() ?? '');
    final summary = _pickLocalized(data, 'summary', isAr);
    final integration = _pickLocalized(data, 'integration_analysis', isAr);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            summary,
            style: GoogleFonts.cairo(
              fontSize: 13,
              height: 1.45,
              color: AppColors.foreground,
            ),
          ),
        ],
        if (integration.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            isAr ? 'تحليل التكامل' : 'Integration',
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            integration,
            style: GoogleFonts.cairo(
              fontSize: 12,
              height: 1.45,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
        _buildElements(
          data['elements'],
          title: isAr ? 'العناصر' : 'Elements',
        ),
        _buildTraitChips(data['traits']),
        _buildNarrativeBlocks(data['narrative_blocks'], isAr),
      ],
    );
  }

  Widget _buildElements(dynamic elements, {required String title}) {
    if (elements is! Map) return const SizedBox.shrink();
    final m = Map<String, dynamic>.from(elements);
    if (m.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          ...m.entries.map((e) {
            final v = e.value;
            final score = v is num
                ? v.toDouble().clamp(0.0, 1.0)
                : double.tryParse(v?.toString() ?? '')?.clamp(0.0, 1.0) ?? 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${(score * 100).round()}%',
                        style: GoogleFonts.cairo(fontSize: 11),
                      ),
                    ],
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: score,
                      minHeight: 6,
                      backgroundColor: AppColors.border.withOpacity(0.35),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTraitChips(dynamic traits) {
    if (traits is! List || traits.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: traits.map((t) {
          final label = t?.toString() ?? '';
          if (label.isEmpty) return const SizedBox.shrink();
          return Chip(
            label: Text(label, style: GoogleFonts.cairo(fontSize: 11)),
            backgroundColor: AppColors.lavenderLight,
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNarrativeBlocks(dynamic blocks, bool isAr) {
    if (blocks is! List || blocks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: blocks.map((b) {
          if (b is! Map) return const SizedBox.shrink();
          final bm = Map<String, dynamic>.from(b);
          final title = _pickLocalized(bm, 'title', isAr);
          final body = _pickLocalized(bm, 'body', isAr);
          if (title.isEmpty && body.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                if (body.isNotEmpty)
                  Text(
                    body,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.foreground,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildColorResult(Map<String, dynamic> data, bool isAr) {
    final interp = _pickLocalized(data, 'interpretation', isAr);
    final integration = _pickLocalized(data, 'integration_notes', isAr);
    final emotions = data['dominant_emotions'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (interp.isNotEmpty)
          Text(
            interp,
            style: GoogleFonts.cairo(
              fontSize: 13,
              height: 1.45,
              color: AppColors.foreground,
            ),
          ),
        if (integration.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            isAr ? 'ملاحظات التكامل' : 'Integration notes',
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            integration,
            style: GoogleFonts.cairo(
              fontSize: 12,
              height: 1.45,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
        if (emotions is List && emotions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            isAr ? 'المشاعر البارزة' : 'Dominant emotions',
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          ...emotions.map((e) {
            if (e is! Map) return const SizedBox.shrink();
            final em = Map<String, dynamic>.from(e);
            final label = _pickLocalized(em, 'label', isAr);
            final key = em['key']?.toString() ?? '';
            final score = em['score'];
            final s = score is num ? score.toDouble() : 0.0;
            final line = label.isNotEmpty ? label : key;
            if (line.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      line,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${(s * 100).round()}%',
                    style: GoogleFonts.cairo(fontSize: 11),
                  ),
                ],
              ),
            );
          }),
        ],
        _buildElements(
          data['emotion_spectrum'],
          title: isAr ? 'طيف المشاعر' : 'Emotion spectrum',
        ),
      ],
    );
  }

  Widget _buildCosmicTab(bool isAr) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_cosmicResult != null && _cosmicResult!.isNotEmpty)
          _card(child: _buildCosmicResult(_cosmicResult!, isAr)),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr ? 'البيانات' : 'Your data',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  isAr ? 'تاريخ الميلاد' : 'Birth date',
                  style: GoogleFonts.cairo(fontSize: 12),
                ),
                subtitle: Text(
                  _birthDate != null
                      ? DateFormat.yMMMd(
                              Localizations.localeOf(context).toLanguageTag())
                          .format(_birthDate!)
                      : (isAr ? 'لم يُحدد' : 'Not set'),
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                trailing: const Icon(Icons.calendar_today_rounded, size: 20),
                onTap: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _birthDate ?? DateTime(1990, 1, 1),
                    firstDate: DateTime(1900),
                    lastDate: now,
                  );
                  if (d != null) setState(() => _birthDate = d);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  isAr ? 'وقت الميلاد (اختياري)' : 'Birth time (optional)',
                  style: GoogleFonts.cairo(fontSize: 12),
                ),
                subtitle: Text(
                  _birthTime != null
                      ? _birthTime!.format(context)
                      : (isAr ? 'لم يُحدد' : 'Not set'),
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.schedule_rounded, size: 20),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _birthTime ?? TimeOfDay.now(),
                  );
                  if (t != null) setState(() => _birthTime = t);
                },
              ),
              TextField(
                controller: _placeController,
                decoration: InputDecoration(
                  labelText: isAr ? 'مكان الميلاد (اختياري)' : 'Birth place (optional)',
                  labelStyle: GoogleFonts.cairo(),
                ),
                style: GoogleFonts.cairo(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _cosmicLoading ? null : () => _runCosmic(isAr),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _cosmicLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isAr ? 'احسب البصمة الكونية' : 'Compute cosmic imprint',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColorTab(bool isAr) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_colorResult != null && _colorResult!.isNotEmpty)
          _card(child: _buildColorResult(_colorResult!, isAr)),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr
                    ? 'اختر من 3 إلى 7 ألوان بالترتيب الذي يلهمك'
                    : 'Pick 3–7 colors in the order that resonates',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _paletteHex.map((hex) {
                  final selected = _selectedHex.contains(hex);
                  final c = _parseHex(hex);
                  final light = hex.toUpperCase() == '#ECEFF1';
                  final checkDark = c.computeLuminance() > 0.55;
                  return GestureDetector(
                    onTap: () => _togglePalette(hex),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : (light
                                  ? AppColors.border
                                  : Colors.black26),
                          width: selected ? 3 : 1,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.35),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: selected
                          ? Icon(
                              Icons.check_rounded,
                              color: checkDark ? Colors.black87 : Colors.white,
                              size: 22,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              if (_selectedHex.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _selectedHex.join(' → '),
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _colorNotesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: isAr ? 'ملاحظات (اختياري)' : 'Notes (optional)',
                  labelStyle: GoogleFonts.cairo(),
                ),
                style: GoogleFonts.cairo(fontSize: 13),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _colorLoading ? null : () => _runColor(isAr),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _colorLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isAr ? 'حلّل المشاعر من الألوان' : 'Analyze color emotions',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.beige,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isAr ? 'تحليل التكامل' : 'Integration analysis',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelColor: Colors.white70,
          labelColor: Colors.white,
          tabs: [
            Tab(text: isAr ? 'البصمة الكونية' : 'Cosmic Imprint'),
            Tab(text: isAr ? 'الألوان' : 'Color emotions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCosmicTab(isAr),
          _buildColorTab(isAr),
        ],
      ),
    );
  }
}
