import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/shop_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'account_screen.dart';
import 'chat_screen.dart';
import 'shell.dart';

/// Ouvre WhatsApp avec un message déjà écrit.
Future<void> openWhatsApp(BuildContext context, String number, String text) async {
  final uri = Uri.parse(
      'https://wa.me/$number?text=${Uri.encodeComponent(text)}');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    showMessage(context, 'WhatsApp n’a pas pu s’ouvrir.', error: true);
  }
}

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key, required this.product});
  final ShopProduct product;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late final Future<String?> _photo = widget.product.hasPhoto
      ? ShopService.photo(widget.product.id)
      : Future.value(null);
  int _qty = 1;

  ShopProduct get p => widget.product;

  void _addToCart({bool buyNow = false}) {
    context.read<Cart>().add(p, _qty);
    if (buyNow) {
      Shell.goTo(context, 1);
    } else {
      showMessage(context, 'Ajouté au panier ($_qty × ${p.name})');
    }
  }

  Future<void> _chat({String? text}) async {
    if (!await ensureSignedIn(context) || !mounted) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ChatScreen(product: p, draft: text)));
  }

  @override
  Widget build(BuildContext context) {
    final canBuy = !p.isService && p.price > 0;
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 340,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              color: Colors.white,
              child: Hero(
                tag: 'p-${p.id}',
                child: FutureBuilder<String?>(
                  future: _photo,
                  builder: (_, snap) {
                    final data = snap.data ?? p.thumb;
                    return GestureDetector(
                      onTap: data == null ? null : () => openImage(context, data),
                      child: B64Image(data, fit: BoxFit.contain),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.category.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F1FD),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(p.category,
                        style: const TextStyle(
                            color: AppColors.dark,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 10),
                Text(p.name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(children: [
                  PriceTag(p.price, big: true),
                  if (p.price > 0)
                    Text('  / ${p.unit}',
                        style: const TextStyle(color: Colors.black54)),
                ]),
                if (p.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(p.description,
                      style: const TextStyle(fontSize: 15, height: 1.45)),
                ],
                const SizedBox(height: 22),
                if (canBuy) ...[
                  Row(children: [
                    const Text('Quantité',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    _QtyStepper(
                        value: _qty,
                        onChanged: (v) => setState(() => _qty = v)),
                  ]),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.yellow,
                        foregroundColor: AppColors.dark),
                    onPressed: () => _addToCart(buyNow: true),
                    icon: const Icon(Icons.flash_on),
                    label: const Text('Acheter maintenant'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _addToCart,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Ajouter au panier'),
                  ),
                ] else
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.yellow,
                        foregroundColor: AppColors.dark),
                    onPressed: () => _chat(
                        text: 'Bonjour, je souhaite un devis pour : ${p.name}.'),
                    icon: const Icon(Icons.request_quote_outlined),
                    label: const Text('Demander un devis'),
                  ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _chat(),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Discuter'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StreamBuilder<ShopInfo>(
                      stream: ShopService.info(),
                      builder: (_, snap) => OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.green),
                        onPressed: () => openWhatsApp(
                            context,
                            (snap.data ?? const ShopInfo()).whatsapp,
                            'Bonjour MCS VISION, je suis intéressé(e) par '
                            '« ${p.name} » (${fcfa(p.price)}).'),
                        icon: const Icon(Icons.phone_in_talk_outlined),
                        label: const Text('WhatsApp'),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD5DEEA)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              onPressed: value > 1 ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove)),
          Text('$value',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          IconButton(
              onPressed: () => onChanged(value + 1),
              icon: const Icon(Icons.add)),
        ]),
      );
}

/// Quantité réutilisée dans le panier.
class QtyStepper extends _QtyStepper {
  const QtyStepper({required super.value, required super.onChanged});
}
