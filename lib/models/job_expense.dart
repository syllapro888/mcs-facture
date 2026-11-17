import 'dart:convert';

/// Avancement d'un chantier.
enum JobStatus {
  enCours('En cours'),
  termine('Terminé');

  const JobStatus(this.label);
  final String label;

  static JobStatus parse(String? v) =>
      JobStatus.values.firstWhere((s) => s.name == v, orElse: () => JobStatus.enCours);
}

/// Une dépense : ce qui a été acheté, combien, à quel prix.
class ExpenseLine {
  final String label;
  final double quantity;
  final int unitPrice; // FCFA

  const ExpenseLine({required this.label, this.quantity = 1, this.unitPrice = 0});

  int get total => (quantity * unitPrice).round();

  Map<String, Object?> toJson() => {'label': label, 'qty': quantity, 'price': unitPrice};

  factory ExpenseLine.fromJson(Map<String, Object?> m) => ExpenseLine(
        label: (m['label'] as String?) ?? '',
        quantity: (m['qty'] as num?)?.toDouble() ?? 1,
        unitPrice: (m['price'] as num?)?.toInt() ?? 0,
      );
}

/// Note de dépenses d'un travail (installation, dépannage…) : les achats
/// faits pour un client, leur total et les photos justificatives.
class JobExpense {
  final int? id;
  final String title; // ex. Installation caméras
  final String owner; // propriétaire / client
  final String place; // lieu du chantier
  final DateTime date;
  final JobStatus status;
  final int billed; // montant du travail facturé au client (facultatif)
  final String notes;
  final List<ExpenseLine> lines;
  final List<String> photos; // chemins relatifs (reçus, matériel…)
  final DateTime createdAt;

  const JobExpense({
    this.id,
    this.title = '',
    this.owner = '',
    this.place = '',
    required this.date,
    this.status = JobStatus.enCours,
    this.billed = 0,
    this.notes = '',
    this.lines = const [],
    this.photos = const [],
    required this.createdAt,
  });

  int get total => lines.fold(0, (s, l) => s + l.total);

  /// Ce qui reste une fois les dépenses payées (si le montant facturé est connu).
  int get margin => billed - total;

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'owner': owner,
        'place': place,
        'date': date.toIso8601String(),
        'status': status.name,
        'billed': billed,
        'notes': notes,
        'lines': jsonEncode([for (final l in lines) l.toJson()]),
        'photos': jsonEncode(photos),
        'created_at': createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

  static List<Object?> _list(Object? raw) {
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final v = jsonDecode(raw);
      return v is List ? v : const [];
    } catch (_) {
      return const [];
    }
  }

  factory JobExpense.fromMap(Map<String, Object?> m) => JobExpense(
        id: m['id'] as int?,
        title: (m['title'] as String?) ?? '',
        owner: (m['owner'] as String?) ?? '',
        place: (m['place'] as String?) ?? '',
        date: DateTime.tryParse((m['date'] as String?) ?? '') ?? DateTime.now(),
        status: JobStatus.parse(m['status'] as String?),
        billed: (m['billed'] as num?)?.toInt() ?? 0,
        notes: (m['notes'] as String?) ?? '',
        lines: [
          for (final e in _list(m['lines']))
            if (e is Map) ExpenseLine.fromJson(e.cast<String, Object?>())
        ],
        photos: [
          for (final e in _list(m['photos']))
            if (e is String) e
        ],
        createdAt:
            DateTime.tryParse((m['created_at'] as String?) ?? '') ?? DateTime.now(),
      );
}
