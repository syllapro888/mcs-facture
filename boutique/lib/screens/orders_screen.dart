import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/shop_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'account_screen.dart';

Color statusColor(OrderStatus s) => switch (s) {
      OrderStatus.attente => AppColors.yellow,
      OrderStatus.confirmee => AppColors.light,
      OrderStatus.livree => AppColors.green,
      OrderStatus.annulee => Colors.red.shade700,
    };

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    return Scaffold(
      appBar: AppBar(title: const Text('Mes commandes')),
      body: !s.signedIn
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.receipt_long_outlined,
                      size: 56, color: AppColors.light),
                  const SizedBox(height: 10),
                  const Text('Connectez-vous pour voir vos commandes.'),
                  const SizedBox(height: 12),
                  FilledButton(
                      onPressed: () => ensureSignedIn(context),
                      child: const Text('Se connecter')),
                ]),
              ),
            )
          : _OrderList(uid: s.uid),
    );
  }
}

class _OrderList extends StatefulWidget {
  const _OrderList({required this.uid});
  final String uid;

  @override
  State<_OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<_OrderList> {
  late Stream<List<ShopOrder>> _stream = ShopService.myOrders(widget.uid);

  @override
  void didUpdateWidget(covariant _OrderList old) {
    super.didUpdateWidget(old);
    if (old.uid != widget.uid) _stream = ShopService.myOrders(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ShopOrder>>(
      stream: _stream,
      builder: (_, snap) {
        if (snap.hasError) {
          return const Center(child: Text('Impossible de charger les commandes.'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return const Center(child: Text('Aucune commande pour le moment.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (_, i) => _OrderCard(order: list[i]),
        );
      },
    );
  }
}

class _OrderCard extends StatefulWidget {
  const _OrderCard({required this.order});
  final ShopOrder order;

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _busy = false;

  Future<void> _addProof() async {
    final img = await pickImageB64(context);
    if (img == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ShopService.addProof(widget.order.id, img);
      if (mounted) showMessage(context, 'Capture envoyée à MCS VISION');
    } catch (e) {
      if (mounted) showMessage(context, 'Envoi impossible : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la commande ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Non')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Oui, annuler')),
        ],
      ),
    );
    if (ok == true) await ShopService.cancelOrder(widget.order.id);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final color = statusColor(o.status);
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Commande ${o.shortId}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(o.status.label,
                  style: TextStyle(
                      color: o.status == OrderStatus.attente
                          ? const Color(0xFF8A6500)
                          : color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          Text(
              '${DateFormat('dd/MM/yyyy HH:mm').format(o.createdAt)} • ${o.payment.label}',
              style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 8),
          for (final l in o.items)
            Text('${l.qty} × ${l.name}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Row(children: [
            if (o.proof != null && o.proof!.isNotEmpty)
              TextButton.icon(
                onPressed: () => openImage(context, o.proof!),
                icon: const Icon(Icons.receipt, size: 18),
                label: const Text('Ma capture'),
              ),
            const Spacer(),
            Text(fcfa(o.total),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.dark)),
          ]),
          _Steps(status: o.status),
          if (o.needsProof) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  foregroundColor: AppColors.dark),
              onPressed: _busy ? null : _addProof,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Ajouter la capture du paiement'),
            ),
          ],
          if (o.status == OrderStatus.attente)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: _cancel, child: const Text('Annuler')),
            ),
        ]),
      ),
    );
  }
}

/// Suivi : envoyée → confirmée → livrée.
class _Steps extends StatelessWidget {
  const _Steps({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == OrderStatus.annulee) return const SizedBox.shrink();
    final step = switch (status) {
      OrderStatus.attente => 0,
      OrderStatus.confirmee => 1,
      _ => 2,
    };
    const labels = ['Envoyée', 'Confirmée', 'Livrée'];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(children: [
        for (var i = 0; i < 3; i++) ...[
          Column(children: [
            CircleAvatar(
              radius: 11,
              backgroundColor:
                  i <= step ? AppColors.green : const Color(0xFFE0E6EE),
              child: Icon(Icons.check,
                  size: 14, color: i <= step ? Colors.white : Colors.grey),
            ),
            const SizedBox(height: 2),
            Text(labels[i], style: const TextStyle(fontSize: 11)),
          ]),
          if (i < 2)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 14),
                color: i < step ? AppColors.green : const Color(0xFFE0E6EE),
              ),
            ),
        ],
      ]),
    );
  }
}
