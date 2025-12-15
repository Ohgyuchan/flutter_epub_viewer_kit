import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reader_settings.dart';
import '../utils/settings_storage.dart';

class SettingsNotifier extends Notifier<ReaderSettings> {
  ReaderSettings? _initialSettings;
  SettingsStorage? _storage;
  bool _isInitialized = false;

  void setInitialSettings(ReaderSettings settings) {
    _initialSettings = settings;
  }

  void setStorage(SettingsStorage storage) {
    _storage = storage;
  }

  @override
  ReaderSettings build() {
    return _initialSettings ?? const ReaderSettings();
  }

  Future<void> loadFromStorage() async {
    if (_storage == null || _isInitialized) return;
    _isInitialized = true;

    final saved = await _storage!.load();
    if (saved != null) {
      state = saved;
    }
  }

  void _saveToStorage() {
    _storage?.save(state);
  }

  void setSettings(ReaderSettings settings) {
    state = settings;
    _saveToStorage();
  }

  void setColorTheme(ColorTheme theme) {
    state = state.copyWith(
      backgroundColor: theme.background,
      textColor: theme.text,
    );
    _saveToStorage();
  }

  void setFontFamily(String fontFamily) {
    state = state.copyWith(fontFamily: fontFamily);
    _saveToStorage();
  }

  // fontSize: 1~9 (default: 4)
  void increaseFontSize() {
    if (state.fontSize < 9) {
      state = state.copyWith(fontSize: state.fontSize + 1);
      _saveToStorage();
    }
  }

  void decreaseFontSize() {
    if (state.fontSize > 1) {
      state = state.copyWith(fontSize: state.fontSize - 1);
      _saveToStorage();
    }
  }

  // lineSpacing: 1~5 (default: 2)
  void increaseLineSpacing() {
    if (state.lineSpacing < 5) {
      state = state.copyWith(lineSpacing: state.lineSpacing + 1);
      _saveToStorage();
    }
  }

  void decreaseLineSpacing() {
    if (state.lineSpacing > 1) {
      state = state.copyWith(lineSpacing: state.lineSpacing - 1);
      _saveToStorage();
    }
  }

  // margin: 1~5 (default: 1)
  void increaseMargin() {
    if (state.margin < 5) {
      state = state.copyWith(margin: state.margin + 1);
      _saveToStorage();
    }
  }

  void decreaseMargin() {
    if (state.margin > 1) {
      state = state.copyWith(margin: state.margin - 1);
      _saveToStorage();
    }
  }

  void toggleViewMode() {
    state = state.copyWith(isPageMode: !state.isPageMode);
    _saveToStorage();
  }

  void resetToDefault() {
    state = const ReaderSettings();
    _saveToStorage();
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, ReaderSettings>(SettingsNotifier.new);
