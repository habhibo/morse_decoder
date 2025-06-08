import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageManager {
  static const String _customLanguagesKey = 'custom_languages';

  Future<void> saveCustomLanguage(String languageName, Map<String, String> charToMorse) async {
    final prefs = await SharedPreferences.getInstance();
    final customLanguages = await getCustomLanguages();

    customLanguages[languageName] = charToMorse;

    final jsonString = json.encode(customLanguages.map(
          (key, value) => MapEntry(key, value),
    ));

    await prefs.setString(_customLanguagesKey, jsonString);
  }

  Future<Map<String, Map<String, String>>> getCustomLanguages() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_customLanguagesKey);

    if (jsonString == null) return {};

    final decoded = json.decode(jsonString) as Map<String, dynamic>;
    return decoded.map(
          (key, value) => MapEntry(key, Map<String, String>.from(value)),
    );
  }
}