import 'dart:io' show Platform;

import 'package:health/health.dart';

import 'package:newfitness/features/integrations/logic/health_sync.dart';

/// [HealthGateway] de verdade, pelo pacote `health` (Health Connect no
/// Android, HealthKit no iOS).
class PluginHealthGateway implements HealthGateway {
  PluginHealthGateway() : _health = Health();

  final Health _health;
  bool _configured = false;

  static const _types = [HealthDataType.WORKOUT, HealthDataType.WEIGHT];
  static const _access = [HealthDataAccess.WRITE, HealthDataAccess.READ_WRITE];

  Future<void> _ready() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<HealthAvailability> availability() async {
    if (Platform.isIOS) return HealthAvailability.available;
    if (!Platform.isAndroid) return HealthAvailability.unsupported;
    await _ready();
    final status = await _health.getHealthConnectSdkStatus();
    return switch (status) {
      HealthConnectSdkStatus.sdkAvailable => HealthAvailability.available,
      // Sem o app (Android 9 a 13) ou desatualizado: a loja resolve. Se o
      // aparelho não for compatível, a própria loja avisa.
      HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired ||
      HealthConnectSdkStatus.sdkUnavailable => HealthAvailability.needsInstall,
      null => HealthAvailability.unsupported,
    };
  }

  @override
  Future<void> installProvider() async {
    await _ready();
    await _health.installHealthConnect();
  }

  @override
  Future<bool> requestAccess() async {
    await _ready();
    return _health.requestAuthorization(_types, permissions: _access);
  }

  @override
  Future<bool> writeWorkout({
    required DateTime start,
    required DateTime end,
    required String title,
  }) async {
    await _ready();
    return _health.writeWorkoutData(
      activityType: Platform.isIOS
          ? HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING
          : HealthWorkoutActivityType.STRENGTH_TRAINING,
      start: start,
      end: end,
      title: title,
      recordingMethod: RecordingMethod.manual,
    );
  }

  @override
  Future<bool> writeWeight(double kg, DateTime at) async {
    await _ready();
    return _health.writeHealthData(
      value: kg,
      unit: HealthDataUnit.KILOGRAM,
      type: HealthDataType.WEIGHT,
      startTime: at,
      endTime: at,
      recordingMethod: RecordingMethod.manual,
    );
  }

  @override
  Future<List<WeightSample>> readWeights(DateTime from, DateTime to) async {
    await _ready();
    final points = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.WEIGHT],
      startTime: from,
      endTime: to,
    );
    return [
      for (final p in points)
        if (p.value is NumericHealthValue)
          WeightSample(
            (p.value as NumericHealthValue).numericValue.toDouble(),
            p.dateFrom,
          ),
    ];
  }
}
