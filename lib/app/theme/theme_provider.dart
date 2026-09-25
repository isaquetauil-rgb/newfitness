import 'package:flutter/material.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/core/storage/local_prefs.dart';

/// Preferência de modo claro/escuro do usuário, persistida localmente (não é
/// dado de conta — por isso fica em [LocalPrefs], não no Firestore).
class ThemeProvider extends ChangeNotifier {
  ThemeProvider({LocalPrefs? localPrefs})
    : _localPrefs = localPrefs ?? getIt<LocalPrefs>(),
      _isDarkMode = (localPrefs ?? getIt<LocalPrefs>()).isDarkMode;

  final LocalPrefs _localPrefs;
  bool _isDarkMode;

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    notifyListeners();
    await _localPrefs.setDarkMode(value);
  }
}
