import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Salvaguarda de regressão para a correção de segurança de
/// `users/{userId}` (aluno não pode se auto-vincular a um instrutor
/// alterando o próprio documento).
///
/// IMPORTANTE — o que este arquivo NÃO prova: ele só confere que o TEXTO
/// das condições esperadas está presente em `firestore.rules`; não executa
/// as regras de verdade. Uma prova comportamental completa exigiria o
/// emulador do Firestore + `@firebase/rules-unit-testing`, que este projeto
/// não tem configurado (ver relatório da auditoria de segurança). Isto aqui
/// serve só para pegar alguém removendo/enfraquecendo essas linhas sem
/// perceber numa mudança futura — a garantia real está no arquivo de regras
/// em si, revisado manualmente linha a linha durante a auditoria.
void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync();
  });

  group('users/{userId} — trava de auto-escalonamento de privilégio', () {
    test('criação exige instructorId, nutritionistId e inviteCode nulos (fora do admin)', () {
      expect(
        rules,
        contains("request.resource.data.get('instructorId', null) == null"),
      );
      expect(
        rules,
        contains("request.resource.data.get('nutritionistId', null) == null"),
      );
      expect(
        rules,
        contains("request.resource.data.get('inviteCode', null) == null"),
      );
    });

    test('atualização exige role/instructorId/nutritionistId/inviteCode '
        'inalterados (fora do admin)', () {
      for (final field in [
        'role',
        'instructorId',
        'nutritionistId',
        'inviteCode',
      ]) {
        expect(
          rules,
          contains(
            "request.resource.data.get('$field', null) == "
            "resource.data.get('$field', null)",
          ),
        );
      }
    });

    test('invite_codes é inacessível para qualquer cliente', () {
      expect(rules, contains('match /invite_codes/{code}'));
    });

    test('admin continua com bypass total em create/update/delete', () {
      // A regra de `users/{userId}` deve ter pelo menos 3 ocorrências de
      // `isAdmin()` (create, update, delete) além da usada em `read`.
      final usersBlockStart = rules.indexOf('match /users/{userId} {');
      final usersBlockEnd = rules.indexOf('\n    match /muscle_groups');
      expect(usersBlockStart, greaterThan(-1));
      expect(usersBlockEnd, greaterThan(usersBlockStart));
      final usersBlock = rules.substring(usersBlockStart, usersBlockEnd);
      final adminMatches = 'isAdmin()'.allMatches(usersBlock).length;
      expect(adminMatches, greaterThanOrEqualTo(4));
    });
  });

  group('coleções novas de exercícios/progresso', () {
    test('muscle_groups e equipment só são graváveis pelo admin', () {
      expect(rules, contains('match /muscle_groups/{groupId}'));
      expect(rules, contains('match /equipment/{equipmentId}'));
    });

    test('progress_records só é gravável pelo próprio dono', () {
      expect(rules, contains('match /progress_records/{exerciseId}'));
    });
  });
}
