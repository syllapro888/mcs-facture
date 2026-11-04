import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mcs_facture/models/company_settings.dart';
import 'package:mcs_facture/models/invoice.dart';
import 'package:mcs_facture/models/invoice_item.dart';
import 'package:mcs_facture/services/pdf_service.dart';
import 'package:mcs_facture/utils/sample_invoice.dart';

PdfFonts _fonts() {
  Uint8List f(String n) => File('assets/fonts/$n').readAsBytesSync();
  return PdfFonts(
    regular: f('Poppins-Regular.ttf'),
    medium: f('Poppins-Medium.ttf'),
    bold: f('Poppins-Bold.ttf'),
    italic: f('Poppins-Italic.ttf'),
  );
}

Future<Uint8List?> _noImage(String? _) async => null;

/// Les PDF de test sont écrits dans build/test_pdf/ (GitHub les publie,
/// pour pouvoir les regarder sans installer l'application).
Future<void> _write(String name, Uint8List bytes) async {
  final dir = Directory('build/test_pdf')..createSync(recursive: true);
  await File('${dir.path}/$name').writeAsBytes(bytes);
}

void main() {
  test('la facture d’exemple produit un vrai PDF', () async {
    final bytes = await PdfService.build(
      invoice: sampleInvoice(),
      settings: const CompanySettings(),
      fonts: _fonts(),
      loadImage: _noImage,
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(5000));
    await _write('exemple_facture.pdf', bytes);
  });

  test('photo manquante ou illisible : pas de blocage', () async {
    final inv = sampleInvoice().copyWith(items: const [
      InvoiceItem(name: 'Caméra', unitPrice: 25000, photoPath: 'photos/absent.jpg'),
      InvoiceItem(name: 'Batterie', unitPrice: 90000, photoPath: 'photos/casse.jpg'),
    ]);
    final bytes = await PdfService.build(
      invoice: inv,
      settings: const CompanySettings(),
      fonts: _fonts(),
      loadImage: (p) async =>
          p == 'photos/casse.jpg' ? Uint8List.fromList([1, 2, 3]) : null,
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('beaucoup d’articles : plusieurs pages, devis, TVA, duplicata', () async {
    final items = [
      for (var i = 1; i <= 45; i++)
        InvoiceItem(
          name: 'Article $i avec une désignation volontairement longue pour '
              'vérifier le retour à la ligne automatique',
          description: 'Description complémentaire $i',
          quantity: i.toDouble(),
          unit: 'pièce',
          unitPrice: 1000 * i,
          discount: i.isEven ? 500 : 0,
        ),
      const InvoiceItem(isLabor: true, name: 'Installation', unitPrice: 75000),
    ];
    final inv = sampleInvoice().copyWith(
      type: DocumentType.devis,
      items: items,
      vatEnabled: true,
      vatRate: 18,
      amountPaid: 100000,
    );
    final small = await PdfService.build(
      invoice: sampleInvoice(),
      settings: const CompanySettings(),
      fonts: _fonts(),
      loadImage: _noImage,
    );
    final bytes = await PdfService.build(
      invoice: inv,
      settings: const CompanySettings(),
      fonts: _fonts(),
      loadImage: _noImage,
      duplicata: true,
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(small.length));
    await _write('exemple_devis_multipages.pdf', bytes);
  });
}
