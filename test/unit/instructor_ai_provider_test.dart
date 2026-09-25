import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/features/instructor/logic/instructor_ai_provider.dart';
import 'package:newfitness/shared/models/exercise_suggestion.dart';

import '../helpers/mocks.dart';

void main() {
  late MockAiService aiService;
  late InstructorAiProvider provider;

  setUp(() {
    aiService = MockAiService();
    provider = InstructorAiProvider(aiService: aiService);
  });

  const sampleSuggestions = [
    ExerciseSuggestion(
      exerciseName: 'Rosca alternada',
      sets: 3,
      reps: '10-12',
      restSeconds: 60,
      reason: 'Isola o bíceps sem sobrecarregar o ombro.',
    ),
    ExerciseSuggestion(
      exerciseName: 'Tríceps corda',
      sets: 3,
      reps: '12-15',
      restSeconds: 45,
      reason: 'Trabalha a cabeça lateral do tríceps.',
    ),
  ];

  test(
    'ask geral chama AiService sem studentName e guarda as sugestões',
    () async {
      when(
        () => aiService.suggestTrainingPlan(
          prompt: any(named: 'prompt'),
          studentName: any(named: 'studentName'),
        ),
      ).thenAnswer(
        (_) async =>
            const TrainingSuggestionResult(suggestions: sampleSuggestions),
      );

      await provider.ask(prompt: 'mais ideias de treino de braço');

      expect(provider.suggestions, sampleSuggestions);
      expect(provider.rawText, isNull);
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
    ).thenAnswer(
      (_) async =>
          const TrainingSuggestionResult(suggestions: sampleSuggestions),
    );

    await provider.ask(prompt: 'dor nas costas', studentName: 'Dona Maria');

    verify(
      () => aiService.suggestTrainingPlan(
        prompt: 'dor nas costas',
        studentName: 'Dona Maria',
      ),
    ).called(1);
  });

  test('resposta sem JSON válido vira rawText de fallback', () async {
    when(
      () => aiService.suggestTrainingPlan(
        prompt: any(named: 'prompt'),
        studentName: any(named: 'studentName'),
      ),
    ).thenAnswer(
      (_) async => const TrainingSuggestionResult(
        rawText: 'Foque em mobilidade e fortalecimento lombar.',
      ),
    );

    await provider.ask(prompt: 'dor nas costas', studentName: 'Dona Maria');

    expect(provider.suggestions, isEmpty);
    expect(provider.rawText, 'Foque em mobilidade e fortalecimento lombar.');
  });

  test('erro da IA vira mensagem amigável', () async {
    when(
      () => aiService.suggestTrainingPlan(
        prompt: any(named: 'prompt'),
        studentName: any(named: 'studentName'),
      ),
    ).thenThrow(Exception('falha de rede'));

    await provider.ask(prompt: 'teste');

    expect(provider.suggestions, isEmpty);
    expect(provider.error, isNotNull);
  });

  test('reset limpa o estado', () async {
    when(
      () => aiService.suggestTrainingPlan(
        prompt: any(named: 'prompt'),
        studentName: any(named: 'studentName'),
      ),
    ).thenAnswer(
      (_) async =>
          const TrainingSuggestionResult(suggestions: sampleSuggestions),
    );
    await provider.ask(prompt: 'teste');

    provider.reset();

    expect(provider.suggestions, isEmpty);
    expect(provider.rawText, isNull);
    expect(provider.error, isNull);
    expect(provider.isLoading, isFalse);
  });
}
