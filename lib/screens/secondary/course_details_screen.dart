import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../core/design/app_colors.dart';
import '../../core/navigation/route_names.dart';
import '../../services/courses_service.dart';
import '../../services/exams_service.dart';
import '../../core/api/api_client.dart';
import '../../services/wishlist_service.dart';
import '../../services/profile_service.dart';

/// Modern Course Details Screen with Beautiful UI
class CourseDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? course;

  const CourseDetailsScreen({super.key, this.course});

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _selectedLessonIndex = 0;
  bool _isLoading = false;
  bool _isEnrolling = false;
  bool _isEnrolled = false;
  Map<String, dynamic>? _courseData;
  List<Map<String, dynamic>> _courseExams = [];
  bool _isLoadingExams = false;
  bool _isInWishlist = false;
  bool _isTogglingWishlist = false;
  bool _isViewingOwnCourse = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCourseDetails();
    _checkWishlistStatus();
  }

  Future<void> _loadCourseDetails() async {
    // If course data is already provided, use it
    if (widget.course != null && widget.course!['id'] != null) {
      final courseId = widget.course!['id']?.toString();
      if (courseId != null && courseId.isNotEmpty) {
        setState(() => _isLoading = true);
        try {
          final courseDetails =
              await CoursesService.instance.getCourseDetails(courseId);

          // Print detailed response
          if (kDebugMode) {
            print(
                '═══════════════════════════════════════════════════════════');
            print('📋 COURSE DETAILS RESPONSE (getCourseDetails)');
            print(
                '═══════════════════════════════════════════════════════════');
            print('Course ID: $courseId');
            print('Response Type: ${courseDetails.runtimeType}');
            print('Response Keys: ${courseDetails.keys.toList()}');
            print(
                '───────────────────────────────────────────────────────────');
            print('Full Response JSON:');
            try {
              const encoder = JsonEncoder.withIndent('  ');
              print(encoder.convert(courseDetails));
            } catch (e) {
              print('Could not convert to JSON: $e');
              print('Raw Response: $courseDetails');
            }
            print(
                '───────────────────────────────────────────────────────────');
            print('Key Fields:');
            print('  - id: ${courseDetails['id']}');
            print('  - title: ${courseDetails['title']}');
            print('  - price: ${courseDetails['price']}');
            print('  - is_free: ${courseDetails['is_free']}');
            print('  - is_enrolled: ${courseDetails['is_enrolled']}');
            print('  - is_in_wishlist: ${courseDetails['is_in_wishlist']}');
            print('  - rating: ${courseDetails['rating']}');
            print('  - students_count: ${courseDetails['students_count']}');
            print('  - duration_hours: ${courseDetails['duration_hours']}');
            print(
                '  - curriculum length: ${(courseDetails['curriculum'] as List?)?.length ?? 0}');
            print(
                '  - lessons length: ${(courseDetails['lessons'] as List?)?.length ?? 0}');
            print(
                '───────────────────────────────────────────────────────────');
            print('📚 CURRICULUM DETAILS:');
            final curriculum = courseDetails['curriculum'] as List?;
            if (curriculum != null && curriculum.isNotEmpty) {
              print('  Total Items: ${curriculum.length}');

              // First, show summary of all topics
              print('');
              print('📁 ALL TOPICS FROM API:');
              print(
                  '═══════════════════════════════════════════════════════════');
              int topicCount = 0;
              for (int i = 0; i < curriculum.length; i++) {
                final item = curriculum[i];
                if (item is Map) {
                  // Check if this is a topic (has lessons field, even if empty)
                  // A topic is identified by having a 'lessons' field (can be empty list)
                  // OR by not having video/youtube_id fields (which indicate it's a lesson)
                  final nestedLessons = item['lessons'] as List?;
                  final hasVideo = item['video'] != null;
                  final hasYoutubeId = item['youtube_id'] != null ||
                      item['youtubeVideoId'] != null;

                  // It's a topic if:
                  // 1. It has a 'lessons' field (even if empty), OR
                  // 2. It doesn't have video/youtube_id (meaning it's a container, not a lesson)
                  final isTopic =
                      nestedLessons != null || (!hasVideo && !hasYoutubeId);

                  if (isTopic) {
                    topicCount++;
                    final lessonsCount = nestedLessons?.length ?? 0;
                    print('📁 TOPIC $topicCount:');
                    print('  - ID: ${item['id']}');
                    print('  - Title: ${item['title']}');
                    print('  - Order: ${item['order']}');
                    print('  - Type: ${item['type']}');
                    print('  - Lessons Count: $lessonsCount');
                    print('  - Duration Minutes: ${item['duration_minutes']}');
                    print('  - Has Lessons Field: ${nestedLessons != null}');
                    print('  - All Topic Keys: ${item.keys.toList()}');

                    // If it has lessons, show them
                    if (nestedLessons != null && nestedLessons.isNotEmpty) {
                      print('  - Lessons:');
                      for (int j = 0; j < nestedLessons.length; j++) {
                        final lesson = nestedLessons[j];
                        if (lesson is Map) {
                          print(
                              '      Lesson ${j + 1}: ${lesson['title'] ?? lesson['id']}');
                        }
                      }
                    } else if (nestedLessons != null && nestedLessons.isEmpty) {
                      print('  - ⚠️ This topic has an empty lessons array');
                    } else {
                      print('  - ⚠️ This topic does not have a lessons field');
                    }
                    print('');
                  }
                }
              }
              print(
                  '═══════════════════════════════════════════════════════════');
              print('Total Topics Found: $topicCount');
              print('Total Curriculum Items: ${curriculum.length}');
              print(
                  '═══════════════════════════════════════════════════════════');
              print('');

              // Then show all items in detail
              print('📋 ALL CURRICULUM ITEMS (DETAILED):');
              for (int i = 0; i < curriculum.length; i++) {
                final item = curriculum[i];
                if (item is Map) {
                  print(
                      '───────────────────────────────────────────────────────────');
                  print('  Item ${i + 1}:');
                  print('    - id: ${item['id']}');
                  print('    - title: ${item['title']}');
                  print('    - order: ${item['order']}');
                  print('    - type: ${item['type']}');
                  print('    - video: ${item['video']}');
                  print('    - youtube_id: ${item['youtube_id']}');
                  print('    - youtubeVideoId: ${item['youtubeVideoId']}');
                  print('    - duration_minutes: ${item['duration_minutes']}');
                  print('    - is_locked: ${item['is_locked']}');
                  print('    - is_completed: ${item['is_completed']}');
                  if (item['lessons'] != null) {
                    final lessonsList = item['lessons'] as List?;
                    print('    - has lessons: ${lessonsList?.length ?? 0}');
                    if (lessonsList != null && lessonsList.isNotEmpty) {
                      print('    - Lessons in this topic:');
                      for (int j = 0; j < lessonsList.length; j++) {
                        final lesson = lessonsList[j];
                        if (lesson is Map) {
                          print('      Lesson ${j + 1}:');
                          print('        - id: ${lesson['id']}');
                          print('        - title: ${lesson['title']}');
                          print('        - type: ${lesson['type']}');
                        }
                      }
                    }
                  }
                  print('    - All Keys: ${item.keys.toList()}');

                  // Print full JSON for topics
                  final nestedLessons = item['lessons'] as List?;
                  if (nestedLessons != null && nestedLessons.isNotEmpty) {
                    try {
                      const encoder = JsonEncoder.withIndent('    ');
                      print('    - Full Topic JSON:');
                      print(encoder.convert(item));
                    } catch (e) {
                      print('    - Could not convert topic to JSON: $e');
                    }
                  }
                }
              }
            } else {
              print('  Curriculum is empty or null');
            }
            print(
                '───────────────────────────────────────────────────────────');
            print('📖 LESSONS DETAILS:');
            final lessons = courseDetails['lessons'] as List?;
            if (lessons != null && lessons.isNotEmpty) {
              print('  Total Lessons: ${lessons.length}');
              for (int i = 0; i < lessons.length && i < 3; i++) {
                final lesson = lessons[i];
                if (lesson is Map) {
                  print('  Lesson $i:');
                  print('    - id: ${lesson['id']}');
                  print('    - title: ${lesson['title']}');
                  print('    - video: ${lesson['video']}');
                  print('    - All Keys: ${lesson.keys.toList()}');
                }
              }
            } else {
              print('  Lessons is empty or null');
            }
            print(
                '═══════════════════════════════════════════════════════════');
          }

          setState(() {
            _courseData = courseDetails;
            _isEnrolled = courseDetails['is_enrolled'] == true;
            _isInWishlist = courseDetails['is_in_wishlist'] == true;
            _isLoading = false;
          });
          _loadCourseExams();
          _checkWishlistStatus();
          _checkIfViewingOwnCourse(courseDetails);
        } catch (e) {
          if (kDebugMode) {
            print(
                '═══════════════════════════════════════════════════════════');
            print('❌ ERROR LOADING COURSE DETAILS');
            print(
                '═══════════════════════════════════════════════════════════');
            print('Course ID: $courseId');
            print('Error: $e');
            print('Error Type: ${e.runtimeType}');
            print(
                '═══════════════════════════════════════════════════════════');
          }
          setState(() {
            _courseData = widget.course; // Fallback to provided course
            _isLoading = false;
          });
          _checkIfViewingOwnCourse(widget.course);
        }
      } else {
        setState(() {
          _courseData = widget.course;
        });
        _checkIfViewingOwnCourse(widget.course);
      }
    } else {
      setState(() {
        _courseData = widget.course;
      });
      _checkIfViewingOwnCourse(widget.course);
    }
  }

  Future<void> _checkIfViewingOwnCourse(Map<String, dynamic>? course) async {
    if (course == null) return;
    final instructorId = course['instructor_id']?.toString() ??
        course['instructorId']?.toString() ??
        (course['instructor'] is Map
            ? (course['instructor'] as Map)['id']?.toString()
            : null);
    if (instructorId == null || instructorId.isEmpty) return;
    try {
      final profile = await ProfileService.instance.getProfile();
      final myId = profile['id']?.toString();
      if (myId != null && myId == instructorId && mounted) {
        setState(() => _isViewingOwnCourse = true);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _getFirstLesson() {
    final course = _courseData ?? widget.course;
    final curriculum = course?['curriculum'] as List?;
    final lessons = course?['lessons'] as List?;
    Map<String, dynamic>? firstLesson;

    if (curriculum != null && curriculum.isNotEmpty) {
      for (var item in curriculum) {
        if (item is Map<String, dynamic>) {
          // Check if this item has nested lessons (it's a topic/section)
          final nestedLessons = item['lessons'] as List?;
          if (nestedLessons != null && nestedLessons.isNotEmpty) {
            // Use first nested lesson
            final nestedLesson = nestedLessons[0];
            if (nestedLesson is Map<String, dynamic>) {
              firstLesson = nestedLesson;
              break;
            }
          } else {
            // This item is a lesson itself (has video or id)
            if (item['video'] != null ||
                item['id'] != null ||
                item['youtube_id'] != null ||
                item['youtubeVideoId'] != null) {
              firstLesson = item;
              break;
            }
          }
        }
      }
    }

    // If no lesson from curriculum, use lessons directly
    if (firstLesson == null && lessons != null && lessons.isNotEmpty) {
      final lesson = lessons[0];
      if (lesson is Map<String, dynamic>) {
        firstLesson = lesson;
      }
    }

    return firstLesson;
  }

  void _playLesson(int index, Map<String, dynamic> lesson) async {
    if (kDebugMode) {
      print('═══════════════════════════════════════════════════════════');
      print('▶️ NAVIGATING TO LESSON');
      print('═══════════════════════════════════════════════════════════');
      print('Lesson Index: $index');
      print('Lesson ID: ${lesson['id']}');
      print('Lesson Title: ${lesson['title']}');
      print('All Lesson Keys: ${lesson.keys.toList()}');
      print('═══════════════════════════════════════════════════════════');
    }

    setState(() {
      _selectedLessonIndex = index;
    });

    // Navigate to lesson viewer screen
    if (mounted) {
      final course = _courseData ?? widget.course;
      final courseId = course?['id']?.toString();
      context.push(RouteNames.lessonViewer, extra: {
        'lesson': lesson,
        'courseId': courseId,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = _courseData ?? widget.course;

    if (_isLoading && _courseData == null) {
      return Scaffold(
        backgroundColor: AppColors.beige,
        body: _buildSkeleton(),
      );
    }

    if (course == null) {
      return Scaffold(
        backgroundColor: AppColors.beige,
        appBar: AppBar(
          title: const Text('تفاصيل الدورة'),
        ),
        body: Center(
          child: Text(
            'لا توجد بيانات للدورة',
            style: GoogleFonts.cairo(),
          ),
        ),
      );
    }

    final isFree = course['is_free'] == true || course['isFree'] == true;

    // Safely parse price
    num priceValue = 0.0;
    if (course['price'] != null) {
      if (course['price'] is num) {
        priceValue = course['price'] as num;
      } else if (course['price'] is String) {
        priceValue = num.tryParse(course['price'] as String) ?? 0.0;
      }
    }
    final isFreeFromPrice = priceValue == 0;
    final finalIsFree = isFree || isFreeFromPrice;

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.beige,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Video Player Section
              _buildVideoSection(),

              // Content Section - Scrollable
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  children: [
                    // Course Info Header
                    _buildCourseHeader(course, finalIsFree, priceValue),

                    // Tabs
                    _buildTabs(),

                    // Tab Content
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildLessonsTab(),
                          _buildAboutTab(course),
                          _buildExamsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // Bottom Action Button
      bottomNavigationBar: _buildBottomBar(course, finalIsFree),
    );
  }

  Widget _buildVideoSection() {
    final course = _courseData ?? widget.course;
    // Get thumbnail image
    final thumbnail = course?['thumbnail']?.toString() ??
        course?['image']?.toString() ??
        course?['banner']?.toString();

    return Container(
      height: 220,
      color: Colors.black,
      child: Stack(
        children: [
          // Thumbnail Image
          if (thumbnail != null && thumbnail.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.purple.withOpacity(0.1),
                  child: const Center(
                    child: Icon(
                      Icons.image,
                      color: AppColors.purple,
                      size: 50,
                    ),
                  ),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.black,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.purple,
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              color: AppColors.purple.withOpacity(0.1),
              child: const Center(
                child: Icon(
                  Icons.image,
                  color: AppColors.purple,
                  size: 50,
                ),
              ),
            ),

          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ),

          // Play Button Overlay (if enrolled)
          if (_isEnrolled)
            Positioned.fill(
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    // Navigate to first lesson
                    final firstLesson = _getFirstLesson();
                    if (firstLesson != null && mounted) {
                      final course = _courseData ?? widget.course;
                      final courseId = course?['id']?.toString();
                      context.push(RouteNames.lessonViewer, extra: {
                        'lesson': firstLesson,
                        'courseId': courseId,
                      });
                    }
                  },
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.purple,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),

          // Top Bar
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _isTogglingWishlist ? null : _toggleWishlist,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _isTogglingWishlist
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Icon(
                                _isInWishlist
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.share_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseHeader(
      Map<String, dynamic>? course, bool isFree, num price) {
    if (course == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Badge & Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  course['category'] is Map
                      ? (course['category'] as Map)['name']?.toString() ??
                          'التصميم'
                      : course['category']?.toString() ?? 'التصميم',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.purple,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isFree
                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                        : [const Color(0xFFF97316), const Color(0xFFEA580C)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isFree ? 'مجاني' : '${price.toInt()} ج.م',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            course['title']?.toString() ?? 'عنوان الدورة',
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 8),

          // Instructor
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.purple.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.person, size: 16, color: AppColors.purple),
              ),
              const SizedBox(width: 8),
              Text(
                course['instructor'] is Map
                    ? (course['instructor'] as Map)['name']?.toString() ??
                        'المدرب'
                    : course['instructor']?.toString() ?? 'المدرب',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: AppColors.purple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stats Row
          Row(
            children: [
              _buildStatChip(
                Icons.star_rounded,
                _safeParseRating(course['rating']),
                Colors.amber,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                Icons.people_rounded,
                _safeParseCount(course['students_count'] ?? course['students']),
                AppColors.purple,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                Icons.access_time_rounded,
                '${_safeParseHours(course['duration_hours'] ?? course['hours'])}س',
                const Color(0xFF10B981),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.mutedForeground,
        labelStyle:
            GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.cairo(fontSize: 13),
        padding: const EdgeInsets.all(4),
        tabs: const [
          Tab(text: 'الدروس'),
          Tab(text: 'نبذة'),
          Tab(text: 'الاختبارات'),
        ],
      ),
    );
  }

  String _safeParseRating(dynamic rating) {
    if (rating == null) return '0.0';
    if (rating is num) return rating.toStringAsFixed(1);
    if (rating is String) {
      final parsed = num.tryParse(rating);
      return parsed?.toStringAsFixed(1) ?? '0.0';
    }
    return '0.0';
  }

  String _safeParseCount(dynamic count) {
    if (count == null) return '0';
    if (count is int) return count.toString();
    if (count is num) return count.toInt().toString();
    if (count is String) {
      final parsed = int.tryParse(count);
      return parsed?.toString() ?? '0';
    }
    return '0';
  }

  int _safeParseHours(dynamic hours) {
    if (hours == null) return 0;
    if (hours is int) return hours;
    if (hours is num) return hours.toInt();
    if (hours is String) {
      final parsed = int.tryParse(hours);
      return parsed ?? 0;
    }
    return 0;
  }

  Widget _buildLessonsTab() {
    final course = _courseData ?? widget.course;
    // Try curriculum first, then lessons
    final curriculum = course?['curriculum'] as List?;
    final lessons = course?['lessons'] as List?;

    // Build hierarchical structure: topics with nested lessons
    final List<Map<String, dynamic>> topicsWithLessons = [];
    final List<Map<String, dynamic>> flatLessonsList = [];

    // First, try to get lessons from curriculum
    if (curriculum != null && curriculum.isNotEmpty) {
      for (var item in curriculum) {
        if (item is Map<String, dynamic>) {
          // Check if this item has nested lessons (it's a topic/section)
          final nestedLessons = item['lessons'] as List?;
          final hasVideo = item['video'] != null;
          final hasYoutubeId =
              item['youtube_id'] != null || item['youtubeVideoId'] != null;

          // It's a topic if it has lessons field (even if empty) OR doesn't have video/youtube_id
          final isTopic = nestedLessons != null || (!hasVideo && !hasYoutubeId);

          if (isTopic) {
            // This is a topic - add it even if it has no lessons
            final topicLessons = <Map<String, dynamic>>[];
            if (nestedLessons != null && nestedLessons.isNotEmpty) {
              for (var nestedLesson in nestedLessons) {
                if (nestedLesson is Map<String, dynamic>) {
                  topicLessons.add(nestedLesson);
                  // Add to flat list for indexing
                  flatLessonsList.add(nestedLesson);
                }
              }
            }
            // Add topic even if it has no lessons (empty array or null)
            topicsWithLessons.add({
              'is_topic': true,
              'topic': item,
              'lessons': topicLessons,
            });
          } else {
            // This item is a lesson itself (has video or id)
            if (hasVideo || item['id'] != null || hasYoutubeId) {
              flatLessonsList.add(item);
              topicsWithLessons.add({
                'is_topic': false,
                'lesson': item,
              });
            }
          }
        }
      }
    }

    // If no lessons from curriculum, use lessons directly
    if (topicsWithLessons.isEmpty && lessons != null && lessons.isNotEmpty) {
      for (var lesson in lessons) {
        if (lesson is Map<String, dynamic>) {
          flatLessonsList.add(lesson);
          topicsWithLessons.add({
            'is_topic': false,
            'lesson': lesson,
          });
        }
      }
    }

    if (kDebugMode) {
      print('═══════════════════════════════════════════════════════════');
      print('📚 BUILDING LESSONS TAB');
      print('═══════════════════════════════════════════════════════════');
      print('Curriculum items: ${curriculum?.length ?? 0}');
      print('Lessons items: ${lessons?.length ?? 0}');
      print('Topics with lessons: ${topicsWithLessons.length}');
      print('Total flat lessons: ${flatLessonsList.length}');

      // Count topics
      int topicCount = 0;
      int standaloneLessonCount = 0;
      for (var item in topicsWithLessons) {
        if (item['is_topic'] == true) {
          topicCount++;
        } else {
          standaloneLessonCount++;
        }
      }

      print('');
      print('📊 SUMMARY:');
      print('  - Total Topics: $topicCount');
      print('  - Standalone Lessons: $standaloneLessonCount');
      print('  - Total Items: ${topicsWithLessons.length}');
      print('');

      // Show ALL topics from curriculum (even if they have no lessons)
      if (curriculum != null && curriculum.isNotEmpty) {
        print('📁 ALL TOPICS FROM CURRICULUM (COMPLETE LIST):');
        print('═══════════════════════════════════════════════════════════');
        int allTopicsCount = 0;
        for (int i = 0; i < curriculum.length; i++) {
          final item = curriculum[i];
          if (item is Map<String, dynamic>) {
            final nestedLessons = item['lessons'] as List?;
            final hasVideo = item['video'] != null;
            final hasYoutubeId =
                item['youtube_id'] != null || item['youtubeVideoId'] != null;

            // It's a topic if it has lessons field OR doesn't have video/youtube_id
            final isTopic =
                nestedLessons != null || (!hasVideo && !hasYoutubeId);

            if (isTopic) {
              allTopicsCount++;
              final lessonsCount = nestedLessons?.length ?? 0;
              print('📁 TOPIC $allTopicsCount:');
              print('  - ID: ${item['id']}');
              print('  - Title: ${item['title']}');
              print('  - Order: ${item['order']}');
              print('  - Type: ${item['type']}');
              print('  - Lessons Count: $lessonsCount');
              print('  - Has Lessons Field: ${nestedLessons != null}');
              if (nestedLessons == null) {
                print('  - ⚠️ No lessons field found');
              } else if (nestedLessons.isEmpty) {
                print('  - ⚠️ Empty lessons array');
              }
              print('  - All Keys: ${item.keys.toList()}');
              print('');
            }
          }
        }
        print('═══════════════════════════════════════════════════════════');
        print('Total Topics in Curriculum: $allTopicsCount');
        print('═══════════════════════════════════════════════════════════');
        print('');
      }

      // Show all topics summary (only topics that have lessons)
      if (topicCount > 0) {
        print('📁 TOPICS WITH LESSONS (FOR DISPLAY):');
        print('═══════════════════════════════════════════════════════════');
        int currentTopicNum = 0;
        for (int i = 0; i < topicsWithLessons.length; i++) {
          final item = topicsWithLessons[i];
          if (item['is_topic'] == true) {
            currentTopicNum++;
            final topic = item['topic'] as Map<String, dynamic>;
            final topicLessons = item['lessons'] as List<Map<String, dynamic>>;
            print('📁 TOPIC $currentTopicNum:');
            print('  - ID: ${topic['id']}');
            print('  - Title: ${topic['title']}');
            print('  - Order: ${topic['order']}');
            print('  - Lessons Count: ${topicLessons.length}');
            print('');
          }
        }
        print('═══════════════════════════════════════════════════════════');
        print('');
      }

      if (topicsWithLessons.isNotEmpty) {
        print('First item:');
        final first = topicsWithLessons[0];
        if (first['is_topic'] == true) {
          print('  - Type: Topic');
          print('  - Topic Title: ${first['topic']?['title']}');
          print(
              '  - Lessons Count: ${(first['lessons'] as List?)?.length ?? 0}');
        } else {
          print('  - Type: Lesson');
          print('  - Lesson Title: ${first['lesson']?['title']}');
        }
      }
      print('═══════════════════════════════════════════════════════════');
      print('📖 DETAILED LESSONS DATA:');
      print('═══════════════════════════════════════════════════════════');
      for (int i = 0; i < topicsWithLessons.length; i++) {
        final item = topicsWithLessons[i];
        final isTopic = item['is_topic'] == true;

        if (isTopic) {
          final topic = item['topic'] as Map<String, dynamic>;
          final topicLessons = item['lessons'] as List<Map<String, dynamic>>;

          print('───────────────────────────────────────────────────────────');
          print('📁 TOPIC ${i + 1}:');
          print('  - ID: ${topic['id']}');
          print('  - Title: ${topic['title']}');
          print('  - Order: ${topic['order']}');
          print('  - Type: ${topic['type']}');
          print('  - Lessons Count: ${topicLessons.length}');
          print('  - All Topic Keys: ${topic.keys.toList()}');
          print('');
          print('  📚 LESSONS IN THIS TOPIC:');

          for (int j = 0; j < topicLessons.length; j++) {
            final lesson = topicLessons[j];
            print(
                '    ───────────────────────────────────────────────────────');
            print('    📝 LESSON ${j + 1}:');
            print('      - ID: ${lesson['id']}');
            print('      - Title: ${lesson['title']}');
            print('      - Order: ${lesson['order']}');
            print('      - Type: ${lesson['type']}');
            print('      - Duration Minutes: ${lesson['duration_minutes']}');
            print('      - Is Locked: ${lesson['is_locked']}');
            print('      - Is Completed: ${lesson['is_completed']}');
            print('      - Video: ${lesson['video']}');
            print('      - YouTube ID: ${lesson['youtube_id']}');
            print('      - YouTube Video ID: ${lesson['youtubeVideoId']}');

            // Print video object details if exists
            if (lesson['video'] is Map) {
              final video = lesson['video'] as Map;
              print('      - Video Object Keys: ${video.keys.toList()}');
              video.forEach((key, value) {
                print('        - video.$key: $value');
              });
            }

            print('      - All Lesson Keys: ${lesson.keys.toList()}');

            // Print full lesson JSON
            try {
              const encoder = JsonEncoder.withIndent('        ');
              print('      - Full Lesson JSON:');
              print(encoder.convert(lesson));
            } catch (e) {
              print('      - Could not convert lesson to JSON: $e');
            }
          }
        } else {
          final lesson = item['lesson'] as Map<String, dynamic>;
          print('───────────────────────────────────────────────────────────');
          print('📝 STANDALONE LESSON ${i + 1}:');
          print('  - ID: ${lesson['id']}');
          print('  - Title: ${lesson['title']}');
          print('  - Order: ${lesson['order']}');
          print('  - Type: ${lesson['type']}');
          print('  - Duration Minutes: ${lesson['duration_minutes']}');
          print('  - Is Locked: ${lesson['is_locked']}');
          print('  - Is Completed: ${lesson['is_completed']}');
          print('  - Video: ${lesson['video']}');
          print('  - YouTube ID: ${lesson['youtube_id']}');
          print('  - YouTube Video ID: ${lesson['youtubeVideoId']}');

          // Print video object details if exists
          if (lesson['video'] is Map) {
            final video = lesson['video'] as Map;
            print('  - Video Object Keys: ${video.keys.toList()}');
            video.forEach((key, value) {
              print('    - video.$key: $value');
            });
          }

          print('  - All Lesson Keys: ${lesson.keys.toList()}');

          // Print full lesson JSON
          try {
            const encoder = JsonEncoder.withIndent('    ');
            print('  - Full Lesson JSON:');
            print(encoder.convert(lesson));
          } catch (e) {
            print('  - Could not convert lesson to JSON: $e');
          }
        }
      }
      print('═══════════════════════════════════════════════════════════');
    }

    if (topicsWithLessons.isEmpty) {
      return _buildEmptyState('لا توجد دروس متاحة', Icons.play_lesson_rounded);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      // physics: const NeverScrollableScrollPhysics(),
      itemCount: topicsWithLessons.length,
      itemBuilder: (context, index) {
        final item = topicsWithLessons[index];
        final isTopic = item['is_topic'] == true;

        if (isTopic) {
          // Render topic header with nested lessons
          final topic = item['topic'] as Map<String, dynamic>;
          final topicLessons = item['lessons'] as List<Map<String, dynamic>>;
          final topicTitle = topic['title']?.toString() ?? 'الموضوع';
          final topicOrder = topic['order'] ?? index + 1;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Topic Header
              Container(
                margin: EdgeInsets.only(bottom: 12, top: index > 0 ? 16 : 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.purple.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.purple,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '$topicOrder',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        topicTitle,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.purple,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${topicLessons.length} دروس',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.purple,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Nested Lessons
              ...topicLessons.map((lesson) {
                // Find global index for this lesson
                final globalIndex = flatLessonsList.indexWhere(
                    (l) => l['id']?.toString() == lesson['id']?.toString());
                final actualIndex = globalIndex >= 0 ? globalIndex : 0;

                return _buildLessonItem(lesson, actualIndex, flatLessonsList);
              }),
            ],
          );
        } else {
          // Render standalone lesson
          final lesson = item['lesson'] as Map<String, dynamic>;
          final globalIndex = flatLessonsList.indexWhere(
              (l) => l['id']?.toString() == lesson['id']?.toString());
          final actualIndex = globalIndex >= 0 ? globalIndex : 0;

          return _buildLessonItem(lesson, actualIndex, flatLessonsList);
        }
      },
    );
  }

  Widget _buildLessonItem(Map<String, dynamic> lesson, int index,
      List<Map<String, dynamic>> allLessons) {
    final isLocked = lesson['is_locked'] == true || lesson['locked'] == true;
    final isCompleted =
        lesson['is_completed'] == true || lesson['completed'] == true;
    final isSelected = index == _selectedLessonIndex;

    return GestureDetector(
      onTap: isLocked
          ? null
          : () {
              _playLesson(index, lesson);
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.purple.withOpacity(0.08)
              : isLocked
                  ? Colors.grey[50]
                  : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.purple
                : isCompleted
                    ? const Color(0xFF10B981)
                    : Colors.grey.withOpacity(0.15),
            width: isSelected || isCompleted ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Index/Status Circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                      )
                    : isCompleted
                        ? const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          )
                        : null,
                color: isLocked ? Colors.grey[200] : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLocked
                  ? Icon(Icons.lock_rounded, color: Colors.grey[400], size: 20)
                  : isCompleted
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 20)
                      : isSelected
                          ? const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 22)
                          : Center(
                              child: Text(
                                '${index + 1}',
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.purple,
                                ),
                              ),
                            ),
            ),
            const SizedBox(width: 14),

            // Lesson Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson['title']?.toString() ?? 'الدرس',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isLocked ? Colors.grey[500] : AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(lesson),
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Play Icon
            if (!isLocked)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : AppColors.purple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSelected ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: AppColors.purple,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Map<String, dynamic> lesson) {
    // Try duration_minutes first, then duration
    if (lesson['duration_minutes'] != null) {
      final minutes = lesson['duration_minutes'];
      if (minutes is int) {
        return '$minutes دقيقة';
      } else if (minutes is num) {
        return '${minutes.toInt()} دقيقة';
      } else if (minutes is String) {
        final parsed = int.tryParse(minutes);
        if (parsed != null) return '$parsed دقيقة';
      }
    }
    return lesson['duration']?.toString() ?? '10 دقائق';
  }

  Widget _buildAboutTab(Map<String, dynamic>? course) {
    final courseData = _courseData ?? course;
    final description = courseData?['description']?.toString() ??
        'هذه الدورة مصممة خصيصاً لمساعدتك على تعلم المهارات الأساسية والمتقدمة في المجال. '
            'ستتعلم من خلال دروس عملية ومشاريع حقيقية تساعدك على تطبيق ما تعلمته بشكل فعال. '
            'الدورة مناسبة للمبتدئين والمحترفين على حد سواء.';

    // Get what_you_learn from API
    final whatYouLearn = courseData?['what_you_learn'] as List?;
    final features = <Map<String, dynamic>>[];

    if (whatYouLearn != null && whatYouLearn.isNotEmpty) {
      for (var item in whatYouLearn) {
        if (item is String) {
          features.add({'icon': Icons.check_circle_outline, 'text': item});
        } else if (item is Map) {
          features.add({
            'icon': Icons.check_circle_outline,
            'text': item['text']?.toString() ?? item.toString()
          });
        }
      }
    }

    // Add default features if empty
    if (features.isEmpty) {
      features.addAll([
        {
          'icon': Icons.check_circle_outline,
          'text': 'شهادة معتمدة عند الإكمال'
        },
        {'icon': Icons.access_time, 'text': 'وصول مدى الحياة للمحتوى'},
        {'icon': Icons.phone_android, 'text': 'متاح على جميع الأجهزة'},
        {'icon': Icons.download_rounded, 'text': 'ملفات للتحميل'},
      ]);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'وصف الدورة',
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              description,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: AppColors.mutedForeground,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'ماذا ستحصل عليه',
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        feature['icon'] as IconData,
                        size: 18,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      feature['text'] as String,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: AppColors.foreground,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildExamsTab() {
    if (_isLoadingExams) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppColors.purple,
            ),
            const SizedBox(height: 16),
            Text(
              'جاري تحميل الاختبارات...',
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      );
    }

    if (_courseExams.isEmpty) {
      return _buildEmptyState('لا توجد اختبارات متاحة', Icons.quiz_rounded);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      itemCount: _courseExams.length,
      itemBuilder: (context, index) {
        final exam = _courseExams[index];
        return _buildExamCard(exam, index);
      },
    );
  }

  Widget _buildExamCard(Map<String, dynamic> exam, int index) {
    final canStart = exam['can_start'] == true;
    final isPassed = exam['is_passed'] == true;
    final bestScore = exam['best_score'];
    final questionsCount = exam['questions_count'] ?? 0;
    final durationMinutes = exam['duration_minutes'] ?? 15;
    final passingScore = exam['passing_score'] ?? 70;
    final maxAttempts = exam['max_attempts'];
    final attemptsUsed = exam['attempts_used'] ?? 0;
    final examId = exam['id']?.toString() ?? '';
    final examTitle = exam['title']?.toString() ?? 'الاختبار';
    final examDescription = exam['description']?.toString() ?? '';

    // Determine if it's a trial exam
    final isTrial = exam['type'] == 'trial' ||
        exam['type'] == 'trial_exam' ||
        examTitle.contains('تجريبي') ||
        examTitle.contains('trial');

    return Container(
      margin: EdgeInsets.only(bottom: index < _courseExams.length - 1 ? 16 : 0),
      decoration: BoxDecoration(
        gradient: isTrial
            ? const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [AppColors.primary, AppColors.primaryLight],
              )
            : null,
        color: isTrial ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isTrial
            ? null
            : Border.all(
                color: AppColors.purple.withOpacity(0.2),
                width: 1,
              ),
        boxShadow: isTrial
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isTrial
                            ? Colors.white.withOpacity(0.2)
                            : AppColors.purple.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isTrial ? Icons.quiz_rounded : Icons.assignment_rounded,
                        size: 28,
                        color: isTrial ? Colors.white : AppColors.purple,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            examTitle,
                            style: GoogleFonts.cairo(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color:
                                  isTrial ? Colors.white : AppColors.foreground,
                            ),
                          ),
                          if (examDescription.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              examDescription,
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                color: isTrial
                                    ? Colors.white.withOpacity(0.8)
                                    : AppColors.mutedForeground,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Exam Info
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildExamInfoChip(
                      Icons.help_outline,
                      '$questionsCount سؤال',
                      isTrial
                          ? Colors.white.withOpacity(0.3)
                          : AppColors.purple.withOpacity(0.1),
                      isTrial ? Colors.white : AppColors.purple,
                    ),
                    _buildExamInfoChip(
                      Icons.access_time,
                      '$durationMinutes دقيقة',
                      isTrial
                          ? Colors.white.withOpacity(0.3)
                          : AppColors.purple.withOpacity(0.1),
                      isTrial ? Colors.white : AppColors.purple,
                    ),
                    _buildExamInfoChip(
                      Icons.star,
                      '$passingScore% للنجاح',
                      isTrial
                          ? Colors.white.withOpacity(0.3)
                          : AppColors.purple.withOpacity(0.1),
                      isTrial ? Colors.white : AppColors.purple,
                    ),
                    if (maxAttempts != null)
                      _buildExamInfoChip(
                        Icons.repeat,
                        '$attemptsUsed/$maxAttempts محاولات',
                        isTrial
                            ? Colors.white.withOpacity(0.3)
                            : AppColors.purple.withOpacity(0.1),
                        isTrial ? Colors.white : AppColors.purple,
                      ),
                  ],
                ),
                if (bestScore != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isPassed
                          ? Colors.green.withOpacity(isTrial ? 0.3 : 0.1)
                          : Colors.orange.withOpacity(isTrial ? 0.3 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPassed ? Icons.check_circle : Icons.info_outline,
                          size: 16,
                          color: isTrial
                              ? Colors.white
                              : (isPassed ? Colors.green : Colors.orange),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPassed
                              ? 'أفضل نتيجة: $bestScore% ✓'
                              : 'أفضل نتيجة: $bestScore%',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isTrial
                                ? Colors.white
                                : (isPassed ? Colors.green : Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: canStart ? () => _startExam(examId, exam) : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: canStart
                          ? (isTrial ? Colors.white : AppColors.purple)
                          : (isTrial
                              ? Colors.white.withOpacity(0.5)
                              : Colors.grey[300]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          canStart
                              ? Icons.play_arrow_rounded
                              : Icons.lock_rounded,
                          color: canStart
                              ? (isTrial ? AppColors.purple : Colors.white)
                              : Colors.grey,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          canStart
                              ? 'ابدأ الاختبار'
                              : (maxAttempts != null &&
                                      attemptsUsed >= maxAttempts
                                  ? 'تم استنفاد المحاولات'
                                  : 'غير متاح'),
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: canStart
                                ? (isTrial ? AppColors.purple : Colors.white)
                                : Colors.grey,
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

  Widget _buildExamInfoChip(
    IconData icon,
    String text,
    Color bgColor, [
    Color? iconColor,
  ]) {
    final finalIconColor = iconColor ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: finalIconColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: finalIconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.purple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: AppColors.purple),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.cairo(
              fontSize: 16,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(Map<String, dynamic>? course, bool isFree) {
    if (_isViewingOwnCourse) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school_rounded, color: AppColors.purple, size: 22),
              const SizedBox(width: 8),
              Text(
                'أنت مدرب هذه الدورة',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.purple,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: _isTogglingWishlist ? null : _toggleWishlist,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _isTogglingWishlist
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.orange),
                        ),
                      )
                    : Icon(
                        _isInWishlist
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: AppColors.orange,
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _isEnrolling
                    ? null
                    : () async {
                        final courseData = _courseData ?? course;

                        // If already enrolled, go to first lesson
                        if (_isEnrolled) {
                          final firstLesson = _getFirstLesson();
                          if (firstLesson != null && mounted) {
                            final course = _courseData ?? widget.course;
                            final courseId = course?['id']?.toString();
                            context.push(RouteNames.lessonViewer, extra: {
                              'lesson': firstLesson,
                              'courseId': courseId,
                            });
                          }
                          return;
                        }

                        // If free course, enroll directly
                        if (isFree) {
                          await _enrollInCourse();
                        } else {
                          // If paid course, go to checkout
                          context.push(RouteNames.checkout, extra: courseData);
                        }
                      },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _isEnrolling
                        ? null
                        : const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryLight],
                          ),
                    color: _isEnrolling ? Colors.grey[300] : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isEnrolling)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.grey),
                          ),
                        )
                      else
                        Icon(
                          _isEnrolled
                              ? Icons.play_circle_rounded
                              : isFree
                                  ? Icons.play_circle_rounded
                                  : Icons.shopping_cart_rounded,
                          color: _isEnrolling ? Colors.grey : Colors.white,
                          size: 22,
                        ),
                      const SizedBox(width: 10),
                      Text(
                        _isEnrolling
                            ? 'جاري الاشتراك...'
                            : _isEnrolled
                                ? 'ابدأ التعلم الآن'
                                : isFree
                                    ? 'اشترك مجاناً'
                                    : 'اشترك في الدورة',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isEnrolling ? Colors.grey[600] : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enrollInCourse() async {
    final course = _courseData ?? widget.course;
    if (course == null || course['id'] == null) return;

    final courseId = course['id']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    setState(() => _isEnrolling = true);

    try {
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('📤 ENROLL REQUEST (enrollInCourse)');
        print('═══════════════════════════════════════════════════════════');
        print('Course ID: $courseId');
        final title = course['title']?.toString();
        if (title != null) {
          print('Course Title: $title');
        }
        print('═══════════════════════════════════════════════════════════');
      }

      final enrollment = await CoursesService.instance.enrollInCourse(courseId);

      // Print detailed response
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('✅ ENROLLMENT RESPONSE (enrollInCourse)');
        print('═══════════════════════════════════════════════════════════');
        print('Course ID: $courseId');
        print('Response Type: ${enrollment.runtimeType}');
        print('Response Keys: ${enrollment.keys.toList()}');
        print('───────────────────────────────────────────────────────────');
        print('Full Response JSON:');
        try {
          const encoder = JsonEncoder.withIndent('  ');
          print(encoder.convert(enrollment));
        } catch (e) {
          print('Could not convert to JSON: $e');
          print('Raw Response: $enrollment');
        }
        print('───────────────────────────────────────────────────────────');
        print('Key Fields:');
        enrollment.forEach((key, value) {
          print('  - $key: $value (${value.runtimeType})');
        });
        print('═══════════════════════════════════════════════════════════');
      }

      setState(() {
        _isEnrolled = true;
        _isEnrolling = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم الاشتراك في الدورة بنجاح',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }

      // Navigate to first lesson if available
      final firstLesson = _getFirstLesson();
      if (firstLesson != null && mounted) {
        final course = _courseData ?? widget.course;
        final courseId = course?['id']?.toString();
        context.push(RouteNames.lessonViewer, extra: {
          'lesson': firstLesson,
          'courseId': courseId,
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error enrolling in course: $e');
      }

      setState(() => _isEnrolling = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('401') ||
                      e.toString().contains('Unauthorized')
                  ? 'يجب تسجيل الدخول أولاً'
                  : 'حدث خطأ أثناء الاشتراك في الدورة',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadCourseExams() async {
    final course = _courseData ?? widget.course;
    if (course == null || course['id'] == null) return;

    final courseId = course['id']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    setState(() => _isLoadingExams = true);

    try {
      final exams = await ExamsService.instance.getCourseExams(courseId);

      // Print detailed response
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('📝 COURSE EXAMS RESPONSE (getCourseExams)');
        print('═══════════════════════════════════════════════════════════');
        print('Course ID: $courseId');
        print('Response Type: ${exams.runtimeType}');
        print('Total Exams: ${exams.length}');
        print('───────────────────────────────────────────────────────────');
        print('Full Response JSON:');
        try {
          const encoder = JsonEncoder.withIndent('  ');
          print(encoder.convert(exams));
        } catch (e) {
          print('Could not convert to JSON: $e');
          print('Raw Response: $exams');
        }
        print('───────────────────────────────────────────────────────────');
        print('Exams Summary:');
        for (int i = 0; i < exams.length; i++) {
          final exam = exams[i];
          print('  Exam ${i + 1}:');
          print('    - ID: ${exam['id']}');
          print('    - Title: ${exam['title']}');
          print('    - Type: ${exam['type']}');
          print('    - Questions Count: ${exam['questions_count']}');
          print('    - Can Start: ${exam['can_start']}');
        }
        print('═══════════════════════════════════════════════════════════');
      }

      setState(() {
        _courseExams = exams;
        _isLoadingExams = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('❌ ERROR LOADING COURSE EXAMS');
        print('═══════════════════════════════════════════════════════════');
        print('Course ID: $courseId');
        print('Error: $e');
        print('Error Type: ${e.runtimeType}');
        print('═══════════════════════════════════════════════════════════');
      }
      setState(() => _isLoadingExams = false);
    }
  }

  Future<void> _checkWishlistStatus() async {
    final course = _courseData ?? widget.course;
    if (course == null || course['id'] == null) return;

    final courseId = course['id']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    try {
      final wishlist = await WishlistService.instance.getWishlist();

      // Print detailed response
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('❤️ WISHLIST RESPONSE (getWishlist)');
        print('═══════════════════════════════════════════════════════════');
        print('Course ID: $courseId');
        print('Response Type: ${wishlist.runtimeType}');
        print('Response Keys: ${wishlist.keys.toList()}');
        print('───────────────────────────────────────────────────────────');
        print('Full Response JSON:');
        try {
          const encoder = JsonEncoder.withIndent('  ');
          print(encoder.convert(wishlist));
        } catch (e) {
          print('Could not convert to JSON: $e');
          print('Raw Response: $wishlist');
        }
        print('───────────────────────────────────────────────────────────');
        print('Key Fields:');
        wishlist.forEach((key, value) {
          if (key == 'data' && value is List) {
            print('  - $key: List with ${value.length} items');
            for (int i = 0; i < value.length && i < 3; i++) {
              print('    Item $i: ${value[i]}');
            }
          } else {
            print('  - $key: $value (${value.runtimeType})');
          }
        });
        print('═══════════════════════════════════════════════════════════');
      }

      final items = wishlist['data'] as List?;

      if (items != null) {
        final isInWishlist = items.any((item) {
          final itemCourse = item['course'] as Map<String, dynamic>?;
          final itemCourseId =
              itemCourse?['id']?.toString() ?? item['course_id']?.toString();
          return itemCourseId == courseId;
        });

        if (kDebugMode) {
          print('Is Course in Wishlist: $isInWishlist');
        }

        if (mounted) {
          setState(() {
            _isInWishlist = isInWishlist;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('❌ ERROR CHECKING WISHLIST STATUS');
        print('═══════════════════════════════════════════════════════════');
        print('Course ID: $courseId');
        print('Error: $e');
        print('Error Type: ${e.runtimeType}');
        print('═══════════════════════════════════════════════════════════');
      }
      // Don't update state on error, keep current state
    }
  }

  Future<void> _toggleWishlist() async {
    final course = _courseData ?? widget.course;
    if (course == null || course['id'] == null) return;

    final courseId = course['id']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    setState(() => _isTogglingWishlist = true);

    try {
      if (_isInWishlist) {
        if (kDebugMode) {
          print('═══════════════════════════════════════════════════════════');
          print('🗑️ REMOVING FROM WISHLIST');
          print('═══════════════════════════════════════════════════════════');
          print('Course ID: $courseId');
          print('═══════════════════════════════════════════════════════════');
        }
        await WishlistService.instance.removeFromWishlist(courseId);
        if (kDebugMode) {
          print('✅ Successfully removed from wishlist');
        }
      } else {
        if (kDebugMode) {
          print('═══════════════════════════════════════════════════════════');
          print('➕ ADDING TO WISHLIST');
          print('═══════════════════════════════════════════════════════════');
          print('Course ID: $courseId');
          print('═══════════════════════════════════════════════════════════');
        }
        await WishlistService.instance.addToWishlist(courseId);
        if (kDebugMode) {
          print('✅ Successfully added to wishlist');
        }
      }

      setState(() {
        _isInWishlist = !_isInWishlist;
        _isTogglingWishlist = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isInWishlist
                  ? 'تمت الإضافة إلى قائمة الرغبات'
                  : 'تمت الإزالة من قائمة الرغبات',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error toggling wishlist: $e');
      }

      setState(() => _isTogglingWishlist = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('401') ||
                      e.toString().contains('Unauthorized')
                  ? 'يجب تسجيل الدخول أولاً'
                  : 'حدث خطأ أثناء ${_isInWishlist ? 'الإزالة من' : 'الإضافة إلى'} قائمة الرغبات',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _startExam(String examId, Map<String, dynamic> examData) async {
    if (examId.isEmpty) return;

    final course = _courseData ?? widget.course;
    if (course == null || course['id'] == null) return;

    final courseId = course['id']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    try {
      // Start exam via API
      final examSession = await ExamsService.instance.startExam(examId);

      // Print detailed response
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('🚀 START EXAM RESPONSE (startExam)');
        print('═══════════════════════════════════════════════════════════');
        print('Exam ID: $examId');
        print('Response Type: ${examSession.runtimeType}');
        print('Response Keys: ${examSession.keys.toList()}');
        print('───────────────────────────────────────────────────────────');
        print('Full Response JSON:');
        try {
          const encoder = JsonEncoder.withIndent('  ');
          print(encoder.convert(examSession));
        } catch (e) {
          print('Could not convert to JSON: $e');
          print('Raw Response: $examSession');
        }
        print('───────────────────────────────────────────────────────────');
        print('Key Fields:');
        examSession.forEach((key, value) {
          if (key == 'questions' && value is List) {
            print('  - $key: List with ${value.length} questions');
            for (int i = 0; i < value.length && i < 2; i++) {
              print('    Question $i: ${value[i]}');
            }
          } else {
            print('  - $key: $value (${value.runtimeType})');
          }
        });
        print('═══════════════════════════════════════════════════════════');
      }

      final questions = examSession['questions'] as List?;
      final attemptId = examSession['attempt_id']?.toString();

      if (questions == null || questions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'لا توجد أسئلة متاحة في الامتحان',
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TrialExamScreen(
              examId: examId,
              attemptId: attemptId,
              courseName:
                  (_courseData ?? widget.course)?['title']?.toString() ??
                      'الدورة',
              examData: examData,
              examSession: examSession,
            ),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error starting exam: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('401') ||
                      e.toString().contains('Unauthorized')
                  ? 'يجب تسجيل الدخول أولاً'
                  : 'حدث خطأ أثناء بدء الامتحان',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Widget _buildSkeleton() {
    return Skeletonizer(
      enabled: true,
      child: Scaffold(
        backgroundColor: AppColors.beige,
        body: SafeArea(
          child: Column(
            children: [
              // Video skeleton
              Container(
                height: 220,
                color: Colors.black,
              ),
              // Content skeleton
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header skeleton
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 80,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              Container(
                                width: 60,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 24,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 24,
                            width: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 60,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 60,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Tabs skeleton
                          Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Lessons skeleton
                          ...List.generate(5, (index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                height: 70,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trial Exam Screen
class TrialExamScreen extends StatefulWidget {
  final String examId;
  final String? attemptId;
  final String courseName;
  final Map<String, dynamic>? examData;
  final Map<String, dynamic>? examSession;
  final List<Map<String, dynamic>>? questions; // Fallback for static questions

  const TrialExamScreen({
    super.key,
    required this.examId,
    this.attemptId,
    required this.courseName,
    this.examData,
    this.examSession,
    this.questions,
  });

  @override
  State<TrialExamScreen> createState() => _TrialExamScreenState();
}

class _TrialExamScreenState extends State<TrialExamScreen> {
  int _currentQuestionIndex = 0;
  final Map<int, List<String>> _selectedAnswers =
      {}; // For multiple choice questions
  final Map<int, String?> _singleAnswers = {}; // For single choice questions
  bool _showResult = false;
  bool _isSubmitting = false;
  Map<String, dynamic>? _examResult;
  List<Map<String, dynamic>> _questions = [];
  String? _attemptId;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  void _loadQuestions() {
    // Get questions from exam session or use fallback
    if (widget.examSession != null &&
        widget.examSession!['questions'] != null) {
      final questions = widget.examSession!['questions'] as List;
      _questions = questions.map((q) => q as Map<String, dynamic>).toList();
      _attemptId =
          widget.examSession!['attempt_id']?.toString() ?? widget.attemptId;
    } else if (widget.questions != null) {
      _questions = List<Map<String, dynamic>>.from(widget.questions!);
    }

    // Initialize answers
    for (int i = 0; i < _questions.length; i++) {
      _singleAnswers[i] = null;
      _selectedAnswers[i] = [];
    }
  }

  void _selectAnswer(int optionIndex) {
    setState(() {
      final question = _questions[_currentQuestionIndex];

      // Check if multiple choice
      final isMultiple = question['is_multiple'] == true ||
          question['type'] == 'multiple_choice';

      if (isMultiple) {
        final selected = _selectedAnswers[_currentQuestionIndex] ?? [];
        final optionId = question['options']?[optionIndex]?['id']?.toString() ??
            question['options']?[optionIndex]?['option_id']?.toString();

        if (selected.contains(optionId)) {
          selected.remove(optionId);
        } else {
          selected.add(optionId ?? optionIndex.toString());
        }
        _selectedAnswers[_currentQuestionIndex] = selected;
      } else {
        // Single choice
        final optionId = question['options']?[optionIndex]?['id']?.toString() ??
            question['options']?[optionIndex]?['option_id']?.toString();
        _singleAnswers[_currentQuestionIndex] =
            optionId ?? optionIndex.toString();
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _submitExam();
    }
  }

  bool get _hasSelectedAnswer {
    final question = _questions[_currentQuestionIndex];
    final isMultiple = question['is_multiple'] == true ||
        question['type'] == 'multiple_choice';

    if (isMultiple) {
      final selected = _selectedAnswers[_currentQuestionIndex] ?? [];
      return selected.isNotEmpty;
    } else {
      return _singleAnswers[_currentQuestionIndex] != null;
    }
  }

  Future<void> _submitExam() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      // Prepare answers in API format
      final answers = <Map<String, dynamic>>[];

      for (int i = 0; i < _questions.length; i++) {
        final question = _questions[i];
        final questionId = question['id']?.toString() ??
            question['question_id']?.toString() ??
            'q_$i';

        final isMultiple = question['is_multiple'] == true ||
            question['type'] == 'multiple_choice';

        if (isMultiple) {
          final selected = _selectedAnswers[i] ?? [];
          answers.add({
            'question_id': questionId,
            'selected_options': selected,
          });
        } else {
          final selected = _singleAnswers[i];
          if (selected != null) {
            answers.add({
              'question_id': questionId,
              'selected_options': [selected],
            });
          }
        }
      }

      if (_attemptId == null || _attemptId!.isEmpty) {
        throw Exception('Attempt ID is missing');
      }

      // Print answers before submission
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('📤 SUBMITTING EXAM');
        print('═══════════════════════════════════════════════════════════');
        print('Exam ID: ${widget.examId}');
        print('Attempt ID: $_attemptId');
        print('Total Questions: ${_questions.length}');
        print('Answers to Submit:');
        try {
          const encoder = JsonEncoder.withIndent('  ');
          print(encoder.convert(answers));
        } catch (e) {
          print('Could not convert answers to JSON: $e');
          print('Raw Answers: $answers');
        }
        print('═══════════════════════════════════════════════════════════');
      }

      final result = await ExamsService.instance.submitExam(
        widget.examId,
        attemptId: _attemptId!,
        answers: answers,
      );

      // Print detailed response
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('✅ EXAM SUBMISSION RESPONSE (submitExam)');
        print('═══════════════════════════════════════════════════════════');
        print('Exam ID: ${widget.examId}');
        print('Attempt ID: $_attemptId');
        print('Response Type: ${result.runtimeType}');
        print('Response Keys: ${result.keys.toList()}');
        print('───────────────────────────────────────────────────────────');
        print('Full Response JSON:');
        try {
          const encoder = JsonEncoder.withIndent('  ');
          print(encoder.convert(result));
        } catch (e) {
          print('Could not convert to JSON: $e');
          print('Raw Response: $result');
        }
        print('───────────────────────────────────────────────────────────');
        print('Key Fields:');
        result.forEach((key, value) {
          print('  - $key: $value (${value.runtimeType})');
        });
        print('───────────────────────────────────────────────────────────');
        print('Summary:');
        print('  - Score: ${result['score']}%');
        print('  - Is Passed: ${result['is_passed']}');
        print(
            '  - Correct Answers: ${result['correct_answers']}/${result['total_questions']}');
        if (result['time_taken_minutes'] != null) {
          print('  - Time Taken: ${result['time_taken_minutes']} minutes');
        }
        print('═══════════════════════════════════════════════════════════');
      }

      setState(() {
        _examResult = result;
        _showResult = true;
        _isSubmitting = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error submitting exam: $e');
      }

      setState(() => _isSubmitting = false);

      final errorMessage = () {
        if (e is ApiException && e.message.isNotEmpty) {
          return e.message;
        }

        final message = e.toString();
        if (message.contains('401') ||
            message.toLowerCase().contains('unauthorized')) {
          return 'يجب تسجيل الدخول أولاً';
        }

        return message.isNotEmpty ? message : 'حدث خطأ أثناء تقديم الامتحان';
      }();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage, style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.beige,
        appBar: AppBar(
          backgroundColor: AppColors.purple,
          title: Text(
            'الامتحان التجريبي',
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold, color: Colors.white),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: AppColors.purple,
              ),
              const SizedBox(height: 16),
              Text(
                'جاري تحميل الأسئلة...',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_showResult) {
      return _buildResultScreen();
    }

    final question = _questions[_currentQuestionIndex];
    final options = question['options'] as List? ?? [];
    final isMultiple = question['is_multiple'] == true ||
        question['type'] == 'multiple_choice';

    return Scaffold(
      backgroundColor: AppColors.beige,
      appBar: AppBar(
        backgroundColor: AppColors.purple,
        title: Text(
          'الامتحان التجريبي',
          style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Center(
              child: Text(
                '${_currentQuestionIndex + 1}/${_questions.length}',
                style: GoogleFonts.cairo(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'السؤال ${_currentQuestionIndex + 1}',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.purple,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    question['question']?.toString() ??
                        question['text']?.toString() ??
                        'السؤال',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.foreground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Options
            ...List.generate(options.length, (index) {
              final option = options[index];
              final optionId = option['id']?.toString() ??
                  option['option_id']?.toString() ??
                  index.toString();

              bool isSelected = false;
              if (isMultiple) {
                final selected = _selectedAnswers[_currentQuestionIndex] ?? [];
                isSelected = selected.contains(optionId);
              } else {
                isSelected = _singleAnswers[_currentQuestionIndex] == optionId;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => _selectAnswer(index),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.purple.withOpacity(0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.purple
                            : Colors.grey.withOpacity(0.2),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.purple
                                : Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isSelected && isMultiple
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : Text(
                                    String.fromCharCode(1571 + index),
                                    style: GoogleFonts.cairo(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.mutedForeground,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            option['text']?.toString() ??
                                option['option']?.toString() ??
                                option.toString(),
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected
                                  ? AppColors.purple
                                  : AppColors.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),

            // Next Button
            GestureDetector(
              onTap:
                  (_hasSelectedAnswer && !_isSubmitting) ? _nextQuestion : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: (_hasSelectedAnswer && !_isSubmitting)
                      ? const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight])
                      : null,
                  color: (!_hasSelectedAnswer || _isSubmitting)
                      ? Colors.grey[300]
                      : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.grey),
                          ),
                        )
                      : Text(
                          _currentQuestionIndex == _questions.length - 1
                              ? 'إنهاء الامتحان'
                              : 'التالي',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _hasSelectedAnswer
                                ? Colors.white
                                : Colors.grey[500],
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    int score = 0;
    bool passed = false;
    int correctAnswers = 0;
    int totalQuestions = _questions.length;
    String? message;

    if (_examResult != null) {
      score = (_examResult!['score'] as num?)?.toInt() ?? 0;
      passed = _examResult!['is_passed'] == true;
      correctAnswers = _examResult!['correct_answers'] as int? ?? 0;
      totalQuestions =
          _examResult!['total_questions'] as int? ?? _questions.length;
      message = _examResult!['message']?.toString();
    } else {
      // Fallback calculation (should not happen if API works)
      score = 0;
      passed = false;
    }

    return Scaffold(
      backgroundColor: AppColors.beige,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: passed
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF97316),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    passed ? Icons.emoji_events_rounded : Icons.refresh_rounded,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  message ?? (passed ? 'أحسنت! 🎉' : 'حاول مرة أخرى'),
                  style: GoogleFonts.cairo(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'نتيجتك: $score%',
                  style: GoogleFonts.cairo(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: passed
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF97316),
                  ),
                ),
                Text(
                  '$correctAnswers من $totalQuestions إجابات صحيحة',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    color: AppColors.mutedForeground,
                  ),
                ),
                if (_examResult != null &&
                    _examResult!['time_taken_minutes'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'الوقت المستغرق: ${_examResult!['time_taken_minutes']} دقيقة',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        'إنهاء',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
