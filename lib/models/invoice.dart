import 'invoice_item.dart';

enum DocumentType { facture, devis }

extension DocumentTypeX on DocumentType {
  String get label => this == DocumentType.facture ? 'Facture' : 'Devis';
  String get title => this == DocumentType.facture ? 'FACTURE' : 'DEVIS';
}

enum InvoiceStatus { brouillon, enAttente, partiel, paye, annule }

extension InvoiceStatusX on InvoiceStatus {
  String get label => switch (this) {
        InvoiceStatus.brouillon => 'Brouillon',
        InvoiceStatus.enAttente => 'En attente',
        InvoiceStatus.partiel => 'Partiellement payé',
        InvoiceStatus.paye => 'Payé',
        InvoiceStatus.annule => 'Annulé',
      };

  bool get isFinal => this != InvoiceStatus.brouillon;
}

/// Résultat des calculs. Un montant null signifie « À préciser ».
class InvoiceTotals {
  final int suppliesSubtotal;
  final bool suppliesIncomplete;
  final int laborSubtotal;
  final bool laborIncomplete;
  final bool hasLabor;
  final int lineDiscounts;
  final int globalDiscount;
  final bool vatEnabled;
  final double vatRate;
  final int? vat;
  final int? totalHT;
  final int? totalTTC;
  final int amountPaid;

  const InvoiceTotals({
    required this.suppliesSubtotal,
    required this.suppliesIncomplete,
    required this.laborSubtotal,
    required this.laborIncomplete,
    required this.hasLabor,
    required this.lineDiscounts,
    required this.globalDiscount,
    required this.vatEnabled,
    required this.vatRate,
    required this.vat,
    required this.totalHT,
    required this.totalTTC,
    required this.amountPaid,
  });

  bool get isComplete => totalTTC != null;

  /// Reste à payer (null si le total n'est pas encore connu).
  int? get balance {
    final t = totalTTC;
    if (t == null) return null;
    final r = t - amountPaid;
    return r < 0 ? 0 : r;
  }

  static InvoiceTotals compute({
    required List<InvoiceItem> items,
    int globalDiscount = 0,
    bool vatEnabled = false,
    double vatRate = 0,
    int amountPaid = 0,
  }) {
    var supplies = 0;
    var suppliesIncomplete = false;
    var labor = 0;
    var laborIncomplete = false;
    var hasLabor = false;
    var lineDiscounts = 0;

    for (final item in items) {
      final line = item.lineTotal;
      if (item.isLabor) {
        hasLabor = true;
        if (line == null) {
          laborIncomplete = true;
        } else {
          labor += line;
        }
      } else {
        if (line == null) {
          suppliesIncomplete = true;
        } else {
          supplies += line;
        }
      }
      if (item.unitPrice != null) lineDiscounts += item.discount;
    }

    final incomplete = suppliesIncomplete || laborIncomplete;
    int? ht;
    int? vat;
    int? ttc;
    if (!incomplete) {
      ht = supplies + labor - globalDiscount;
      if (ht < 0) ht = 0;
      vat = vatEnabled ? (ht * vatRate / 100).round() : 0;
      ttc = ht + vat;
    }

    return InvoiceTotals(
      suppliesSubtotal: supplies,
      suppliesIncomplete: suppliesIncomplete,
      laborSubtotal: labor,
      laborIncomplete: laborIncomplete,
      hasLabor: hasLabor,
      lineDiscounts: lineDiscounts,
      globalDiscount: globalDiscount,
      vatEnabled: vatEnabled,
      vatRate: vatRate,
      vat: vat,
      totalHT: ht,
      totalTTC: ttc,
      amountPaid: amountPaid,
    );
  }
}

class Invoice {
  final int? id;
  final DocumentType type;
  final String number;
  final int year;
  final int seq;
  final DateTime date;
  final int? clientId;
  final String clientName;
  final String clientPhone;
  final String clientAddress;
  final String notes;
  final String paymentTerms;
  final InvoiceStatus status;
  final bool vatEnabled;
  final double vatRate;
  final int globalDiscount;
  final int amountPaid;
  final List<InvoiceItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Invoice({
    this.id,
    required this.type,
    required this.number,
    required this.year,
    required this.seq,
    required this.date,
    this.clientId,
    this.clientName = '',
    this.clientPhone = '',
    this.clientAddress = '',
    this.notes = '',
    this.paymentTerms = '',
    this.status = InvoiceStatus.brouillon,
    this.vatEnabled = false,
    this.vatRate = 0,
    this.globalDiscount = 0,
    this.amountPaid = 0,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  InvoiceTotals get totals => InvoiceTotals.compute(
        items: items,
        globalDiscount: globalDiscount,
        vatEnabled: vatEnabled,
        vatRate: vatRate,
        amountPaid: amountPaid,
      );

  List<InvoiceItem> get supplies => items.where((i) => !i.isLabor).toList();
  List<InvoiceItem> get labor => items.where((i) => i.isLabor).toList();

  Invoice copyWith({
    int? id,
    bool clearId = false,
    DocumentType? type,
    String? number,
    int? year,
    int? seq,
    DateTime? date,
    int? clientId,
    bool clearClient = false,
    String? clientName,
    String? clientPhone,
    String? clientAddress,
    String? notes,
    String? paymentTerms,
    InvoiceStatus? status,
    bool? vatEnabled,
    double? vatRate,
    int? globalDiscount,
    int? amountPaid,
    List<InvoiceItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Invoice(
        id: clearId ? null : (id ?? this.id),
        type: type ?? this.type,
        number: number ?? this.number,
        year: year ?? this.year,
        seq: seq ?? this.seq,
        date: date ?? this.date,
        clientId: clearClient ? null : (clientId ?? this.clientId),
        clientName: clientName ?? this.clientName,
        clientPhone: clientPhone ?? this.clientPhone,
        clientAddress: clientAddress ?? this.clientAddress,
        notes: notes ?? this.notes,
        paymentTerms: paymentTerms ?? this.paymentTerms,
        status: status ?? this.status,
        vatEnabled: vatEnabled ?? this.vatEnabled,
        vatRate: vatRate ?? this.vatRate,
        globalDiscount: globalDiscount ?? this.globalDiscount,
        amountPaid: amountPaid ?? this.amountPaid,
        items: items ?? this.items,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toMap() {
    final t = totals;
    return {
      'id': id,
      'type': type.name,
      'number': number,
      'year': year,
      'seq': seq,
      'date': date.toIso8601String(),
      'client_id': clientId,
      'client_name': clientName,
      'client_phone': clientPhone,
      'client_address': clientAddress,
      'notes': notes,
      'payment_terms': paymentTerms,
      'status': status.name,
      'vat_enabled': vatEnabled ? 1 : 0,
      'vat_rate': vatRate,
      'global_discount': globalDiscount,
      'amount_paid': amountPaid,
      // Total mémorisé pour les listes et statistiques (null = à préciser).
      'total': t.totalTTC,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Invoice.fromMap(Map<String, Object?> m,
          [List<InvoiceItem> items = const []]) =>
      Invoice(
        id: m['id'] as int?,
        type: DocumentType.values.firstWhere((e) => e.name == m['type'],
            orElse: () => DocumentType.facture),
        number: (m['number'] as String?) ?? '',
        year: (m['year'] as num?)?.toInt() ?? DateTime.now().year,
        seq: (m['seq'] as num?)?.toInt() ?? 0,
        date: DateTime.tryParse((m['date'] as String?) ?? '') ?? DateTime.now(),
        clientId: m['client_id'] as int?,
        clientName: (m['client_name'] as String?) ?? '',
        clientPhone: (m['client_phone'] as String?) ?? '',
        clientAddress: (m['client_address'] as String?) ?? '',
        notes: (m['notes'] as String?) ?? '',
        paymentTerms: (m['payment_terms'] as String?) ?? '',
        status: InvoiceStatus.values.firstWhere((e) => e.name == m['status'],
            orElse: () => InvoiceStatus.brouillon),
        vatEnabled: (m['vat_enabled'] as int? ?? 0) == 1,
        vatRate: (m['vat_rate'] as num?)?.toDouble() ?? 0,
        globalDiscount: (m['global_discount'] as num?)?.toInt() ?? 0,
        amountPaid: (m['amount_paid'] as num?)?.toInt() ?? 0,
        items: items,
        createdAt: DateTime.tryParse((m['created_at'] as String?) ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse((m['updated_at'] as String?) ?? '') ??
            DateTime.now(),
      );
}
