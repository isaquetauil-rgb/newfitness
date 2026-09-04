import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../models/exercise.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    if (widget.exercise.videoUrl.isEmpty) return;
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.exercise.videoUrl),
      );
      await controller.initialize();
      _videoController = controller;
      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: false,
        looping: true,
        aspectRatio: controller.value.aspectRatio,
      );
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
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
    if (exerciseHasNoVideo(widget.exercise)) {
      return const Center(
        child: Icon(Icons.videocam_off, color: Colors.grey, size: 40),
      );
    }
    if (_loadFailed) {
      return const Center(
        child: Text(
          'Não foi possível carregar o vídeo',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    if (_chewieController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Chewie(controller: _chewieController!);
  }
}

bool exerciseHasNoVideo(Exercise exercise) => exercise.videoUrl.isEmpty;
