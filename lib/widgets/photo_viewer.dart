import 'package:flutter/material.dart';

import '../utils/app_paths.dart';
import 'custom_text_field.dart';

/// Affichage plein écran des photos, avec suppression.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer(
      {super.key, required this.photos, required this.initial, required this.onDelete});
  final List<String> photos;
  final int initial;
  final ValueChanged<int> onDelete;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _page = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final ok = await confirm(context, 'Retirer cette capture ?',
        'Elle sera retirée de la commande.',
        ok: 'Retirer', danger: true);
    if (!ok || !mounted) return;
    widget.onDelete(_index);
    if (widget.photos.isEmpty) {
      Navigator.pop(context);
    } else {
      setState(() => _index = _index.clamp(0, widget.photos.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('${_index + 1} / ${widget.photos.length}'),
        actions: [
          IconButton(
              tooltip: 'Retirer',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete),
        ],
      ),
      body: PageView.builder(
        controller: _page,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: FutureBuilder(
              future: AppPaths.readPhoto(widget.photos[i]),
              initialData: AppPaths.cached(widget.photos[i]),
              builder: (_, snap) => snap.data == null
                  ? const CircularProgressIndicator()
                  : Image.memory(snap.data!, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
