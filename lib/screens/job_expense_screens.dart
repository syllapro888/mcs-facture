import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../models/client.dart';
import '../models/job_expense.dart';
import '../providers/job_expense_provider.dart';
import '../utils/currency_formatter.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/photo_viewer.dart';
import '../widgets/product_image_picker.dart';
import 'client_list_screen.dart';

// ======================= Liste =======================

/// Dépenses chantier : ce qui a été acheté pour chaque travail.
class JobExpenseListScreen extends StatefulWidget {
  const JobExpenseListScreen({super.key});

  @override
  State<JobExpenseListScreen> createState() => _JobExpenseListScreenState();
}

class _JobExpenseListScreenState extends State<JobExpenseListScreen> {
  JobStatus? _filter;
  String _query = '';

  void _open([JobExpense? e]) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => JobExpenseFormScreen(expense: e)));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JobExpenseProvider>();
    final q = _query.trim().toLowerCase();
    final list = provider.items.where((e) {
      if (_filter != null && e.status != _filter) return false;
      if (q.isEmpty) return true;
      return e.title.toLowerCase().contains(q) ||
          e.owner.toLowerCase().contains(q) ||
          e.place.toLowerCase().contains(q) ||
          e.lines.any((l) => l.label.toLowerCase().contains(q));
    }).toList();
    final shownTotal = list.fold<int>(0, (s, e) => s + e.total);

    return Scaffold(
      appBar: AppBar(title: const Text('Dépenses chantier')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau chantier'),
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.dark,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Dépenses des chantiers en cours',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(CurrencyFormatter.fcfa(provider.openTotal),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${list.length} chantier${list.length > 1 ? 's' : ''} affiché${list.length > 1 ? 's' : ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(CurrencyFormatter.fcfa(shownTotal),
                  style: const TextStyle(
                      color: AppColors.yellow, fontWeight: FontWeight.bold)),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Chantier, propriétaire, lieu, article…',
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
              for (final s in <JobStatus?>[null, ...JobStatus.values])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(s?.label ?? 'Tous'),
                    selected: _filter == s,
                    onSelected: (_) => setState(() => _filter = s),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: provider.loading && provider.items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Aucun chantier.\nAppuyez sur « Nouveau chantier » pour noter '
                          'vos achats pour un travail.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                      itemCount: list.length,
                      itemBuilder: (_, i) =>
                          _JobCard(job: list[i], onTap: () => _open(list[i])),
                    ),
        ),
      ]),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.onTap});
  final JobExpense job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = job;
    final done = e.status == JobStatus.termine;
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(e.title.isEmpty ? 'Chantier' : e.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: done ? const Color(0xFFD6F2DF) : const Color(0xFFFFF4D6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(e.status.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: done ? const Color(0xFF2E7D4F) : const Color(0xFF8A6500))),
              ),
            ]),
            const SizedBox(height: 2),
            Text(
              [
                DateFormat('dd/MM/yyyy').format(e.date),
                if (e.owner.isNotEmpty) e.owner,
                if (e.place.isNotEmpty) e.place,
              ].join(' • '),
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Text(
                  '${e.lines.length} achat${e.lines.length > 1 ? 's' : ''}'
                  '${e.photos.isNotEmpty ? ' • ${e.photos.length} photo${e.photos.length > 1 ? 's' : ''}' : ''}',
                  style: const TextStyle(fontSize: 13)),
              const Spacer(),
              Text(CurrencyFormatter.fcfa(e.total),
                  style: const TextStyle(
                      color: AppColors.dark, fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ======================= Fiche =======================

class _LineRow {
  _LineRow([ExpenseLine? l])
      : label = TextEditingController(text: l?.label ?? ''),
        qty = TextEditingController(
            text: l == null ? '1' : CurrencyFormatter.quantity(l.quantity)),
        price = TextEditingController(
            text: l == null || l.unitPrice == 0 ? '' : CurrencyFormatter.number(l.unitPrice));

  final TextEditingController label;
  final TextEditingController qty;
  final TextEditingController price;

  ExpenseLine toLine() => ExpenseLine(
        label: label.text.trim(),
        quantity: CurrencyFormatter.parseQuantity(qty.text) ?? 1,
        unitPrice: CurrencyFormatter.parseAmount(price.text) ?? 0,
      );

  bool get isEmpty => label.text.trim().isEmpty && price.text.trim().isEmpty;

  void dispose() {
    label.dispose();
    qty.dispose();
    price.dispose();
  }
}

class JobExpenseFormScreen extends StatefulWidget {
  const JobExpenseFormScreen({super.key, this.expense});
  final JobExpense? expense;

  @override
  State<JobExpenseFormScreen> createState() => _JobExpenseFormScreenState();
}

class _JobExpenseFormScreenState extends State<JobExpenseFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _owner;
  late final TextEditingController _place;
  late final TextEditingController _billed;
  late final TextEditingController _notes;
  late DateTime _date;
  late JobStatus _status;
  late List<String> _photos;
  final List<_LineRow> _lines = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _title = TextEditingController(text: e?.title ?? '');
    _owner = TextEditingController(text: e?.owner ?? '');
    _place = TextEditingController(text: e?.place ?? '');
    _billed = TextEditingController(
        text: (e?.billed ?? 0) > 0 ? CurrencyFormatter.number(e!.billed) : '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _date = e?.date ?? DateTime.now();
    _status = e?.status ?? JobStatus.enCours;
    _photos = List.of(e?.photos ?? const []);
    _lines.addAll(e == null || e.lines.isEmpty ? [_LineRow()] : e.lines.map(_LineRow.new));
  }

  @override
  void dispose() {
    for (final c in [_title, _owner, _place, _billed, _notes]) {
      c.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  JobExpense _current() {
    final base = widget.expense;
    return JobExpense(
      id: base?.id,
      title: _title.text.trim(),
      owner: _owner.text.trim(),
      place: _place.text.trim(),
      date: _date,
      status: _status,
      billed: CurrencyFormatter.parseAmount(_billed.text) ?? 0,
      notes: _notes.text.trim(),
      lines: [
        for (final l in _lines)
          if (!l.isEmpty) l.toLine()
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

  Future<void> _pickClient() async {
    final c = await Navigator.push<Client>(context,
        MaterialPageRoute(builder: (_) => const ClientListScreen(pickMode: true)));
    if (c == null || !mounted) return;
    setState(() {
      _owner.text = c.name;
      if (_place.text.trim().isEmpty) _place.text = c.address;
    });
  }

  Future<void> _addPhotos() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Prendre une photo'),
            subtitle: const Text('Reçu, facture du vendeur, matériel…'),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Plusieurs photos (galerie)'),
            onTap: () => Navigator.pop(ctx, 'many'),
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

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final e = _current();
    if (e.lines.isEmpty) {
      showMessage(context, 'Ajoutez au moins un achat.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<JobExpenseProvider>().save(e);
      if (!mounted) return;
      showMessage(context, 'Chantier enregistré');
      Navigator.pop(context);
    } catch (err) {
      if (mounted) showMessage(context, 'Erreur : $err', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final e = widget.expense;
    if (e == null) return;
    final ok = await confirm(context, 'Supprimer ce chantier ?',
        'Les dépenses et les photos de ce chantier seront supprimées.',
        ok: 'Supprimer', danger: true);
    if (!ok || !mounted) return;
    await context.read<JobExpenseProvider>().delete(e);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final e = _current();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Nouveau chantier' : 'Chantier'),
        actions: [
          if (widget.expense != null)
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
            label: Text('Enregistrer • Total ${CurrencyFormatter.fcfa(e.total)}'),
          ),
        ),
      ),
      body: Form(
        key: _form,
        onChanged: () => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const _Section('Le travail'),
            CustomTextField(
              controller: _title,
              label: 'Travail (ex. Installation caméras)',
              icon: Icons.handyman_outlined,
            ),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: CustomTextField(
                    controller: _owner,
                    label: 'Propriétaire / client',
                    icon: Icons.person_outline),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: IconButton.filledTonal(
                  tooltip: 'Choisir dans mes clients',
                  onPressed: _pickClient,
                  icon: const Icon(Icons.people_alt_outlined),
                ),
              ),
            ]),
            Row(children: [
              Expanded(
                child: CustomTextField(
                    controller: _place, label: 'Lieu', icon: Icons.place_outlined),
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
            Wrap(spacing: 8, children: [
              for (final s in JobStatus.values)
                ChoiceChip(
                  label: Text(s.label),
                  selected: _status == s,
                  onSelected: (_) => setState(() => _status = s),
                ),
            ]),
            const SizedBox(height: 16),

            const _Section('Achats'),
            for (var i = 0; i < _lines.length; i++)
              _LineCard(
                key: ObjectKey(_lines[i]),
                row: _lines[i],
                onRemove: _lines.length == 1
                    ? null
                    : () => setState(() => _lines.removeAt(i).dispose()),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _lines.add(_LineRow())),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un achat'),
              ),
            ),
            _Totals(job: e),
            const SizedBox(height: 10),
            CustomTextField(
              controller: _billed,
              label: 'Montant du travail facturé au client (facultatif)',
              suffix: 'FCFA',
              numeric: true,
            ),
            const SizedBox(height: 6),

            const _Section('Photos justificatives'),
            SizedBox(
              height: 96,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  InkWell(
                    onTap: _addPhotos,
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
                          Icon(Icons.add_a_photo_outlined, color: AppColors.dark),
                          Text('Ajouter', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  for (var i = 0; i < _photos.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PhotoViewer(
                              photos: _photos,
                              initial: i,
                              onDelete: (k) => setState(() => _photos.removeAt(k)),
                            ),
                          ),
                        ),
                        child: LocalPhoto(_photos[i], size: 88),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
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
                color: AppColors.dark, fontWeight: FontWeight.bold, fontSize: 15)),
      );
}

class _LineCard extends StatelessWidget {
  const _LineCard({super.key, required this.row, this.onRemove});
  final _LineRow row;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = row.toLine();
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 4, 8),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: row.label,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    isDense: true, labelText: 'Acheté (ex. Câble 50 m)'),
              ),
            ),
            IconButton(icon: const Icon(Icons.close), onPressed: onRemove),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            SizedBox(
              width: 90,
              child: TextFormField(
                controller: row.qty,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(isDense: true, labelText: 'Qté'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: row.price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    isDense: true, labelText: 'Prix unitaire', suffixText: 'FCFA'),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: Text(CurrencyFormatter.fcfa(l.total),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.dark)),
            ),
            const SizedBox(width: 8),
          ]),
        ]),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.job});
  final JobExpense job;

  @override
  Widget build(BuildContext context) {
    Widget line(String label, String value, {Color? color, bool big = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Text(label,
                style: TextStyle(color: big ? Colors.white : Colors.white70,
                    fontWeight: big ? FontWeight.bold : FontWeight.normal)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    color: color ?? Colors.white,
                    fontSize: big ? 20 : 14,
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
        line('Total des achats', CurrencyFormatter.fcfa(job.total),
            color: AppColors.yellow, big: true),
        if (job.billed > 0) ...[
          const Divider(color: Colors.white24),
          line('Facturé au client', CurrencyFormatter.fcfa(job.billed)),
          line(job.margin >= 0 ? 'Il vous reste' : 'Dépassement',
              CurrencyFormatter.fcfa(job.margin.abs()),
              color: job.margin >= 0 ? const Color(0xFF7BE0A0) : const Color(0xFFFF8A80)),
        ],
      ]),
    );
  }
}
