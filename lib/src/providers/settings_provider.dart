import 'package:flutter/foundation.dart';
import '../models/reader_settings.dart';
import '../utils/settings_storage.dart';

class SettingsNotifier extends ChangeNotifier {
  SettingsNotifier({
    ReaderSettings? initialSettings,
    this.storage,
  }) : _settings = initialSettings ?? const ReaderSettings();

  final SettingsStorage? storage;
  ReaderSettings _settings;
  bool _isInitialized = false;

  ReaderSettings get settings => _settings;

  Future<void> loadFromStorage() async {
    if (storage == null || _isInitialized) return;
    _isInitialized = true;

    final saved = await storage!.load();
    if (saved != null) {
      _settings = saved;
      notifyListeners();
    }
  }

  void _saveToStorage() {
    storage?.save(_settings);
  }

  void setSettings(ReaderSettings settings) {
    _settings = settings;
    _saveToStorage();
    notifyListeners();
  }

  void setColorTheme(ColorTheme theme) {
    _settings = _settings.copyWith(
      backgroundColor: theme.background,
      textColor: theme.text,
    );
    _saveToStorage();
    notifyListeners();
  }

  void setFontFamily(String fontFamily) {
    _settings = _settings.copyWith(fontFamily: fontFamily);
    _saveToStorage();
    notifyListeners();
  }

  // fontSize: 1~9 (default: 4)
  void increaseFontSize() {
    if (_settings.fontSize < 9) {
      _settings = _settings.copyWith(fontSize: _settings.fontSize + 1);
      _saveToStorage();
      notifyListeners();
    }
  }

  void decreaseFontSize() {
    if (_settings.fontSize > 1) {
      _settings = _settings.copyWith(fontSize: _settings.fontSize - 1);
      _saveToStorage();
      notifyListeners();
    }
  }

  // lineSpacing: 1~5 (default: 2)
  void increaseLineSpacing() {
    if (_settings.lineSpacing < 5) {
      _settings = _settings.copyWith(lineSpacing: _settings.lineSpacing + 1);
      _saveToStorage();
      notifyListeners();
    }
  }

  void decreaseLineSpacing() {
    if (_settings.lineSpacing > 1) {
      _settings = _settings.copyWith(lineSpacing: _settings.lineSpacing - 1);
      _saveToStorage();
      notifyListeners();
    }
  }

  // margin: 1~5 (default: 1)
  void increaseMargin() {
    if (_settings.margin < 5) {
      _settings = _settings.copyWith(margin: _settings.margin + 1);
      _saveToStorage();
      notifyListeners();
    }
  }

  void decreaseMargin() {
    if (_settings.margin > 1) {
      _settings = _settings.copyWith(margin: _settings.margin - 1);
      _saveToStorage();
      notifyListeners();
    }
  }

  void toggleViewMode() {
    _settings = _settings.copyWith(isPageMode: !_settings.isPageMode);
    _saveToStorage();
    notifyListeners();
  }

  void resetToDefault() {
    _settings = const ReaderSettings();
    _saveToStorage();
    notifyListeners();
  }
}
