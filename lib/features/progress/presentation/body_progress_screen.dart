import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/progress/logic/body_photo_provider.dart';
import 'package:newfitness/shared/models/body_photo.dart';

/// Aba "Fotos" do Progresso — a galeria de fotos do próprio usuário.
class BodyProgressScreen extends StatelessWidget {
  const BodyProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid;
    if (uid == null) {
      return const Center(child: Text('Faça login para ver suas fotos'));
    }
    return BodyPhotoGallery(uid: uid, canAdd: true);
  }
}

/// Galeria de fotos de evolução de [uid], agrupada por data, com filtro por
/// posição. [canAdd] só é verdadeiro para o próprio aluno — o instrutor
/// vinculado apenas visualiza (as regras também só deixam o dono gravar).
class BodyPhotoGallery extends StatefulWidget {
  const BodyPhotoGallery({super.key, required this.uid, required this.canAdd});

  final String uid;
  final bool canAdd;

  @override
  State<BodyPhotoGallery> createState() => _BodyPhotoGalleryState();
}

class _BodyPhotoGalleryState extends State<BodyPhotoGallery> {
  String? _positionFilter;
  late Stream<List<BodyPhoto>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = context.read<BodyPhotoProvider>().watchPhotos(widget.uid);
  }

  @override
  void didUpdateWidget(BodyPhotoGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _stream = context.read<BodyPhotoProvider>().watchPhotos(widget.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BodyPhotoProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<BodyPhoto>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _Message(
              'Não foi possível carregar as fotos de evolução.',
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data ?? [];
          if (all.isEmpty) {
            return _Message(
              widget.canAdd
                  ? 'Nenhuma foto ainda.\nRegistre fotos periódicas '
                        '(frente, costas, lados) para acompanhar sua evolução.'
                  : 'Nenhuma foto de evolução registrada.',
            );
          }

          final photos = _positionFilter == null
              ? all
              : all.where((p) => p.position == _positionFilter).toList();
          final byDay = <DateTime, List<BodyPhoto>>{};
          for (final p in photos) {
            final day = DateTime(p.date.year, p.date.month, p.date.day);
            byDay.putIfAbsent(day, () => []).add(p);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Todas'),
                      selected: _positionFilter == null,
                      onSelected: (_) => setState(() => _positionFilter = null),
                    ),
                    for (final pos in PhotoPosition.all) ...[
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text(PhotoPosition.labelOf(pos)),
                        selected: _positionFilter == pos,
                        onSelected: (_) =>
                            setState(() => _positionFilter = pos),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (photos.isEmpty) const _Message('Nenhuma foto nesta posição.'),
              for (final entry in byDay.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(entry.key),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.75,
                  children: [
                    for (final photo in entry.value)
                      _PhotoThumb(
                        photo: photo,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PhotoViewerScreen(photo: photo),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: !widget.canAdd
          ? null
          : FloatingActionButton(
              heroTag: 'add_body_photo',
              onPressed: provider.isUploading ? null : _addPhoto,
              child: provider.isUploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_a_photo_outlined),
            ),
    );
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (picked == null || !mounted) return;

    final details = await showModalBottomSheet<_PhotoDetails>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _PhotoDetailsSheet(),
    );
    if (details == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<BodyPhotoProvider>().addPhoto(
        widget.uid,
        picked,
        position: details.position,
        note: details.note,
        date: details.date,
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar a foto.')),
      );
    }
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.photo, required this.onTap});

  final BodyPhoto photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            BodyPhotoImage(photo: photo, fit: BoxFit.cover),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  PhotoPosition.labelOf(photo.position),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Exibe uma foto de evolução. Fotos novas são baixadas pelo SDK a partir
/// do caminho privado (passando pelas Storage Rules); fotos antigas usam a
/// URL de download que já estava gravada.
class BodyPhotoImage extends StatelessWidget {
  const BodyPhotoImage({super.key, required this.photo, this.fit});

  final BodyPhoto photo;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context) {
    final path = photo.storagePath;
    if (path == null) {
      final url = photo.imageUrl;
      if (url == null) return const _BrokenImage();
      return Image.network(
        url,
        fit: fit,
        errorBuilder: (_, _, _) => const _BrokenImage(),
      );
    }
    return FutureBuilder<Uint8List>(
      future: context.read<BodyPhotoProvider>().loadBytes(path),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const _BrokenImage();
        final bytes = snapshot.data;
        if (bytes == null) {
          return const Center(
            child: SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return Image.memory(bytes, fit: fit, gaplessPlayback: true);
      },
    );
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade300,
      child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
    );
  }
}

class _PhotoDetails {
  const _PhotoDetails({required this.position, required this.date, this.note});

  final String position;
  final DateTime date;
  final String? note;
}

class _PhotoDetailsSheet extends StatefulWidget {
  const _PhotoDetailsSheet();

  @override
  State<_PhotoDetailsSheet> createState() => _PhotoDetailsSheetState();
}

class _PhotoDetailsSheetState extends State<_PhotoDetailsSheet> {
  String _position = PhotoPosition.front;
  DateTime _date = DateTime.now();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detalhes da foto',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            const Text('Posição'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final pos in PhotoPosition.all)
                  ChoiceChip(
                    label: Text(PhotoPosition.labelOf(pos)),
                    selected: _position == pos,
                    onSelected: (_) => setState(() => _position = pos),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(DateFormat('dd/MM/yyyy').format(_date)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Observação (opcional)',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final note = _noteCtrl.text.trim();
                  Navigator.pop(
                    context,
                    _PhotoDetails(
                      position: _position,
                      date: _date,
                      note: note.isEmpty ? null : note,
                    ),
                  );
                },
                child: const Text('Salvar foto'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PhotoViewerScreen extends StatelessWidget {
  final BodyPhoto photo;

  const PhotoViewerScreen({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    final viewerUid = context.read<AuthProvider>().user?.uid;
    final isOwner = viewerUid == photo.userId;
    final note = photo.note;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${DateFormat('dd/MM/yyyy').format(photo.date)} · '
          '${PhotoPosition.labelOf(photo.position)}',
        ),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Apagar foto?'),
                    content: const Text('Esta ação não pode ser desfeita.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Apagar'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;
                await context.read<BodyPhotoProvider>().deletePhoto(photo);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: InteractiveViewer(
                child: BodyPhotoImage(photo: photo, fit: BoxFit.contain),
              ),
            ),
          ),
          if (note != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(note, style: const TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}
