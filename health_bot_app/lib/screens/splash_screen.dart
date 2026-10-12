import 'package:flutter/material.dart';

import '../motion/motion_query.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'home_screen.dart';

/// Cold-start screen.
///
/// It holds for a fixed moment rather than waiting on work — the store is
/// already loaded by the time this builds — so its only job is to show the
/// mark before the first screen arrives.
///
/// The dwell is short on purpose. A splash that lingers is a tax on someone
/// who may be opening this because they feel unwell.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _dwell = Duration(milliseconds: 1100);

  @override
  void initState() {
    super.initState();
    Future.delayed(_dwell, _goHome);
  }

  void _goHome() {
    if (!mounted) return;
    final reduceMotion = MotionQuery.reduceMotion(context);

    // Always go to HomeScreen. Personal details are collected when the user
    // starts a symptom check, not on app launch.
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: Duration(milliseconds: reduceMotion ? 160 : 320),
        pageBuilder: (_, _, _) => const HomeScreen(),
        // A plain cross-fade. Home is the same page with content on it, not a
        // new place, so nothing needs to slide.
        transitionsBuilder: (context, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.signal,
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
              child: const Icon(
                Icons.monitor_heart_rounded,
                size: 36,
                color: AppColors.textInverse,
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            Text('Health-Bot', style: AppText.h1),
            const SizedBox(height: AppTheme.space4),
            Text('Symptom checker', style: AppText.bodySm),
          ],
        ),
      ),
    );
  }
}
