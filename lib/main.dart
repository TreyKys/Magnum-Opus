import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:magnum_opus/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magnum_opus/features/onboarding/presentation/loading_screen.dart';
import 'package:magnum_opus/features/onboarding/presentation/intro_screen.dart';
import 'package:magnum_opus/features/vault/presentation/dashboard_screen.dart'; // We'll create this later
import 'dart:io';

import 'package:magnum_opus/features/settings/presentation/settings_screen.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = !(prefs.getBool('has_seen_intro') ?? false);

  await MobileAds.instance.initialize();
  await dotenv.load(fileName: ".env");
  HttpOverrides.global = MyHttpOverrides();
  runApp(
    ProviderScope(
      child: MyApp(isFirstLaunch: isFirstLaunch),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isFirstLaunch;
  const MyApp({super.key, required this.isFirstLaunch});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Magnum Opus',
      theme: AppTheme.darkTheme,
      home: LoadingScreen(isFirstLaunch: isFirstLaunch),
      debugShowCheckedModeBanner: false,
      routes: {
        '/settings': (context) => const SettingsScreen(),
        '/intro': (context) => const IntroScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}
