import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:newfitness/features/notifications/data/notification_service.dart';

void main() {
  group('scheduleModeFor', () {
    test('exato só quando o Android permite', () {
      expect(scheduleModeFor(true), AndroidScheduleMode.exactAllowWhileIdle);
      expect(scheduleModeFor(null), AndroidScheduleMode.exactAllowWhileIdle);
      expect(scheduleModeFor(false), AndroidScheduleMode.inexactAllowWhileIdle);
    });
  });

  group('scheduleWithFallback', () {
    test('permissão negada: agenda direto no inexato', () async {
      final modes = <AndroidScheduleMode>[];
      await scheduleWithFallback((m) async => modes.add(m), false);
      expect(modes, [AndroidScheduleMode.inexactAllowWhileIdle]);
    });

    test('Android recusa o exato na hora: tenta de novo no inexato', () async {
      final modes = <AndroidScheduleMode>[];
      await scheduleWithFallback((m) async {
        modes.add(m);
        if (m == AndroidScheduleMode.exactAllowWhileIdle) {
          throw PlatformException(
            code: 'exact_alarms_not_permitted',
            message: 'Exact alarms are not permitted',
          );
        }
      }, true);
      expect(modes, [
        AndroidScheduleMode.exactAllowWhileIdle,
        AndroidScheduleMode.inexactAllowWhileIdle,
      ]);
    });

    test(
      'SecurityException do AlarmManager também cai para o inexato',
      () async {
        final modes = <AndroidScheduleMode>[];
        await scheduleWithFallback((m) async {
          modes.add(m);
          if (m == AndroidScheduleMode.exactAllowWhileIdle) {
            throw PlatformException(
              code: 'error',
              message:
                  'java.lang.SecurityException: Caller needs '
                  'SCHEDULE_EXACT_ALARM',
            );
          }
        }, null);
        expect(modes.last, AndroidScheduleMode.inexactAllowWhileIdle);
      },
    );

    test('outros erros não são escondidos', () async {
      expect(
        () => scheduleWithFallback(
          (_) async => throw PlatformException(code: 'invalid_icon'),
          true,
        ),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
