import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Only used for CupertinoPageTransitionsBuilder below — the app stays Material.
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

import 'config/app_config.dart';
import 'screens/splash_screen.dart';
import 'services/health_store.dart';
import 'theme/app_theme.dart';
import 'theme/colors.dart';
import 'theme/text_styles.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _reportConfiguration();

  // The status bar sits directly on the page, so its icons have to be dark on
  // every platform — the system default would render them light on some
  // Android builds and make the clock invisible against the paper.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.canvas,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Profile and history are read before the first frame so the home screen
  // can greet the user by name immediately, rather than rendering "Hello"
  // and then snapping to their name a frame later.
  await HealthStore.instance.load();

  runApp(const HealthBotApp());
}

/// Surface configuration problems at startup rather than at the moment a
/// user taps something that needs them.
///
/// In release builds, shipping-unsafe settings — symptom data over plain
/// HTTP, a backend URL still pointing at a developer machine, a missing auth
/// token — throw immediately. A build like that is a packaging mistake, and
/// failing loudly on the developer's device beats discovering it in the wild.
void _reportConfiguration() {
  for (final warning in AppConfig.missingConfiguration()) {
    debugPrint('CONFIG: $warning');
  }

  if (kReleaseMode) {
    final blockers = AppConfig.releaseBlockers();
    if (blockers.isNotEmpty) {
      throw StateError(
        'This release build is misconfigured and must not be distributed:\n'
        '${blockers.map((b) => '  - $b').join('\n')}\n'
        'Build with --dart-define-from-file=env.json (see DEPLOYMENT.md).',
      );
    }
  }
}

class HealthBotApp extends StatelessWidget {
  const HealthBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health-Bot',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const SplashScreen(),
    );
  }

  /// One light theme, declared once. There is no dark counterpart to switch
  /// to, so the app does not offer a themeMode it cannot honour.
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.canvas,
    canvasColor: AppColors.canvas,
    colorScheme: const ColorScheme.light(
      primary: AppColors.signal,
      onPrimary: AppColors.textInverse,
      secondary: AppColors.pulse,
      onSecondary: AppColors.textInverse,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.ember,
      onError: AppColors.textInverse,
    ),
    dividerColor: AppColors.divider,
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),
    iconTheme: const IconThemeData(color: AppColors.textMuted),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.signal,
      linearTrackColor: AppColors.surfaceHigh,
      circularTrackColor: Colors.transparent,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.signal,
      selectionColor: AppColors.signal.withValues(alpha: 0.20),
      selectionHandleColor: AppColors.signal,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.text,
      contentTextStyle: AppText.body.copyWith(color: AppColors.textInverse),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
    ),
    // Feedback lives on Pressable's own spring, not the default ripple —
    // avoid stacking both on the same tap.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    // A single directional, interruptible slide+back-swipe transition on
    // every platform, so forward/back always follow the same path
    // (spatial consistency) instead of Android's default fade-through.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
