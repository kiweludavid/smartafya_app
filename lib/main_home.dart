import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/home_screen_ui.dart';

void main() {
  runApp(const _SmartAfyaHomeApp());
}

class _SmartAfyaHomeApp extends StatelessWidget {
  const _SmartAfyaHomeApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: const SmartAfyaHomeScreenUi(),
    );
  }
}

