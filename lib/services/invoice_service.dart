import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../database/app_database.dart';
import '../models/company_settings.dart';
import '../models/invoice.dart';
import '../utils/app_paths.dart';
import '../utils/invoice_number_generator.dart';
import 'pdf_service.dart';

/// Règles métier des factures : numérotation, enregistrement, duplication,
/// vérification avant export et génération du PDF.
class InvoiceService {
  InvoiceService(this.db);
  final AppDatabase db;

  static PdfFonts? _fonts;

  static Future<PdfFonts> fonts() async {
    final cached = _fonts;
    if (cached != null) return cached;
    Future<Uint8List> load(String name) async =>
        (await rootBundle.load('assets/fonts/$name')).buffer.asUint8List();
    final f = PdfFonts(
      regular: await load('Poppins-Regular.ttf'),
      medium: await load('Poppins-Medium.ttf'),
      bold: await load('Poppins-Bold.ttf'),
      italic: await load('Poppins-Italic.ttf'),
    );
    _fonts = f;
    return f;
  }

  /// Prochain numéro libre pour ce type et cette année.
  Future<({int seq, String number})> nextNumber(
      DocumentType type, int year) async {
    var seq = await db.maxSeq(type, year) + 1;
    var number = InvoiceNumberGenerator.format(type, year, seq);
    while (await db.numberExists(number)) {
      seq++;
      number = InvoiceNumberGenerator.format(type, year, seq);
    }
    return (seq: seq, number: number);
  }

  /// Nouveau document vide (aucune donnée d'exemple n'est insérée).
  Future<Invoice> blank(DocumentType type, CompanySettings settings) async {
    final now = DateTime.now();
    final n = await nextNumber(type, now.year);
    return Invoice(
      type: type,
      number: n.number,
      year: now.year,
      seq: n.seq,
      date: now,
      paymentTerms: settings.defaultPaymentTerms,
      vatEnabled: settings.vatEnabled,
      vatRate: settings.vatRate,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Liste des problèmes empêchant l'export (vide = tout va bien).
  static List<String> validate(Invoice inv) {
    final errors = <String>[];
    if (inv.clientName.trim().isEmpty) errors.add('Le nom du client est vide.');
    if (inv.items.isEmpty) errors.add('Ajoutez au moins un article.');
    for (final item in inv.items) {
      if (item.name.trim().isEmpty) {
        errors.add('Un article n’a pas de désignation.');
        break;
      }
    }
    for (final item in inv.items) {
      if (item.quantity <= 0) {
        errors.add('« ${item.name} » : la quantité doit être supérieure à 0.');
      }
      if (!item.isLabor && item.unitPrice == null) {
        errors.add('« ${item.name} » : le prix unitaire est manquant.');
      }
    }
    return errors;
  }

  /// Enregistre et renvoie la facture avec son identifiant.
  Future<Invoice> save(Invoice inv) async {
    var toSave = inv.copyWith(updatedAt: DateTime.now());
    if (toSave.id == null &&
        await db.numberExists(toSave.number)) {
      // Numéro pris entre-temps : on prend le suivant.
      final n = await nextNumber(toSave.type, toSave.year);
      toSave = toSave.copyWith(number: n.number, seq: n.seq);
    }
    final id = await db.saveInvoice(toSave);
    return toSave.copyWith(id: id);
  }

  /// Copie en nouveau brouillon (même client, mêmes lignes et prix).
  /// [asType] permet de transformer un devis en facture.
  Future<Invoice> duplicate(Invoice source, {DocumentType? asType}) async {
    final type = asType ?? source.type;
    final now = DateTime.now();
    final n = await nextNumber(type, now.year);
    final copy = source.copyWith(
      clearId: true,
      type: type,
      number: n.number,
      year: now.year,
      seq: n.seq,
      date: now,
      status: InvoiceStatus.brouillon,
      amountPaid: 0,
      items: source.items.map((e) => e.copyWith()).toList(),
      createdAt: now,
      updatedAt: now,
    );
    return save(copy);
  }

  Future<Uint8List> pdf(Invoice inv, CompanySettings settings,
          {bool duplicata = false}) async =>
      PdfService.build(
        invoice: inv,
        settings: settings,
        fonts: await fonts(),
        loadImage: AppPaths.readPhoto,
        duplicata: duplicata,
      );

  static String fileName(Invoice inv, {bool duplicata = false}) =>
      InvoiceNumberGenerator.fileName(inv.type, inv.year, inv.seq,
          duplicata: duplicata);
}
