import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/design/app_colors.dart';
import '../../services/course_community_service.dart';
import '../../services/profile_service.dart';

class CourseCommunityScreen extends StatefulWidget {
  const CourseCommunityScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.communityThreadId,
    this.waveId,
  });

  final String courseId;
  final String courseTitle;

  /// Legacy local cache key (per-wave thread id from [CourseWaveInfo.communityThreadId]).
  final String communityThreadId;

  /// Backend wave scope when the API supports it.
  final String? waveId;

  @override
  State<CourseCommunityScreen> createState() => _CourseCommunityScreenState();
}

class _CourseCommunityScreenState extends State<CourseCommunityScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  bool _loading = true;
  List<Map<String, dynamic>> _messages = [];
  String? _myUserId;
  String? _profileName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await ProfileService.instance.getProfile();
      if (!mounted) return;
      _myUserId = p['id']?.toString();
      _profileName = p['name']?.toString();
    } catch (_) {
      // Bubbles fall back when user_id is unknown
    }
    final msgs = await CourseCommunityService.instance.listMessages(
      widget.courseId,
      waveId: widget.waveId,
      localThreadId: widget.communityThreadId,
    );
    if (!mounted) return;
    setState(() {
      _messages = msgs;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent + 120,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;

    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final senderName = _profileName?.trim().isNotEmpty == true
        ? _profileName!.trim()
        : (isAr ? 'طالب' : 'Student');

    _controller.clear();
    final ok = await CourseCommunityService.instance.addMessage(
      widget.courseId,
      waveId: widget.waveId,
      localThreadId: widget.communityThreadId,
      text: text,
      senderName: senderName,
      senderRole: 'student',
      senderUserId: _myUserId,
    );
    await _load();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr
                ? 'تعذر الإرسال للخادم؛ تم حفظ الرسالة محلياً مؤقتاً'
                : 'Could not reach server; message saved on this device only',
            style: GoogleFonts.cairo(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
          isAr ? 'المجتمع' : 'Community',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: Colors.white,
            child: Text(
              widget.courseTitle.isEmpty
                  ? (isAr
                      ? 'نقاش مع المسجلين في هذه الموجة'
                      : 'Discussion for this wave only')
                  : widget.courseTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.foreground,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      final role = m['sender_role']?.toString() ?? 'student';
                      final uid = m['user_id']?.toString();
                      final isMine = uid != null &&
                          uid.isNotEmpty &&
                          _myUserId != null &&
                          uid == _myUserId;
                      final resolvedName = (() {
                        final fromApi = m['sender_name']?.toString().trim();
                        if (fromApi != null && fromApi.isNotEmpty) {
                          return fromApi;
                        }
                        if (isMine &&
                            _profileName != null &&
                            _profileName!.trim().isNotEmpty) {
                          return _profileName!.trim();
                        }
                        return '';
                      })();
                      return _bubble(
                        name: resolvedName,
                        text: m['text']?.toString() ?? '',
                        role: role,
                        isMine: isMine,
                        isAr: isAr,
                      );
                    },
                  ),
          ),
          _composer(isAr),
        ],
      ),
    );
  }

  Widget _bubble({
    required String name,
    required String text,
    required String role,
    required bool isMine,
    required bool isAr,
  }) {
    final bg = isMine ? AppColors.primary : AppColors.card;
    final fg = isMine ? Colors.white : AppColors.foreground;
    final align = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final roleLabel = role == 'instructor'
        ? (isAr ? 'مدرب' : 'Instructor')
        : (isAr ? 'طالب' : 'Student');

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: isMine
              ? null
              : Border.all(color: AppColors.border.withOpacity(0.7)),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              name.isEmpty ? roleLabel : '$name • $roleLabel',
              style: GoogleFonts.cairo(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: isMine ? Colors.white70 : AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer(bool isAr) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
                decoration: InputDecoration(
                  hintText: isAr ? 'اكتب رسالة...' : 'Write a message...',
                  hintStyle:
                      GoogleFonts.cairo(color: AppColors.mutedForeground),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppColors.primary.withOpacity(0.18),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: isAr ? 'إرسال' : 'Send',
              onPressed: _send,
              icon: const Icon(Icons.send_rounded, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
