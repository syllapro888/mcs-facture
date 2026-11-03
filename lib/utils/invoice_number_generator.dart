import '../models/invoice.dart';

/// Numérotation : MCSV-2026-0001 (factures), MCSV-D-2026-0001 (devis).
class InvoiceNumberGenerator {
  InvoiceNumberGenerator._();

  static String prefix(DocumentType type) =>
      type == DocumentType.facture ? 'MCSV' : 'MCSV-D';

  static String format(DocumentType type, int year, int seq) =>
      '${prefix(type)}-$year-${seq.toString().padLeft(4, '0')}';

  /// MCSV_FACTURE_2026_0001.pdf
  static String fileName(DocumentType type, int year, int seq,
      {bool duplicata = false}) {
    final kind = type == DocumentType.facture ? 'FACTURE' : 'DEVIS';
    final dup = duplicata ? '_DUPLICATA' : '';
    return 'MCSV_${kind}_${year}_${seq.toString().padLeft(4, '0')}$dup.pdf';
  }
}
