import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_radius.dart';
import '../../services/course_transformation_service.dart';

class CourseTransformationScreen extends StatefulWidget {
  const CourseTransformationScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  final String courseId;
  final String courseTitle;

  @override
  State<CourseTransformationScreen> createState() =>
      _CourseTransformationScreenState();
}

class _CourseTransformationScreenState extends State<CourseTransformationScreen> {
  final TextEditingController _beforeController = TextEditingController();
  final TextEditingController _afterController = TextEditingController();

  double _commitment = 0.5;
  double _consistency = 0.5;
  double _results = 0.5;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _beforeController.dispose();
    _afterController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await CourseTransformationService.instance.get(widget.courseId);
    if (!mounted) return;
    _beforeController.text = data['before']?.toString() ?? '';
    _afterController.text = data['after']?.toString() ?? '';
    _commitment = _to01(data['commitment']) ?? 0.5;
    _consistency = _to01(data['consistency']) ?? 0.5;
    _results = _to01(data['results']) ?? 0.5;
    setState(() => _loading = false);
  }

  double? _to01(dynamic v) {
    if (v == null) return null;
    final d = v is num ? v.toDouble() : double.tryParse(v.toString());
    if (d == null) return null;
    return d.clamp(0.0, 1.0);
  }

  double get _score => ((_commitment + _consistency + _results) / 3.0) * 100.0;

  Future<void> _save() async {
    final payload = <String, dynamic>{
      'before': _beforeController.text.trim(),
      'after': _afterController.text.trim(),
      'commitment': _commitment,
      'consistency': _consistency,
      'results': _results,
      'score': _score,
      'updated_at': DateTime.now().toIso8601String(),
    };
    final synced =
        await CourseTransformationService.instance.set(widget.courseId, payload);
    if (!mounted) return;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? (isAr ? 'تم حفظ بيانات التحول' : 'Transformation saved')
              : (isAr
                  ? 'تم الحفظ على الجهاز فقط — تعذر المزامنة مع الخادم'
                  : 'Saved on device only — could not sync to server'),
          style: GoogleFonts.cairo(),
        ),
        backgroundColor: synced ? AppColors.success : AppColors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(
          isAr ? 'نظام التحول' : 'Transformation',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: isAr ? 'حفظ' : 'Save',
            onPressed: _save,
            icon: const Icon(Icons.save_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.border.withOpacity(0.7)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.courseTitle.isEmpty
                                  ? (isAr ? 'الدورة' : 'Course')
                                  : widget.courseTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AppColors.foreground,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isAr
                                  ? 'درجة التحول: ${_score.toStringAsFixed(0)}/100'
                                  : 'Score: ${_score.toStringAsFixed(0)}/100',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_score.toStringAsFixed(0)}%',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _noteCard(
                  title: isAr ? 'قبل' : 'Before',
                  hint: isAr
                      ? 'اكتب وضعك قبل بداية الدورة...'
                      : 'Describe your state before the course...',
                  controller: _beforeController,
                  icon: Icons.history_rounded,
                  color: AppColors.orange,
                ),
                const SizedBox(height: 12),
                _noteCard(
                  title: isAr ? 'بعد' : 'After',
                  hint: isAr
                      ? 'اكتب ماذا تغير بعد الدورة...'
                      : 'Describe what changed after the course...',
                  controller: _afterController,
                  icon: Icons.rocket_launch_rounded,
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(height: 12),
                _indicator(
                  label: isAr ? 'الالتزام' : 'Commitment',
                  value: _commitment,
                  onChanged: (v) => setState(() => _commitment = v),
                  color: AppColors.primary,
                ),
                _indicator(
                  label: isAr ? 'الاستمرارية' : 'Consistency',
                  value: _consistency,
                  onChanged: (v) => setState(() => _consistency = v),
                  color: AppColors.orange,
                ),
                _indicator(
                  label: isAr ? 'النتائج' : 'Results',
                  value: _results,
                  onChanged: (v) => setState(() => _results = v),
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: Text(
                      isAr ? 'حفظ' : 'Save',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
              ],
            ),
    );
  }

  Widget _noteCard({
    required String title,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            style: GoogleFonts.cairo(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.cairo(color: AppColors.mutedForeground),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.primary.withOpacity(0.18),
                  width: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _indicator({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.foreground,
                ),
              ),
              const Spacer(),
              Text(
                '${(value * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: AppColors.border.withOpacity(0.35),
              thumbColor: color,
              overlayColor: color.withOpacity(0.12),
            ),
            child: Slider(
              value: value,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

