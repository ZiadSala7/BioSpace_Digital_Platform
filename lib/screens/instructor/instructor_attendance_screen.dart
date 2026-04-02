import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_radius.dart';
import '../../core/navigation/route_names.dart';
import '../../services/profile_service.dart';
import '../../services/teacher_dashboard_service.dart';

/// Instructor attendance dashboard:
/// - Pick course
/// - Enter session title
/// - View attendees + % for that session
class InstructorAttendanceScreen extends StatefulWidget {
  const InstructorAttendanceScreen({super.key});

  @override
  State<InstructorAttendanceScreen> createState() =>
      _InstructorAttendanceScreenState();
}

class _InstructorAttendanceScreenState extends State<InstructorAttendanceScreen> {
  bool _coursesLoading = true;
  bool _sessionLoading = false;
  String? _error;

  List<Map<String, dynamic>> _courses = [];
  String? _selectedCourseId;
  final TextEditingController _sessionTitleController =
      TextEditingController(text: '');

  Map<String, dynamic>? _sessionResponse;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _sessionTitleController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _coursesLoading = true;
      _error = null;
    });
    try {
      final profile = await ProfileService.instance.getProfile();
      final userId = profile['id']?.toString() ?? '';
      if (userId.isEmpty) {
        setState(() {
          _coursesLoading = false;
          _courses = [];
        });
        return;
      }

      final data = await TeacherDashboardService.instance.getMyCourses(
        instructorId: userId,
        limit: 200,
      );
      final list = data['data'] ?? data;
      final listMap = list is List
          ? list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _courses = listMap;
        _coursesLoading = false;
        _selectedCourseId ??=
            _courses.isNotEmpty ? _courses.first['id']?.toString() : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _coursesLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadSession() async {
    final courseId = _selectedCourseId?.trim() ?? '';
    final title = _sessionTitleController.text.trim();
    if (courseId.isEmpty || title.isEmpty) {
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr
                ? 'اختر الدورة وأدخل عنوان الجلسة'
                : 'Select a course and enter a session title',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _sessionLoading = true;
      _error = null;
    });
    try {
      final res = await TeacherDashboardService.instance.getAttendanceSession(
        courseId: courseId,
        sessionTitle: title,
      );
      if (!mounted) return;
      setState(() {
        _sessionResponse = res;
        _sessionLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sessionLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  int _safeInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  double _safeDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final data = _sessionResponse?['data'];
    final dataMap = data is Map ? Map<String, dynamic>.from(data) : null;

    final present = _safeInt(dataMap?['present'] ?? dataMap?['present_count']);
    final total = _safeInt(dataMap?['total'] ?? dataMap?['total_students']);
    final pct = dataMap?['percentage'] != null
        ? _safeDouble(dataMap?['percentage'])
        : (total <= 0 ? 0.0 : (present / total) * 100.0);

    final attendeesRaw = dataMap?['attendees'] ?? dataMap?['students'];
    final attendees = attendeesRaw is List
        ? attendeesRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(
          isAr ? 'الحضور' : 'Attendance',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go(RouteNames.instructorProfile),
        ),
        actions: [
          IconButton(
            tooltip: isAr ? 'مسح QR' : 'Scan QR',
            onPressed: () => context.go(RouteNames.instructorScanQr),
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadCourses();
            if (_sessionResponse != null) {
              await _loadSession();
            }
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _buildControlsCard(context, isAr),
              const SizedBox(height: 12),
              _buildSummaryCard(
                context,
                isAr: isAr,
                present: present,
                total: total,
                pct: pct,
                loading: _sessionLoading,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _buildErrorCard(context, isAr, _error!),
              ],
              const SizedBox(height: 12),
              _buildAttendeesCard(context, isAr, attendees),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsCard(BuildContext context, bool isAr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAr ? 'الجلسة' : 'Session',
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          if (_coursesLoading)
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: _selectedCourseId,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppColors.primary.withOpacity(0.25),
                    width: 1.2,
                  ),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              style: GoogleFonts.cairo(
                color: AppColors.foreground,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              hint: Text(
                isAr ? 'اختر الدورة' : 'Select course',
                style: GoogleFonts.cairo(color: AppColors.mutedForeground),
              ),
              items: _courses.map((c) {
                final id = c['id']?.toString() ?? '';
                final title = c['title']?.toString() ?? id;
                return DropdownMenuItem<String>(
                  value: id,
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(),
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedCourseId = v),
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _sessionTitleController,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
            decoration: InputDecoration(
              hintText: isAr
                  ? 'عنوان الجلسة (مثال: المحاضرة 1)'
                  : 'Session title (e.g. Lecture 1)',
              hintStyle: GoogleFonts.cairo(color: AppColors.mutedForeground),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.primary.withOpacity(0.25),
                  width: 1.2,
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            textInputAction: TextInputAction.search,
            onFieldSubmitted: (_) => _loadSession(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sessionLoading ? null : _loadSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                isAr ? 'تحديث الحضور' : 'Refresh attendance',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required bool isAr,
    required int present,
    required int total,
    required double pct,
    required bool loading,
  }) {
    return Container(
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
              Icons.fact_check_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? 'نسبة الحضور' : 'Attendance rate',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAr
                      ? '$present / $total طالب'
                      : '$present / $total students',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (loading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${pct.clamp(0, 100).toStringAsFixed(0)}%',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, bool isAr, String error) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.destructive.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.destructive.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.destructive),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error.isEmpty
                  ? (isAr ? 'حدث خطأ' : 'Something went wrong')
                  : error,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.destructive,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendeesCard(
    BuildContext context,
    bool isAr,
    List<Map<String, dynamic>> attendees,
  ) {
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
              Text(
                isAr ? 'الحاضرون' : 'Attendees',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.foreground,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.border.withOpacity(0.7)),
                ),
                child: Text(
                  '${attendees.length}',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (attendees.isEmpty)
            Text(
              isAr
                  ? 'لا يوجد حضور مسجل لهذه الجلسة بعد'
                  : 'No attendance recorded for this session yet',
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground,
              ),
            )
          else
            ...attendees.take(40).map((a) {
              final name = a['name']?.toString() ??
                  a['full_name']?.toString() ??
                  a['student_name']?.toString() ??
                  (a['user'] is Map
                      ? (a['user']['name']?.toString() ?? '')
                      : '');
              final email = a['email']?.toString() ??
                  (a['user'] is Map ? (a['user']['email']?.toString() ?? '') : '');
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? (isAr ? 'طالب' : 'Student') : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.foreground,
                            ),
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 18,
                    ),
                  ],
                ),
              );
            }),
          if (attendees.length > 40) ...[
            const SizedBox(height: 6),
            Text(
              isAr
                  ? '... عرض أول 40 فقط'
                  : '... showing first 40 only',
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go(RouteNames.instructorScanQr),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: Text(
                isAr ? 'متابعة المسح' : 'Continue scanning',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

