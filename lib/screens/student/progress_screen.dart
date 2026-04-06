import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_text_styles.dart';
import '../../core/navigation/route_names.dart';
import '../../widgets/bottom_nav.dart';
import '../../l10n/app_localizations.dart';
import '../../services/progress_service.dart';
import '../../services/wellness_analysis_service.dart';

/// Progress Screen - Pixel-perfect match to React version
/// Matches: components/screens/progress-screen.tsx
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  String _period = 'weekly';
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _progressData;
  List<Map<String, dynamic>> _enrollments = [];
  String? _selectedCourseId;

  // Chart data from API
  List<Map<String, dynamic>> _chartData = [];

  // Top students from API
  List<Map<String, dynamic>> _topStudents = [];
  Map<String, dynamic>? _cosmicInsight;
  Map<String, dynamic>? _colorInsight;

  num _numFrom(dynamic v, [num fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  int _intFromSafe(dynamic v, [int fallback = 0]) =>
      _numFrom(v, fallback).toInt();

  Map<String, dynamic>? get _selectedEnrollment {
    if (_selectedCourseId == null || _selectedCourseId!.isEmpty) return null;
    for (final e in _enrollments) {
      final course = e['course'];
      if (course is Map) {
        final id = course['id']?.toString();
        if (id == _selectedCourseId) return e;
      }
    }
    return null;
  }

  String get _selectedCourseLabel {
    final selected = _selectedEnrollment;
    if (selected == null) return AppLocalizations.of(context)!.allSubjects;
    final course = selected['course'];
    if (course is Map && course['title'] != null) {
      return course['title'].toString();
    }
    return AppLocalizations.of(context)!.allSubjects;
  }

  int get _displayCompletedLessons {
    final selected = _selectedEnrollment;
    if (selected != null) {
      return _intFromSafe(
        selected['completed_lessons'],
        _intFromSafe(
          (selected['course'] is Map)
              ? (selected['course'] as Map)['completed_lessons']
              : null,
          0,
        ),
      );
    }
    return _intFromSafe(_progressData?['statistics']?['completed_lessons'], 0);
  }

  int get _displayTotalLessons {
    final selected = _selectedEnrollment;
    if (selected != null) {
      final course = selected['course'];
      return _intFromSafe(
        selected['total_lessons'],
        _intFromSafe((course is Map) ? course['lessons_count'] : null, 0),
      );
    }
    return _intFromSafe(_progressData?['statistics']?['total_lessons'], 0);
  }

  int get _displayProgressPercent {
    final selected = _selectedEnrollment;
    if (selected != null) {
      final p = _intFromSafe(selected['progress'], 0);
      return p.clamp(0, 100);
    }
    return _intFromSafe(_progressData?['user']?['overall_progress'], 0)
        .clamp(0, 100);
  }

  int get _displayHours {
    final selected = _selectedEnrollment;
    if (selected != null) {
      final course = selected['course'];
      final duration = _numFrom((course is Map) ? course['duration_hours'] : 0);
      return (duration * (_displayProgressPercent / 100)).round();
    }
    return _intFromSafe(_progressData?['statistics']?['total_hours'], 0);
  }

  @override
  void initState() {
    super.initState();
    _fetchProgressData();
  }

  Future<void> _fetchProgressData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        ProgressService.instance.getProgressData(_period),
        WellnessAnalysisService.instance.getLatestCosmicImprint(),
        WellnessAnalysisService.instance.getLatestColorEmotional(),
      ]);
      final data = results[0] as Map<String, dynamic>;
      final cosmic = results[1] as Map<String, dynamic>;
      final color = results[2] as Map<String, dynamic>;

      setState(() {
        _progressData = data;
        _cosmicInsight = cosmic.isNotEmpty ? cosmic : null;
        _colorInsight = color.isNotEmpty ? color : null;
        _enrollments = (data['enrollments'] is List)
            ? List<Map<String, dynamic>>.from(data['enrollments'] as List)
            : <Map<String, dynamic>>[];
        if (_selectedCourseId != null) {
          final exists = _enrollments.any((e) {
            final course = e['course'];
            return course is Map && course['id']?.toString() == _selectedCourseId;
          });
          if (!exists) _selectedCourseId = null;
        }
        _isLoading = false;

        // Extract chart data based on period
        if (data['chart_data'] != null) {
          final chartData = data['chart_data'] as Map<String, dynamic>;
          _chartData = List<Map<String, dynamic>>.from(
            chartData[_period] as List? ?? [],
          );
        }

        // Extract top students
        if (data['top_students'] != null) {
          _topStudents = List<Map<String, dynamic>>.from(
            data['top_students'] as List? ?? [],
          );
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onPeriodChanged(String period) {
    if (_period != period) {
      setState(() {
        _period = period;
      });
      _fetchProgressData();
    }
  }

  List<Map<String, dynamic>> _buildAnalyticalChartData() {
    final selected = _selectedEnrollment;
    if (selected == null) return _chartData;

    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final progress = _displayProgressPercent;
    final completed = _displayCompletedLessons;
    final total = _displayTotalLessons;
    final completion = total > 0 ? ((completed / total) * 100).round() : 0;
    final remaining = total > 0 ? (((total - completed) / total) * 100).round() : 0;
    final course = selected['course'];
    final rating = _numFrom((course is Map) ? course['rating'] : 0).toDouble();
    final ratingPct = (rating.clamp(0, 5) / 5 * 100).round();

    return [
      {
        'day': isAr ? 'التقدم' : 'Progress',
        'value': progress,
        'stripes': false,
      },
      {
        'day': isAr ? 'الإنجاز' : 'Completion',
        'value': completion.clamp(0, 100),
        'stripes': false,
      },
      {
        'day': isAr ? 'المتبقي' : 'Remaining',
        'value': remaining.clamp(0, 100),
        'stripes': true,
      },
      {
        'day': isAr ? 'التقييم' : 'Rating',
        'value': ratingPct.clamp(0, 100),
        'stripes': false,
      },
    ];
  }

  void _showCourseSelector() {
    if (_enrollments.isEmpty) return;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isAr ? 'اختر مادة' : 'Choose course',
                  style: AppTextStyles.bodyMedium(
                    color: AppColors.foreground,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text(AppLocalizations.of(context)!.allSubjects),
                  trailing: _selectedCourseId == null
                      ? const Icon(Icons.check_rounded, color: AppColors.primary)
                      : null,
                  onTap: () {
                    setState(() => _selectedCourseId = null);
                    Navigator.pop(context);
                  },
                ),
                ..._enrollments.map((e) {
                  final course = e['course'];
                  final id = (course is Map) ? course['id']?.toString() : null;
                  final title = (course is Map)
                      ? course['title']?.toString() ?? (isAr ? 'مادة' : 'Course')
                      : (isAr ? 'مادة' : 'Course');
                  if (id == null || id.isEmpty) return const SizedBox.shrink();
                  return ListTile(
                    title: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${_intFromSafe(e['progress'], 0).clamp(0, 100)}%',
                    ),
                    trailing: _selectedCourseId == id
                        ? const Icon(Icons.check_rounded, color: AppColors.primary)
                        : null,
                    onTap: () {
                      setState(() => _selectedCourseId = id);
                      Navigator.pop(context);
                    },
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beige,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              margin: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width > 400
                    ? (MediaQuery.of(context).size.width - 400) / 2
                    : 0,
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _error!,
                                style: AppTextStyles.bodyMedium(
                                  color: Colors.red,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _fetchProgressData,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header - matches React Header component
                              _buildHeader(context),

                              // Content - matches React: px-4 space-y-4
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16), // px-4
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 16),

                                    // Title and filter - matches React: flex items-center justify-between
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          AppLocalizations.of(context)!
                                              .progress,
                                          style: AppTextStyles.h2(
                                            color: AppColors.foreground,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: _showCourseSelector,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16, // px-4
                                              vertical: 8, // py-2
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.lavenderLight,
                                              borderRadius: BorderRadius.circular(
                                                  999), // rounded-full
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.bar_chart,
                                                  size: 16, // w-4 h-4
                                                  color: AppColors.purple,
                                                ),
                                                const SizedBox(width: 8), // gap-2
                                                ConstrainedBox(
                                                  constraints:
                                                      const BoxConstraints(maxWidth: 120),
                                                  child: Text(
                                                    _selectedCourseLabel,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style:
                                                        AppTextStyles.bodySmall(
                                                      color: AppColors.purple,
                                                    ).copyWith(
                                                            fontWeight:
                                                                FontWeight.w500),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(
                                                  Icons.keyboard_arrow_down,
                                                  size: 16, // w-4 h-4
                                                  color: AppColors.purple,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16), // space-y-4

                                    // Stats card - matches React: bg-white rounded-3xl p-5 shadow-sm
                                    Container(
                                      padding: const EdgeInsets.all(20), // p-5
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                            24), // rounded-3xl
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          // Header row - matches React: mb-4
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 16), // mb-4
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Container(
                                                  width: 32, // w-8
                                                  height: 32, // h-8
                                                  decoration: BoxDecoration(
                                                    color:
                                                        AppColors.purpleLight,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8), // rounded-lg
                                                  ),
                                                  child: const Icon(
                                                    Icons.bar_chart,
                                                    size: 16, // w-4 h-4
                                                    color: AppColors.purple,
                                                  ),
                                                ),
                                                // Period toggle - matches React: bg-gray-100 rounded-full p-1
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                      4), // p-1
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[100],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            999), // rounded-full
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      GestureDetector(
                                                        onTap: () =>
                                                            _onPeriodChanged(
                                                                'weekly'),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal:
                                                                16, // px-4
                                                            vertical: 4, // py-1
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: _period ==
                                                                    'weekly'
                                                                ? Colors.white
                                                                : Colors
                                                                    .transparent,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        999),
                                                            boxShadow:
                                                                _period ==
                                                                        'weekly'
                                                                    ? [
                                                                        BoxShadow(
                                                                          color: Colors
                                                                              .black
                                                                              .withOpacity(0.1),
                                                                          blurRadius:
                                                                              4,
                                                                          offset: const Offset(
                                                                              0,
                                                                              2),
                                                                        ),
                                                                      ]
                                                                    : null,
                                                          ),
                                                          child: Text(
                                                            AppLocalizations.of(
                                                                    context)!
                                                                .weekly,
                                                            style: AppTextStyles
                                                                .bodySmall(
                                                              color: AppColors
                                                                  .foreground,
                                                            ).copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500),
                                                          ),
                                                        ),
                                                      ),
                                                      GestureDetector(
                                                        onTap: () =>
                                                            _onPeriodChanged(
                                                                'monthly'),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal:
                                                                16, // px-4
                                                            vertical: 4, // py-1
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: _period ==
                                                                    'monthly'
                                                                ? Colors.white
                                                                : Colors
                                                                    .transparent,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        999),
                                                            boxShadow:
                                                                _period ==
                                                                        'monthly'
                                                                    ? [
                                                                        BoxShadow(
                                                                          color: Colors
                                                                              .black
                                                                              .withOpacity(0.1),
                                                                          blurRadius:
                                                                              4,
                                                                          offset: const Offset(
                                                                              0,
                                                                              2),
                                                                        ),
                                                                      ]
                                                                    : null,
                                                          ),
                                                          child: Text(
                                                            AppLocalizations.of(
                                                                    context)!
                                                                .monthly,
                                                            style: AppTextStyles
                                                                .bodySmall(
                                                              color: AppColors
                                                                  .foreground,
                                                            ).copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Stats - matches React: gap-8 mb-6
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 24), // mb-6
                                            child: Row(
                                              children: [
                                                // Lessons count
                                                RichText(
                                                  text: TextSpan(
                                                    children: [
                                                      TextSpan(
                                                        text:
                                                            '${_displayCompletedLessons} ',
                                                        style: AppTextStyles.h1(
                                                          color: AppColors
                                                              .foreground,
                                                        ),
                                                      ),
                                                      TextSpan(
                                                        text:
                                                            AppLocalizations.of(
                                                                    context)!
                                                                .lesson,
                                                        style: AppTextStyles
                                                            .bodyMedium(
                                                          color: AppColors
                                                              .mutedForeground,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(
                                                    width: 32), // gap-8
                                                // Hours count
                                                RichText(
                                                  text: TextSpan(
                                                    children: [
                                                      TextSpan(
                                                        text: '${_displayHours} ',
                                                        style: AppTextStyles.h1(
                                                          color: AppColors
                                                              .foreground,
                                                        ),
                                                      ),
                                                      TextSpan(
                                                        text:
                                                            AppLocalizations.of(
                                                                    context)!
                                                                .hour,
                                                        style: AppTextStyles
                                                            .bodyMedium(
                                                          color: AppColors
                                                              .mutedForeground,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Horizontal bar chart - matches React HorizontalBarChart
                                          _buildHorizontalBarChart(),
                                          const SizedBox(height: 12),
                                          _buildCourseProgressTracker(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16), // space-y-4

                                    // Transformation System (Before / After + indicators + score)
                                    _buildTransformationSection(),
                                    const SizedBox(height: 16), // space-y-4
                                    _buildInsightsSection(),
                                    const SizedBox(height: 16), // space-y-4

                                    // Rating of students - matches React: bg-white rounded-3xl p-5 shadow-sm
                                    Container(
                                      padding: const EdgeInsets.all(20), // p-5
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                            24), // rounded-3xl
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 40, // w-10
                                                height: 40, // h-10
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      Colors.yellow[300]!,
                                                      Colors.yellow[600]!,
                                                    ],
                                                  ),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Center(
                                                  child: Text('⭐',
                                                      style: TextStyle(
                                                          fontSize: 18)),
                                                ),
                                              ),
                                              const SizedBox(
                                                  width: 12), // gap-3
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    AppLocalizations.of(
                                                            context)!
                                                        .studentRating,
                                                    style: AppTextStyles
                                                        .bodyMedium(
                                                      color:
                                                          AppColors.foreground,
                                                    ).copyWith(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  Text(
                                                    AppLocalizations.of(
                                                            context)!
                                                        .top10Students,
                                                    style:
                                                        AppTextStyles.bodySmall(
                                                      color: AppColors
                                                          .mutedForeground,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                '• • •',
                                                style: AppTextStyles.bodyMedium(
                                                  color:
                                                      AppColors.mutedForeground,
                                                ),
                                              ),
                                              const SizedBox(width: 8), // mr-2
                                              // Student avatars - matches React: flex -space-x-2
                                              SizedBox(
                                                width:
                                                    72, // 3 circles with overlap
                                                height: 32,
                                                child: Stack(
                                                  children: _topStudents
                                                      .take(3)
                                                      .toList()
                                                      .asMap()
                                                      .entries
                                                      .map((entry) {
                                                    final index = entry.key;
                                                    final student = entry.value;
                                                    final avatarUrl =
                                                        student['avatar']
                                                            as String?;
                                                    return Positioned(
                                                      left: index * 16.0,
                                                      child: Container(
                                                        width: 32, // w-8
                                                        height: 32, // h-8
                                                        decoration:
                                                            BoxDecoration(
                                                          color: AppColors
                                                              .orangeLight,
                                                          shape:
                                                              BoxShape.circle,
                                                          border: Border.all(
                                                            color: Colors.white,
                                                            width: 2,
                                                          ),
                                                        ),
                                                        child: ClipOval(
                                                          child: avatarUrl !=
                                                                      null &&
                                                                  avatarUrl
                                                                      .isNotEmpty
                                                              ? Image.network(
                                                                  avatarUrl,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                  errorBuilder: (context,
                                                                          error,
                                                                          stackTrace) =>
                                                                      const Icon(
                                                                    Icons
                                                                        .person,
                                                                    size: 16,
                                                                    color: AppColors
                                                                        .purple,
                                                                  ),
                                                                )
                                                              : Image.asset(
                                                                  'assets/images/user-avatar.png',
                                                                  fit: BoxFit
                                                                      .cover,
                                                                  errorBuilder: (context,
                                                                          error,
                                                                          stackTrace) =>
                                                                      const Icon(
                                                                    Icons
                                                                        .person,
                                                                    size: 16,
                                                                    color: AppColors
                                                                        .purple,
                                                                  ),
                                                                ),
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16), // space-y-4

                                    // My exams button - matches React: w-full bg-white rounded-3xl p-5
                                    GestureDetector(
                                      onTap: () =>
                                          context.push(RouteNames.myExams),
                                      child: Container(
                                        padding:
                                            const EdgeInsets.all(20), // p-5
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                              24), // rounded-3xl
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.05),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 48, // w-12
                                              height: 48, // h-12
                                              decoration: BoxDecoration(
                                                color: AppColors.orange
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        16), // rounded-2xl
                                              ),
                                              child: const Icon(
                                                Icons.description,
                                                size: 24, // w-6 h-6
                                                color: AppColors.orange,
                                              ),
                                            ),
                                            const SizedBox(width: 16), // gap-4
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    AppLocalizations.of(
                                                            context)!
                                                        .myExamsButton,
                                                    style: AppTextStyles
                                                        .bodyMedium(
                                                      color:
                                                          AppColors.foreground,
                                                    ).copyWith(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  Text(
                                                    AppLocalizations.of(
                                                            context)!
                                                        .viewAllCompletedExams,
                                                    style:
                                                        AppTextStyles.bodySmall(
                                                      color: AppColors
                                                          .mutedForeground,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Transform.rotate(
                                              angle:
                                                  1.5708, // 90 degrees = -90deg in React
                                              child: const Icon(
                                                Icons.keyboard_arrow_down,
                                                size: 20, // w-5 h-5
                                                color:
                                                    AppColors.mutedForeground,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    const SizedBox(
                                        height: 150), // Space for bottom nav
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
            ),

            // Bottom Navigation
            const BottomNav(activeTab: 'progress'),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final user = _progressData?['user'] as Map<String, dynamic>?;
    final userName = user?['name'] as String? ?? '';
    final userAvatar = user?['avatar'] as String?;
    final overallProgress = (user?['overall_progress'] as num?)?.toInt() ?? 76;

    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 48, // w-12
                  height: 48, // h-12
                  decoration: const BoxDecoration(
                    color: AppColors.orangeLight,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: userAvatar != null && userAvatar.isNotEmpty
                        ? Image.network(
                            userAvatar,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset(
                              'assets/images/user-avatar.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.person,
                                      color: AppColors.purple),
                            ),
                          )
                        : Image.asset(
                            'assets/images/user-avatar.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.person, color: AppColors.purple),
                          ),
                  ),
                ),
                const SizedBox(width: 12), // gap-3
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userName.isNotEmpty
                            ? 'مرحباً، $userName'
                            : AppLocalizations.of(context)!.helloJacob,
                        style: AppTextStyles.h4(color: AppColors.foreground),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.flash_on,
                            size: 16, // w-4 h-4
                            color: AppColors.orange,
                          ),
                          const SizedBox(width: 4), // gap-1
                          Flexible(
                            child: Text(
                              AppLocalizations.of(context)!
                                  .progressPercent(overallProgress),
                              style: AppTextStyles.bodySmall(
                                color: AppColors.mutedForeground,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44, // w-11
                  height: 44, // h-11
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.verified_user,
                    size: 20, // w-5 h-5
                    color: AppColors.purple,
                  ),
                ),
                const SizedBox(width: 8), // gap-2
                GestureDetector(
                  onTap: () => context.push(RouteNames.notifications),
                  child: Container(
                    width: 44, // w-11
                    height: 44, // h-11
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        const Center(
                          child: Icon(
                            Icons.notifications,
                            size: 20, // w-5 h-5
                            color: AppColors.foreground,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 8, // w-2
                            height: 8, // h-2
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalBarChart() {
    final dataSource = _buildAnalyticalChartData();
    if (dataSource.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxValue = dataSource
        .map((d) => (d['value'] as num?)?.toInt() ?? 0)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: dataSource.map((data) {
        final value = (data['value'] as num?)?.toInt() ?? 0;
        final stripes = data['stripes'] as bool? ?? false;
        final progress = maxValue > 0 ? value / maxValue : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  data['day'] as String,
                  style: AppTextStyles.labelSmall(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerRight,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: stripes ? null : AppColors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: stripes
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CustomPaint(
                                painter: _StripePainter(),
                                child: Container(),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 30,
                child: Text(
                  '$value',
                  style: AppTextStyles.labelSmall(
                    color: AppColors.foreground,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCourseProgressTracker() {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final completed = _displayCompletedLessons;
    final total = _displayTotalLessons;
    final progress = _displayProgressPercent.clamp(0, 100);
    final ratio = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
    final milestone = progress >= 100
        ? (isAr ? 'مكتمل' : 'Completed')
        : progress >= 75
            ? (isAr ? 'متقدم' : 'Advanced')
            : progress >= 40
                ? (isAr ? 'مستمر' : 'In progress')
                : (isAr ? 'بداية' : 'Started');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isAr ? 'متتبع الإنجاز' : 'Achievement tracker',
                style: AppTextStyles.bodyMedium(
                  color: AppColors.foreground,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '$completed/$total',
                style: AppTextStyles.bodySmall(
                  color: AppColors.mutedForeground,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: ratio,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAr
                ? 'نسبة التقدم: $progress% - المرحلة: $milestone'
                : 'Progress: $progress% - Stage: $milestone',
            style: AppTextStyles.bodySmall(color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }

  int _intFrom(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  double _doubleFrom(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  Widget _buildTransformationSection() {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    // Optional backend support (if present in the future)
    final tf = _progressData?['transformation'];
    final tfMap = tf is Map ? Map<String, dynamic>.from(tf) : null;

    final beforeText = tfMap?['before']?.toString().trim();
    final afterText = tfMap?['after']?.toString().trim();

    final rawScore = tfMap?['score'] ?? tfMap?['transformation_score'];

    // Fallback: derive a simple score from existing progress statistics (0..100)
    final stats = _progressData?['statistics'];
    final statsMap = stats is Map ? Map<String, dynamic>.from(stats) : null;
    final completedLessons = _intFrom(
      statsMap?['completed_lessons'] ?? statsMap?['lessons_completed'],
    );
    final totalLessons = _intFrom(
      statsMap?['total_lessons'] ?? statsMap?['lessons_total'],
    );
    final completionRate =
        totalLessons > 0 ? (completedLessons / totalLessons) : 0.0;

    final score = rawScore != null
        ? _doubleFrom(rawScore).clamp(0.0, 100.0)
        : (completionRate * 100.0).clamp(0.0, 100.0);

    final indicators = <Map<String, dynamic>>[
      {
        'label': isAr ? 'الالتزام' : 'Commitment',
        'value': (tfMap?['commitment'] != null)
            ? _doubleFrom(tfMap?['commitment']).clamp(0.0, 1.0)
            : completionRate.clamp(0.0, 1.0),
        'color': AppColors.primary,
      },
      {
        'label': isAr ? 'الاستمرارية' : 'Consistency',
        'value': (tfMap?['consistency'] != null)
            ? _doubleFrom(tfMap?['consistency']).clamp(0.0, 1.0)
            : (_chartData.isNotEmpty ? 0.65 : 0.45),
        'color': AppColors.orange,
      },
      {
        'label': isAr ? 'النتائج' : 'Results',
        'value': (tfMap?['results'] != null)
            ? _doubleFrom(tfMap?['results']).clamp(0.0, 1.0)
            : (score / 100.0).clamp(0.0, 1.0),
        'color': const Color(0xFF10B981),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'نظام التحول' : 'Transformation',
                        style: AppTextStyles.bodyMedium(
                          color: AppColors.foreground,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isAr
                            ? 'قبل / بعد + مؤشرات + درجة'
                            : 'Before/After + indicators + score',
                        style: AppTextStyles.bodySmall(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${score.toStringAsFixed(0)}/100',
                  style: AppTextStyles.bodySmall(
                    color: Colors.white,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Before / After tracking
          Row(
            children: [
              Expanded(
                child: _tfNoteCard(
                  title: isAr ? 'قبل' : 'Before',
                  icon: Icons.history_rounded,
                  color: AppColors.orange,
                  text: beforeText ??
                      (isAr
                          ? 'اكتب وضعك قبل بداية الدورة (ملاحظة قصيرة)'
                          : 'Write your state before starting (short note)'),
                  isPlaceholder: beforeText == null || beforeText.isEmpty,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _tfNoteCard(
                  title: isAr ? 'بعد' : 'After',
                  icon: Icons.rocket_launch_rounded,
                  color: const Color(0xFF10B981),
                  text: afterText ??
                      (isAr
                          ? 'اكتب ماذا تغير بعد الدورة (ملاحظة قصيرة)'
                          : 'Write what changed after the course (short note)'),
                  isPlaceholder: afterText == null || afterText.isEmpty,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Indicators
          ...indicators.map((i) {
            final v = (i['value'] as double?)?.clamp(0.0, 1.0) ?? 0.0;
            final label = i['label']?.toString() ?? '';
            final color = i['color'] as Color? ?? AppColors.primary;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.bodySmall(
                          color: AppColors.foreground,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(
                        '${(v * 100).toStringAsFixed(0)}%',
                        style: AppTextStyles.bodySmall(
                          color: AppColors.mutedForeground,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: v,
                      backgroundColor: Colors.grey[100],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                String? courseId = tfMap?['course_id']?.toString() ??
                    tfMap?['courseId']?.toString();
                courseId ??= _progressData?['course_id']?.toString() ??
                    _progressData?['courseId']?.toString();
                final enr = _progressData?['enrollment'];
                if ((courseId == null || courseId.isEmpty) && enr is Map) {
                  final m = Map<String, dynamic>.from(enr);
                  courseId = m['course_id']?.toString();
                  final c = m['course'];
                  if ((courseId == null || courseId.isEmpty) && c is Map) {
                    courseId = c['id']?.toString();
                  }
                }
                if (courseId != null && courseId.isNotEmpty) {
                  final title = tfMap?['course_title']?.toString() ??
                      tfMap?['courseTitle']?.toString() ??
                      '';
                  context.push(
                    RouteNames.courseTransformation,
                    extra: {
                      'courseId': courseId,
                      'courseTitle': title,
                    },
                  );
                  return;
                }
                context.push(RouteNames.enrolled);
              },
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: Text(
                isAr ? 'تحديث بيانات التحول' : 'Update transformation',
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tfNoteCard({
    required String title,
    required IconData icon,
    required Color color,
    required String text,
    required bool isPlaceholder,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.bodySmall(
                  color: AppColors.foreground,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall(
              color: isPlaceholder ? AppColors.mutedForeground : AppColors.foreground,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _insightPreviewText(Map<String, dynamic>? raw, String fallback) {
    if (raw == null || raw.isEmpty) return fallback;
    final report = raw['report']?.toString().trim();
    if (report != null && report.isNotEmpty) return report;
    final sections = raw['sections'];
    if (sections is List && sections.isNotEmpty) {
      final first = sections.first;
      if (first is Map) {
        final body = first['body']?.toString().trim();
        if (body != null && body.isNotEmpty) return body;
      }
    }
    return fallback;
  }

  Widget _buildInsightsSection() {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final cosmicText = _insightPreviewText(
      _cosmicInsight,
      isAr ? 'لا توجد بصمة كونية محفوظة بعد.' : 'No saved cosmic imprint yet.',
    );
    final colorText = _insightPreviewText(
      _colorInsight,
      isAr
          ? 'لا يوجد تحليل عاطفي للألوان محفوظ بعد.'
          : 'No saved color emotional analysis yet.',
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'تحليلات الوعي' : 'Insights Analysis',
                      style: AppTextStyles.bodyMedium(
                        color: AppColors.foreground,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isAr
                          ? 'البصمة الكونية + التحليل العاطفي للألوان'
                          : 'Cosmic imprint + color emotional analysis',
                      style: AppTextStyles.bodySmall(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _insightMiniCard(
            title: isAr ? 'البصمة الكونية' : 'Cosmic imprint',
            icon: Icons.auto_awesome_rounded,
            text: cosmicText,
            color: AppColors.primary,
          ),
          const SizedBox(height: 10),
          _insightMiniCard(
            title: isAr ? 'العاطفة اللونية' : 'Color emotional',
            icon: Icons.palette_rounded,
            text: colorText,
            color: AppColors.orange,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.push(RouteNames.wellnessAnalysis),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(
                isAr ? 'فتح شاشة التحليل' : 'Open analysis screen',
              ),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightMiniCard({
    required String title,
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodySmall(
                    color: AppColors.foreground,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.orange
      ..style = PaintingStyle.fill;

    final stripePaint = Paint()
      ..color = AppColors.orange.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(12),
      ),
      stripePaint,
    );

    // Stripes
    const stripeWidth = 8.0;
    const gap = 8.0;
    for (double x = -size.height;
        x < size.width + size.height;
        x += stripeWidth + gap) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + stripeWidth, size.height)
        ..lineTo(x + stripeWidth + size.height, 0)
        ..lineTo(x + size.height, 0)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
