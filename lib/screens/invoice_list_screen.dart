import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../models/invoice.dart';
import '../providers/invoice_provider.dart';
import '../utils/currency_formatter.dart';
import '../widgets/custom_text_field.dart';
import 'invoice_form_screen.dart';
import 'invoice_preview_screen.dart';

Color statusColor(InvoiceStatus s) => switch (s) {
      InvoiceStatus.brouillon => Colors.grey.shade600,
      InvoiceStatus.enAttente => const Color(0xFFE08A00),
      InvoiceStatus.partiel => AppColors.light,
      InvoiceStatus.paye => Colors.green.shade700,
      InvoiceStatus.annule => Colors.red.shade700,
    };

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key, required this.type});
  final DocumentType type;

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  String _query = '';
  InvoiceStatus? _status;
  DateTimeRange? _range;

  Future<Invoice?> _loadFull(Invoice header) async {
    final full = await context.read<InvoiceProvider>().full(header.id!);
    if (full == null && mounted) {
      showMessage(context, 'Document introuvable', error: true);
    }
    return full;
  }

  Future<void> _open(Invoice header, {bool duplicata = false}) async {
    final full = await _loadFull(header);
    if (full == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              InvoicePreviewScreen(invoice: full, duplicata: duplicata)),
    );
  }

  Future<void> _edit(Invoice header) async {
    if (header.status.isFinal) {
      final ok = await confirm(
        context,
        'Document finalisé',
        '${header.number} a déjà été émis (${header.status.label}). '
            'Le modifier peut créer des incohérences avec la version envoyée. '
            'Vous pouvez aussi le dupliquer.\n\nModifier quand même ?',
        ok: 'Modifier',
      );
      if (!ok || !mounted) return;
    }
    final full = await _loadFull(header);
    if (full == null || !mounted) return;
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => InvoiceFormScreen(invoice: full)));
  }

  Future<void> _duplicate(Invoice header, {DocumentType? asType}) async {
    try {
      final copy = await context
          .read<InvoiceProvider>()
          .duplicate(header, asType: asType);
      if (!mounted) return;
      showMessage(context, 'Copie créée : ${copy.number} (brouillon)');
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => InvoiceFormScreen(invoice: copy)));
    } catch (e) {
      if (mounted) showMessage(context, 'Erreur : $e', error: true);
    }
  }

  Future<void> _delete(Invoice header) async {
    final ok = await confirm(
      context,
      'Supprimer ${header.number} ?',
      'Cette action est définitive.',
      ok: 'Supprimer',
      danger: true,
    );
    if (!ok || !mounted) return;
    await context.read<InvoiceProvider>().delete(header);
    if (mounted) showMessage(context, '${header.number} supprimé');
  }

  Future<void> _changeStatus(InvoiceSummary s) async {
    final inv = s.invoice;
    final status = await showDialog<InvoiceStatus>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Statut'),
        children: [
          for (final st in InvoiceStatus.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, st),
              child: Row(children: [
                Icon(st == inv.status ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: statusColor(st)),
                const SizedBox(width: 10),
                Text(st.label),
              ]),
            ),
        ],
      ),
    );
    if (status == null || !mounted) return;
    var paid = inv.amountPaid;
    if (status == InvoiceStatus.paye) {
      paid = s.total ?? inv.amountPaid;
    } else if (status == InvoiceStatus.partiel) {
      final ctrl = TextEditingController(
          text: paid == 0 ? '' : CurrencyFormatter.number(paid));
      final value = await showDialog<int>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Montant déjà payé'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(suffixText: 'FCFA'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(
                    ctx, CurrencyFormatter.parseAmount(ctrl.text) ?? 0),
                child: const Text('Valider')),
          ],
        ),
      );
      ctrl.dispose();
      if (value == null) return;
      paid = value;
    } else if (status == InvoiceStatus.brouillon ||
        status == InvoiceStatus.enAttente) {
      paid = 0;
    }
    if (!mounted) return;
    await context.read<InvoiceProvider>().setStatus(inv, status, amountPaid: paid);
    if (mounted) showMessage(context, 'Statut : ${status.label}');
  }

  void _actions(InvoiceSummary s) {
    final inv = s.invoice;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        void go(VoidCallback f) {
          Navigator.pop(ctx);
          f();
        }

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                title: Text('${inv.number} — ${inv.clientName}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(CurrencyFormatter.fcfa(s.total)),
              ),
              const Divider(height: 1),
              ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: const Text('Ouvrir / imprimer / partager'),
                  onTap: () => go(() => _open(inv))),
              ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Modifier'),
                  onTap: () => go(() => _edit(inv))),
              ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Changer le statut'),
                  onTap: () => go(() => _changeStatus(s))),
              ListTile(
                  leading: const Icon(Icons.copy_outlined),
                  title: const Text('Dupliquer'),
                  onTap: () => go(() => _duplicate(inv))),
              if (inv.type == DocumentType.devis)
                ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: const Text('Transformer en facture'),
                    onTap: () =>
                        go(() => _duplicate(inv, asType: DocumentType.facture))),
              if (inv.status.isFinal)
                ListTile(
                    leading: const Icon(Icons.content_copy),
                    title: const Text('Générer un duplicata'),
                    onTap: () => go(() => _open(inv, duplicata: true))),
              ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
                  title: Text('Supprimer',
                      style: TextStyle(color: Colors.red.shade700)),
                  onTap: () => go(() => _delete(inv))),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );
    if (r != null) setState(() => _range = r);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoiceProvider>();
    final list = provider.filter(
      type: widget.type,
      query: _query,
      status: _status,
      from: _range?.start,
      to: _range?.end,
    );
    final df = DateFormat('dd/MM/yyyy');
    final isFacture = widget.type == DocumentType.facture;

    return Scaffold(
      appBar: AppBar(
        title: Text(isFacture ? 'Historique des factures' : 'Historique des devis'),
        actions: [
          IconButton(
            tooltip: 'Filtrer par date',
            icon: Icon(_range == null ? Icons.date_range : Icons.event_busy),
            onPressed: _range == null
                ? _pickRange
                : () => setState(() => _range = null),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => InvoiceFormScreen(type: widget.type))),
        icon: const Icon(Icons.add),
        label: Text(isFacture ? 'Facture' : 'Devis'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Numéro ou client',
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        if (_range != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Chip(
              label: Text(
                  'Du ${df.format(_range!.start)} au ${df.format(_range!.end)}'),
              onDeleted: () => setState(() => _range = null),
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
                  label: const Text('Tous'),
                  selected: _status == null,
                  onSelected: (_) => setState(() => _status = null),
                ),
              ),
              for (final st in InvoiceStatus.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(st.label),
                    selected: _status == st,
                    onSelected: (_) => setState(() => _status = st),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: provider.loading && provider.all.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
                  ? const Center(child: Text('Aucun document.'))
                  : RefreshIndicator(
                      onRefresh: provider.load,
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 90),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = list[i];
                          final inv = s.invoice;
                          return ListTile(
                            onTap: () => _actions(s),
                            title: Row(children: [
                              Expanded(
                                child: Text(inv.number,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ),
                              Text(CurrencyFormatter.fcfa(s.total),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: s.total == null
                                          ? const Color(0xFFB07A00)
                                          : AppColors.dark)),
                            ]),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(children: [
                                Expanded(
                                  child: Text(
                                      '${df.format(inv.date)} • ${inv.clientName}',
                                      overflow: TextOverflow.ellipsis),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor(inv.status)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(inv.status.label,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: statusColor(inv.status),
                                          fontWeight: FontWeight.w600)),
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }
}
