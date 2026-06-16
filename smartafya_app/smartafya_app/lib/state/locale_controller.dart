import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LocaleChoice {
  system,
  english,
  swahili,
}

class LocaleController extends ChangeNotifier {
  static const _prefKey = 'app_locale';

  Locale? _locale;

  Locale? get locale => _locale;

  LocaleChoice get choice {
    if (_locale == null) return LocaleChoice.system;
    if (_locale!.languageCode == 'sw') return LocaleChoice.swahili;
    return LocaleChoice.english;
  }

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    _locale = _localeFromStorage(saved);
    notifyListeners();
  }

  Future<void> setLocaleChoice(LocaleChoice choice) async {
    final prefs = await SharedPreferences.getInstance();
    switch (choice) {
      case LocaleChoice.system:
        _locale = null;
        await prefs.setString(_prefKey, 'system');
      case LocaleChoice.english:
        _locale = const Locale('en');
        await prefs.setString(_prefKey, 'en');
      case LocaleChoice.swahili:
        _locale = const Locale('sw');
        await prefs.setString(_prefKey, 'sw');
    }
    notifyListeners();
  }

  static Locale? _localeFromStorage(String? value) {
    switch (value) {
      case 'en':
        return const Locale('en');
      case 'sw':
        return const Locale('sw');
      case 'system':
      default:
        return null;
    }
  }
}
