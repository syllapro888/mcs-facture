import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../utils/currency_formatter.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/product_image_picker.dart';

/// Comment ouvrir l'ajout rapide.
enum BulkStart { empty, photos, camera }

/// Un article en cours de saisie.
class _Draft {
  _Draft({this.photo, String name = '', String price = ''})
      : name = TextEditingController(text: name),
        price = TextEditingController(text: price);

  String? photo;
  final TextEditingController name;
  final TextEditingController price;

  bool get isEmpty =>
      name.text.trim().isEmpty && price.text.trim().isEmpty && photo == null;

  void dispose() {
    name.dispose();
    price.dispose();
  }
}

/// Ajout rapide : plusieurs articles d'un coup, avec la même catégorie.
/// - plusieurs photos de la galerie → un article par photo ;
/// - mode caméra : photo, nom, prix, « Suivant » ;
/// - lignes sans photo.
class ProductBulkScreen extends StatefulWidget {
  const ProductBulkScreen({super.key, this.start = BulkStart.empty, this.category});
  final BulkStart start;
  final String? category;

  @override
  State<ProductBulkScreen> createState() => _ProductBulkScreenState();
}

class _ProductBulkScreenState extends State<ProductBulkScreen> {
  final List<_Draft> _rows = [];
  late String _category;
  String _unit = 'pièce';
  bool _publish = false;
  bool _saving = false;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _category = widget.category ?? ProductCategories.all.last;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (widget.start) {
        case BulkStart.photos:
          _addPhotos();
        case BulkStart.camera:
          _cameraMode();
        case BulkStart.empty:
          _addEmpty(3);
      }
    });
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _addEmpty([int n = 1]) =>
      setState(() => _rows.addAll(List.generate(n, (_) => _Draft())));

  Future<void> _addPhotos() async {
    final photos = await QuickPhotos.pickMany(context);
    if (!mounted || photos.isEmpty) return;
    setState(() {
      // Remplit d'abord les lignes vides existantes.
      _rows.removeWhere((r) => r.isEmpty);
      _rows.addAll([for (final p in photos) _Draft(photo: p)]);
    });
    showMessage(context,
        '${photos.length} photo${photos.length > 1 ? 's' : ''} ajoutée${photos.length > 1 ? 's' : ''} : tapez le nom et le prix sous chacune.');
  }

  /// Photo → nom + prix → « Suivant » (nouvelle photo) ou « Terminer ».
  Future<void> _cameraMode() async {
    while (mounted) {
      final photo = await QuickPhotos.camera(context);
      if (!mounted || photo == null) return;
      final result = await showDialog<(_Draft, bool)>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _QuickEntryDialog(photo: photo),
      );
      if (!mounted || result == null) return;
      setState(() {
        _rows.removeWhere((r) => r.isEmpty);
        _rows.add(result.$1);
      });
      if (!result.$2) return; // « Terminer »
    }
  }

  Future<void> _newCategory() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle catégorie'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ex. Imprimantes'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('Créer')),
        ],
      ),
    );
    c.dispose();
    final v = name?.trim() ?? '';
    if (v.isNotEmpty && mounted) setState(() => _category = v);
  }

  Future<void> _save() async {
    final filled = _rows.where((r) => !r.isEmpty).toList();
    if (filled.isEmpty) {
      showMessage(context, 'Ajoutez au moins un article.', error: true);
      return;
    }
    if (filled.any((r) => r.name.text.trim().isEmpty)) {
      setState(() => _showErrors = true);
      showMessage(context, 'Chaque article doit avoir un nom.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final list = [
        for (var i = 0; i < filled.length; i++)
          Product(
            name: filled[i].name.text.trim(),
            category: _category,
            unit: _unit,
            price: CurrencyFormatter.parseAmount(filled[i].price.text) ?? 0,
            photoPath: filled[i].photo,
            published: _publish,
            createdAt: now.add(Duration(milliseconds: i)),
          ),
      ];
      await context.read<ProductProvider>().saveAll(list);
      if (!mounted) return;
      showMessage(context,
          '${list.length} article${list.length > 1 ? 's' : ''} ajouté${list.length > 1 ? 's' : ''} dans « $_category »');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showMessage(context, 'Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = context.watch<ProductProvider>().products.map((p) => p.category);
    final categories = {...ProductCategories.all, ...existing, _category}.toList();
    final units = {...Units.all, _unit}.toList();
    final count = _rows.where((r) => !r.isEmpty).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajout rapide')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.done_all),
            label: Text(count == 0
                ? 'Enregistrer'
                : 'Enregistrer $count article${count > 1 ? 's' : ''}'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // Réglages communs à tous les articles.
          Card(
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Catégorie (pour tous)'),
                      items: [
                        for (final c in categories)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: (v) =>
                          setState(() => _category = v ?? _category),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Nouvelle catégorie',
                    icon: const Icon(Icons.create_new_folder_outlined),
                    onPressed: _newCategory,
                  ),
                ]),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _unit,
                  decoration: const InputDecoration(labelText: 'Unité'),
                  items: [
                    for (final u in units)
                      DropdownMenuItem(value: u, child: Text(u)),
                  ],
                  onChanged: (v) => setState(() => _unit = v ?? _unit),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _publish,
                  onChanged: (v) => setState(() => _publish = v),
                  title: const Text('Publier dans MCS Boutique'),
                  subtitle: const Text('Les clients verront ces articles'),
                  secondary: const Icon(Icons.storefront_outlined),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _ActionChip(
                icon: Icons.photo_library_outlined,
                label: 'Plusieurs photos',
                onTap: _addPhotos),
            _ActionChip(
                icon: Icons.photo_camera_outlined,
                label: 'Mode caméra',
                onTap: _cameraMode),
            _ActionChip(
                icon: Icons.playlist_add, label: 'Ligne vide', onTap: _addEmpty),
          ]),
          const SizedBox(height: 12),
          if (_rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Choisissez plusieurs photos ou utilisez le mode caméra : '
                'chaque photo devient un article.',
                textAlign: TextAlign.center,
              ),
            ),
          for (var i = 0; i < _rows.length; i++)
            _DraftCard(
              key: ObjectKey(_rows[i]),
              index: i + 1,
              draft: _rows[i],
              unit: _unit,
              showErrors: _showErrors,
              onPhoto: () async {
                final p = await ImagePickerHelper.pick(context);
                if (p != null) setState(() => _rows[i].photo = p);
              },
              onRemove: () => setState(() => _rows.removeAt(i).dispose()),
              onChanged: () => setState(() {}),
            ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
        avatar: Icon(icon, color: AppColors.dark, size: 20),
        label: Text(label),
        backgroundColor: const Color(0xFFFFF4D6),
        side: BorderSide.none,
        onPressed: onTap,
      );
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    super.key,
    required this.index,
    required this.draft,
    required this.unit,
    required this.showErrors,
    required this.onPhoto,
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final _Draft draft;
  final String unit;
  final bool showErrors;
  final VoidCallback onPhoto;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final missingName =
        showErrors && !draft.isEmpty && draft.name.text.trim().isEmpty;
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: onPhoto,
            borderRadius: BorderRadius.circular(8),
            child: LocalPhoto(draft.photo,
                size: 76, icon: Icons.add_a_photo_outlined),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(children: [
              TextField(
                controller: draft.name,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                onChanged: (_) => onChanged(),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'Article $index',
                  errorText: missingName ? 'Nom obligatoire' : null,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: draft.price,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onChanged: (_) => onChanged(),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'Prix',
                  suffixText: 'FCFA / $unit',
                ),
              ),
            ]),
          ),
          IconButton(
            tooltip: 'Retirer',
            icon: const Icon(Icons.close),
            onPressed: onRemove,
          ),
        ]),
      ),
    );
  }
}

/// Mode caméra : nom et prix de l'article qu'on vient de photographier.
class _QuickEntryDialog extends StatefulWidget {
  const _QuickEntryDialog({required this.photo});
  final String photo;

  @override
  State<_QuickEntryDialog> createState() => _QuickEntryDialogState();
}

class _QuickEntryDialogState extends State<_QuickEntryDialog> {
  late final _Draft _d = _Draft(photo: widget.photo);
  bool _error = false;

  void _close(bool next) {
    if (_d.name.text.trim().isEmpty) {
      if (!next) {
        Navigator.pop(context); // « Terminer » sans nom : photo ignorée
        return;
      }
      setState(() => _error = true);
      return;
    }
    Navigator.pop(context, (_d, next));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvel article'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          LocalPhoto(widget.photo, size: 140),
          const SizedBox(height: 12),
          TextField(
            controller: _d.name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Nom',
              errorText: _error ? 'Nom obligatoire' : null,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _d.price,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Prix', suffixText: 'FCFA'),
            onSubmitted: (_) => _close(true),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => _close(false), child: const Text('Terminer')),
        FilledButton.icon(
          onPressed: () => _close(true),
          icon: const Icon(Icons.photo_camera),
          label: const Text('Suivant'),
        ),
      ],
    );
  }
}
