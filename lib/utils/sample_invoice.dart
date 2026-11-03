import '../models/invoice.dart';
import '../models/invoice_item.dart';

/// Facture d'exemple (cahier des charges, section 17).
/// Utilisée seulement pour les tests et le bouton « Voir un exemple » :
/// elle n'est jamais enregistrée ni insérée dans les nouvelles factures.
Invoice sampleInvoice() {
  final now = DateTime.now();
  InvoiceItem f(String name, double q, String unit, int price) =>
      InvoiceItem(name: name, quantity: q, unit: unit, unitPrice: price);
  return Invoice(
    type: DocumentType.facture,
    number: 'MCSV-${now.year}-EXEMPLE',
    year: now.year,
    seq: 0,
    date: now,
    clientName: 'Client exemple',
    clientPhone: '+242 06 000 00 00',
    clientAddress: 'Brazzaville',
    paymentTerms: 'Paiement à la livraison.',
    status: InvoiceStatus.enAttente,
    items: [
      f('Rails de 3 m', 4, 'pièce', 10000),
      f('Crochets pour panneaux', 10, 'pièce', 1000),
      f('Câble solaire 6 mm² noir', 30, 'mètre', 1500),
      f('Câble solaire 6 mm² rouge', 30, 'mètre', 1500),
      f('Connecteurs MC4', 5, 'pièce', 1000),
      f('Goulotte 120 × 120', 1, 'pièce', 2000),
      f('Coffret de protection', 1, 'pièce', 30000),
      f('Gaine', 1, 'pièce', 5000),
      const InvoiceItem(
          isLabor: true, name: 'Main-d’œuvre', unit: 'forfait', unitPrice: null),
    ],
    createdAt: now,
    updatedAt: now,
  );
}
