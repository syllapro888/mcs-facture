import 'package:flutter_test/flutter_test.dart';
import 'package:mcs_facture/models/job_expense.dart';
import 'package:mcs_facture/models/product.dart';

void main() {
  final job = JobExpense(
    title: 'Installation caméras',
    owner: 'M. Mabiala',
    place: 'Moungali',
    date: DateTime(2026, 11, 17),
    billed: 150000,
    lines: const [
      ExpenseLine(label: 'Câble 50 m', quantity: 2, unitPrice: 12500),
      ExpenseLine(label: 'Transport', unitPrice: 3000),
    ],
    photos: const ['photos/recu.jpg'],
    createdAt: DateTime(2026, 11, 17),
  );

  test('total et reste', () {
    expect(job.total, 28000);
    expect(job.margin, 122000);
  });

  test('enregistrement et relecture', () {
    final back = JobExpense.fromMap(job.toMap()..['id'] = 3);
    expect(back.id, 3);
    expect(back.owner, 'M. Mabiala');
    expect(back.lines.length, 2);
    expect(back.lines.first.quantity, 2);
    expect(back.photos, ['photos/recu.jpg']);
    expect(back.status, JobStatus.enCours);
    expect(back.total, 28000);
  });

  test('catalogue boutique (privé)', () {
    final p = Product(name: 'Clé USB', shopOnly: true, createdAt: DateTime(2026));
    expect(Product.fromMap(p.toMap()).shopOnly, isTrue);
    expect(Product.fromMap({'name': 'Ancien'}).shopOnly, isFalse);
  });
}
