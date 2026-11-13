import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../models/client.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../providers/invoice_provider.dart';
import '../providers/settings_provider.dart';
import '../services/invoice_service.dart';
import '../utils/currency_formatter.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/invoice_item_form.dart';
import '../widgets/invoice_totals.dart';
import '../widgets/product_image_picker.dart';
import 'client_list_screen.dart';
import 'invoice_preview_screen.dart';
import 'product_list_screen.dart';

/// Création ou modification d'une facture / d'un devis.
class InvoiceFormScreen extends StatefulWidget {
  const InvoiceFormScreen({super.key, this.type = DocumentType.facture, this.invoice});

  final DocumentType type;

  /// Facture complète (avec ses lignes) à modifier, ou null pour une nouvelle.
  final Invoice? invoice;

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final _form = GlobalKey<FormState>();
  final _clientName = TextEditingController();
  final _clientPhone = TextEditingController();
  final _clientAddress = TextEditingController();
  final _notes = TextEditingController();
  final _terms = TextEditingController();
  final _discount = TextEditingController();
  final _vatRate = TextEditingController();

  Invoice? _base; // numéro, dates, statut...
  int? _clientId;
  DateTime _date = DateTime.now();
  DocumentType _type = DocumentType.facture;
  bool _vatEnabled = false;
  List<InvoiceItem> _items = [];
  bool _busy = false;

  /// Tri automatique des articles par prix total (plus cher en haut).
  bool _sortByTotal = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final settings = context.read<SettingsProvider>().settings;
    final service = context.read<InvoiceProvider>().service;
    final inv = widget.invoice ?? await service.blank(widget.type, settings);
    if (!mounted) return;
    setState(() {
      _base = inv;
      _type = inv.type;
      _date = inv.date;
      _clientId = inv.clientId;
      _clientName.text = inv.clientName;
      _clientPhone.text = inv.clientPhone;
      _clientAddress.text = inv.clientAddress;
      _notes.text = inv.notes;
      _terms.text = inv.paymentTerms;
      _discount.text =
          inv.globalDiscount == 0 ? '' : CurrencyFormatter.number(inv.globalDiscount);
      _vatEnabled = inv.vatEnabled;
      _vatRate.text = CurrencyFormatter.quantity(inv.vatRate);
      _items = List.of(inv.items);
      // Ancien document rangé à la main : on garde son ordre (tri désactivé).
      _sortByTotal = widget.invoice == null ||
          InvoiceItem.isSortedByTotalDesc(_items);
    });
  }

  @override
  void dispose() {
    for (final c in [
      _clientName,
      _clientPhone,
      _clientAddress,
      _notes,
      _terms,
      _discount,
      _vatRate
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Invoice _build() {
    final b = _base!;
    return b.copyWith(
      type: _type,
      date: _date,
      clientId: _clientId,
      clearClient: _clientId == null,
      clientName: _clientName.text.trim(),
      clientPhone: _clientPhone.text.trim(),
      clientAddress: _clientAddress.text.trim(),
      notes: _notes.text.trim(),
      paymentTerms: _terms.text.trim(),
      globalDiscount: CurrencyFormatter.parseAmount(_discount.text) ?? 0,
      vatEnabled: _vatEnabled,
      vatRate: CurrencyFormatter.parseQuantity(_vatRate.text) ?? 0,
      items: _items,
    );
  }

  /// Nouveau document : le numéro suit le type et l'année choisis.
  Future<void> _renumber() async {
    final b = _base;
    if (b == null || b.id != null) return;
    final n = await context
        .read<InvoiceProvider>()
        .service
        .nextNumber(_type, _date.year);
    if (!mounted) return;
    setState(() => _base = b.copyWith(
        type: _type, year: _date.year, seq: n.seq, number: n.number));
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    final yearChanged = d.year != _date.year;
    setState(() => _date = d);
    if (yearChanged) await _renumber();
  }

  Future<void> _pickClient() async {
    final c = await Navigator.push<Client>(context,
        MaterialPageRoute(builder: (_) => const ClientListScreen(pickMode: true)));
    if (c == null) return;
    setState(() {
      _clientId = c.id;
      _clientName.text = c.name;
      _clientPhone.text = c.phone;
      _clientAddress.text = c.address;
    });
  }

  /// Remet les lignes dans l'ordre du prix total (plus cher en haut)
  /// si le tri automatique est activé.
  void _resort() {
    if (_sortByTotal) _items = InvoiceItem.sortByTotalDesc(_items);
  }

  Future<void> _addFromCatalog() async {
    final picked = await Navigator.push<List<PickedProduct>>(context,
        MaterialPageRoute(builder: (_) => const ProductListScreen(pickMode: true)));
    if (picked == null || picked.isEmpty || !mounted) return;
    var added = 0;
    setState(() {
      for (final (:product, :quantity) in picked) {
        final p = product;
        // Produit déjà présent : on augmente la quantité au lieu de doubler la ligne.
        final existing = _items.indexWhere((it) =>
            it.productId != null &&
            it.productId == p.id &&
            it.unitPrice == p.price);
        if (existing >= 0) {
          final it = _items[existing];
          _items[existing] = it.copyWith(quantity: it.quantity + quantity);
        } else {
          _items.add(InvoiceItem(
            isLabor: p.category == 'Main-d’œuvre',
            name: p.name,
            description: p.description,
            quantity: quantity,
            unit: p.unit,
            unitPrice: p.price,
            photoPath: p.photoPath,
            productId: p.id,
          ));
          added++;
        }
      }
      _resort();
    });
    final merged = picked.length - added;
    showMessage(
        context,
        '$added article${added > 1 ? 's' : ''} ajouté${added > 1 ? 's' : ''}'
        '${merged > 0 ? ', $merged quantité${merged > 1 ? 's' : ''} augmentée${merged > 1 ? 's' : ''}' : ''}');
  }

  Future<void> _addFree({required bool labor}) async {
    final item = await InvoiceItemForm.show(
      context,
      InvoiceItem(
        isLabor: labor,
        name: labor ? 'Main-d’œuvre' : '',
        unit: labor ? 'forfait' : 'pièce',
      ),
    );
    if (item != null) {
      setState(() {
        _items.add(item);
        _resort();
      });
    }
  }

  Future<void> _editItem(int index) async {
    final item = await InvoiceItemForm.show(context, _items[index]);
    if (item != null) {
      setState(() {
        _items[index] = item;
        _resort();
      });
    }
  }

  void _move(int index, int delta) {
    final to = index + delta;
    if (to < 0 || to >= _items.length) return;
    setState(() {
      final it = _items.removeAt(index);
      _items.insert(to, it);
    });
  }

  Future<Invoice?> _save() async {
    if (!_form.currentState!.validate()) return null;
    setState(() => _busy = true);
    try {
      final saved = await context.read<InvoiceProvider>().save(_build());
      if (!mounted) return saved;
      setState(() => _base = saved);
      return saved;
    } catch (e) {
      if (mounted) showMessage(context, 'Erreur d’enregistrement : $e', error: true);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveDraft() async {
    final saved = await _save();
    if (saved != null && mounted) {
      showMessage(context, '${saved.type.label} ${saved.number} enregistré(e)');
    }
  }

  Future<void> _preview() async {
    if (!_form.currentState!.validate()) return;
    final errors = InvoiceService.validate(_build());
    if (errors.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('À compléter'),
          content: Text(errors.map((e) => '• $e').join('\n')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    final saved = await _save();
    if (saved == null || !mounted) return;
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => InvoicePreviewScreen(invoice: saved, fromForm: true)),
    );
    if (done == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final base = _base;
    if (base == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Nouveau ${widget.type.label.toLowerCase()}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final totals = _build().totals;
    final isNew = base.id == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew
            ? 'Nouveau ${_type.label.toLowerCase()}'
            : 'Modifier ${base.number}'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _saveDraft,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Enregistrer'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _preview,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Aperçu PDF'),
              ),
            ),
          ]),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            if (isNew)
              SegmentedButton<DocumentType>(
                segments: const [
                  ButtonSegment(
                      value: DocumentType.facture,
                      label: Text('Facture'),
                      icon: Icon(Icons.receipt_long)),
                  ButtonSegment(
                      value: DocumentType.devis,
                      label: Text('Devis'),
                      icon: Icon(Icons.request_quote_outlined)),
                ],
                selected: {_type},
                onSelectionChanged: (s) {
                  setState(() => _type = s.first);
                  _renumber();
                },
              ),
            const SizedBox(height: 12),
            _Section(
              title: 'Document',
              child: Row(children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Numéro'),
                    child: Text(base.number,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'Date',
                          suffixIcon: Icon(Icons.calendar_today, size: 18)),
                      child: Text(DateFormat('dd/MM/yyyy').format(_date)),
                    ),
                  ),
                ),
              ]),
            ),
            _Section(
              title: 'Client',
              trailing: TextButton.icon(
                onPressed: _pickClient,
                icon: const Icon(Icons.people_alt_outlined, size: 18),
                label: const Text('Choisir'),
              ),
              child: Column(children: [
                CustomTextField(
                  controller: _clientName,
                  label: 'Nom du client',
                  icon: Icons.person_outline,
                  required: true,
                  onChanged: (_) => _clientId = null,
                ),
                CustomTextField(
                    controller: _clientPhone,
                    label: 'Téléphone',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone),
                CustomTextField(
                    controller: _clientAddress,
                    label: 'Adresse',
                    icon: Icons.place_outlined),
              ]),
            ),
            _Section(
              title: 'Articles (${_items.length})',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_items.length > 1)
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.sort),
                      title: const Text('Trier par prix total'),
                      subtitle: const Text('Le plus cher en haut'),
                      value: _sortByTotal,
                      onChanged: (v) => setState(() {
                        _sortByTotal = v;
                        _resort();
                      }),
                    ),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Aucun article pour le moment.',
                          textAlign: TextAlign.center),
                    ),
                  for (var i = 0; i < _items.length; i++) _itemTile(i),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.tonalIcon(
                      onPressed: _addFromCatalog,
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Catalogue'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _addFree(labor: false),
                      icon: const Icon(Icons.add),
                      label: const Text('Article libre'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _addFree(labor: true),
                      icon: const Icon(Icons.engineering_outlined),
                      label: const Text('Main-d’œuvre'),
                    ),
                  ]),
                ],
              ),
            ),
            _Section(
              title: 'Remise et TVA',
              child: Column(children: [
                CustomTextField(
                  controller: _discount,
                  label: 'Remise globale',
                  suffix: 'FCFA',
                  numeric: true,
                  onChanged: (_) => setState(() {}),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Appliquer la TVA'),
                  value: _vatEnabled,
                  onChanged: (v) => setState(() => _vatEnabled = v),
                ),
                if (_vatEnabled)
                  CustomTextField(
                    controller: _vatRate,
                    label: 'Taux de TVA',
                    suffix: '%',
                    numeric: true,
                    decimal: true,
                    onChanged: (_) => setState(() {}),
                  ),
              ]),
            ),
            InvoiceTotalsView(totals: totals),
            const SizedBox(height: 12),
            _Section(
              title: 'Conditions et notes',
              child: Column(children: [
                CustomTextField(
                    controller: _terms,
                    label: 'Conditions de paiement',
                    maxLines: 2),
                CustomTextField(
                    controller: _notes, label: 'Notes', maxLines: 3),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemTile(int i) {
    final it = _items[i];
    return Card(
      elevation: 0,
      color: it.isLabor ? const Color(0xFFFFF6DC) : const Color(0xFFF1F7FD),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 8, right: 0),
        leading: it.isLabor
            ? const CircleAvatar(
                backgroundColor: AppColors.yellow,
                foregroundColor: AppColors.dark,
                child: Icon(Icons.engineering_outlined))
            : LocalPhoto(it.photoPath, size: 44),
        title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${CurrencyFormatter.quantity(it.quantity)} ${it.unit} × '
          '${it.unitPrice == null ? CurrencyFormatter.aPreciser : CurrencyFormatter.fcfa(it.unitPrice)}'
          '${it.discount > 0 ? '  (−${CurrencyFormatter.number(it.discount)})' : ''}\n'
          '= ${CurrencyFormatter.fcfa(it.lineTotal)}',
        ),
        isThreeLine: true,
        onTap: () => _editItem(i),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'edit':
                _editItem(i);
              case 'up':
                _move(i, -1);
              case 'down':
                _move(i, 1);
              case 'delete':
                setState(() => _items.removeAt(i));
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Modifier')),
            // Monter / Descendre seulement quand le tri automatique est coupé.
            if (!_sortByTotal) ...const [
              PopupMenuItem(value: 'up', child: Text('Monter')),
              PopupMenuItem(value: 'down', child: Text('Descendre')),
            ],
            const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Container(width: 4, height: 16, color: AppColors.yellow),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.dark,
                          fontSize: 15)),
                ),
                if (trailing != null) trailing!,
              ]),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
