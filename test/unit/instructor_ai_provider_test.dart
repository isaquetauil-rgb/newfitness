import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/features/instructor/logic/instructor_ai_provider.dart';

import '../helpers/mocks.dart';

void main() {
  late MockAiService aiService;
  late InstructorAiProvider provider;

  setUp(() {
    aiService = MockAiService();
    provider = InstructorAiProvider(aiService: aiService);
  });

  test(
    'ask geral chama AiService sem studentName e guarda a sugestão',
    () async {
      when(
        () => aiService.suggestTrainingPlan(
          prompt: any(named: 'prompt'),
          studentName: any(named: 'studentName'),
        ),
      ).thenAnswer((_) async => 'Experimente rosca alternada e tríceps corda.');

      await provider.ask(prompt: 'mais ideias de treino de braço');

      expect(
        provider.suggestion,
        'Experimente rosca alternada e tríceps corda.',
      );
      expect(provider.error, isNull);
      expect(provider.isLoading, isFalse);
      verify(
        () => aiService.suggestTrainingPlan(
          prompt: 'mais ideias de treino de braço',
          studentName: null,
        ),
      ).called(1);
    },
  );

  test('ask contextualizado por aluno passa o studentName adiante', () async {
    when(
      () => aiService.suggestTrainingPlan(
        prompt: any(named: 'prompt'),
        studentName: any(named: 'studentName'),
      ),
    ).thenAnswer((_) async => 'Foque em mobilidade e fortalecimento lombar.');

    await provider.ask(prompt: 'dor nas costas', studentName: 'Dona Maria');

    verify(
      () => aiService.suggestTrainingPlan(
        prompt: 'dor nas costas',
        studentName: 'Dona Maria',
      ),
    ).called(1);
  });

  test('erro da IA vira mensagem amigável', () async {
    when(
      () => aiService.suggestTrainingPlan(
        prompt: any(named: 'prompt'),
        studentName: any(named: 'studentName'),
      ),
    ).thenThrow(Exception('falha de rede'));

    await provider.ask(prompt: 'teste');

    expect(provider.suggestion, isNull);
    expect(provider.error, isNotNull);
  });

  test('reset limpa o estado', () async {
    when(
      () => aiService.suggestTrainingPlan(
        prompt: any(named: 'prompt'),
        studentName: any(named: 'studentName'),
      ),
    ).thenAnswer((_) async => 'sugestão');
    await provider.ask(prompt: 'teste');

    provider.reset();

    expect(provider.suggestion, isNull);
    expect(provider.error, isNull);
    expect(provider.isLoading, isFalse);
  });
}
