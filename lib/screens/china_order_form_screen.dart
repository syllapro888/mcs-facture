import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../models/china_order.dart';
import '../providers/china_order_provider.dart';
import '../utils/currency_formatter.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/photo_viewer.dart';
import '../widgets/product_image_picker.dart';
import 'china_order_list_screen.dart';

/// Ligne d'article en cours de saisie.
class _ItemRow {
  _ItemRow([ChinaItem? i])
      : name = TextEditingController(text: i?.name ?? ''),
        qty = TextEditingController(
            text: i == null ? '1' : CurrencyFormatter.quantity(i.quantity)),
        price = TextEditingController(
            text: i == null || i.unitYuan == 0 ? '' : _fmt(i.unitYuan));

  final TextEditingController name;
  final TextEditingController qty;
  final TextEditingController price;

  static String _fmt(double v) => v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(2).replaceAll('.', ',');

  ChinaItem toItem() => ChinaItem(
        name: name.text.trim(),
        quantity: CurrencyFormatter.parseQuantity(qty.text) ?? 0,
        unitYuan: CurrencyFormatter.parseQuantity(price.text) ?? 0,
      );

  bool get isEmpty => name.text.trim().isEmpty && price.text.trim().isEmpty;

  void dispose() {
    name.dispose();
    qty.dispose();
    price.dispose();
  }
}

class ChinaOrderFormScreen extends StatefulWidget {
  const ChinaOrderFormScreen({super.key, this.order});
  final ChinaOrder? order;

  @override
  State<ChinaOrderFormScreen> createState() => _ChinaOrderFormScreenState();
}

class _ChinaOrderFormScreenState extends State<ChinaOrderFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _supplier;
  late final TextEditingController _reference;
  late final TextEditingController _rate;
  late final TextEditingController _shipping;
  late final TextEditingController _fees;
  late final TextEditingController _tracking;
  late final TextEditingController _notes;
  late DateTime _date;
  late ChinaOrderStatus _status;
  late List<String> _photos;
  final List<_ItemRow> _items = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final o = widget.order;
    final lastRate = context.read<ChinaOrderProvider>().lastRate;
    final rate = o?.rate ?? lastRate;
    _supplier = TextEditingController(text: o?.supplier ?? '');
    _reference = TextEditingController(text: o?.reference ?? '');
    _rate = TextEditingController(
        text: rate > 0 ? _ItemRow._fmt(rate) : '');
    _shipping = TextEditingController(
        text: (o?.shipping ?? 0) > 0 ? CurrencyFormatter.number(o!.shipping) : '');
    _fees = TextEditingController(
        text: (o?.otherFees ?? 0) > 0 ? CurrencyFormatter.number(o!.otherFees) : '');
    _tracking = TextEditingController(text: o?.tracking ?? '');
    _notes = TextEditingController(text: o?.notes ?? '');
    _date = o?.date ?? DateTime.now();
    _status = o?.status ?? ChinaOrderStatus.commandee;
    _photos = List.of(o?.photos ?? const []);
    _items.addAll(o == null || o.items.isEmpty
        ? [_ItemRow()]
        : o.items.map(_ItemRow.new));
  }

  @override
  void dispose() {
    for (final c in [
      _supplier, _reference, _rate, _shipping, _fees, _tracking, _notes
    ]) {
      c.dispose();
    }
    for (final r in _items) {
      r.dispose();
    }
    super.dispose();
  }

  /// Commande telle qu'elle est saisie à l'écran (pour les calculs).
  ChinaOrder _current() {
    final base = widget.order;
    return ChinaOrder(
      id: base?.id,
      reference: _reference.text.trim(),
      supplier: _supplier.text.trim(),
      date: _date,
      status: _status,
      rate: CurrencyFormatter.parseQuantity(_rate.text) ?? 0,
      shipping: CurrencyFormatter.parseAmount(_shipping.text) ?? 0,
      otherFees: CurrencyFormatter.parseAmount(_fees.text) ?? 0,
      tracking: _tracking.text.trim(),
      notes: _notes.text.trim(),
      items: [
        for (final r in _items)
          if (!r.isEmpty) r.toItem()
      ],
      photos: _photos,
      createdAt: base?.createdAt ?? DateTime.now(),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _addCaptures() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Plusieurs captures (galerie)'),
            subtitle: const Text('Paiement Alipay, discussion, facture…'),
            onTap: () => Navigator.pop(ctx, 'many'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Prendre une photo'),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
        ]),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'many') {
      final list = await QuickPhotos.pickMany(context);
      if (list.isNotEmpty && mounted) setState(() => _photos.addAll(list));
    } else {
      final p = await QuickPhotos.camera(context);
      if (p != null && mounted) setState(() => _photos.add(p));
    }
  }

  void _viewPhoto(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoViewer(
          photos: _photos,
          initial: index,
          onDelete: (i) => setState(() => _photos.removeAt(i)),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final o = _current();
    if (o.items.isEmpty) {
      showMessage(context, 'Ajoutez au moins un article.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<ChinaOrderProvider>().save(o);
      if (!mounted) return;
      showMessage(context, 'Commande enregistrée');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showMessage(context, 'Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final o = widget.order;
    if (o == null) return;
    final ok = await confirm(context, 'Supprimer la commande ?',
        'Cette commande et ses informations seront supprimées.',
        ok: 'Supprimer', danger: true);
    if (!ok || !mounted) return;
    await context.read<ChinaOrderProvider>().delete(o);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final o = _current();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.order == null ? 'Nouvelle commande' : 'Commande Chine'),
        actions: [
          if (widget.order != null)
            IconButton(
                tooltip: 'Supprimer',
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete),
        ],
      ),
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
                : const Icon(Icons.save),
            label: const Text('Enregistrer'),
          ),
        ),
      ),
      body: Form(
        key: _form,
        onChanged: () => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // ----- Étape -----
            _Section('Avancement'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final s in ChinaOrderStatus.values)
                ChoiceChip(
                  label: Text(s.label),
                  selected: _status == s,
                  selectedColor: chinaStatusColor(s).withValues(alpha: 0.25),
                  onSelected: (_) => setState(() => _status = s),
                ),
            ]),
            const SizedBox(height: 14),

            // ----- Fournisseur -----
            _Section('Fournisseur'),
            CustomTextField(
                controller: _supplier,
                label: 'Fournisseur / boutique',
                icon: Icons.store_mall_directory_outlined),
            Row(children: [
              Expanded(
                child: CustomTextField(
                    controller: _reference, label: 'N° de commande'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date'),
                      child: Text(DateFormat('dd/MM/yyyy').format(_date)),
                    ),
                  ),
                ),
              ),
            ]),

            // ----- Articles -----
            _Section('Articles (prix en yuan)'),
            for (var i = 0; i < _items.length; i++)
              _ItemCard(
                key: ObjectKey(_items[i]),
                row: _items[i],
                order: o,
                onRemove: _items.length == 1
                    ? null
                    : () => setState(() => _items.removeAt(i).dispose()),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _items.add(_ItemRow())),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un article'),
              ),
            ),
            const SizedBox(height: 8),

            // ----- Argent -----
            _Section('Paiement et frais'),
            CustomTextField(
              controller: _rate,
              label: 'Taux : 1 yuan =',
              suffix: 'FCFA',
              numeric: true,
              decimal: true,
              hint: 'Ex. 84',
            ),
            Row(children: [
              Expanded(
                child: CustomTextField(
                    controller: _shipping,
                    label: 'Transport',
                    suffix: 'FCFA',
                    numeric: true),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CustomTextField(
                    controller: _fees,
                    label: 'Douane / frais',
                    suffix: 'FCFA',
                    numeric: true),
              ),
            ]),
            _Totals(order: o),
            const SizedBox(height: 14),

            // ----- Captures -----
            _Section('Captures (Alipay, discussions…)'),
            SizedBox(
              height: 96,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  InkWell(
                    onTap: _addCaptures,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4D6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              color: AppColors.dark),
                          Text('Ajouter', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  for (var i = 0; i < _photos.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: InkWell(
                        onTap: () => _viewPhoto(i),
                        child: LocalPhoto(_photos[i], size: 88),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ----- Suivi -----
            _Section('Livraison'),
            CustomTextField(
                controller: _tracking,
                label: 'Transporteur / n° de suivi',
                icon: Icons.local_shipping_outlined),
            CustomTextField(controller: _notes, label: 'Notes', maxLines: 3),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(
                color: AppColors.dark,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
      );
}

class _ItemCard extends StatelessWidget {
  const _ItemCard(
      {super.key, required this.row, required this.order, this.onRemove});
  final _ItemRow row;
  final ChinaOrder order;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final item = row.toItem();
    final cost = order.rate > 0 && item.quantity > 0 && item.unitYuan > 0
        ? order.unitCost(item)
        : null;
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 4, 6),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: row.name,
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    const InputDecoration(isDense: true, labelText: 'Article'),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onRemove,
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: row.qty,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(isDense: true, labelText: 'Quantité'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: row.price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    isDense: true, labelText: 'Prix unitaire', prefixText: '¥ '),
              ),
            ),
            const SizedBox(width: 44),
          ]),
          if (item.totalYuan > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 6, 0),
              child: Row(children: [
                Text('Total ${yuan(item.totalYuan)}',
                    style: const TextStyle(fontSize: 12)),
                const Spacer(),
                if (cost != null)
                  Text('Revient : ${CurrencyFormatter.fcfa(cost)} / unité',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E9E5B))),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.order});
  final ChinaOrder order;

  @override
  Widget build(BuildContext context) {
    Widget line(String label, String value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Text(label,
                style: TextStyle(
                    color: bold ? Colors.white : Colors.white70,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    color: bold ? AppColors.yellow : Colors.white,
                    fontSize: bold ? 18 : 14,
                    fontWeight: FontWeight.bold)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: [
        line('Total en yuan', yuan(order.totalYuan)),
        line('Marchandise en FCFA',
            order.rate > 0 ? CurrencyFormatter.fcfa(order.goodsFcfa) : 'Taux ?'),
        if (order.shipping + order.otherFees > 0)
          line('Transport et frais',
              CurrencyFormatter.fcfa(order.shipping + order.otherFees)),
        const Divider(color: Colors.white24),
        line('Coût total', CurrencyFormatter.fcfa(order.totalFcfa), bold: true),
      ]),
    );
  }
}
