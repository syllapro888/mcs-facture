import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/shop_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'account_screen.dart';
import 'product_screen.dart';
import 'shell.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>();
    return Scaffold(
      appBar: AppBar(title: const Text('Mon panier')),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                color: Colors.white,
                child: Row(children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total',
                            style: TextStyle(color: Colors.black54)),
                        Text(fcfa(cart.total),
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.dark)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.yellow,
                        foregroundColor: AppColors.dark),
                    onPressed: () async {
                      if (!await ensureSignedIn(context) || !context.mounted) {
                        return;
                      }
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CheckoutScreen()));
                    },
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Commander'),
                  ),
                ]),
              ),
            ),
      body: cart.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.shopping_cart_outlined,
                    size: 60, color: AppColors.light),
                const SizedBox(height: 10),
                const Text('Votre panier est vide.'),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: () => Shell.tab.value = 0,
                    child: const Text('Voir les articles')),
              ]),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final l in cart.lines)
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: B64Image(l.product.thumb, width: 70, height: 70),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.product.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              if (l.negotiated)
                                Text.rich(TextSpan(children: [
                                  const TextSpan(
                                      text: '🤝 Prix négocié  ',
                                      style: TextStyle(
                                          color: AppColors.green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                  TextSpan(
                                      text: fcfa(l.product.price * l.qty),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black45,
                                          decoration:
                                              TextDecoration.lineThrough)),
                                ])),
                              Text(fcfa(l.total),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.dark)),
                            ],
                          ),
                        ),
                        Column(children: [
                          if (l.negotiated)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text('× ${l.qty}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            )
                          else
                            QtyStepper(
                                value: l.qty,
                                onChanged: (v) =>
                                    context.read<Cart>().setQty(l, v)),
                          TextButton(
                            onPressed: () => context.read<Cart>().setQty(l, 0),
                            child: const Text('Retirer'),
                          ),
                        ]),
                      ]),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Validation de la commande : coordonnées et paiement.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  late final Session s = context.read<Session>();
  late final _name = TextEditingController(text: s.name);
  late final _phone = TextEditingController(text: s.phone);
  late final _address = TextEditingController(text: s.address);
  final _note = TextEditingController();
  Payment _payment = Payment.momo;
  String? _proof;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickProof() async {
    final img = await pickImageB64(context);
    if (img != null) setState(() => _proof = img);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final cart = context.read<Cart>();
    setState(() => _busy = true);
    try {
      final name = _name.text.trim();
      final phone = _phone.text.trim();
      final address = _address.text.trim();
      await ShopService.placeOrder(
        uid: s.uid,
        clientName: name,
        phone: phone,
        email: s.email,
        address: address,
        note: _note.text.trim(),
        items: cart.toOrderLines(),
        payment: _payment,
        proof: _payment == Payment.momo ? _proof : null,
      );
      // Mémorise les coordonnées pour la prochaine fois.
      if (name != s.name || phone != s.phone || address != s.address) {
        await s.saveProfile(name: name, phone: phone, address: address);
      }
      cart.clear();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: AppColors.green, size: 48),
          title: const Text('Commande envoyée !'),
          content: Text(_payment == Payment.momo && _proof == null
              ? 'Pensez à ajouter la capture de votre paiement Mobile Money '
                  'dans « Commandes ». MCS VISION confirmera dès réception.'
              : 'MCS VISION va confirmer votre commande très vite. '
                  'Suivez-la dans l’onglet « Commandes ».'),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      if (mounted) Shell.goTo(context, 2);
    } catch (e) {
      if (mounted) showMessage(context, 'Envoi impossible : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>();
    return Scaffold(
      appBar: AppBar(title: const Text('Valider la commande')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.yellow,
                foregroundColor: AppColors.dark),
            onPressed: _busy || cart.isEmpty ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            label: Text('Envoyer la commande • ${fcfa(cart.total)}'),
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _Title('Livraison'),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nom complet'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Votre nom' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Votre numéro' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _address,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Adresse de livraison',
                  hintText: 'Quartier, rue, repère…'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Votre adresse' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _note,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Remarque (facultatif)'),
            ),
            const SizedBox(height: 20),
            const _Title('Paiement'),
            _PaymentTile(
              icon: Icons.phone_android,
              title: 'Mobile Money',
              subtitle: 'Envoyez l’argent puis ajoutez la capture',
              selected: _payment == Payment.momo,
              onTap: () => setState(() => _payment = Payment.momo),
            ),
            if (_payment == Payment.momo) _MomoBox(
              total: cart.total,
              proof: _proof,
              onPick: _pickProof,
              onRemove: () => setState(() => _proof = null),
            ),
            _PaymentTile(
              icon: Icons.local_shipping_outlined,
              title: 'Paiement à la réception',
              subtitle: 'Vous payez quand vous recevez l’article',
              selected: _payment == Payment.cash,
              onTap: () => setState(() => _payment = Payment.cash),
            ),
            const _PaymentTile(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Alipay',
              subtitle: 'Bientôt disponible',
              selected: false,
              onTap: null,
            ),
            const SizedBox(height: 20),
            const _Title('Récapitulatif'),
            for (final l in cart.toOrderLines())
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(
                      child: Text('${l.qty} × ${l.name}'
                          '${l.negotiated ? '  (prix négocié)' : ''}')),
                  Text(fcfa(l.total),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.dark)),
      );
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Card(
      elevation: 0,
      color: selected ? const Color(0xFFFFF4D6) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: selected ? AppColors.yellow : Colors.transparent, width: 2),
      ),
      child: ListTile(
        enabled: !disabled,
        onTap: onTap,
        leading: Icon(icon, color: disabled ? Colors.grey : AppColors.dark),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? AppColors.dark : Colors.grey),
      ),
    );
  }
}

/// Numéros Mobile Money et capture du paiement.
class _MomoBox extends StatelessWidget {
  const _MomoBox({
    required this.total,
    required this.proof,
    required this.onPick,
    required this.onRemove,
  });
  final int total;
  final String? proof;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: StreamBuilder<ShopInfo>(
        stream: ShopService.info(),
        builder: (_, snap) {
          final info = snap.data ?? const ShopInfo();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('1. Envoyez ${fcfa(total)} au numéro :',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              if (info.momo.isEmpty)
                Text(info.phones,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold))
              else
                for (final m in info.momo)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: '${m.operator} : '),
                      TextSpan(
                          text: m.number,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      if (m.holder.isNotEmpty) TextSpan(text: '  (${m.holder})'),
                    ])),
                  ),
              const SizedBox(height: 12),
              const Text('2. Ajoutez la capture d’écran du paiement :',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (proof == null)
                OutlinedButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Choisir la capture'),
                )
              else
                Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: B64Image(proof, width: 70, height: 90),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                      child: Text('Capture ajoutée ✅',
                          style: TextStyle(color: AppColors.green))),
                  TextButton(onPressed: onRemove, child: const Text('Changer')),
                ]),
              const SizedBox(height: 6),
              const Text(
                'La commande est validée dès que MCS VISION confirme la réception.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          );
        },
      ),
    );
  }
}
