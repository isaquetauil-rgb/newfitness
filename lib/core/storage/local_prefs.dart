import 'package:shared_preferences/shared_preferences.dart';

/// Persistência local leve para preferências de UI — não é fonte de verdade
/// de dados do usuário (isso continua no Firestore). Usado para lembrar,
/// por exemplo, a última aba aberta no app.
class LocalPrefs {
  LocalPrefs(this._prefs);

  final SharedPreferences _prefs;

  static const _lastTabIndexKey = 'last_tab_index';

  int? get lastTabIndex => _prefs.getInt(_lastTabIndexKey);

  Future<void> setLastTabIndex(int index) =>
      _prefs.setInt(_lastTabIndexKey, index);
}
