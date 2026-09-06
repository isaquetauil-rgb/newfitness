import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/progress/logic/body_photo_provider.dart';
import 'package:newfitness/shared/models/body_photo.dart';

class BodyProgressScreen extends StatelessWidget {
  const BodyProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid;
    final provider = context.watch<BodyPhotoProvider>();

    if (uid == null) {
      return const Center(child: Text('Faça login para ver suas fotos'));
    }

    return Scaffold(
      body: StreamBuilder<List<BodyPhoto>>(
        stream: provider.watchPhotos(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final photos = snapshot.data ?? [];

          if (photos.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nenhuma foto ainda.\nRegistre fotos periódicas para acompanhar sua evolução.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: photos.length,
            itemBuilder: (context, i) {
              final photo = photos[i];
              return GestureDetector(
                onTap: () =>
                    context.push(AppRoutes.progressPhoto, extra: photo),
                child: Hero(
                  tag: 'body_photo_${photo.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(photo.imageUrl, fit: BoxFit.cover),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: provider.isUploading ? null : () => _addPhoto(context, uid),
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

  Future<void> _addPhoto(BuildContext context, String uid) async {
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
    if (source == null || !context.mounted) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null || !context.mounted) return;

    await context.read<BodyPhotoProvider>().addPhoto(uid, File(picked.path));
  }
}

class PhotoViewerScreen extends StatelessWidget {
  final BodyPhoto photo;

  const PhotoViewerScreen({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(DateFormat('dd/MM/yyyy').format(photo.date)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await context.read<BodyPhotoProvider>().deletePhoto(photo);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: 'body_photo_${photo.id}',
          child: InteractiveViewer(
            child: Image.network(photo.imageUrl, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
