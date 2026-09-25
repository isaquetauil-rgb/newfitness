import 'package:flutter/material.dart';

import 'package:newfitness/shared/models/exercise.dart';

import 'alternative_exercises_field.dart';
import 'exercise_form_controller.dart';

/// Todos os campos do formulário de exercício, organizados em seções —
/// compartilhado entre `AdminExerciseFormScreen` (biblioteca global) e
/// `CustomExerciseFormScreen` (biblioteca privada do instrutor), que só
/// diferem em como tratam o vídeo e onde salvam (ver `ExerciseFormController`
/// para o estado e `buildExercise()` para montar o [Exercise] final).
class ExerciseFormFields extends StatelessWidget {
  const ExerciseFormFields({
    super.key,
    required this.controller,
    required this.allExercises,
    required this.muscleGroupOptions,
    required this.equipmentOptions,
  });

  final ExerciseFormController controller;

  /// Pool usado pelos campos de variações/substitutos (o próprio exercício,
  /// se já tiver id, é excluído automaticamente).
  final List<Exercise> allExercises;
  final List<String> muscleGroupOptions;
  final List<String> equipmentOptions;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Informações básicas'),
            TextField(
              controller: controller.nameCtrl,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.alternateNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome alternativo (opcional)',
                hintText: 'ex: Stiff, para "Levantamento terra romeno"',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AutocompleteTextField(
                    controller: controller.muscleGroupCtrl,
                    focusNode: controller.muscleGroupFocusNode,
                    label: 'Grupo muscular',
                    options: muscleGroupOptions,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AutocompleteTextField(
                    controller: controller.equipmentCtrl,
                    focusNode: controller.equipmentFocusNode,
                    label: 'Equipamento',
                    options: equipmentOptions,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Categoria', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final cat in exerciseCategories)
                  ChoiceChip(
                    label: Text(exerciseCategoryLabel(cat)),
                    selected: controller.category == cat,
                    onSelected: (_) => controller.category =
                        controller.category == cat ? '' : cat,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.descriptionCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Descrição'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.imageUrlsCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Imagens do exercício (uma URL por linha, opcional)',
              ),
            ),

            const _SectionTitle('Como executar'),
            TextField(
              controller: controller.instructionsCtrl,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Passo a passo (uma instrução por linha)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.executionNotesCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Execução correta (dicas de postura/respiração)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.commonMistakesCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Erros comuns (um por linha)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.careNotesCtrl,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Cuidados e observações',
                hintText: 'ex: evitar em caso de dor lombar aguda',
              ),
            ),

            const _SectionTitle('Prescrição padrão'),
            Text(
              'Usada para pré-preencher a ficha do instrutor — cada plano '
              'pode ajustar livremente.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.defaultSetsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Séries'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: controller.defaultRepsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Reps (ex: 8-12)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.executionTempoSecondsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tempo de execução (s)',
                      hintText: 'ex: prancha, isometria',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: controller.defaultRestSecondsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Descanso (s)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.defaultLoadCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Carga sugerida',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: controller.loadUnit.isEmpty
                        ? null
                        : controller.loadUnit,
                    decoration: const InputDecoration(labelText: 'Unidade'),
                    items: [
                      for (final unit in exerciseLoadUnits)
                        DropdownMenuItem(value: unit, child: Text(unit)),
                    ],
                    onChanged: (v) => controller.loadUnit = v ?? '',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Registra distância (cardio)'),
              value: controller.tracksDistance,
              onChanged: (v) => controller.tracksDistance = v,
            ),
            if (controller.tracksDistance)
              TextField(
                controller: controller.defaultDistanceMetersCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Distância sugerida (metros)',
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Registra duração (cardio)'),
              value: controller.tracksDuration,
              onChanged: (v) => controller.tracksDuration = v,
            ),
            if (controller.tracksDuration)
              TextField(
                controller: controller.defaultDurationSecondsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duração sugerida (segundos)',
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.estimatedCaloriesPerMinuteCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Calorias estimadas por minuto (opcional)',
              ),
            ),

            const _SectionTitle('Classificação para "Trocar exercício"'),
            Text(
              'Usada para sugerir automaticamente exercícios equivalentes e '
              'para os filtros da biblioteca.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Text(
              'Nível de dificuldade',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final level in exerciseDifficultyLevels)
                  ChoiceChip(
                    label: Text(exerciseDifficultyLabel(level)),
                    selected: controller.difficultyLevel == level,
                    onSelected: (_) => controller.difficultyLevel =
                        controller.difficultyLevel == level ? '' : level,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.movementPatternCtrl,
              decoration: InputDecoration(
                labelText: 'Padrão de movimento',
                hintText: exerciseMovementPatternSuggestions.join(', '),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.secondaryMusclesCtrl,
              decoration: const InputDecoration(
                labelText: 'Músculos secundários (separados por vírgula)',
                hintText: 'ex: Tríceps, Ombro',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.objectivesCtrl,
              decoration: InputDecoration(
                labelText: 'Objetivo (separado por vírgula)',
                hintText: exerciseObjectiveSuggestions.join(', '),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.searchTagsCtrl,
              decoration: const InputDecoration(
                labelText: 'Tags de busca (separadas por vírgula)',
                hintText: 'ex: peito superior, compound',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Cadeia muscular/movimento',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final chain in exerciseKineticChains)
                  ChoiceChip(
                    label: Text(chain[0].toUpperCase() + chain.substring(1)),
                    selected: controller.kineticChain == chain,
                    onSelected: (_) => controller.kineticChain =
                        controller.kineticChain == chain ? '' : chain,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exercício unilateral'),
              subtitle: const Text('Feito um lado do corpo por vez'),
              value: controller.isUnilateral,
              onChanged: (v) => controller.isUnilateral = v,
            ),

            const _SectionTitle('Variações e substitutos'),
            AlternativeExercisesField(
              allExercises: allExercises,
              excludeId: controller.existing?.id,
              selectedIds: controller.variationIds,
              onChanged: controller.setVariationIds,
              title: 'Variações deste exercício',
              helperText:
                  'Mesmo movimento com ângulo/equipamento diferente (ex: '
                  'supino reto → supino inclinado com halteres).',
              emptyText: 'Nenhuma variação vinculada ainda.',
            ),
            const SizedBox(height: 20),
            AlternativeExercisesField(
              allExercises: allExercises,
              excludeId: controller.existing?.id,
              selectedIds: controller.alternativeIds,
              onChanged: controller.setAlternativeIds,
              title: 'Substitutos equivalentes',
              helperText:
                  'Mesmo objetivo/músculo, movimento não necessariamente '
                  'igual (ex: supino reto → crucifixo).',
              emptyText:
                  'Nenhum substituto vinculado ainda — o sistema ainda assim '
                  'sugere automaticamente por grupo muscular, padrão de '
                  'movimento e equipamento.',
            ),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Campo de texto com sugestões vindas da taxonomia curada
/// (`ExerciseTaxonomyProvider`), mas que continua aceitando qualquer texto
/// livre — não trava o cadastro caso o valor ainda não exista na taxonomia.
class _AutocompleteTextField extends StatelessWidget {
  const _AutocompleteTextField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.options,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (value) {
        if (value.text.isEmpty) return options;
        final query = value.text.toLowerCase();
        return options.where((o) => o.toLowerCase().contains(query));
      },
      fieldViewBuilder:
          (context, textEditingController, fieldFocusNode, onSubmitted) {
            return TextField(
              controller: textEditingController,
              focusNode: fieldFocusNode,
              decoration: InputDecoration(labelText: label),
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        final optionsList = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 200,
                maxWidth: MediaQuery.sizeOf(context).width - 32,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: optionsList.length,
                itemBuilder: (context, i) => ListTile(
                  dense: true,
                  title: Text(optionsList[i]),
                  onTap: () => onSelected(optionsList[i]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
