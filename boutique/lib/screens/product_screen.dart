import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String? _offersUid;
  Stream<List<PriceOffer>>? _offers;

  ShopProduct get p => widget.product;

  /// Offres du client connecté (flux gardé entre deux affichages).
  Stream<List<PriceOffer>> _offersOf(String uid) {
    if (_offers == null || _offersUid != uid) {
      _offersUid = uid;
      _offers = ShopService.myOffers(uid);
    }
    return _offers!;
  }

  void _addToCart({bool buyNow = false}) {
    context.read<Cart>().add(p, _qty);
    if (buyNow) {
      Shell.goTo(context, 1);
    } else {
      showMessage(context, 'Ajouté au panier ($_qty × ${p.name})');
    }
  }

  /// Le client propose son prix pour la quantité choisie.
  Future<void> _proposePrice() async {
    if (!await ensureSignedIn(context) || !mounted) return;
    final res = await showDialog<(int, String)>(
      context: context,
      builder: (_) => _OfferDialog(product: p, qty: _qty),
    );
    if (res == null || !mounted) return;
    final s = context.read<Session>();
    try {
      await ShopService.proposePrice(
        uid: s.uid,
        clientName: s.name,
        phone: s.phone,
        product: p,
        price: res.$1,
        qty: _qty,
        note: res.$2,
      );
      if (mounted) {
        showMessage(context,
            'Offre envoyée ! MCS VISION vous répond dans « Messages ».');
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Envoi impossible : $e', error: true);
    }
  }

  void _orderAtOffer(PriceOffer o) {
    final cart = context.read<Cart>();
    if (!cart.hasOffer(o.id)) cart.addOffer(p, o);
    Shell.goTo(context, 1);
  }

  Future<void> _answer(PriceOffer o, bool accept) async {
    try {
      await ShopService.answerCounter(o, accept: accept);
      if (mounted && accept) {
        showMessage(context, 'Prix accepté : vous pouvez commander.');
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Erreur : $e', error: true);
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
    final session = context.watch<Session>();
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
                  const SizedBox(height: 10),
                  if (session.signedIn)
                    StreamBuilder<List<PriceOffer>>(
                      key: ValueKey(session.uid),
                      stream: _offersOf(session.uid),
                      builder: (_, snap) {
                        final mine = (snap.data ?? const <PriceOffer>[])
                            .where((o) => o.pid == p.id)
                            .toList();
                        final current =
                            mine.where((o) => o.open).firstOrNull;
                        return _OfferPanel(
                          offer: current ?? mine.firstOrNull,
                          onPropose: _proposePrice,
                          onOrder: _orderAtOffer,
                          onAnswer: _answer,
                          onCancel: (o) => ShopService.cancelOffer(o),
                        );
                      },
                    )
                  else
                    _OfferPanel(onPropose: _proposePrice),
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

/// Discussion de prix : bouton « Proposer un prix » et suivi de l'offre.
class _OfferPanel extends StatelessWidget {
  const _OfferPanel({
    this.offer,
    required this.onPropose,
    this.onOrder,
    this.onAnswer,
    this.onCancel,
  });
  final PriceOffer? offer;
  final VoidCallback onPropose;
  final void Function(PriceOffer)? onOrder;
  final void Function(PriceOffer, bool accept)? onAnswer;
  final void Function(PriceOffer)? onCancel;

  @override
  Widget build(BuildContext context) {
    final o = offer;
    final proposeBtn = TextButton.icon(
      onPressed: onPropose,
      icon: const Icon(Icons.local_offer_outlined),
      label: Text(o == null || !o.open
          ? 'Proposer un prix'
          : 'Faire une nouvelle proposition'),
    );
    if (o == null || o.status == OfferStatus.annulee) {
      return Center(child: proposeBtn);
    }

    final (Color bg, IconData icon, String title, String detail) =
        switch (o.status) {
      OfferStatus.attente => (
          const Color(0xFFFFF4D6),
          Icons.hourglass_top,
          'Votre offre : ${fcfa(o.price)}',
          'En attente de la réponse de MCS VISION.'
        ),
      OfferStatus.contre => (
          const Color(0xFFE3F1FD),
          Icons.swap_horiz,
          'Contre-offre : ${fcfa(o.counter ?? o.price)}',
          'Vous aviez proposé ${fcfa(o.price)}. Acceptez-vous ce prix ?'
        ),
      OfferStatus.acceptee => (
          const Color(0xFFE6F6EC),
          Icons.check_circle,
          'Prix accepté : ${fcfa(o.price)}',
          'Commandez maintenant à ce prix '
              '(${o.qty} ${o.unit}${o.discountPercent > 0 ? ', -${o.discountPercent} %' : ''}).'
        ),
      OfferStatus.refusee => (
          const Color(0xFFFDECEC),
          Icons.cancel_outlined,
          'Offre de ${fcfa(o.price)} refusée',
          'Vous pouvez faire une autre proposition.'
        ),
      _ => (
          const Color(0xFFF1F5FA),
          Icons.receipt_long_outlined,
          'Prix négocié commandé : ${fcfa(o.price)}',
          'Suivez votre commande dans « Commandes ».'
        ),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, color: AppColors.dark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(detail, style: const TextStyle(color: Colors.black87)),
        const SizedBox(height: 6),
        if (o.status == OfferStatus.acceptee)
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white),
            onPressed: () => onOrder?.call(o),
            icon: const Icon(Icons.shopping_cart_checkout),
            label: Text('Commander à ${fcfa(o.price * o.qty)}'),
          ),
        if (o.status == OfferStatus.contre)
          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: () => onAnswer?.call(o, true),
                child: const Text('Accepter'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => onAnswer?.call(o, false),
                child: const Text('Refuser'),
              ),
            ),
          ]),
        Wrap(alignment: WrapAlignment.spaceBetween, children: [
          if (o.status == OfferStatus.attente)
            TextButton(
              onPressed: () => onCancel?.call(o),
              child: const Text('Annuler mon offre'),
            ),
          if (o.status != OfferStatus.attente) proposeBtn,
        ]),
      ]),
    );
  }
}

/// Saisie du prix proposé.
class _OfferDialog extends StatefulWidget {
  const _OfferDialog({required this.product, required this.qty});
  final ShopProduct product;
  final int qty;

  @override
  State<_OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<_OfferDialog> {
  final _form = GlobalKey<FormState>();
  final _price = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _value => int.tryParse(_price.text.replaceAll(RegExp(r'\D'), ''));

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final v = _value;
    return AlertDialog(
      title: const Text('Proposer un prix'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Prix affiché : ${fcfa(p.price)} / ${p.unit}'
                  '${widget.qty > 1 ? '  •  Quantité : ${widget.qty}' : ''}',
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 14),
              TextFormField(
                controller: _price,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Votre prix par ${p.unit}',
                  suffixText: 'FCFA',
                ),
                onChanged: (_) => setState(() {}),
                validator: (_) {
                  final x = _value;
                  if (x == null || x <= 0) return 'Indiquez un montant';
                  if (x >= p.price) {
                    return 'Doit être inférieur à ${fcfa(p.price)}';
                  }
                  return null;
                },
              ),
              if (v != null && v > 0 && widget.qty > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Total : ${fcfa(v * widget.qty)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _note,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    const InputDecoration(labelText: 'Message (facultatif)'),
              ),
              const SizedBox(height: 8),
              const Text(
                'MCS VISION peut accepter, refuser ou vous faire une '
                'contre-offre. Vous serez prévenu dans « Messages ».',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(context, (_value!, _note.text.trim()));
          },
          child: const Text('Envoyer l’offre'),
        ),
      ],
    );
  }
}
