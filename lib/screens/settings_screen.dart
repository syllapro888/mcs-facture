import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../database/app_database.dart';
import '../models/company_settings.dart';
import '../providers/client_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/product_provider.dart';
import '../providers/settings_provider.dart';
import '../services/backup_service.dart';
import '../services/update_service.dart';
import '../utils/currency_formatter.dart';
import '../utils/sample_invoice.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/product_image_picker.dart';
import '../widgets/update_dialog.dart';
import 'invoice_preview_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _form = GlobalKey<FormState>();
  late CompanySettings _s;
  late final Map<String, TextEditingController> _c;
  bool _busy = false;

  static const _darkChoices = [0xFF0B2A5B, 0xFF102A43, 0xFF1A237E, 0xFF0D3B66, 0xFF1B1B1B];
  static const _lightChoices = [0xFF3FA9F5, 0xFF4FC3F7, 0xFF29B6F6, 0xFF64B5F6, 0xFF26A69A];
  static const _accentChoices = [0xFFF7B500, 0xFFFFC107, 0xFFFF9800, 0xFFFDD835, 0xFFE53935];

  @override
  void initState() {
    super.initState();
    _s = context.read<SettingsProvider>().settings;
    _c = {
      'name': TextEditingController(text: _s.name),
      'activities': TextEditingController(text: _s.activities),
      'slogan': TextEditingController(text: _s.slogan),
      'address': TextEditingController(text: _s.address),
      'phones': TextEditingController(text: _s.phones),
      'email': TextEditingController(text: _s.email),
      'manager': TextEditingController(text: _s.managerName),
      'vat': TextEditingController(text: CurrencyFormatter.quantity(_s.vatRate)),
      'terms': TextEditingController(text: _s.defaultPaymentTerms),
      'conditions': TextEditingController(text: _s.salesConditions),
      'quality': TextEditingController(text: _s.qualityText),
      'install': TextEditingController(text: _s.installText),
      'sav': TextEditingController(text: _s.afterSalesText),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  CompanySettings _current() => _s.copyWith(
        name: _c['name']!.text.trim(),
        activities: _c['activities']!.text.trim(),
        slogan: _c['slogan']!.text.trim(),
        address: _c['address']!.text.trim(),
        phones: _c['phones']!.text.trim(),
        email: _c['email']!.text.trim(),
        managerName: _c['manager']!.text.trim(),
        vatRate: CurrencyFormatter.parseQuantity(_c['vat']!.text) ?? 0,
        defaultPaymentTerms: _c['terms']!.text.trim(),
        salesConditions: _c['conditions']!.text.trim(),
        qualityText: _c['quality']!.text.trim(),
        installText: _c['install']!.text.trim(),
        afterSalesText: _c['sav']!.text.trim(),
      );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    try {
      await context.read<SettingsProvider>().save(_current());
      if (mounted) showMessage(context, 'Paramètres enregistrés');
    } catch (e) {
      if (mounted) showMessage(context, 'Erreur : $e', error: true);
    }
  }

  Future<void> _sample() async {
    await context.read<SettingsProvider>().save(_current());
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              InvoicePreviewScreen(invoice: sampleInvoice(), sample: true)),
    );
  }

  Future<void> _backup() async {
    setState(() => _busy = true);
    try {
      final path = await BackupService(AppDatabase.instance).exportToDevice();
      if (mounted && path != null) showMessage(context, 'Sauvegarde enregistrée');
    } catch (e) {
      if (mounted) showMessage(context, 'Échec de la sauvegarde : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final ok = await confirm(
      context,
      'Restaurer une sauvegarde ?',
      'Les factures, devis, produits, clients et paramètres actuels seront '
          'remplacés par ceux du fichier choisi.',
      ok: 'Choisir le fichier',
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final done =
          await BackupService(AppDatabase.instance).restoreFromDevice();
      if (!done || !mounted) return;
      await Future.wait([
        context.read<SettingsProvider>().load(),
        context.read<ProductProvider>().load(),
        context.read<ClientProvider>().load(),
        context.read<InvoiceProvider>().load(),
      ]);
      if (!mounted) return;
      showMessage(context, 'Sauvegarde restaurée');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showMessage(context, 'Restauration impossible : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 10),
        child: Row(children: [
          Container(width: 4, height: 16, color: AppColors.yellow),
          const SizedBox(width: 8),
          Text(t,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.dark,
                  fontSize: 16)),
        ]),
      );

  Widget _colors(String label, List<int> choices, int value,
          ValueChanged<int> onPick) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          SizedBox(width: 84, child: Text(label)),
          Expanded(
            child: Wrap(spacing: 0, runSpacing: 6, children: [
          for (final c in {...choices, value})
            GestureDetector(
              onTap: () => onPick(c),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: c == value ? Colors.black : Colors.black12,
                      width: c == value ? 3 : 1),
                ),
              ),
            ),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        actions: [
          IconButton(
              tooltip: 'Enregistrer',
              icon: const Icon(Icons.save),
              onPressed: _save),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              if (_busy) const LinearProgressIndicator(),
              _title('Logo'),
              ProductImagePicker(
                photoPath: _s.logoPath,
                label: _s.logoPath == null
                    ? 'Logo MCS VISION par défaut (changer : galerie ou fichiers)'
                    : 'Logo de l’entreprise (galerie ou fichiers)',
                onChanged: (p) => setState(() => _s = p == null
                    ? _s.copyWith(clearLogo: true)
                    : _s.copyWith(logoPath: p)),
              ),
              _title('Entreprise'),
              CustomTextField(
                  controller: _c['name']!, label: 'Nom', required: true),
              CustomTextField(
                  controller: _c['activities']!,
                  label: 'Activités',
                  maxLines: 2),
              CustomTextField(controller: _c['slogan']!, label: 'Slogan'),
              CustomTextField(
                  controller: _c['address']!, label: 'Adresse', maxLines: 2),
              CustomTextField(
                  controller: _c['phones']!,
                  label: 'Téléphones (un par ligne)',
                  maxLines: 2),
              CustomTextField(
                  controller: _c['email']!,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress),
              CustomTextField(
                  controller: _c['manager']!,
                  label: 'Nom du responsable (signature)'),
              _title('Couleurs du document'),
              _colors('Bleu foncé', _darkChoices, _s.primaryColor,
                  (c) => setState(() => _s = _s.copyWith(primaryColor: c))),
              _colors('Bleu clair', _lightChoices, _s.secondaryColor,
                  (c) => setState(() => _s = _s.copyWith(secondaryColor: c))),
              _colors('Jaune', _accentChoices, _s.accentColor,
                  (c) => setState(() => _s = _s.copyWith(accentColor: c))),
              _title('TVA'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('TVA activée par défaut'),
                subtitle: const Text('Désactivée = mode sans TVA'),
                value: _s.vatEnabled,
                onChanged: (v) => setState(() => _s = _s.copyWith(vatEnabled: v)),
              ),
              CustomTextField(
                controller: _c['vat']!,
                label: 'Taux de TVA par défaut',
                suffix: '%',
                numeric: true,
                decimal: true,
              ),
              _title('Textes de la facture'),
              CustomTextField(
                  controller: _c['terms']!,
                  label: 'Conditions de paiement par défaut',
                  maxLines: 2),
              CustomTextField(
                  controller: _c['conditions']!,
                  label: 'Conditions de vente',
                  maxLines: 4),
              CustomTextField(
                  controller: _c['quality']!,
                  label: 'Qualité des produits',
                  maxLines: 2),
              CustomTextField(
                  controller: _c['install']!,
                  label: 'Installation professionnelle',
                  maxLines: 2),
              CustomTextField(
                  controller: _c['sav']!,
                  label: 'Service après-vente',
                  maxLines: 2),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer les paramètres'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _sample,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Voir une facture d’exemple'),
              ),
              if (!kIsWeb) ...[
              _title('Mises à jour'),
              FutureBuilder<String>(
                future: UpdateService.currentVersion(),
                builder: (_, snap) => Text(
                  'Version installée : ${snap.data ?? '…'}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => UpdateUi.checkManually(context),
                icon: const Icon(Icons.system_update),
                label: const Text('Mettre à jour l’application'),
              ),
              ],
              _title('Sauvegarde'),
              const Text(
                'Les données restent sur ce téléphone. Faites une sauvegarde '
                'régulière (factures, clients, produits et photos) dans vos '
                'fichiers, Google Drive ou iCloud.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _backup,
                    icon: const Icon(Icons.backup_outlined),
                    label: const Text('Sauvegarder'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _restore,
                    icon: const Icon(Icons.restore),
                    label: const Text('Restaurer'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
