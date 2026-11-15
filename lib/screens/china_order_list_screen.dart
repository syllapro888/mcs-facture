import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../models/china_order.dart';
import '../providers/china_order_provider.dart';
import '../utils/currency_formatter.dart';
import 'china_order_form_screen.dart';

/// Couleur de chaque étape.
Color chinaStatusColor(ChinaOrderStatus s) => switch (s) {
      ChinaOrderStatus.commandee => const Color(0xFF6B8BB5),
      ChinaOrderStatus.payee => const Color(0xFF3FA9F5),
      ChinaOrderStatus.expediee => const Color(0xFFF7B500),
      ChinaOrderStatus.arrivee => const Color(0xFF2E9E5B),
      ChinaOrderStatus.annulee => const Color(0xFFC62828),
    };

String yuan(num v) {
  final s = v == v.roundToDouble()
      ? CurrencyFormatter.number(v)
      : v.toStringAsFixed(2).replaceAll('.', ',');
  return '¥ $s';
}

class ChinaOrderListScreen extends StatefulWidget {
  const ChinaOrderListScreen({super.key});

  @override
  State<ChinaOrderListScreen> createState() => _ChinaOrderListScreenState();
}

class _ChinaOrderListScreenState extends State<ChinaOrderListScreen> {
  ChinaOrderStatus? _filter;
  String _query = '';

  void _open([ChinaOrder? o]) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => ChinaOrderFormScreen(order: o)));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChinaOrderProvider>();
    final q = _query.trim().toLowerCase();
    final list = provider.orders.where((o) {
      if (_filter != null && o.status != _filter) return false;
      if (q.isEmpty) return true;
      return o.supplier.toLowerCase().contains(q) ||
          o.reference.toLowerCase().contains(q) ||
          o.tracking.toLowerCase().contains(q) ||
          o.items.any((i) => i.name.toLowerCase().contains(q));
    }).toList();
    final pendingCount = provider.orders
        .where((o) =>
            o.status != ChinaOrderStatus.arrivee &&
            o.status != ChinaOrderStatus.annulee)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Commandes Chine')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        icon: const Icon(Icons.add),
        label: const Text('Commande'),
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.dark,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$pendingCount commande${pendingCount > 1 ? 's' : ''} en cours',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(CurrencyFormatter.fcfa(provider.pendingTotal),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const Text('pas encore arrivées',
                style: TextStyle(color: AppColors.yellow, fontSize: 11)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Fournisseur, article, n° de suivi…',
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: const Text('Toutes'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
              ),
              for (final s in ChinaOrderStatus.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(s.label),
                    selected: _filter == s,
                    onSelected: (_) => setState(() => _filter = s),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: provider.loading && provider.orders.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Aucune commande.\nAppuyez sur « Commande » pour suivre un achat en Chine.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                      itemCount: list.length,
                      itemBuilder: (_, i) =>
                          _OrderCard(order: list[i], onTap: () => _open(list[i])),
                    ),
        ),
      ]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});
  final ChinaOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final color = chinaStatusColor(o.status);
    final title = o.supplier.isEmpty ? 'Fournisseur non précisé' : o.supplier;
    final items = o.items.map((i) => i.name).where((n) => n.isNotEmpty).join(', ');
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(o.status.label,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 2),
            Text(
              [
                DateFormat('dd/MM/yyyy').format(o.date),
                if (o.reference.isNotEmpty) 'N° ${o.reference}',
                '${o.items.length} article${o.items.length > 1 ? 's' : ''}',
                if (o.photos.isNotEmpty)
                  '${o.photos.length} capture${o.photos.length > 1 ? 's' : ''}',
              ].join(' • '),
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            if (items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(items,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
              ),
            const SizedBox(height: 6),
            Row(children: [
              Text(yuan(o.totalYuan),
                  style: const TextStyle(
                      color: Color(0xFFC62828), fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(CurrencyFormatter.fcfa(o.totalFcfa),
                  style: const TextStyle(
                      color: AppColors.dark,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ]),
          ]),
        ),
      ),
    );
  }
}
