import 'package:flutter/material.dart';

import '../app.dart';
import '../models/invoice_item.dart';
import '../models/product.dart';
import '../utils/currency_formatter.dart';
import 'custom_text_field.dart';
import 'product_image_picker.dart';

/// Formulaire d'une ligne (fourniture ou main-d'œuvre), en feuille du bas.
class InvoiceItemForm extends StatefulWidget {
  const InvoiceItemForm({super.key, required this.initial});
  final InvoiceItem initial;

  static Future<InvoiceItem?> show(BuildContext context, InvoiceItem initial) =>
      showModalBottomSheet<InvoiceItem>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => InvoiceItemForm(initial: initial),
      );

  @override
  State<InvoiceItemForm> createState() => _InvoiceItemFormState();
}

class _InvoiceItemFormState extends State<InvoiceItemForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _qty;
  late final TextEditingController _price;
  late final TextEditingController _discount;
  late String _unit;
  String? _photo;

  bool get _labor => widget.initial.isLabor;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i.name);
    _desc = TextEditingController(text: i.description);
    _qty = TextEditingController(text: CurrencyFormatter.quantity(i.quantity));
    _price = TextEditingController(
        text: i.unitPrice == null ? '' : CurrencyFormatter.number(i.unitPrice!));
    _discount = TextEditingController(
        text: i.discount == 0 ? '' : CurrencyFormatter.number(i.discount));
    _unit = i.unit;
    _photo = i.photoPath;
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _qty.dispose();
    _price.dispose();
    _discount.dispose();
    super.dispose();
  }

  InvoiceItem _current() {
    final price = CurrencyFormatter.parseAmount(_price.text);
    return InvoiceItem(
      isLabor: _labor,
      name: _name.text.trim(),
      description: _desc.text.trim(),
      quantity: CurrencyFormatter.parseQuantity(_qty.text) ?? 0,
      unit: _unit,
      unitPrice: price,
      discount: CurrencyFormatter.parseAmount(_discount.text) ?? 0,
      photoPath: _labor ? null : _photo,
      productId: widget.initial.productId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final units = {...Units.all, _unit}.toList();
    final line = _current().lineTotal;
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_labor ? 'Main-d’œuvre' : 'Article',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (!_labor) ...[
                ProductImagePicker(
                  photoPath: _photo,
                  size: 80,
                  onChanged: (p) => setState(() => _photo = p),
                ),
                const SizedBox(height: 12),
              ],
              CustomTextField(
                controller: _name,
                label: _labor ? 'Prestation' : 'Désignation',
                required: true,
              ),
              CustomTextField(
                controller: _desc,
                label: 'Description complémentaire',
                maxLines: 2,
              ),
              Row(children: [
                Expanded(
                  child: CustomTextField(
                    controller: _qty,
                    label: 'Quantité',
                    numeric: true,
                    decimal: true,
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final q = CurrencyFormatter.parseQuantity(v ?? '');
                      if (q == null || q <= 0) return 'Quantité invalide';
                      return null;
                    },
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
              CustomTextField(
                controller: _price,
                label: 'Prix unitaire',
                suffix: 'FCFA',
                numeric: true,
                hint: _labor ? 'Laisser vide si pas encore connu' : null,
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (_labor) return null;
                  return CurrencyFormatter.parseAmount(v ?? '') == null
                      ? 'Prix obligatoire'
                      : null;
                },
              ),
              CustomTextField(
                controller: _discount,
                label: 'Remise sur la ligne',
                suffix: 'FCFA',
                numeric: true,
                onChanged: (_) => setState(() {}),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F2FC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Text('Montant de la ligne'),
                  const Spacer(),
                  Text(CurrencyFormatter.fcfa(line),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.dark)),
                ]),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Valider la ligne'),
                onPressed: () {
                  if (!_form.currentState!.validate()) return;
                  Navigator.pop(context, _current());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
