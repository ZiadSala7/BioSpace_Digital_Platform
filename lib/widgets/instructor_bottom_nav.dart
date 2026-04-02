import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/design/app_colors.dart';
import '../core/navigation/route_names.dart';
import '../core/localization/localization_helper.dart';

/// Bottom navigation for instructor flow – same theme as student BottomNav.
class InstructorBottomNav extends StatelessWidget {
  final String activeTab;

  const InstructorBottomNav({
    super.key,
    required this.activeTab,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.card.withOpacity(0.78),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppColors.border.withOpacity(0.7),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.10),
                          blurRadius: 30,
                          offset: const Offset(0, 6),
                          spreadRadius: -12,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _NavItem(
                          icon: Icons.dashboard_rounded,
                          label: context.l10n.home,
                          id: 'home',
                          activeTab: activeTab,
                          onTap: () => context.go(RouteNames.instructorHome),
                        ),
                        _NavItem(
                          icon: Icons.menu_book_rounded,
                          label: context.l10n.myCourses,
                          id: 'courses',
                          activeTab: activeTab,
                          onTap: () => context.go(RouteNames.instructorCourses),
                        ),
                        _CenterNavItem(
                          activeTab: activeTab,
                          onTap: () =>
                              context.go(RouteNames.instructorCreateCourse),
                        ),
                        _NavItem(
                          icon: Icons.payments_rounded,
                          label: _earningsLabel(context),
                          id: 'earnings',
                          activeTab: activeTab,
                          onTap: () => context.go(RouteNames.instructorEarnings),
                        ),
                        _NavItem(
                          icon: Icons.person_rounded,
                          label: context.l10n.myAccount,
                          id: 'profile',
                          activeTab: activeTab,
                          onTap: () => context.go(RouteNames.instructorProfile),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _earningsLabel(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'ar' ? 'الأرباح' : 'Earnings';
  }
}

class _CenterNavItem extends StatelessWidget {
  final String activeTab;
  final VoidCallback onTap;

  const _CenterNavItem({
    required this.activeTab,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = activeTab == 'create';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primaryLight,
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.purple.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: 0,
            ),
          ],
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  isActive ? Colors.white.withOpacity(0.5) : Colors.transparent,
              width: 3,
            ),
          ),
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String id;
  final String activeTab;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.id,
    required this.activeTab,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = activeTab == id;
    final activeColor = AppColors.primary;
    final inactiveColor = AppColors.mutedForeground;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 14 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    activeColor.withOpacity(0.14),
                    activeColor.withOpacity(0.06),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: isActive ? 24 : 22,
              color: isActive ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 56),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: isActive ? 10 : 9,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
