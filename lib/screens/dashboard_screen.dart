import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../models/invoice.dart';
import '../providers/invoice_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/currency_formatter.dart';
import '../widgets/product_image_picker.dart';
import 'client_list_screen.dart';
import 'invoice_form_screen.dart';
import 'invoice_list_screen.dart';
import 'product_list_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _go(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<InvoiceProvider>().stats;
    final company = context.watch<SettingsProvider>().settings;

    final actions = <(IconData, String, Widget)>[
      (Icons.receipt_long, 'Nouvelle facture',
          const InvoiceFormScreen(type: DocumentType.facture)),
      (Icons.request_quote_outlined, 'Nouveau devis',
          const InvoiceFormScreen(type: DocumentType.devis)),
      (Icons.history, 'Factures',
          const InvoiceListScreen(type: DocumentType.facture)),
      (Icons.folder_copy_outlined, 'Devis',
          const InvoiceListScreen(type: DocumentType.devis)),
      (Icons.inventory_2_outlined, 'Catalogue', const ProductListScreen()),
      (Icons.people_alt_outlined, 'Clients', const ClientListScreen()),
      (Icons.bar_chart, 'Statistiques', const StatsScreen()),
      (Icons.settings_outlined, 'Paramètres', const SettingsScreen()),
    ];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => context.read<InvoiceProvider>().load(),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 20, 20, 24),
              decoration: const BoxDecoration(
                color: AppColors.dark,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (company.logoPath != null) ...[
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10)),
                        child: LocalPhoto(company.logoPath, size: 44),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(company.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          Text(company.slogan,
                              style: const TextStyle(
                                  color: AppColors.yellow,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  Row(children: [
                    _stat('Factures', '${stats.invoiceCount}'),
                    _stat('Payées', '${stats.paidCount}'),
                    _stat('Impayées', '${stats.unpaidCount}'),
                  ]),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: const Border(
                          left: BorderSide(color: AppColors.yellow, width: 4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Chiffre d’affaires enregistré',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(CurrencyFormatter.fcfa(stats.revenue),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                        if (stats.toPreciseCount > 0)
                          Text(
                              '+ ${stats.toPreciseCount} facture(s) au total à préciser',
                              style: const TextStyle(
                                  color: AppColors.yellow, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  for (var i = 0; i < actions.length; i++)
                    _ActionTile(
                      icon: actions[i].$1,
                      label: actions[i].$2,
                      highlight: i < 2,
                      onTap: () => _go(context, actions[i].$3),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlight ? AppColors.yellow : Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: highlight ? 2 : 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: AppColors.dark, size: 30),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.dark,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
