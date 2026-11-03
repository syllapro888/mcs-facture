import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/product_provider.dart';
import '../utils/currency_formatter.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/product_image_picker.dart';
import 'product_form_screen.dart';

/// Catalogue. En mode sélection ([pickMode]), un appui renvoie le produit.
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key, this.pickMode = false});
  final bool pickMode;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  String _query = '';
  String? _category;

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final list = provider.search(_query, category: _category);
    final categories = {
      ...ProductCategories.all,
      ...provider.products.map((p) => p.category)
    }.toList();

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.pickMode ? 'Choisir un produit' : 'Catalogue')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Produit'),
      ),
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
                        return ListTile(
                          leading: LocalPhoto(p.photoPath),
                          title: Text(p.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${p.category} • ${CurrencyFormatter.fcfa(p.price)} / ${p.unit}'),
                          onTap: widget.pickMode
                              ? () => Navigator.pop(context, p)
                              : () => _edit(p),
                          trailing: widget.pickMode
                              ? const Icon(Icons.add_circle_outline)
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
