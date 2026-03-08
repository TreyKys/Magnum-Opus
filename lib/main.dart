import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/features/vault/presentation/vault_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    );
  }
}
