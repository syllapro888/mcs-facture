import 'package:flutter_test/flutter_test.dart';
import 'package:mcs_boutique/models.dart';
import 'package:mcs_boutique/services/shop_service.dart';

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

  group('discussion de prix', () {
    const product = ShopProduct(id: 'p1', name: 'Caméra', price: 50000);
    final offer = PriceOffer(
      id: 'o1',
      uid: 'u1',
      pid: 'p1',
      productName: 'Caméra',
      listPrice: 50000,
      price: 42000,
      qty: 2,
      status: OfferStatus.acceptee,
      createdAt: DateTime(2026),
    );

    test('statuts des offres', () {
      expect(OfferStatus.parse('contre'), OfferStatus.contre);
      expect(OfferStatus.parse(null), OfferStatus.attente);
      expect(offer.open, isTrue);
      expect(offer.discountPercent, 16);
    });

    test('le panier applique le prix négocié', () {
      final cart = Cart()
        ..add(product)
        ..addOffer(product, offer);
      expect(cart.lines.length, 2);
      expect(cart.count, 3);
      expect(cart.total, 50000 + 2 * 42000);
      expect(cart.hasOffer('o1'), isTrue);

      final lines = cart.toOrderLines();
      final deal = lines.firstWhere((l) => l.negotiated);
      expect(deal.price, 42000);
      expect(deal.listPrice, 50000);
      expect(deal.toMap()['offerId'], 'o1');
      expect(OrderLine.fromMap(deal.toMap()).offerId, 'o1');
      expect(lines.firstWhere((l) => !l.negotiated).toMap()
          .containsKey('offerId'), isFalse);

      // La quantité d'une ligne négociée est fixée par l'offre.
      final dealLine = cart.lines.firstWhere((l) => l.negotiated);
      cart.setQty(dealLine, 5);
      expect(cart.lines.firstWhere((l) => l.negotiated).qty, 2);
      cart.setQty(dealLine, 0);
      expect(cart.hasOffer('o1'), isFalse);
    });
  });
}
