import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/product_provider.dart';
import '../utils/currency_formatter.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/product_image_picker.dart';
import 'product_bulk_screen.dart';
import 'product_form_screen.dart';

/// Un produit choisi dans le catalogue, avec sa quantité.
typedef PickedProduct = ({Product product, double quantity});

/// Catalogue. En mode sélection ([pickMode]), on coche plusieurs produits
/// (ou toute une catégorie d'un coup) puis « Ajouter » renvoie la liste
/// des [PickedProduct].
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key, this.pickMode = false, this.shopCatalog = false});
  final bool pickMode;

  /// Ouvrir directement le catalogue boutique (privé).
  final bool shopCatalog;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  String _query = '';
  String? _category;

  /// true : catalogue boutique (privé), false : catalogue principal.
  late bool _shop = widget.shopCatalog;

  /// Filtre « En ligne » : seulement les articles publiés dans la boutique.
  bool _onlyPublished = false;

  /// Sélection en mode choix : id du produit -> quantité.
  final Map<int, double> _picked = {};

  Future<void> _edit([Product? p]) async {
    await Navigator.push(context,
        MaterialPageRoute(
            builder: (_) => ProductFormScreen(product: p, shopOnly: _shop)));
  }

  Future<void> _move(Product p) async {
    await context.read<ProductProvider>().setShopOnly([p], !p.shopOnly);
    if (!mounted) return;
    showMessage(
        context,
        p.shopOnly
            ? '« ${p.name} » déplacé dans le catalogue principal'
            : '« ${p.name} » déplacé dans le catalogue boutique');
  }

  /// Choix : un produit, ajout rapide, plusieurs photos, mode caméra.
  Future<void> _addMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Plusieurs photos d’un coup'),
            subtitle: const Text('Chaque photo devient un article'),
            onTap: () => Navigator.pop(ctx, 'photos'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Mode caméra rapide'),
            subtitle: const Text('Photo, nom, prix… et suivant'),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.table_rows_outlined),
            title: const Text('Saisie rapide (plusieurs lignes)'),
            subtitle: const Text('Nom et prix à la suite, sans photo'),
            onTap: () => Navigator.pop(ctx, 'rows'),
          ),
          ListTile(
            leading: const Icon(Icons.add_box_outlined),
            title: const Text('Un seul produit (fiche complète)'),
            onTap: () => Navigator.pop(ctx, 'one'),
          ),
        ]),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'one') return _edit();
    final start = switch (choice) {
      'photos' => BulkStart.photos,
      'camera' => BulkStart.camera,
      _ => BulkStart.empty,
    };
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                ProductBulkScreen(start: start, category: _category, shopOnly: _shop)));
  }

  /// Copie d'un produit (pour un modèle proche) : on change seulement
  /// ce qui diffère.
  Future<void> _duplicate(Product p) async {
    final copy = Product(
      name: '${p.name} (copie)',
      description: p.description,
      category: p.category,
      unit: p.unit,
      price: p.price,
      photoPath: p.photoPath,
      published: p.published,
      shopOnly: p.shopOnly,
      createdAt: DateTime.now(),
    );
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ProductFormScreen(product: copy)));
  }

  Future<void> _setPublished(List<Product> list, bool publish) async {
    if (list.isEmpty) return;
    await context.read<ProductProvider>().setPublished(list, publish);
    if (!mounted) return;
    final n = list.length;
    final s = n > 1 ? 's' : '';
    showMessage(
        context,
        publish
            ? '$n article$s publié$s dans MCS Boutique'
            : '$n article$s retiré$s de MCS Boutique');
  }

  Future<void> _delete(Product p) async {
    final ok = await confirm(context, 'Supprimer le produit ?',
        '« ${p.name} » sera retiré du catalogue. Les factures déjà créées ne changent pas.',
        ok: 'Supprimer', danger: true);
    if (!ok || !mounted) return;
    await context.read<ProductProvider>().delete(p);
    if (mounted) showMessage(context, 'Produit supprimé');
  }

  void _toggle(Product p) {
    final id = p.id;
    if (id == null) return;
    setState(() {
      if (_picked.containsKey(id)) {
        _picked.remove(id);
      } else {
        _picked[id] = 1;
      }
    });
  }

  void _changeQty(Product p, double delta) {
    final id = p.id;
    if (id == null) return;
    setState(() {
      final q = (_picked[id] ?? 0) + delta;
      if (q <= 0) {
        _picked.remove(id);
      } else {
        _picked[id] = q;
      }
    });
  }

  /// Coche ou décoche d'un coup tous les produits affichés
  /// (toute la catégorie choisie).
  void _toggleAll(List<Product> visible, bool allPicked) {
    setState(() {
      for (final p in visible) {
        final id = p.id;
        if (id == null) continue;
        if (allPicked) {
          _picked.remove(id);
        } else {
          _picked.putIfAbsent(id, () => 1);
        }
      }
    });
  }

  void _confirmPick(List<Product> all) {
    final result = <PickedProduct>[
      for (final p in all)
        if (p.id != null && _picked.containsKey(p.id))
          (product: p, quantity: _picked[p.id]!),
    ];
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    var list = provider
        .search(_query, category: _category)
        .where((p) => p.shopOnly == _shop)
        .toList();
    if (_onlyPublished) list = list.where((p) => p.published).toList();
    if (widget.pickMode) {
      // En mode choix : les plus chers en haut.
      list = List.of(list)..sort((a, b) => b.price.compareTo(a.price));
    }
    final categories = {
      ...ProductCategories.all,
      ...provider.products.map((p) => p.category)
    }.toList();

    final pickedCount = _picked.length;
    var pickedTotal = 0;
    for (final p in provider.products) {
      final q = p.id == null ? null : _picked[p.id];
      if (q != null) pickedTotal += (q * p.price).round();
    }
    final allVisiblePicked = list.isNotEmpty &&
        list.every((p) => p.id != null && _picked.containsKey(p.id));

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.pickMode
              ? 'Choisir des produits'
              : (_shop ? 'Catalogue boutique' : 'Catalogue'))),
      floatingActionButton: widget.pickMode && pickedCount > 0
          ? null
          : FloatingActionButton.extended(
              onPressed: widget.pickMode ? () => _edit() : _addMenu,
              icon: const Icon(Icons.add),
              label: Text(widget.pickMode ? 'Produit' : 'Ajouter'),
            ),
      bottomNavigationBar: widget.pickMode && pickedCount > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: FilledButton.icon(
                  onPressed: () => _confirmPick(provider.products),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(
                      'Ajouter $pickedCount article${pickedCount > 1 ? 's' : ''}'
                      ' • ${CurrencyFormatter.fcfa(pickedTotal)}'),
                ),
              ),
            )
          : null,
      body: Column(children: [
        // Catalogue principal / catalogue boutique (privé).
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: Text('Catalogue (${provider.products.length - provider.shopOnlyCount})')),
                ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.lock_outline),
                    label: Text('Boutique (${provider.shopOnlyCount})')),
              ],
              selected: {_shop},
              onSelectionChanged: (v) => setState(() {
                _shop = v.first;
                _category = null;
              }),
            ),
          ),
        ),
        if (_shop)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              widget.pickMode
                  ? 'Articles du catalogue boutique (privé).'
                  : 'Catalogue privé : pas proposé dans les factures et devis, '
                      'mais publiable dans MCS Boutique.',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Rechercher un produit',
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              if (!widget.pickMode)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    avatar: const Icon(Icons.storefront, size: 18),
                    label: Text('En ligne (${provider.publishedCount})'),
                    selected: _onlyPublished,
                    selectedColor: const Color(0xFFD6F2DF),
                    onSelected: (v) => setState(() => _onlyPublished = v),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: const Text('Tout'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
              ),
              for (final c in categories)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
                ),
            ],
          ),
        ),
        if (!widget.pickMode && _category != null && list.isNotEmpty)
          _CategoryPublishBar(
            category: _category!,
            total: list.length,
            published: list.where((p) => p.published).length,
            onPublish: () =>
                _setPublished(list.where((p) => !p.published).toList(), true),
            onUnpublish: () =>
                _setPublished(list.where((p) => p.published).toList(), false),
          ),
        if (widget.pickMode && list.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: allVisiblePicked,
              onChanged: (_) => _toggleAll(list, allVisiblePicked),
              title: Text(
                _category == null
                    ? 'Tout sélectionner (${list.length})'
                    : 'Toute la catégorie « $_category » (${list.length})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        Expanded(
          child: provider.loading && provider.products.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Aucun produit.\nAppuyez sur « Produit » pour en ajouter.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final p = list[i];
                        final qty = p.id == null ? null : _picked[p.id];
                        final selected = qty != null;
                        return ListTile(
                          selected: widget.pickMode && selected,
                          selectedTileColor: const Color(0xFFF1F7FD),
                          leading: LocalPhoto(p.photoPath),
                          title: Text(p.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text.rich(TextSpan(children: [
                            if (!widget.pickMode && p.published)
                              const WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: _OnlineBadge(),
                              ),
                            TextSpan(
                                text:
                                    '${p.category} • ${CurrencyFormatter.fcfa(p.price)} / ${p.unit}'),
                          ])),
                          onTap: widget.pickMode
                              ? () => _toggle(p)
                              : () => _edit(p),
                          trailing: widget.pickMode
                              ? (selected
                                  ? _QtyStepper(
                                      quantity: qty,
                                      onMinus: () => _changeQty(p, -1),
                                      onPlus: () => _changeQty(p, 1),
                                    )
                                  : const Icon(Icons.check_box_outline_blank))
                              : PopupMenuButton<String>(
                                  onSelected: (v) {
                                    switch (v) {
                                      case 'edit':
                                        _edit(p);
                                      case 'copy':
                                        _duplicate(p);
                                      case 'publish':
                                        _setPublished([p], !p.published);
                                      case 'move':
                                        _move(p);
                                      case 'delete':
                                        _delete(p);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                        value: 'edit', child: Text('Modifier')),
                                    const PopupMenuItem(
                                        value: 'copy',
                                        child: Text('Dupliquer')),
                                    PopupMenuItem(
                                        value: 'publish',
                                        child: Text(p.published
                                            ? 'Retirer de MCS Boutique'
                                            : 'Publier dans MCS Boutique')),
                                    PopupMenuItem(
                                        value: 'move',
                                        child: Text(p.shopOnly
                                            ? 'Mettre dans le catalogue principal'
                                            : 'Mettre dans le catalogue boutique')),
                                    const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Supprimer')),
                                  ],
                                ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper(
      {required this.quantity, required this.onMinus, required this.onPlus});
  final double quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.remove_circle_outline),
        onPressed: onMinus,
      ),
      Text(CurrencyFormatter.quantity(quantity),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      IconButton(
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.add_circle_outline),
        onPressed: onPlus,
      ),
    ]);
  }
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFFD6F2DF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('En ligne',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade800)),
      );
}

/// Publier / retirer toute une catégorie de MCS Boutique.
class _CategoryPublishBar extends StatelessWidget {
  const _CategoryPublishBar({
    required this.category,
    required this.total,
    required this.published,
    required this.onPublish,
    required this.onUnpublish,
  });

  final String category;
  final int total;
  final int published;
  final VoidCallback onPublish;
  final VoidCallback onUnpublish;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.storefront_outlined, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text('$published / $total en ligne',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        if (published < total)
          TextButton(onPressed: onPublish, child: const Text('Tout publier')),
        if (published > 0)
          TextButton(onPressed: onUnpublish, child: const Text('Tout retirer')),
      ]),
    );
  }
}
