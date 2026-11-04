import 'package:flutter/material.dart';

import '../app.dart';
import '../models/invoice.dart';
import '../utils/currency_formatter.dart';

/// Récapitulatif des montants, recalculé à chaque modification.
class InvoiceTotalsView extends StatelessWidget {
  const InvoiceTotalsView({super.key, required this.totals});
  final InvoiceTotals totals;

  @override
  Widget build(BuildContext context) {
    final t = totals;
    String labor;
    if (!t.hasLabor) {
      labor = 'Non incluse';
    } else if (t.laborIncomplete) {
      labor = t.laborSubtotal > 0
          ? '${CurrencyFormatter.fcfa(t.laborSubtotal)} + à préciser'
          : CurrencyFormatter.aPreciser;
    } else {
      labor = CurrencyFormatter.fcfa(t.laborSubtotal);
    }
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFD5E6F7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          _line('Sous-total fournitures',
              t.suppliesIncomplete
                  ? CurrencyFormatter.aPreciser
                  : CurrencyFormatter.fcfa(t.suppliesSubtotal)),
          _line('Sous-total main-d’œuvre', labor, warn: t.laborIncomplete),
          if (t.globalDiscount > 0)
            _line('Remise', '-${CurrencyFormatter.fcfa(t.globalDiscount)}'),
          if (t.vatEnabled) ...[
            _line('Total HT', CurrencyFormatter.fcfa(t.totalHT)),
            _line('TVA (${CurrencyFormatter.quantity(t.vatRate)} %)',
                CurrencyFormatter.fcfa(t.vat)),
          ],
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.dark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Text(t.vatEnabled ? 'TOTAL TTC' : 'MONTANT TOTAL',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(CurrencyFormatter.fcfa(t.totalTTC),
                  style: TextStyle(
                      color: t.isComplete ? Colors.white : AppColors.yellow,
                      fontWeight: FontWeight.bold,
                      fontSize: 17)),
            ]),
          ),
          if (!t.isComplete)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Le total définitif sera connu quand la main-d’œuvre sera chiffrée.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          if (t.amountPaid > 0) ...[
            const SizedBox(height: 6),
            _line('Déjà payé', CurrencyFormatter.fcfa(t.amountPaid)),
            _line('Reste à payer', CurrencyFormatter.fcfa(t.balance)),
          ],
        ]),
      ),
    );
  }

  Widget _line(String label, String value, {bool warn = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label)),
          Text(value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontStyle: warn ? FontStyle.italic : FontStyle.normal,
                color: warn ? const Color(0xFFB07A00) : AppColors.dark,
              )),
        ]),
      );
}
