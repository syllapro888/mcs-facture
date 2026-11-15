import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../theme.dart';

/// Image enregistrée en base64 (photos d'articles, captures).
class B64Image extends StatelessWidget {
  const B64Image(this.data,
      {super.key, this.fit = BoxFit.cover, this.width, this.height});
  final String? data;
  final BoxFit fit;
  final double? width;
  final double? height;

  static final _cache = <int, Uint8List>{};

  static Uint8List? decode(String? data) {
    if (data == null || data.isEmpty) return null;
    final key = data.hashCode ^ data.length;
    final hit = _cache[key];
    if (hit != null) return hit;
    try {
      final bytes = base64Decode(data);
      if (_cache.length > 300) _cache.clear();
      return _cache[key] = bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = decode(data);
    if (bytes == null) {
      return Container(
        width: width,
        height: height,
        color: const Color(0xFFE8EEF6),
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined,
            color: AppColors.light, size: 40),
      );
    }
    return Image.memory(bytes,
        fit: fit, width: width, height: height, gaplessPlayback: true);
  }
}

/// Choisit une photo (capture Mobile Money…) et la renvoie en base64,
/// compressée pour rester légère.
Future<String?> pickImageB64(BuildContext context,
    {ImageSource source = ImageSource.gallery}) async {
  try {
    final x = await ImagePicker().pickImage(
        source: source, maxWidth: 1000, maxHeight: 1600, imageQuality: 55);
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    if (bytes.length > 700 * 1024) {
      if (context.mounted) {
        showMessage(context, 'Image trop lourde, choisissez une capture.',
            error: true);
      }
      return null;
    }
    return base64Encode(bytes);
  } catch (e) {
    if (context.mounted) {
      showMessage(context, 'Impossible de charger l’image : $e', error: true);
    }
    return null;
  }
}

void showMessage(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? Colors.red.shade700 : AppColors.dark,
      behavior: SnackBarBehavior.floating,
    ));
}

/// Affiche une image en plein écran (zoom).
void openImage(BuildContext context, String data) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black),
        body: InteractiveViewer(
          maxScale: 5,
          child: Center(child: B64Image(data, fit: BoxFit.contain)),
        ),
      ),
    ),
  );
}

/// Pastille de prix jaune.
class PriceTag extends StatelessWidget {
  const PriceTag(this.price, {super.key, this.big = false});
  final int price;
  final bool big;

  @override
  Widget build(BuildContext context) => Text(
        price > 0 ? fcfa(price) : 'Prix sur demande',
        style: TextStyle(
          color: AppColors.dark,
          fontWeight: FontWeight.bold,
          fontSize: big ? 22 : 14,
        ),
      );
}
