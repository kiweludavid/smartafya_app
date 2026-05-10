import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen_ui.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'services/api_client.dart';
import 'services/notification_service.dart';
import 'state/client_home_controller.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Avoid "blank screens" in release when a widget throws during build/layout.
  // This surfaces the error so it can be fixed quickly.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Something went wrong',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  NotificationService.init();
  ApiClient.onUnauthorized = () {
    final nav = appNavigatorKey.currentState;
    if (nav != null && nav.mounted) {
      nav.pushNamedAndRemoveUntil('/login', (route) => false);
    }
  };
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ClientHomeController()),
      ],
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          textTheme: GoogleFonts.interTextTheme(),
        ),
        initialRoute: '/login',
        routes: {
          '/signup': (_) => const SmartAfyaSignupScreen(),
          '/login': (_) => const SmartAfyaLoginScreen(),
          '/home': (_) => const SmartAfyaHomeScreenUi(),
        },
      ),
    ),
  );
}
