import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../screens/splash_screen.dart';

class ZhasauApp extends StatelessWidget {
  const ZhasauApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, isDark, _) {
        return MaterialApp(
          title: 'Zhasau',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.current,
          locale: const Locale('ru'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ru'), Locale('en')],
          home: const SplashScreen(),
        );
      },
    );
  }
}
