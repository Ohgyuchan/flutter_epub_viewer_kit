import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reader_settings.dart';

class SettingsStorage {
  static const String _defaultKey = 'epub_reader_settings';

  final String storageKey;

  SettingsStorage({String? storageKey}) : storageKey = storageKey ?? _defaultKey;

  Future<ReaderSettings?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(storageKey);
      if (jsonString == null) return null;

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return ReaderSettings.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  Future<void> save(ReaderSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(settings.toJson());
      await prefs.setString(storageKey, jsonString);
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (e) {
      // Silently fail
    }
  }
}
