import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/invoice.dart';
import '../providers/invoice_provider.dart';
import '../providers/settings_provider.dart';
import '../services/invoice_service.dart';
import '../widgets/custom_text_field.dart';
import 'invoice_form_screen.dart';

/// Aperçu du VÉRITABLE PDF qui sera imprimé, partagé ou exporté.
/// Renvoie true quand le document a été finalisé (pour fermer le formulaire).
class InvoicePreviewScreen extends StatefulWidget {
  const InvoicePreviewScreen(
      {super.key,
      required this.invoice,
      this.duplicata = false,
      this.fromForm = false,
      this.sample = false});

  final Invoice invoice;
  final bool duplicata;

  /// Ouvert depuis le formulaire : « Modifier » revient simplement en arrière.
  final bool fromForm;

  /// Document d'exemple (non enregistré) : ni modification ni finalisation.
  final bool sample;

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  late Invoice _invoice;
  late Future<Uint8List> _pdf;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
    _generate();
  }

  void _generate() {
    final settings = context.read<SettingsProvider>().settings;
    final service = context.read<InvoiceProvider>().service;
    _pdf = service.pdf(_invoice, settings, duplicata: widget.duplicata);
  }

  String get _fileName =>
      InvoiceService.fileName(_invoice, duplicata: widget.duplicata);

  Future<void> _run(Future<void> Function(Uint8List bytes) action) async {
    setState(() => _busy = true);
    try {
      final bytes = await _pdf;
      await action(bytes);
    } catch (e) {
      if (mounted) showMessage(context, 'Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finalize() async {
    if (_invoice.status != InvoiceStatus.brouillon) {
      Navigator.pop(context, true);
      return;
    }
    final errors = InvoiceService.validate(_invoice);
    if (errors.isNotEmpty) {
      showMessage(context, errors.first, error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await context
          .read<InvoiceProvider>()
          .setStatus(_invoice, InvoiceStatus.enAttente);
      if (!mounted) return;
      showMessage(context,
          '${_invoice.type.label} ${_invoice.number} enregistré(e) — en attente de paiement');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, 'Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    // Depuis le formulaire : on revient simplement en arrière.
    if (widget.fromForm) {
      Navigator.pop(context, false);
      return;
    }
    if (_invoice.status.isFinal) {
      final ok = await confirm(
        context,
        'Document finalisé',
        'Ce document a déjà été émis. Le modifier peut créer des incohérences '
            'avec la version envoyée au client. Préférez « Dupliquer » si possible.\n\n'
            'Modifier quand même ?',
        ok: 'Modifier',
      );
      if (!ok || !mounted) return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => InvoiceFormScreen(invoice: _invoice)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDraft = _invoice.status == InvoiceStatus.brouillon;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.duplicata
            ? 'Duplicata ${_invoice.number}'
            : '${_invoice.type.label} ${_invoice.number}'),
      ),
      body: Column(children: [
        Expanded(
          child: PdfPreview(
            build: (_) => _pdf,
            pdfFileName: _fileName,
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            allowPrinting: false,
            allowSharing: false,
            useActions: false,
            loadingWidget: const Center(child: CircularProgressIndicator()),
            onError: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Impossible de créer le PDF :\n$error',
                    textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (!widget.sample)
                  _Action(
                      icon: Icons.edit_outlined,
                      label: 'Modifier',
                      onTap: _busy ? null : _edit),
                if (isDraft && !widget.duplicata && !widget.sample)
                  _Action(
                      icon: Icons.check_circle_outline,
                      label: 'Enregistrer',
                      onTap: _busy ? null : _finalize),
                _Action(
                  icon: Icons.print_outlined,
                  label: 'Imprimer',
                  onTap: _busy
                      ? null
                      : () => _run((b) async {
                            await Printing.layoutPdf(
                                onLayout: (_) async => b, name: _fileName);
                          }),
                ),
                _Action(
                  icon: Icons.share_outlined,
                  label: 'Partager',
                  onTap: _busy
                      ? null
                      : () => _run((b) async {
                            await Printing.sharePdf(
                                bytes: b, filename: _fileName);
                          }),
                ),
                _Action(
                  icon: Icons.download_outlined,
                  label: 'Exporter',
                  onTap: _busy
                      ? null
                      : () => _run((b) async {
                            final path = await FilePicker.saveFile(
                              dialogTitle: 'Enregistrer le PDF',
                              fileName: _fileName,
                              mimeType: 'application/pdf',
                              bytes: b,
                            );
                            if (path != null && mounted) {
                              showMessage(context, 'PDF enregistré : $_fileName');
                            }
                          }),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? Colors.grey
        : Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ]),
      ),
    );
  }
}
