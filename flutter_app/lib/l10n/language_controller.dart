import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguageMode {
  automatic,
  greek,
  english,
}

class LanguageController extends ChangeNotifier {
  static const String _storageKey = 'edgespace_language_mode';

  AppLanguageMode _mode = AppLanguageMode.automatic;

  AppLanguageMode get mode => _mode;

  Locale? get locale {
    return switch (_mode) {
      AppLanguageMode.automatic => null,
      AppLanguageMode.greek => const Locale('el'),
      AppLanguageMode.english => const Locale('en'),
    };
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);

    _mode = AppLanguageMode.values.firstWhere(
      (value) => value.name == saved,
      orElse: () => AppLanguageMode.automatic,
    );
  }

  Future<void> setMode(AppLanguageMode value) async {
    if (_mode == value) return;

    _mode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, value.name);
  }
}

extension EdgeSpaceLocalization on BuildContext {
  bool get isGreek {
    return Localizations.localeOf(this).languageCode.toLowerCase() == 'el';
  }

  String tr(String english, String greek) {
    return isGreek ? greek : english;
  }
}
