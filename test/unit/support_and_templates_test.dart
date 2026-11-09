import 'package:flutter_test/flutter_test.dart';
import 'package:newfitness/features/instructor/presentation/plan_editor_screen.dart';
import 'package:newfitness/shared/models/sample_exercises.dart';
import 'package:newfitness/shared/models/support.dart';
import 'package:newfitness/shared/models/workout_templates.dart';

void main() {
  group('canal de apoio', () {
    test('prévia corta mensagens longas no limite das regras', () {
      final preview = supportPreview('a' * 500);
      expect(preview.length, supportPreviewMaxLength);
      expect(preview.endsWith('…'), isTrue);
    });

    test('prévia junta quebras de linha e espaços', () {
      expect(supportPreview('  oi\n\n  tudo   bem? '), 'oi tudo bem?');
    });

    test('lê a conversa com valores padrão seguros', () {
      final thread = SupportThread.fromMap('u1', const {});
      expect(thread.name, 'Aluno');
      expect(thread.lastFrom, SupportAuthor.student);
      expect(thread.unreadByAdmin, isFalse);

      final message = SupportMessage.fromMap('m', const {
        'text': 'Oi',
        'from': 'admin',
        'createdAt': 1000,
      });
      expect(message.from, SupportAuthor.admin);
      expect(message.createdAt.millisecondsSinceEpoch, 1000);
    });
  });

  group('biblioteca', () {
    test('ids únicos e todo exercício com vídeo do YouTube', () {
      final ids = sampleExercises.map((e) => e.id).toSet();
      expect(ids.length, sampleExercises.length);
      for (final e in sampleExercises) {
        expect(
          RegExp(r'^https://www\.youtube\.com/watch\?v=[\w-]{11}$')
              .hasMatch(e.videoUrl),
          isTrue,
          reason: e.id,
        );
        expect(e.instructions, isNotEmpty, reason: e.id);
      }
    });
  });

  group('treinos prontos', () {
    test('todo treino tem aquecimento e progressão', () {
      for (final t in workoutTemplates) {
        expect(t.warmUp, isNotEmpty, reason: t.id);
        expect(t.progression.trim(), isNotEmpty, reason: t.id);
      }
    });

    test('perfis pedidos existem', () {
      final ids = workoutTemplates.map((t) => t.id).toSet();
      for (final id in [
        'futebol',
        'mma',
        'muay_thai',
        'boxe',
        'jiu_jitsu',
        'atleta',
        'fisiculturismo_masculino',
        'fisiculturismo_feminino',
        'idosos',
      ]) {
        expect(ids, contains(id));
      }
    });

    test('personal recebe o treino pronto como modelo editável', () {
      final ready = workoutTemplates.firstWhere((t) => t.id == 'idosos');
      final plan = planTemplateFromReady(ready, 'instrutor');
      expect(plan.instructorUid, 'instrutor');
      expect(plan.workouts, ready.workouts);
      expect(plan.instructions, contains('Aquecimento'));
      expect(plan.instructions, contains('Atenção'));
    });
  });
}
