import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/product_provider.dart';
import '../utils/currency_formatter.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/product_image_picker.dart';
import 'product_form_screen.dart';

/// Un produit choisi dans le catalogue, avec sa quantité.
typedef PickedProduct = ({Product product, double quantity});

/// Catalogue. En mode sélection ([pickMode]), on coche plusieurs produits
/// (ou toute une catégorie d'un coup) puis « Ajouter » renvoie la liste
/// des [PickedProduct].
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key, this.pickMode = false});
  final bool pickMode;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  String _query = '';
  String? _category;

  /// Sélection en mode choix : id du produit -> quantité.
  final Map<int, double> _picked = {};

  Future<void> _edit([Product? p]) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ProductFormScreen(product: p)));
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
    var list = provider.search(_query, category: _category);
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
          title: Text(widget.pickMode ? 'Choisir des produits' : 'Catalogue')),
      floatingActionButton: widget.pickMode && pickedCount > 0
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Produit'),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
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
                          subtitle: Text(
                              '${p.category} • ${CurrencyFormatter.fcfa(p.price)} / ${p.unit}'),
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
                                  onSelected: (v) =>
                                      v == 'edit' ? _edit(p) : _delete(p),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'edit', child: Text('Modifier')),
                                    PopupMenuItem(
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
