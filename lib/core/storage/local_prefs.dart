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
  static const _onboardingSeenKey = 'onboarding_seen';

  int? get lastTabIndex => _prefs.getInt(_lastTabIndexKey);

  Future<void> setLastTabIndex(int index) =>
      _prefs.setInt(_lastTabIndexKey, index);

  /// As telas de primeira visita já foram vistas neste aparelho?
  bool get onboardingSeen => _prefs.getBool(_onboardingSeenKey) ?? false;

  Future<void> setOnboardingSeen() => _prefs.setBool(_onboardingSeenKey, true);

  bool get isDarkMode => _prefs.getBool(_darkModeKey) ?? false;

  Future<void> setDarkMode(bool value) => _prefs.setBool(_darkModeKey, value);

  /// Rascunho do treino em andamento (JSON) — ver `ActiveWorkoutStore`.
  String? get activeWorkoutJson => _prefs.getString(_activeWorkoutKey);

  Future<void> setActiveWorkoutJson(String json) =>
      _prefs.setString(_activeWorkoutKey, json);

  Future<void> clearActiveWorkout() => _prefs.remove(_activeWorkoutKey);

  // Cronômetro de descanso (Configurações). Tudo ligado por padrão.
  static const _restAutoStartKey = 'rest_auto_start';
  static const _restSoundKey = 'rest_sound';
  static const _restVibrationKey = 'rest_vibration';

  bool get restAutoStart => _prefs.getBool(_restAutoStartKey) ?? true;
  bool get restSound => _prefs.getBool(_restSoundKey) ?? true;
  bool get restVibration => _prefs.getBool(_restVibrationKey) ?? true;

  Future<void> setRestAutoStart(bool v) => _prefs.setBool(_restAutoStartKey, v);
  Future<void> setRestSound(bool v) => _prefs.setBool(_restSoundKey, v);
  Future<void> setRestVibration(bool v) => _prefs.setBool(_restVibrationKey, v);
}
