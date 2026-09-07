import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'core/app_theme.dart';
import 'firebase_options.dart';
import 'l10n/language_controller.dart';
import 'screens/auth/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final languageController = LanguageController();
  await languageController.initialize();

  runApp(
    EdgeSpaceBootstrap(
      languageController: languageController,
    ),
  );
}

class EdgeSpaceBootstrap extends StatelessWidget {
  const EdgeSpaceBootstrap({
    super.key,
    required this.languageController,
  });

  final LanguageController languageController;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageController>.value(
          value: languageController,
        ),
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState()..initialize(),
        ),
      ],
      child: const EdgeSpaceApp(),
    );
  }
}

class EdgeSpaceApp extends StatelessWidget {
  const EdgeSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageController>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EdgeSpace AI',

      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,

      // null = follow Android/device language automatically.
      locale: language.locale,

      supportedLocales: const [
        Locale('en'),
        Locale('el'),
      ],

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const AuthGate(),
    );
  }
}