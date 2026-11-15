import 'package:flutter_test/flutter_test.dart';
import 'package:mcs_boutique/models.dart';

void main() {
  test('montants en FCFA', () {
    expect(fcfa(125000), '125 000 FCFA');
    expect(fcfa(0), '0 FCFA');
    expect(fcfa(1500), '1 500 FCFA');
  });

  test('coordonnées de la boutique par défaut', () {
    final i = ShopInfo.fromMap({'whatsapp': '+242 06 998 16 16', 'name': ''});
    expect(i.whatsapp, '242069981616');
    expect(i.name, 'MCS VISION');
    expect(ShopInfo.fromMap({
      'momo': [
        {'operator': 'MTN', 'number': '06 000 00 00', 'name': 'MCS'}
      ]
    }).momo.single.operator, 'MTN');
  });

  test('statuts et paiements', () {
    expect(OrderStatus.parse('livree'), OrderStatus.livree);
    expect(OrderStatus.parse(null), OrderStatus.attente);
    expect(Payment.parse('momo'), Payment.momo);
    expect(const OrderLine(pid: 'p1', name: 'X', price: 1000, qty: 3).total,
        3000);
  });
}
