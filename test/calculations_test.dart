import 'package:flutter_test/flutter_test.dart';
import 'package:mcs_facture/models/company_settings.dart';
import 'package:mcs_facture/models/invoice.dart';
import 'package:mcs_facture/models/invoice_item.dart';
import 'package:mcs_facture/utils/currency_formatter.dart';
import 'package:mcs_facture/utils/invoice_number_generator.dart';
import 'package:mcs_facture/utils/sample_invoice.dart';

void main() {
  group('Facture d’exemple (cahier des charges)', () {
    final inv = sampleInvoice();
    final t = inv.totals;

    test('montants de chaque ligne', () {
      final totals = inv.supplies.map((e) => e.lineTotal).toList();
      expect(totals, [40000, 10000, 45000, 45000, 5000, 2000, 30000, 5000]);
    });

    test('sous-total des fournitures = 182 000 FCFA', () {
      expect(t.suppliesSubtotal, 182000);
      expect(CurrencyFormatter.fcfa(t.suppliesSubtotal), '182 000 FCFA');
    });

    test('main-d’œuvre vide => total « À préciser »', () {
      expect(t.hasLabor, isTrue);
      expect(t.laborIncomplete, isTrue);
      expect(t.totalTTC, isNull);
      expect(t.isComplete, isFalse);
      expect(CurrencyFormatter.fcfa(t.totalTTC), 'À préciser');
    });

    test('une fois la main-d’œuvre chiffrée, le total est définitif', () {
      final items = [
        ...inv.supplies,
        const InvoiceItem(isLabor: true, name: 'Pose', unitPrice: 50000),
      ];
      final t2 = InvoiceTotals.compute(items: items);
      expect(t2.totalTTC, 232000);
    });
  });

  group('Calculs', () {
    test('quantité × prix − remise', () {
      const i = InvoiceItem(
          name: 'Câble', quantity: 30, unitPrice: 1500, discount: 5000);
      expect(i.lineTotal, 40000);
    });

    test('quantité décimale arrondie au franc', () {
      const i = InvoiceItem(name: 'Câble', quantity: 2.5, unitPrice: 1333);
      expect(i.lineTotal, 3333); // 3332,5 -> 3333
    });

    test('remise supérieure au montant => 0, jamais négatif', () {
      const i = InvoiceItem(name: 'X', quantity: 1, unitPrice: 1000, discount: 5000);
      expect(i.lineTotal, 0);
    });

    test('TVA 18 % et remise globale', () {
      final t = InvoiceTotals.compute(
        items: const [
          InvoiceItem(name: 'A', quantity: 2, unitPrice: 50000),
          InvoiceItem(isLabor: true, name: 'Pose', unitPrice: 20000),
        ],
        globalDiscount: 20000,
        vatEnabled: true,
        vatRate: 18,
      );
      expect(t.suppliesSubtotal, 100000);
      expect(t.laborSubtotal, 20000);
      expect(t.totalHT, 100000);
      expect(t.vat, 18000);
      expect(t.totalTTC, 118000);
    });

    test('TVA à 0 % et mode sans TVA', () {
      const items = [InvoiceItem(name: 'A', unitPrice: 10000)];
      expect(InvoiceTotals.compute(items: items, vatEnabled: true, vatRate: 0)
          .totalTTC, 10000);
      expect(InvoiceTotals.compute(items: items, vatRate: 18).totalTTC, 10000);
    });

    test('plusieurs prestations dont une à préciser', () {
      final t = InvoiceTotals.compute(items: const [
        InvoiceItem(name: 'A', unitPrice: 10000),
        InvoiceItem(isLabor: true, name: 'Pose', unitPrice: 15000),
        InvoiceItem(isLabor: true, name: 'Câblage'),
      ]);
      expect(t.laborSubtotal, 15000);
      expect(t.laborIncomplete, isTrue);
      expect(t.totalTTC, isNull);
    });

    test('reste à payer', () {
      final t = InvoiceTotals.compute(
          items: const [InvoiceItem(name: 'A', unitPrice: 100000)],
          amountPaid: 40000);
      expect(t.balance, 60000);
    });
  });

  group('Formats', () {
    test('séparateur de milliers', () {
      expect(CurrencyFormatter.fcfa(0), '0 FCFA');
      expect(CurrencyFormatter.fcfa(999), '999 FCFA');
      expect(CurrencyFormatter.fcfa(1000), '1 000 FCFA');
      expect(CurrencyFormatter.fcfa(1234567), '1 234 567 FCFA');
    });

    test('saisie des montants et quantités', () {
      expect(CurrencyFormatter.parseAmount('182 000'), 182000);
      expect(CurrencyFormatter.parseAmount(''), isNull);
      expect(CurrencyFormatter.parseQuantity('2,5'), 2.5);
      expect(CurrencyFormatter.quantity(30), '30');
      expect(CurrencyFormatter.quantity(2.5), '2,5');
    });

    test('numérotation et nom de fichier', () {
      expect(InvoiceNumberGenerator.format(DocumentType.facture, 2026, 1),
          'MCSV-2026-0001');
      expect(InvoiceNumberGenerator.format(DocumentType.devis, 2026, 12),
          'MCSV-D-2026-0012');
      expect(InvoiceNumberGenerator.fileName(DocumentType.facture, 2026, 1),
          'MCSV_FACTURE_2026_0001.pdf');
    });

    test('paramètres : valeurs par défaut MCS VISION et relecture', () {
      const s = CompanySettings();
      expect(s.name, 'MCS VISION');
      expect(s.phones, contains('+242 069 981 616'));
      final back = CompanySettings.decode(s.copyWith(vatRate: 5).encode());
      expect(back.vatRate, 5);
      expect(back.email, 'Mahamadousyllapro8@gmail.com');
    });

    test('une facture conserve ses prix (aller-retour base de données)', () {
      final inv = sampleInvoice();
      final rows = [
        for (var i = 0; i < inv.items.length; i++) inv.items[i].toMap(1, i)
      ];
      final back = Invoice.fromMap(
          inv.toMap(), rows.map(InvoiceItem.fromMap).toList());
      expect(back.totals.suppliesSubtotal, 182000);
      expect(back.items.last.unitPrice, isNull);
      expect(inv.toMap()['total'], isNull);
    });
  });

  group('Tri des articles par prix total', () {
    const a = InvoiceItem(name: 'A', quantity: 2, unitPrice: 5000); // 10 000
    const b = InvoiceItem(name: 'B', quantity: 1, unitPrice: 45000); // 45 000
    const c = InvoiceItem(name: 'C', quantity: 10, unitPrice: 500); // 5 000
    const d = InvoiceItem(name: 'D', quantity: 1, unitPrice: 10000); // 10 000
    const mo = InvoiceItem(isLabor: true, name: 'Pose'); // À préciser

    test('du plus cher au moins cher, « À préciser » à la fin', () {
      final sorted = InvoiceItem.sortByTotalDesc([mo, a, b, c, d]);
      expect(sorted.map((e) => e.name).toList(), ['B', 'A', 'D', 'C', 'Pose']);
    });

    test('à montant égal, l’ordre d’origine est gardé', () {
      final sorted = InvoiceItem.sortByTotalDesc([d, a]);
      expect(sorted.map((e) => e.name).toList(), ['D', 'A']);
    });

    test('détection d’une liste déjà triée', () {
      expect(InvoiceItem.isSortedByTotalDesc([b, a, c, mo]), isTrue);
      expect(InvoiceItem.isSortedByTotalDesc([a, b]), isFalse);
      expect(InvoiceItem.isSortedByTotalDesc([]), isTrue);
    });
  });
}
