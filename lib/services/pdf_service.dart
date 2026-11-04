import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/company_settings.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../utils/currency_formatter.dart';

/// Polices intégrées au PDF (Poppins), pour que le document garde sa mise en
/// page sur n'importe quel téléphone ou ordinateur.
class PdfFonts {
  final Uint8List regular;
  final Uint8List medium;
  final Uint8List bold;
  final Uint8List italic;

  const PdfFonts({
    required this.regular,
    required this.medium,
    required this.bold,
    required this.italic,
  });
}

typedef ImageLoader = Future<Uint8List?> Function(String? relativePath);

/// Génère le véritable document PDF (A4 portrait, vectoriel) d'une facture
/// ou d'un devis MCS VISION.
class PdfService {
  PdfService._();

  static pw.Font _font(Uint8List b) =>
      pw.Font.ttf(b.buffer.asByteData(b.offsetInBytes, b.lengthInBytes));

  /// Seuls les JPEG et PNG valides sont intégrés ; sinon emplacement neutre.
  static bool _isSupportedImage(Uint8List b) {
    if (b.length < 8) return false;
    final jpeg = b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;
    final png = b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47;
    return jpeg || png;
  }

  static pw.MemoryImage? _image(Uint8List? bytes) {
    if (bytes == null || !_isSupportedImage(bytes)) return null;
    try {
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null; // image illisible : emplacement neutre
    }
  }

  static Future<Uint8List> build({
    required Invoice invoice,
    required CompanySettings settings,
    required PdfFonts fonts,
    required ImageLoader loadImage,
    bool duplicata = false,
  }) async {
    try {
      return await _build(invoice, settings, fonts, loadImage, duplicata);
    } catch (_) {
      // Une image abîmée ne doit jamais bloquer le document :
      // on recommence sans les images.
      return _build(invoice, settings, fonts, (_) async => null, duplicata);
    }
  }

  static Future<Uint8List> _build(Invoice invoice, CompanySettings settings,
      PdfFonts fonts, ImageLoader loadImage, bool duplicata) async {
    // 1. Charger le logo et toutes les photos AVANT de construire le document.
    final logo = _image(await loadImage(settings.logoPath));
    final photos = <int, pw.MemoryImage?>{};
    for (var i = 0; i < invoice.items.length; i++) {
      final item = invoice.items[i];
      if (!item.isLabor) photos[i] = _image(await loadImage(item.photoPath));
    }

    final medium = _font(fonts.medium);
    final s = _Style(settings, medium);
    final totals = invoice.totals;

    final doc = pw.Document(
      title: '${invoice.type.label} ${invoice.number}',
      author: settings.name,
      creator: settings.name,
      theme: pw.ThemeData.withFont(
        base: _font(fonts.regular),
        bold: _font(fonts.bold),
        italic: _font(fonts.italic),
        boldItalic: _font(fonts.bold),
      ),
    );

    final String? watermark = invoice.status == InvoiceStatus.annule
        ? 'ANNULÉ'
        : (duplicata ? 'DUPLICATA' : null);

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 20),
          buildBackground: watermark == null
              ? null
              : (ctx) => pw.FullPage(
                    ignoreMargins: true,
                    child: pw.Center(
                      child: pw.Transform.rotate(
                        angle: 0.6,
                        child: pw.Text(
                          watermark,
                          style: pw.TextStyle(
                            fontSize: 88,
                            fontWeight: pw.FontWeight.bold,
                            color: s.tint(s.dark, 0.9),
                          ),
                        ),
                      ),
                    ),
                  ),
        ),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : _smallHeader(invoice, settings, s),
        footer: (ctx) => _footer(ctx, settings, s),
        build: (ctx) => [
          _header(invoice, settings, s, logo),
          pw.SizedBox(height: 8),
          _stripe(s),
          pw.SizedBox(height: 10),
          if (invoice.supplies.isNotEmpty) ...[
            _sectionTitle('FOURNITURES', s),
            pw.SizedBox(height: 4),
            _suppliesTable(invoice.items, photos, s),
          ],
          if (invoice.supplies.isEmpty && invoice.labor.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Text('Aucun article.', style: s.small),
            ),
          if (invoice.labor.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            _sectionTitle('MAIN-D’ŒUVRE', s),
            pw.SizedBox(height: 4),
            _laborTable(invoice.items, s),
          ],
          pw.SizedBox(height: 10),
          _summary(invoice, totals, settings, s),
          pw.SizedBox(height: 10),
          if (invoice.type == DocumentType.facture)
            // Facture : signature du responsable à droite des garanties.
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: _guarantees(settings, s)),
                pw.SizedBox(width: 10),
                _signatureZone('Signature et cachet du responsable',
                    _managerLabel(settings), s,
                    width: 150),
              ],
            )
          else ...[
            _guarantees(settings, s),
            pw.SizedBox(height: 8),
            _signatures(invoice, settings, s),
          ],
        ],
      ),
    );

    return doc.save();
  }

  // ---------------------------------------------------------------- En-tête

  static pw.Widget _header(Invoice inv, CompanySettings c, _Style s,
      pw.MemoryImage? logo) {
    final date = DateFormat('dd/MM/yyyy').format(inv.date);
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Gauche : logo, nom, activités, slogan
        pw.Expanded(
          flex: 5,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null) ...[
                pw.Container(
                  width: 64,
                  height: 64,
                  alignment: pw.Alignment.center,
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 8),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(c.name,
                        style: pw.TextStyle(
                            fontSize: 19,
                            fontWeight: pw.FontWeight.bold,
                            color: s.dark,
                            letterSpacing: 0.5)),
                    pw.Container(
                        width: 46,
                        height: 2.5,
                        margin: const pw.EdgeInsets.symmetric(vertical: 3),
                        color: s.accent),
                    pw.Text(c.activities,
                        style: pw.TextStyle(
                            fontSize: 7.5, color: s.text, lineSpacing: 1)),
                    pw.SizedBox(height: 4),
                    pw.Text(c.slogan,
                        style: pw.TextStyle(
                            fontSize: 8,
                            fontStyle: pw.FontStyle.italic,
                            color: s.light)),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 10),
        // Centre : coordonnées
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _contact('ADRESSE', c.address, s),
              _contact('TÉLÉPHONES', c.phones, s),
              _contact('EMAIL', c.email, s),
            ],
          ),
        ),
        pw.SizedBox(width: 10),
        // Droite : bandeau FACTURE / DEVIS
        pw.Container(
          width: 176,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                color: s.dark,
                padding:
                    const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                child: pw.Row(
                  children: [
                    pw.Container(width: 4, height: 22, color: s.accent),
                    pw.SizedBox(width: 8),
                    pw.Text(inv.type.title,
                        style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                            letterSpacing: 2)),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.fromLTRB(10, 6, 10, 7),
                decoration: pw.BoxDecoration(
                  color: s.tint(s.light, 0.92),
                  border: pw.Border(
                      bottom: pw.BorderSide(color: s.light, width: 1.2)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _kv('N°', inv.number, s, boldValue: true),
                    _kv('Date', date, s),
                    pw.SizedBox(height: 3),
                    pw.Text('CLIENT',
                        style: pw.TextStyle(
                            fontSize: 6.5,
                            color: s.light,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1)),
                    pw.Text(inv.clientName.isEmpty ? '—' : inv.clientName,
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: s.dark)),
                    if (inv.clientPhone.isNotEmpty)
                      pw.Text(inv.clientPhone, style: s.small),
                    if (inv.clientAddress.isNotEmpty)
                      pw.Text(inv.clientAddress, style: s.small),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _contact(String label, String value, _Style s) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 6.5,
                    fontWeight: pw.FontWeight.bold,
                    color: s.light,
                    letterSpacing: 1)),
            pw.Text(value, style: pw.TextStyle(fontSize: 7.2, color: s.dark)),
          ],
        ),
      );

  static pw.Widget _kv(String k, String v, _Style s, {bool boldValue = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 1.5),
        child: pw.Row(
          children: [
            pw.SizedBox(
                width: 32,
                child: pw.Text(k,
                    style: pw.TextStyle(fontSize: 7.5, color: s.text))),
            pw.Expanded(
              child: pw.Text(v,
                  style: pw.TextStyle(
                      fontSize: boldValue ? 9 : 8,
                      fontWeight:
                          boldValue ? pw.FontWeight.bold : pw.FontWeight.normal,
                      color: s.dark)),
            ),
          ],
        ),
      );

  static pw.Widget _stripe(_Style s) => pw.Row(children: [
        pw.Expanded(flex: 7, child: pw.Container(height: 3, color: s.dark)),
        pw.Expanded(flex: 2, child: pw.Container(height: 3, color: s.accent)),
        pw.Expanded(flex: 1, child: pw.Container(height: 3, color: s.light)),
      ]);

  static pw.Widget _smallHeader(Invoice inv, CompanySettings c, _Style s) =>
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.only(bottom: 4),
        decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: s.light, width: 1))),
        child: pw.Row(children: [
          pw.Text(c.name,
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold, color: s.dark)),
          pw.Spacer(),
          pw.Text('${inv.type.title} N° ${inv.number} (suite)',
              style: pw.TextStyle(fontSize: 8, color: s.dark)),
        ]),
      );

  static pw.Widget _sectionTitle(String title, _Style s) => pw.Row(children: [
        pw.Container(width: 3, height: 11, color: s.accent),
        pw.SizedBox(width: 5),
        pw.Text(title,
            style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: s.dark,
                letterSpacing: 1)),
      ]);

  // ---------------------------------------------------------------- Tableaux

  static pw.Widget _th(String t, _Style s,
          {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        child: pw.Text(t,
            textAlign: align,
            style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                letterSpacing: 0.4)),
      );

  static pw.Widget _td(pw.Widget child,
          {pw.Alignment align = pw.Alignment.centerLeft}) =>
      pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: child,
      );

  static pw.Widget _photoCell(pw.MemoryImage? img, _Style s) {
    const size = 28.0;
    if (img != null) {
      return pw.Container(
        width: size,
        height: size,
        alignment: pw.Alignment.center,
        child: pw.Image(img, fit: pw.BoxFit.contain, width: size, height: size),
      );
    }
    return pw.Container(
      width: size,
      height: size,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: s.tint(s.light, 0.93),
        border: pw.Border.all(color: s.tint(s.light, 0.6), width: 0.6),
      ),
      child: pw.Text('PHOTO',
          style: pw.TextStyle(
              fontSize: 5.5, color: s.tint(s.dark, 0.5), letterSpacing: 0.6)),
    );
  }

  static pw.Widget _designation(InvoiceItem item, _Style s) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(item.name,
              style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: s.dark)),
          if (item.description.trim().isNotEmpty)
            pw.Text(item.description.trim(),
                style: pw.TextStyle(fontSize: 7, color: s.text)),
          if (item.discount > 0 && item.unitPrice != null)
            pw.Text('Remise : -${CurrencyFormatter.fcfa(item.discount)}',
                style: pw.TextStyle(
                    fontSize: 6.8,
                    fontStyle: pw.FontStyle.italic,
                    color: s.text)),
        ],
      );

  static pw.Widget _qty(InvoiceItem item, _Style s) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(CurrencyFormatter.quantity(item.quantity),
              style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: s.dark)),
          pw.Text(item.unit, style: pw.TextStyle(fontSize: 6.5, color: s.text)),
        ],
      );

  static pw.Widget _money(int? value, _Style s, {bool bold = false}) => pw.Text(
        value == null
            ? CurrencyFormatter.aPreciser
            : CurrencyFormatter.number(value),
        textAlign: pw.TextAlign.right,
        style: value == null
            ? pw.TextStyle(
                fontSize: 8,
                fontStyle: pw.FontStyle.italic,
                fontWeight: pw.FontWeight.bold,
                color: s.accentDark)
            : pw.TextStyle(
                fontSize: 8.5,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: s.dark),
      );

  static pw.TableBorder _border(_Style s) => pw.TableBorder(
        horizontalInside: pw.BorderSide(color: s.tint(s.light, 0.45), width: 0.6),
        bottom: pw.BorderSide(color: s.light, width: 1),
      );

  static pw.Widget _suppliesTable(List<InvoiceItem> items,
      Map<int, pw.MemoryImage?> photos, _Style s) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: s.dark),
        children: [
          _th('N°', s, align: pw.TextAlign.center),
          _th('PHOTO', s, align: pw.TextAlign.center),
          _th('DÉSIGNATION', s),
          _th('QUANTITÉ', s, align: pw.TextAlign.center),
          _th('PRIX UNITAIRE\n(FCFA)', s, align: pw.TextAlign.right),
          _th('MONTANT\n(FCFA)', s, align: pw.TextAlign.right),
        ],
      ),
    ];
    var n = 0;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.isLabor) continue;
      n++;
      rows.add(pw.TableRow(
        children: [
          _td(pw.Text('$n', style: pw.TextStyle(fontSize: 8, color: s.dark)),
              align: pw.Alignment.center),
          _td(_photoCell(photos[i], s), align: pw.Alignment.center),
          _td(_designation(item, s)),
          _td(_qty(item, s), align: pw.Alignment.center),
          _td(_money(item.unitPrice, s), align: pw.Alignment.centerRight),
          _td(_money(item.lineTotal, s, bold: true),
              align: pw.Alignment.centerRight),
        ],
      ));
    }
    return pw.Table(
      border: _border(s),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      columnWidths: {
        0: pw.FixedColumnWidth(24),
        1: pw.FixedColumnWidth(42),
        2: pw.FlexColumnWidth(),
        3: pw.FixedColumnWidth(56),
        4: pw.FixedColumnWidth(74),
        5: pw.FixedColumnWidth(80),
      },
      children: rows,
    );
  }

  static pw.Widget _laborTable(List<InvoiceItem> items, _Style s) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: s.dark),
        children: [
          _th('N°', s, align: pw.TextAlign.center),
          _th('PRESTATION', s),
          _th('QUANTITÉ', s, align: pw.TextAlign.center),
          _th('PRIX UNITAIRE\n(FCFA)', s, align: pw.TextAlign.right),
          _th('MONTANT\n(FCFA)', s, align: pw.TextAlign.right),
        ],
      ),
    ];
    var n = 0;
    for (final item in items) {
      if (!item.isLabor) continue;
      n++;
      rows.add(pw.TableRow(
        children: [
          _td(pw.Text('$n', style: pw.TextStyle(fontSize: 8, color: s.dark)),
              align: pw.Alignment.center),
          _td(_designation(item, s)),
          _td(_qty(item, s), align: pw.Alignment.center),
          _td(_money(item.unitPrice, s), align: pw.Alignment.centerRight),
          _td(_money(item.lineTotal, s, bold: true),
              align: pw.Alignment.centerRight),
        ],
      ));
    }
    return pw.Table(
      border: _border(s),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      columnWidths: {
        0: pw.FixedColumnWidth(24),
        1: pw.FlexColumnWidth(),
        2: pw.FixedColumnWidth(56),
        3: pw.FixedColumnWidth(74),
        4: pw.FixedColumnWidth(80),
      },
      children: rows,
    );
  }

  // ---------------------------------------------------------- Récapitulatif

  static pw.Widget _summary(
      Invoice inv, InvoiceTotals t, CompanySettings c, _Style s) {
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

    final vatLabel =
        'TVA (${CurrencyFormatter.quantity(t.vatRate)} %)';
    final totalLabel = t.vatEnabled ? 'TOTAL TTC' : 'MONTANT TOTAL';

    final conditions = <pw.Widget>[
      pw.Text('CONDITIONS DE VENTE',
          style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: s.dark,
              letterSpacing: 1)),
      pw.Container(
          width: 40,
          height: 2,
          margin: const pw.EdgeInsets.only(top: 2, bottom: 5),
          color: s.accent),
      if (inv.paymentTerms.trim().isNotEmpty)
        _para('Paiement', inv.paymentTerms.trim(), s),
      if (c.salesConditions.trim().isNotEmpty)
        pw.Text(c.salesConditions.trim(),
            style: pw.TextStyle(fontSize: 7.2, color: s.text, lineSpacing: 1)),
      if (inv.notes.trim().isNotEmpty) ...[
        pw.SizedBox(height: 5),
        _para('Notes', inv.notes.trim(), s),
      ],
    ];

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(9),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: s.tint(s.light, 0.55), width: 0.8),
            ),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: conditions),
          ),
        ),
        pw.SizedBox(width: 14),
        pw.Container(
          width: 236,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _sumLine('Sous-total fournitures',
                  t.suppliesIncomplete ? CurrencyFormatter.aPreciser
                      : CurrencyFormatter.fcfa(t.suppliesSubtotal), s),
              _sumLine('Sous-total main-d’œuvre', labor, s,
                  highlight: t.laborIncomplete),
              if (t.globalDiscount > 0)
                _sumLine('Remise',
                    '-${CurrencyFormatter.fcfa(t.globalDiscount)}', s),
              if (t.vatEnabled) ...[
                _sumLine('Total HT', CurrencyFormatter.fcfa(t.totalHT), s,
                    highlight: t.totalHT == null),
                _sumLine(vatLabel, CurrencyFormatter.fcfa(t.vat), s,
                    highlight: t.vat == null),
              ],
              pw.SizedBox(height: 4),
              pw.Container(
                color: s.dark,
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: pw.Row(children: [
                  pw.Container(width: 3, height: 14, color: s.accent),
                  pw.SizedBox(width: 6),
                  pw.Text(totalLabel,
                      style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          letterSpacing: 1)),
                  pw.Spacer(),
                  pw.Text(CurrencyFormatter.fcfa(t.totalTTC),
                      style: pw.TextStyle(
                          fontSize: 12.5,
                          fontWeight: pw.FontWeight.bold,
                          color: t.isComplete ? PdfColors.white : s.accent)),
                ]),
              ),
              if (!t.isComplete)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text(
                      'Total définitif à préciser : certains montants '
                      '(main-d’œuvre) ne sont pas encore chiffrés.',
                      style: pw.TextStyle(
                          fontSize: 6.8,
                          fontStyle: pw.FontStyle.italic,
                          color: s.text)),
                ),
              if (inv.amountPaid > 0) ...[
                pw.SizedBox(height: 4),
                _sumLine('Déjà payé', CurrencyFormatter.fcfa(inv.amountPaid), s),
                _sumLine('Reste à payer', CurrencyFormatter.fcfa(t.balance), s,
                    bold: true),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _para(String label, String text, _Style s) => pw.RichText(
        text: pw.TextSpan(
          style: pw.TextStyle(fontSize: 7.2, color: s.text),
          children: [
            pw.TextSpan(
                text: '$label : ',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: s.dark)),
            pw.TextSpan(text: text),
          ],
        ),
      );

  static pw.Widget _sumLine(String label, String value, _Style s,
          {bool highlight = false, bool bold = false}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
        decoration: pw.BoxDecoration(
          border: pw.Border(
              bottom:
                  pw.BorderSide(color: s.tint(s.light, 0.5), width: 0.6)),
        ),
        child: pw.Row(children: [
          pw.Expanded(
              child: pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 8,
                      color: s.dark,
                      fontWeight:
                          bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
          pw.Text(value,
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                fontStyle:
                    highlight ? pw.FontStyle.italic : pw.FontStyle.normal,
                color: highlight ? s.accentDark : s.dark,
              )),
        ]),
      );

  // ---------------------------------------------------------- Pied de page

  static pw.Widget _guarantees(CompanySettings c, _Style s) {
    pw.Widget box(String title, String text) => pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.symmetric(horizontal: 3),
            padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 7),
            decoration: pw.BoxDecoration(
              color: s.tint(s.light, 0.93),
              border: pw.Border(top: pw.BorderSide(color: s.accent, width: 2)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(title,
                    style: pw.TextStyle(
                        fontSize: 7.2,
                        fontWeight: pw.FontWeight.bold,
                        color: s.dark,
                        letterSpacing: 0.5)),
                pw.SizedBox(height: 2),
                pw.Text(text, style: pw.TextStyle(fontSize: 6.8, color: s.text)),
              ],
            ),
          ),
        );
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        box('QUALITÉ DES PRODUITS', c.qualityText),
        box('INSTALLATION PROFESSIONNELLE', c.installText),
        box('SERVICE APRÈS-VENTE', c.afterSalesText),
      ],
    );
  }

  static String _managerLabel(CompanySettings c) =>
      c.managerName.isEmpty ? c.name : '${c.managerName} — ${c.name}';

  static pw.Widget _signatureZone(String title, String name, _Style s,
          {double width = 210}) =>
      pw.Container(
        width: width,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title,
                style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: s.dark)),
            pw.Container(
              height: 30,
              decoration: pw.BoxDecoration(
                border:
                    pw.Border(bottom: pw.BorderSide(color: s.dark, width: 0.8)),
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(name, style: pw.TextStyle(fontSize: 7, color: s.text)),
          ],
        ),
      );

  static pw.Widget _signatures(Invoice inv, CompanySettings c, _Style s) {
    pw.Widget zone(String title, String name) => pw.Container(
          width: 210,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 7.8,
                      fontWeight: pw.FontWeight.bold,
                      color: s.dark)),
              pw.Container(
                height: 32,
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(color: s.dark, width: 0.8)),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(name, style: pw.TextStyle(fontSize: 7.2, color: s.text)),
            ],
          ),
        );
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        inv.type == DocumentType.devis
            ? zone('Bon pour accord — signature du client',
                inv.clientName.isEmpty ? 'Nom et date' : inv.clientName)
            : pw.SizedBox(width: 210),
        zone('Signature et cachet du responsable',
            c.managerName.isEmpty ? c.name : '${c.managerName} — ${c.name}'),
      ],
    );
  }

  static pw.Widget _footer(pw.Context ctx, CompanySettings c, _Style s) {
    final contacts = [
      c.name,
      c.address.replaceAll('\n', ', '),
      c.phones.replaceAll('\n', ' / '),
      c.email,
    ].where((e) => e.trim().isNotEmpty).join('  •  ');
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: s.dark,
      child: pw.Column(children: [
        pw.Text(c.slogan,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                fontSize: 7.8,
                fontStyle: pw.FontStyle.italic,
                color: s.accent)),
        pw.SizedBox(height: 2),
        pw.Row(children: [
          pw.Expanded(
            child: pw.Text(contacts,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 6.3, color: PdfColors.white)),
          ),
          pw.SizedBox(width: 6),
          pw.Text('${ctx.pageNumber}/${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 6.3, color: PdfColors.white)),
        ]),
      ]),
    );
  }
}

/// Palette et styles partagés.
class _Style {
  final PdfColor dark;
  final PdfColor light;
  final PdfColor accent;
  final PdfColor accentDark;
  final PdfColor text;
  final pw.Font medium;
  final pw.TextStyle small;

  _Style(CompanySettings c, this.medium)
      : dark = PdfColor.fromInt(c.primaryColor),
        light = PdfColor.fromInt(c.secondaryColor),
        accent = PdfColor.fromInt(c.accentColor),
        accentDark = _shade(PdfColor.fromInt(c.accentColor), 0.35),
        text = _mix(PdfColor.fromInt(c.primaryColor), PdfColors.grey700, 0.5),
        small = pw.TextStyle(
            fontSize: 7.5,
            color: _mix(PdfColor.fromInt(c.primaryColor), PdfColors.grey700, 0.5));

  /// Éclaircit une couleur (t = 0 : identique, t = 1 : blanc).
  PdfColor tint(PdfColor c, double t) => PdfColor(
        c.red + (1 - c.red) * t,
        c.green + (1 - c.green) * t,
        c.blue + (1 - c.blue) * t,
      );

  static PdfColor _shade(PdfColor c, double t) =>
      PdfColor(c.red * (1 - t), c.green * (1 - t), c.blue * (1 - t));

  static PdfColor _mix(PdfColor a, PdfColor b, double t) => PdfColor(
        a.red + (b.red - a.red) * t,
        a.green + (b.green - a.green) * t,
        a.blue + (b.blue - a.blue) * t,
      );
}
