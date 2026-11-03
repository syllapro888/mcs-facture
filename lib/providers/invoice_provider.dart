import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';

/// Ligne de liste : en-tête de facture + total mémorisé.
class InvoiceSummary {
  final Invoice invoice;
  final int? total; // null = à préciser
  const InvoiceSummary(this.invoice, this.total);
}

class DashboardStats {
  final int invoiceCount;
  final int paidCount;
  final int unpaidCount;
  final int quoteCount;
  final int revenue; // factures émises (hors brouillon / annulé) au total connu
  final int collected; // montants encaissés
  final int toPreciseCount;
  final Map<int, int> revenueByMonth; // mois (1..12) de l'année en cours

  const DashboardStats({
    this.invoiceCount = 0,
    this.paidCount = 0,
    this.unpaidCount = 0,
    this.quoteCount = 0,
    this.revenue = 0,
    this.collected = 0,
    this.toPreciseCount = 0,
    this.revenueByMonth = const {},
  });
}

class InvoiceProvider extends ChangeNotifier {
  InvoiceProvider(this.db) : service = InvoiceService(db);
  final AppDatabase db;
  final InvoiceService service;

  List<InvoiceSummary> _all = [];
  List<InvoiceSummary> get all => _all;
  DashboardStats stats = const DashboardStats();
  bool loading = false;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      final headers = await db.invoiceHeaders();
      final totals = await db.storedTotals();
      _all = [for (final h in headers) InvoiceSummary(h, totals[h.id])];
      stats = _computeStats(_all);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  static DashboardStats _computeStats(List<InvoiceSummary> list) {
    var count = 0, paid = 0, unpaid = 0, quotes = 0, toPrecise = 0;
    var revenue = 0, collected = 0;
    final byMonth = <int, int>{};
    final year = DateTime.now().year;
    for (final s in list) {
      final inv = s.invoice;
      if (inv.type == DocumentType.devis) {
        quotes++;
        continue;
      }
      if (inv.status == InvoiceStatus.brouillon ||
          inv.status == InvoiceStatus.annule) {
        continue;
      }
      count++;
      if (inv.status == InvoiceStatus.paye) {
        paid++;
      } else {
        unpaid++;
      }
      final total = s.total;
      if (total == null) {
        toPrecise++;
      } else {
        revenue += total;
        if (inv.date.year == year) {
          byMonth[inv.date.month] = (byMonth[inv.date.month] ?? 0) + total;
        }
      }
      if (inv.status == InvoiceStatus.paye) {
        collected += total ?? inv.amountPaid;
      } else {
        collected += inv.amountPaid;
      }
    }
    return DashboardStats(
      invoiceCount: count,
      paidCount: paid,
      unpaidCount: unpaid,
      quoteCount: quotes,
      revenue: revenue,
      collected: collected,
      toPreciseCount: toPrecise,
      revenueByMonth: byMonth,
    );
  }

  List<InvoiceSummary> filter({
    required DocumentType type,
    String query = '',
    InvoiceStatus? status,
    DateTime? from,
    DateTime? to,
  }) {
    final q = query.trim().toLowerCase();
    return _all.where((s) {
      final inv = s.invoice;
      if (inv.type != type) return false;
      if (status != null && inv.status != status) return false;
      final day = DateTime(inv.date.year, inv.date.month, inv.date.day);
      if (from != null && day.isBefore(from)) return false;
      if (to != null && day.isAfter(to)) return false;
      if (q.isEmpty) return true;
      return inv.number.toLowerCase().contains(q) ||
          inv.clientName.toLowerCase().contains(q);
    }).toList();
  }

  Future<Invoice?> full(int id) => db.invoice(id);

  Future<Invoice> save(Invoice inv) async {
    final saved = await service.save(inv);
    await load();
    return saved;
  }

  Future<void> setStatus(Invoice inv, InvoiceStatus status,
      {int? amountPaid}) async {
    if (inv.id == null) return;
    await db.updateStatus(inv.id!, status, amountPaid ?? inv.amountPaid);
    await load();
  }

  Future<Invoice> duplicate(Invoice inv, {DocumentType? asType}) async {
    final full = inv.id == null ? inv : (await db.invoice(inv.id!) ?? inv);
    final copy = await service.duplicate(full, asType: asType);
    await load();
    return copy;
  }

  Future<void> delete(Invoice inv) async {
    if (inv.id == null) return;
    await db.deleteInvoice(inv.id!);
    await load();
  }
}
