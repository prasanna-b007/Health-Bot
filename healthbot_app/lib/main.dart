import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const HealthBotApp());
}

class HealthBotApp extends StatelessWidget {
  const HealthBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health-Bot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // Theming is mostly handled by custom components and AppColors/AppText
      ),
      home: const SplashScreen(),
    );
  }
}
