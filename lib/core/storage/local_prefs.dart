import 'package:shared_preferences/shared_preferences.dart';

/// Persistência local leve para preferências de UI — não é fonte de verdade
/// de dados do usuário (isso continua no Firestore). Usado para lembrar,
/// por exemplo, a última aba aberta no app.
class LocalPrefs {
  LocalPrefs(this._prefs);

  final SharedPreferences _prefs;

  static const _lastTabIndexKey = 'last_tab_index';
  static const _darkModeKey = 'dark_mode';
  static const _activeWorkoutKey = 'active_workout_v1';

  int? get lastTabIndex => _prefs.getInt(_lastTabIndexKey);

  Future<void> setLastTabIndex(int index) =>
      _prefs.setInt(_lastTabIndexKey, index);

  bool get isDarkMode => _prefs.getBool(_darkModeKey) ?? false;

  Future<void> setDarkMode(bool value) => _prefs.setBool(_darkModeKey, value);

  /// Rascunho do treino em andamento (JSON) — ver `ActiveWorkoutStore`.
  String? get activeWorkoutJson => _prefs.getString(_activeWorkoutKey);

  Future<void> setActiveWorkoutJson(String json) =>
      _prefs.setString(_activeWorkoutKey, json);

  Future<void> clearActiveWorkout() => _prefs.remove(_activeWorkoutKey);
}
