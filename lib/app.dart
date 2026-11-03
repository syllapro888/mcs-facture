import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'database/app_database.dart';
import 'providers/client_provider.dart';
import 'providers/invoice_provider.dart';
import 'providers/product_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/dashboard_screen.dart';

class AppColors {
  static const dark = Color(0xFF0B2A5B);
  static const light = Color(0xFF3FA9F5);
  static const yellow = Color(0xFFF7B500);
  static const background = Color(0xFFF4F7FB);
}

class McsApp extends StatelessWidget {
  const McsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final db = AppDatabase.instance;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider(db)..load()),
        ChangeNotifierProvider(create: (_) => ProductProvider(db)..load()),
        ChangeNotifierProvider(create: (_) => ClientProvider(db)..load()),
        ChangeNotifierProvider(create: (_) => InvoiceProvider(db)..load()),
      ],
      child: MaterialApp(
        title: 'MCS VISION Factures',
        debugShowCheckedModeBanner: false,
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Poppins',
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.dark,
            primary: AppColors.dark,
            secondary: AppColors.light,
            tertiary: AppColors.yellow,
          ),
          scaffoldBackgroundColor: AppColors.background,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.dark,
            foregroundColor: Colors.white,
            centerTitle: false,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: AppColors.yellow,
            foregroundColor: AppColors.dark,
          ),
        ),
        home: const DashboardScreen(),
      ),
    );
  }
}
