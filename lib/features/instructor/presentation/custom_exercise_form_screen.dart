import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/exercises/logic/exercise_provider.dart';
import 'package:newfitness/features/exercises/logic/exercise_taxonomy_provider.dart';
import 'package:newfitness/features/exercises/presentation/exercise_form_controller.dart';
import 'package:newfitness/features/exercises/presentation/exercise_form_fields.dart';
import 'package:newfitness/features/instructor/logic/custom_exercise_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';

const _uuid = Uuid();

enum _VideoSource { youtubeLink, ownUpload }

/// Formulário de criar/editar um exercício da biblioteca privada do
/// instrutor. Diferente do formulário do admin (`AdminExerciseFormScreen`),
/// o vídeo aceita dois formatos: um link do YouTube (colado) ou um vídeo
/// próprio, gravado/selecionado no celular e enviado ao Firebase Storage —
/// o instrutor escolhe qual usar em [_VideoSource]. Os demais campos
/// (todos os que descrevem o exercício em si) são compartilhados com o
/// formulário do admin via `ExerciseFormFields`.
class CustomExerciseFormScreen extends StatefulWidget {
  const CustomExerciseFormScreen({super.key, this.existing});

  final Exercise? existing;

  @override
  State<CustomExerciseFormScreen> createState() =>
      _CustomExerciseFormScreenState();
}

class _CustomExerciseFormScreenState extends State<CustomExerciseFormScreen> {
  late final _form = ExerciseFormController(widget.existing);
  late final _videoUrlCtrl = TextEditingController(
    text: widget.existing?.videoUrl ?? '',
  );

  _VideoSource _videoSource = _VideoSource.youtubeLink;
  late String? _uploadedVideoUrl = widget.existing?.videoUrl;
  bool _saving = false;

  @override
  void dispose() {
    _form.dispose();
    _videoUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadVideo(ImageSource source) async {
    final instructorUid = context.read<AuthProvider>().user?.uid;
    if (instructorUid == null) return;
    final picker = ImagePicker();
    final file = await picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 3),
    );
    if (file == null || !mounted) return;

    final provider = context.read<CustomExerciseProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await file.readAsBytes();
      // `file.name` (não `file.path`): no Web o path é uma URL `blob:http://
      // host:porta/uuid`, e a "extensão" tirada dele tinha `:` e `/` — o
      // arquivo ia para um caminho aninhado que as regras do Storage não
      // aceitam, e o upload falhava.
      final extension = videoExtensionOf(file.name);
      final url = await provider.uploadVideo(
        instructorUid,
        bytes,
        extension: extension,
      );
      if (mounted) setState(() => _uploadedVideoUrl = url);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Não foi possível enviar o vídeo: $e')),
      );
    }
  }

  Future<void> _save() async {
    final instructorUid = context.read<AuthProvider>().user?.uid;
    if (instructorUid == null) return;
    if (!_form.isValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dê um nome ao exercício.')));
      return;
    }

    final videoUrl = _videoSource == _VideoSource.youtubeLink
        ? _videoUrlCtrl.text.trim()
        : (_uploadedVideoUrl ?? '');

    setState(() => _saving = true);
    final exercise = _form.buildExercise(
      id: widget.existing?.id ?? _uuid.v4(),
      videoUrl: videoUrl,
    );
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<CustomExerciseProvider>().saveExercise(
        instructorUid,
        exercise,
      );
      messenger.showSnackBar(const SnackBar(content: Text('Exercício salvo')));
      if (mounted) context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar o exercício.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploading = context.watch<CustomExerciseProvider>().isUploadingVideo;
    final instructorUid = context.watch<AuthProvider>().user?.uid;
    final global = context.watch<ExerciseProvider>().exercises;
    final taxonomy = context.watch<ExerciseTaxonomyProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Novo exercício' : 'Editar exercício',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (instructorUid == null)
            ExerciseFormFields(
              controller: _form,
              allExercises: global,
              muscleGroupOptions: [
                for (final g in taxonomy.muscleGroups) g.name,
              ],
              equipmentOptions: [for (final e in taxonomy.equipment) e.name],
            )
          else
            StreamBuilder<List<Exercise>>(
              stream: context.read<CustomExerciseProvider>().watchExercises(
                instructorUid,
              ),
              builder: (context, snapshot) {
                final custom = snapshot.data ?? const [];
                return ExerciseFormFields(
                  controller: _form,
                  allExercises: [...custom, ...global],
                  muscleGroupOptions: [
                    for (final g in taxonomy.muscleGroups) g.name,
                  ],
                  equipmentOptions: [
                    for (final e in taxonomy.equipment) e.name,
                  ],
                );
              },
            ),
          const SizedBox(height: 20),
          const Text('Vídeo', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<_VideoSource>(
            segments: const [
              ButtonSegment(
                value: _VideoSource.youtubeLink,
                label: Text('Link do YouTube'),
                icon: Icon(Icons.link),
              ),
              ButtonSegment(
                value: _VideoSource.ownUpload,
                label: Text('Vídeo próprio'),
                icon: Icon(Icons.videocam_outlined),
              ),
            ],
            selected: {_videoSource},
            onSelectionChanged: (s) => setState(() => _videoSource = s.first),
          ),
          const SizedBox(height: 12),
          if (_videoSource == _VideoSource.youtubeLink)
            TextField(
              controller: _videoUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'Link do vídeo (YouTube)',
                hintText: 'https://youtube.com/watch?v=...',
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: uploading
                            ? null
                            : () => _pickAndUploadVideo(ImageSource.camera),
                        icon: const Icon(Icons.videocam_outlined),
                        label: const Text('Gravar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: uploading
                            ? null
                            : () => _pickAndUploadVideo(ImageSource.gallery),
                        icon: const Icon(Icons.video_library_outlined),
                        label: const Text('Da galeria'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (uploading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Enviando vídeo...'),
                      ],
                    ),
                  )
                else if (_uploadedVideoUrl != null &&
                    _uploadedVideoUrl!.isNotEmpty)
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(child: Text('Vídeo enviado.')),
                    ],
                  ),
              ],
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (_saving || uploading) ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

/// Extensão segura para o arquivo de vídeo enviado: só letras/números, até
/// 5 caracteres, a partir do NOME do arquivo; `mp4` quando não der para
/// saber (ex: nome sem extensão).
String videoExtensionOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return 'mp4';
  final ext = fileName.substring(dot + 1).toLowerCase();
  return RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext) ? ext : 'mp4';
}
