import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/shop_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'product_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _products = ShopService.products();
  final _info = ShopService.info();
  String _query = '';
  String? _category;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<ShopProduct>>(
        stream: _products,
        builder: (context, snap) {
          final all = snap.data ?? const <ShopProduct>[];
          final categories = <String>{for (final p in all) p.category}
              .where((c) => c.isNotEmpty)
              .toList()
            ..sort();
          final q = _query.trim().toLowerCase();
          final list = all.where((p) {
            if (_category != null && p.category != _category) return false;
            if (q.isEmpty) return true;
            return p.name.toLowerCase().contains(q) ||
                p.description.toLowerCase().contains(q) ||
                p.category.toLowerCase().contains(q);
          }).toList();

          return CustomScrollView(slivers: [
            SliverToBoxAdapter(child: _Header(info: _info)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Rechercher un article…',
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ),
            if (categories.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      _chip('Tout', _category == null,
                          () => setState(() => _category = null)),
                      for (final c in categories)
                        _chip(c, _category == c,
                            () => setState(() => _category = c)),
                    ],
                  ),
                ),
              ),
            if (snap.hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _Empty(
                    icon: Icons.wifi_off,
                    text: 'Impossible de charger la boutique.\n'
                        'Vérifiez votre connexion Internet.'),
              )
            else if (!snap.hasData)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (list.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _Empty(
                    icon: Icons.inventory_2_outlined,
                    text: all.isEmpty
                        ? 'Les articles arrivent bientôt !'
                        : 'Aucun article trouvé.'),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.68,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => ProductCard(product: list[i]),
                    childCount: list.length,
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          selectedColor: const Color(0xFFFFE7A3),
          onSelected: (_) => onTap(),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.info});
  final Stream<ShopInfo> info;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return StreamBuilder<ShopInfo>(
      stream: info,
      builder: (_, snap) {
        final i = snap.data ?? const ShopInfo();
        return Container(
          padding: EdgeInsets.fromLTRB(16, top + 14, 16, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.dark, Color(0xFF16468F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: Row(children: [
            Container(
              width: 56,
              height: 56,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Image.asset('assets/logo/logo.png'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MCS Boutique',
                      style: TextStyle(
                          color: AppColors.yellow,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  Text(i.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  Text(i.slogan,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ]),
        );
      },
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});
  final ShopProduct product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => ProductScreen(product: p))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Hero(tag: 'p-${p.id}', child: B64Image(p.thumb)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Text(p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13, height: 1.2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 4, 6),
              child: Row(children: [
                Expanded(child: PriceTag(p.price)),
                if (!p.isService && p.price > 0)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Ajouter au panier',
                    style: IconButton.styleFrom(
                        backgroundColor: AppColors.yellow,
                        foregroundColor: AppColors.dark),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    onPressed: () {
                      context.read<Cart>().add(p);
                      showMessage(context, '« ${p.name} » ajouté au panier');
                    },
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: AppColors.light),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center),
          ]),
        ),
      );
}
