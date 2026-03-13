import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/features/vault/presentation/vault_screen.dart';
import 'package:myapp/features/settings/presentation/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Magnum Opus',
      theme: AppTheme.darkTheme,
      home: const VaultScreen(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
