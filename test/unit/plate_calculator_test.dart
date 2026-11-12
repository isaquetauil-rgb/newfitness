import 'package:flutter_test/flutter_test.dart';

import 'package:newfitness/features/workout/logic/plate_calculator.dart';
import 'package:newfitness/shared/models/plate_setup.dart';
import 'package:newfitness/shared/models/user_profile.dart';

void main() {
  const padrao = PlateSetup();

  group('loadPlates', () {
    test('barra de 20 kg: 100 kg = 25 + 15 de cada lado', () {
      final r = loadPlates(100, padrao);
      expect(r.perSide, [25, 15]);
      expect(r.achievedKg, 100);
      expect(r.exact, isTrue);
    });

    test('usa anilhas pequenas: 62,5 kg = 20 + 1,25', () {
      final r = loadPlates(62.5, padrao);
      expect(r.perSide, [20, 1.25]);
      expect(r.exact, isTrue);
    });

    test('mesmo tamanho repetido aparece agrupado', () {
      final r = loadPlates(140, padrao); // 60 por lado
      expect(r.perSide, [25, 25, 10]);
      expect(r.grouped, {25.0: 2, 10.0: 1});
    });

    test('não fecha: mostra o mais próximo (empate fica no mais leve)', () {
      // Sem 1,25: 61 kg pediria 20,5 por lado; dá 20 (60 kg) ou 22,5 (65).
      const semPequenas = PlateSetup(platesKg: [20, 10, 5, 2.5]);
      final r = loadPlates(61, semPequenas);
      expect(r.exact, isFalse);
      expect(r.achievedKg, 60);
      // 62,5 pede 21,25 por lado: exatamente entre 20 e 22,5 → o mais leve.
      expect(loadPlates(62.5, semPequenas).achievedKg, 60);
      expect(loadPlates(64, semPequenas).achievedKg, 65);
    });

    test('acha a combinação exata mesmo quando "pegar a maior" erraria', () {
      // Só 15 e 10: 20 por lado = 10 + 10 (pegar 15 primeiro não fecha).
      const r15 = PlateSetup(platesKg: [15, 10]);
      final r = loadPlates(60, r15);
      expect(r.perSide, [10, 10]);
      expect(r.exact, isTrue);
    });

    test('menor que a barra ou igual: só a barra', () {
      final r = loadPlates(15, padrao);
      expect(r.perSide, isEmpty);
      expect(r.achievedKg, 20);
      expect(r.belowBar, isTrue);
      expect(loadPlates(20, padrao).exact, isTrue);
    });

    test('barra configurada pelo aluno', () {
      const curta = PlateSetup(barKg: 10);
      final r = loadPlates(30, curta);
      expect(r.perSide, [10]);
      expect(r.barKg, 10);
    });

    test('formato pt-BR', () {
      expect(plateKg(1.25), '1,25 kg');
      expect(plateKg(2.5), '2,5 kg');
      expect(plateKg(20), '20 kg');
    });
  });

  group('PlateSetup no perfil', () {
    test('perfil antigo sem o campo: barra de 20 e anilhas padrão', () {
      final p = UserProfile.fromMap('u', {'name': 'Ana', 'email': 'a@x'});
      expect(p.plateSetup, isNull);
      expect(p.toMap().containsKey('plateSetup'), isFalse);
      final s = PlateSetup.fromMap(null);
      expect(s.barKg, 20);
      expect(s.platesKg, PlateSetup.defaultPlatesKg);
    });

    test('vai e volta pelo perfil, ordenado e sem valores inválidos', () {
      final p = UserProfile.fromMap('u', {
        'name': 'Ana',
        'email': 'a@x',
        'plateSetup': {
          'barKg': 15,
          'platesKg': [5, 20, -1, 'x', 10],
        },
      });
      expect(p.plateSetup!.barKg, 15);
      expect(p.plateSetup!.platesKg, [20, 10, 5]);
      expect(p.toMap()['plateSetup'], {
        'barKg': 15.0,
        'platesKg': [20.0, 10.0, 5.0],
      });
      expect(p.copyWith(name: 'B').plateSetup!.barKg, 15);
    });
  });
}
