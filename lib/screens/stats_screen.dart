import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../models/invoice.dart';
import '../providers/invoice_provider.dart';
import '../utils/currency_formatter.dart';

/// Statistiques calculées à partir des documents réellement enregistrés.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  static const _months = [
    'Janv.', 'Févr.', 'Mars', 'Avr.', 'Mai', 'Juin',
    'Juil.', 'Août', 'Sept.', 'Oct.', 'Nov.', 'Déc.'
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoiceProvider>();
    final st = provider.stats;
    final byStatus = <InvoiceStatus, int>{};
    for (final s in provider.all) {
      if (s.invoice.type != DocumentType.facture) continue;
      byStatus[s.invoice.status] = (byStatus[s.invoice.status] ?? 0) + 1;
    }
    final maxMonth = st.revenueByMonth.values.fold<int>(0, (a, b) => a > b ? a : b);
    final year = DateTime.now().year;

    return Scaffold(
      appBar: AppBar(title: const Text('Statistiques')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Row(children: [
            _tile('Chiffre d’affaires', CurrencyFormatter.fcfa(st.revenue)),
            _tile('Encaissé', CurrencyFormatter.fcfa(st.collected)),
          ]),
          Row(children: [
            _tile('Reste à encaisser',
                CurrencyFormatter.fcfa(
                    st.revenue > st.collected ? st.revenue - st.collected : 0)),
            _tile('Devis', '${st.quoteCount}'),
          ]),
          const SizedBox(height: 16),
          Text('Chiffre d’affaires $year',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.dark, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                for (var m = 1; m <= 12; m++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      SizedBox(width: 46, child: Text(_months[m - 1])),
                      Expanded(
                        child: LayoutBuilder(builder: (_, c) {
                          final v = st.revenueByMonth[m] ?? 0;
                          final w = maxMonth == 0 ? 0.0 : c.maxWidth * v / maxMonth;
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              height: 14,
                              width: w,
                              decoration: BoxDecoration(
                                color: AppColors.light,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        }),
                      ),
                      SizedBox(
                        width: 96,
                        child: Text(
                            CurrencyFormatter.number(st.revenueByMonth[m] ?? 0),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ]),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Factures par statut',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.dark, fontSize: 16)),
          Card(
            elevation: 0,
            color: Colors.white,
            child: Column(children: [
              for (final s in InvoiceStatus.values)
                ListTile(
                  dense: true,
                  title: Text(s.label),
                  trailing: Text('${byStatus[s] ?? 0}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
            ]),
          ),
          if (st.toPreciseCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  '${st.toPreciseCount} facture(s) ont un total « À préciser » '
                  'et ne sont pas comptées dans le chiffre d’affaires.',
                  style: const TextStyle(fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }

  Widget _tile(String label, String value) => Expanded(
        child: Card(
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark,
                        fontSize: 16)),
              ],
            ),
          ),
        ),
      );
}
