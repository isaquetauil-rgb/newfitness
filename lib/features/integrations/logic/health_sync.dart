/// Integração opcional com o Health Connect (Android) e o Apple Saúde (iOS):
/// enviar treinos finalizados e ler/gravar o peso corporal. Desligada por
/// padrão; o aluno liga em Perfil > Integrações (vale para este aparelho).
///
/// O acesso ao plugin fica atrás de [HealthGateway] para a lógica ser
/// testada sem celular.
library;

import 'package:newfitness/core/logging/app_logger.dart';
import 'package:newfitness/core/storage/local_prefs.dart';
import 'package:newfitness/shared/models/workout.dart';

final _log = AppLogger.of('HealthSync');

enum HealthAvailability {
  /// Pode usar.
  available,

  /// Android sem o app Health Connect (ou desatualizado): dá para instalar.
  needsInstall,

  /// Aparelho sem suporte.
  unsupported,
}

class WeightSample {
  const WeightSample(this.kg, this.at);
  final double kg;
  final DateTime at;
}

/// O que o app precisa do Health Connect / Apple Saúde.
abstract class HealthGateway {
  Future<HealthAvailability> availability();
  Future<void> installProvider();

  /// Pede acesso a gravar treino e ler/gravar peso. `true` se concedido.
  Future<bool> requestAccess();
  Future<bool> writeWorkout({
    required DateTime start,
    required DateTime end,
    required String title,
  });
  Future<bool> writeWeight(double kg, DateTime at);
  Future<List<WeightSample>> readWeights(DateTime from, DateTime to);
}

/// Intervalo do treino a enviar. Sem duração registrada, conta 1 minuto
/// (o Saúde não aceita sessão de duração zero).
({DateTime start, DateTime end}) workoutWindow(Workout w) {
  final seconds = w.durationSeconds > 60 ? w.durationSeconds : 60;
  return (start: w.date, end: w.date.add(Duration(seconds: seconds)));
}

/// O treino deve ir para o Saúde? Não envia importado (veio de outro app,
/// que provavelmente já enviou) nem treino sem nenhuma série.
bool shouldSendWorkout(Workout w) =>
    !w.isImported && w.exercises.any((e) => e.sets.isNotEmpty);

/// Peso mais recente entre as amostras (ou `null`).
WeightSample? latestWeight(Iterable<WeightSample> samples) {
  WeightSample? best;
  for (final s in samples) {
    if (s.kg <= 0) continue;
    if (best == null || s.at.isAfter(best.at)) best = s;
  }
  return best;
}

/// O peso do Saúde é diferente do perfil (vale oferecer a troca)?
bool weightDiffers(double? profileKg, double healthKg) =>
    profileKg == null || (profileKg - healthKg).abs() >= 0.05;

enum HealthEnableResult { enabled, needsInstall, unsupported, denied }

class HealthSync {
  HealthSync({required this.gateway, required this.prefs});

  final HealthGateway gateway;
  final LocalPrefs prefs;

  bool get enabled => prefs.healthSyncEnabled;

  /// Liga a integração: confere se o aparelho suporta e pede permissão.
  Future<HealthEnableResult> enable() async {
    final availability = await gateway.availability();
    switch (availability) {
      case HealthAvailability.needsInstall:
        return HealthEnableResult.needsInstall;
      case HealthAvailability.unsupported:
        return HealthEnableResult.unsupported;
      case HealthAvailability.available:
        break;
    }
    final granted = await gateway.requestAccess();
    if (!granted) return HealthEnableResult.denied;
    await prefs.setHealthSyncEnabled(true);
    return HealthEnableResult.enabled;
  }

  Future<void> disable() => prefs.setHealthSyncEnabled(false);

  /// Envia o treino recém-finalizado. Nunca lança: o treino já está salvo
  /// no app, o Saúde é só uma cópia.
  Future<bool> onWorkoutFinished(Workout w) async {
    if (!enabled || !shouldSendWorkout(w)) return false;
    try {
      final window = workoutWindow(w);
      return await gateway.writeWorkout(
        start: window.start,
        end: window.end,
        title: w.name,
      );
    } catch (e, st) {
      _log.warning('Falha ao enviar treino para o Saúde', e, st);
      return false;
    }
  }

  /// Grava o peso (ex.: quando o aluno muda no perfil). Nunca lança.
  Future<bool> pushWeight(double kg, {DateTime? at}) async {
    if (!enabled || kg <= 0) return false;
    try {
      return await gateway.writeWeight(kg, at ?? DateTime.now());
    } catch (e, st) {
      _log.warning('Falha ao gravar peso no Saúde', e, st);
      return false;
    }
  }

  /// Peso mais recente no Saúde nos últimos [days] dias (ou `null`).
  Future<WeightSample?> readLatestWeight({int days = 90}) async {
    if (!enabled) return null;
    try {
      final now = DateTime.now();
      return latestWeight(
        await gateway.readWeights(now.subtract(Duration(days: days)), now),
      );
    } catch (e, st) {
      _log.warning('Falha ao ler peso do Saúde', e, st);
      return null;
    }
  }
}
