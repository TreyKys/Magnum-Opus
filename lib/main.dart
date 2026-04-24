import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:magnum_opus/core/theme/app_theme.dart';
import 'package:magnum_opus/features/onboarding/presentation/onboarding_screen.dart';
import 'package:magnum_opus/features/onboarding/providers/onboarding_provider.dart';
import 'package:magnum_opus/app/main_scaffold.dart';
import 'package:magnum_opus/features/settings/presentation/settings_screen.dart';
import 'package:magnum_opus/features/vault/presentation/vault_screen.dart';

// Dev convenience: bypass SSL certificate errors for local/test APIs.
// IMPORTANT: Remove or gate on kReleaseMode before publishing to stores.
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientations only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await MobileAds.instance.initialize();
  await dotenv.load(fileName: '.env');

  // Dev SSL bypass — see MyHttpOverrides above
  HttpOverrides.global = MyHttpOverrides();

  // Pre-read onboarding flag before first frame to avoid flash of onboarding
  // on returning users (provider async init would otherwise briefly show page 1)
  final prefs = await SharedPreferences.getInstance();
  final initiallyOnboarded = prefs.getBool('onboarding_done') ?? false;

  runApp(
    ProviderScope(
      child: MyApp(initiallyOnboarded: initiallyOnboarded),
    ),
  );
}

class MyApp extends ConsumerWidget {
  final bool initiallyOnboarded;

  const MyApp({super.key, required this.initiallyOnboarded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch provider so the UI switches to VaultScreen the moment
    // the user completes onboarding in-session
    final onboardingState = ref.watch(onboardingProvider);
    final showVault = initiallyOnboarded || onboardingState.completed;

    return MaterialApp(
      title: 'Magnum Opus',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: showVault ? const MainScaffold() : const OnboardingScreen(),
      onGenerateRoute: _generateRoute,
    );
  }

  /// Global slide-right-to-left transition for all named routes.
  static Route<dynamic> _generateRoute(RouteSettings settings) {
    Widget page;
    switch (settings.name) {
      case '/settings':
        page = const SettingsScreen();
        break;
      case '/vault':
        page = const VaultScreen();
        break;
      default:
        // Fallback — should never be reached for known routes
        return MaterialPageRoute(
          builder: (_) => const VaultScreen(),
          settings: settings,
        );
    }

    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          ),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
