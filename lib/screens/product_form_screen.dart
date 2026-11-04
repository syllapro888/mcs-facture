import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/product_provider.dart';
import '../utils/currency_formatter.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/product_image_picker.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});
  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _price;
  late String _category;
  late String _unit;
  String? _photo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _desc = TextEditingController(text: p?.description ?? '');
    _price = TextEditingController(
        text: p == null ? '' : CurrencyFormatter.number(p.price));
    _category = p?.category ?? ProductCategories.all.last;
    _unit = p?.unit ?? 'pièce';
    _photo = p?.photoPath;
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final base = widget.product ??
          Product(name: '', createdAt: DateTime.now());
      final p = Product(
        id: base.id,
        name: _name.text.trim(),
        description: _desc.text.trim(),
        category: _category,
        unit: _unit,
        price: CurrencyFormatter.parseAmount(_price.text) ?? 0,
        photoPath: _photo,
        createdAt: base.createdAt,
      );
      await context.read<ProductProvider>().save(p);
      if (!mounted) return;
      showMessage(context, 'Produit enregistré');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showMessage(context, 'Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = {...ProductCategories.all, _category}.toList();
    final units = {...Units.all, _unit}.toList();
    return Scaffold(
      appBar: AppBar(
          title: Text(
              widget.product == null ? 'Nouveau produit' : 'Modifier le produit')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ProductImagePicker(
                photoPath: _photo,
                onChanged: (p) => setState(() => _photo = p)),
            const SizedBox(height: 16),
            CustomTextField(
                controller: _name, label: 'Désignation', required: true),
            CustomTextField(
                controller: _desc, label: 'Description', maxLines: 3),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                value: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                items: [
                  for (final c in categories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
            ),
            Row(children: [
              Expanded(
                child: CustomTextField(
                  controller: _price,
                  label: 'Prix de vente',
                  suffix: 'FCFA',
                  numeric: true,
                  required: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    value: _unit,
                    decoration: const InputDecoration(labelText: 'Unité'),
                    items: [
                      for (final u in units)
                        DropdownMenuItem(value: u, child: Text(u)),
                    ],
                    onChanged: (v) => setState(() => _unit = v ?? _unit),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
