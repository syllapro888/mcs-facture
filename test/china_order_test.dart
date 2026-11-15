import 'package:flutter_test/flutter_test.dart';
import 'package:mcs_facture/models/china_order.dart';
import 'package:mcs_facture/models/product.dart';

void main() {
  final order = ChinaOrder(
    supplier: 'Shenzhen Tech',
    date: DateTime(2026, 11, 15),
    status: ChinaOrderStatus.payee,
    rate: 85,
    shipping: 30000,
    otherFees: 4000,
    items: const [
      ChinaItem(name: 'Caméra IP', quantity: 10, unitYuan: 120),
      ChinaItem(name: 'Câble RJ45', quantity: 5, unitYuan: 40),
    ],
    photos: const ['photos/a.jpg', 'photos/b.png'],
    createdAt: DateTime(2026, 11, 15),
  );

  test('totaux yuan et FCFA', () {
    expect(order.totalYuan, 1400);
    expect(order.goodsFcfa, 119000);
    expect(order.totalFcfa, 153000);
  });

  test('prix de revient : frais répartis selon la valeur', () {
    // Caméras : 1200 ¥ sur 1400 ¥ → 6/7 des 34 000 FCFA de frais.
    final cam = order.unitCost(order.items[0]);
    expect(cam, ((1200 * 85 + 34000 * 1200 / 1400) / 10).round());
    // La somme des prix de revient retombe sur le coût total.
    final sum = order.items
        .map((i) => order.unitCost(i) * i.quantity)
        .reduce((a, b) => a + b);
    expect((sum - order.totalFcfa).abs() <= 5, isTrue);
  });

  test('enregistrement et relecture', () {
    final back = ChinaOrder.fromMap(order.toMap()..['id'] = 7);
    expect(back.id, 7);
    expect(back.status, ChinaOrderStatus.payee);
    expect(back.items.length, 2);
    expect(back.items[1].name, 'Câble RJ45');
    expect(back.photos, ['photos/a.jpg', 'photos/b.png']);
    expect(back.totalFcfa, order.totalFcfa);
  });

  test('produit publié dans la boutique', () {
    final p = Product(name: 'Routeur', published: true, createdAt: DateTime(2026));
    expect(Product.fromMap(p.toMap()).published, isTrue);
    expect(Product.fromMap({'name': 'Ancien'}).published, isFalse);
    expect(p.copyWith(published: false).published, isFalse);
  });
}
