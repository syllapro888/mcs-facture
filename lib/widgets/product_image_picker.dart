import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/app_paths.dart';
import 'custom_text_field.dart';

/// Affiche une photo enregistrée localement (chemin relatif).
class LocalPhoto extends StatelessWidget {
  const LocalPhoto(this.relativePath,
      {super.key, this.size = 48, this.icon = Icons.inventory_2_outlined});

  final String? relativePath;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final rel = relativePath;
    Widget placeholder() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F2FC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF6B8BB5), size: size * 0.5),
        );
    if (rel == null || rel.isEmpty) return placeholder();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        AppPaths.resolve(rel),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder(),
      ),
    );
  }
}

/// Choix d'une photo : galerie, appareil photo ou fichiers.
/// La photo est copiée dans le dossier de l'application.
class ImagePickerHelper {
  static Future<String?> pick(BuildContext context) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Galerie du téléphone'),
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Prendre une photo'),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('Fichiers'),
            onTap: () => Navigator.pop(ctx, 'files'),
          ),
        ]),
      ),
    );
    if (source == null) return null;
    try {
      if (source == 'files') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png'],
          withData: true,
        );
        if (result == null || result.files.isEmpty) return null;
        final f = result.files.first;
        var bytes = f.bytes;
        if (bytes == null && f.path != null) {
          bytes = await File(f.path!).readAsBytes();
        }
        if (bytes == null) return null;
        return AppPaths.savePhoto(bytes, f.extension ?? 'jpg');
      }
      final x = await ImagePicker().pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 85,
      );
      if (x == null) return null;
      final bytes = await x.readAsBytes();
      final name = x.name.toLowerCase();
      final ext = name.endsWith('.png') ? 'png' : 'jpg';
      return AppPaths.savePhoto(bytes, ext);
    } catch (e) {
      if (context.mounted) {
        showMessage(context, 'Impossible de charger la photo : $e',
            error: true);
      }
      return null;
    }
  }
}

/// Zone photo cliquable avec boutons Changer / Retirer.
class ProductImagePicker extends StatelessWidget {
  const ProductImagePicker({
    super.key,
    required this.photoPath,
    required this.onChanged,
    this.size = 110,
    this.label = 'Photo du produit',
  });

  final String? photoPath;
  final ValueChanged<String?> onChanged;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final p = await ImagePickerHelper.pick(context);
            if (p != null) onChanged(p);
          },
          child: LocalPhoto(photoPath,
              size: size, icon: Icons.add_a_photo_outlined),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                icon: const Icon(Icons.image_outlined),
                label: Text(photoPath == null ? 'Choisir' : 'Changer'),
                onPressed: () async {
                  final p = await ImagePickerHelper.pick(context);
                  if (p != null) onChanged(p);
                },
              ),
              if (photoPath != null)
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Retirer'),
                  onPressed: () => onChanged(null),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
