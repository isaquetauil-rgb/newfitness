import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'package:newfitness/shared/models/exercise.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  YoutubePlayerController? _youtubeController;
  bool _isOwnVideo = false;

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayerController.convertUrlToId(
      widget.exercise.videoUrl,
    );
    if (videoId != null) {
      _youtubeController = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: false,
        params: const YoutubePlayerParams(showFullscreenButton: true),
      );
    } else if (widget.exercise.videoUrl.isNotEmpty) {
      // Não é um link do YouTube reconhecível — trata como vídeo próprio do
      // instrutor, enviado ao Firebase Storage (ver `StorageService.
      // uploadExerciseVideo`), reproduzido com um player nativo.
      _isOwnVideo = true;
    }
  }

  @override
  void dispose() {
    _youtubeController?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;

    return Scaffold(
      appBar: AppBar(title: Text(exercise.name)),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(color: Colors.black12, child: _buildVideoArea()),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text(exercise.muscleGroup)),
                    Chip(label: Text(exercise.equipment)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  exercise.description,
                  style: const TextStyle(fontSize: 15),
                ),
                if (exercise.instructions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Como executar',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  for (int i = 0; i < exercise.instructions.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(exercise.instructions[i])),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoArea() {
    if (_youtubeController != null) {
      return YoutubePlayer(controller: _youtubeController!);
    }
    if (_isOwnVideo) {
      return _OwnVideoPlayer(url: widget.exercise.videoUrl);
    }
    return const Center(
      child: Icon(Icons.videocam_off, color: Colors.grey, size: 40),
    );
  }
}

/// Reproduz o vídeo próprio de um instrutor (arquivo no Firebase Storage) —
/// controles mínimos (play/pause + barra de progresso), sem as opções que só
/// fazem sentido pra vídeo do YouTube.
class _OwnVideoPlayer extends StatefulWidget {
  const _OwnVideoPlayer({required this.url});

  final String url;

  @override
  State<_OwnVideoPlayer> createState() => _OwnVideoPlayerState();
}

class _OwnVideoPlayerState extends State<_OwnVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize()
          .then((_) {
            if (mounted) setState(() => _ready = true);
          })
          .catchError((_) {
            if (mounted) setState(() => _failed = true);
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Icon(Icons.error_outline, color: Colors.grey, size: 40),
      );
    }
    if (!_ready) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        GestureDetector(
          onTap: () => setState(
            () => _controller.value.isPlaying
                ? _controller.pause()
                : _controller.play(),
          ),
          child: AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
        ),
        if (!_controller.value.isPlaying)
          const Icon(Icons.play_circle_fill, color: Colors.white70, size: 56),
        VideoProgressIndicator(_controller, allowScrubbing: true),
      ],
    );
  }
}

bool exerciseHasNoVideo(Exercise exercise) => exercise.videoUrl.isEmpty;
