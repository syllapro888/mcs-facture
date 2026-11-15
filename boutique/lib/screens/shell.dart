import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/shop_service.dart';
import '../theme.dart';
import 'account_screen.dart';
import 'cart_screen.dart';
import 'catalog_screen.dart';
import 'chat_screen.dart';
import 'orders_screen.dart';

/// Barre du bas : Boutique, Panier, Commandes, Messages, Compte.
class Shell extends StatefulWidget {
  const Shell({super.key});

  /// Onglet affiché (0 Boutique, 1 Panier, 2 Commandes, 3 Messages, 4 Compte).
  static final tab = ValueNotifier<int>(0);

  /// Revient à l'écran principal et ouvre un onglet.
  static void goTo(BuildContext context, int index) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    tab.value = index;
  }

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  @override
  void initState() {
    super.initState();
    Shell.tab.addListener(_changed);
  }

  @override
  void dispose() {
    Shell.tab.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final tab = Shell.tab.value;
    final session = context.watch<Session>();
    final cartCount = context.watch<Cart>().count;

    final pages = [
      const CatalogScreen(),
      const CartScreen(),
      const OrdersScreen(),
      // La discussion n'est ouverte (et marquée comme lue) qu'à l'affichage.
      tab == 3 ? const ChatScreen() : const SizedBox.shrink(),
      const AccountScreen(),
    ];

    Widget badge(Widget icon, int n) => n > 0
        ? Badge(
            label: Text('$n'),
            backgroundColor: AppColors.yellow,
            textColor: AppColors.dark,
            child: icon)
        : icon;

    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: StreamBuilder<int>(
        stream: session.signedIn ? ShopService.unread(session.uid) : null,
        builder: (_, snap) => NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => Shell.tab.value = i,
          indicatorColor: const Color(0xFFFFE7A3),
          destinations: [
            const NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront),
                label: 'Boutique'),
            NavigationDestination(
                icon: badge(const Icon(Icons.shopping_cart_outlined), cartCount),
                selectedIcon: badge(const Icon(Icons.shopping_cart), cartCount),
                label: 'Panier'),
            const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Commandes'),
            NavigationDestination(
                icon: badge(const Icon(Icons.chat_bubble_outline),
                    snap.data ?? 0),
                selectedIcon:
                    badge(const Icon(Icons.chat_bubble), snap.data ?? 0),
                label: 'Messages'),
            const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Compte'),
          ],
        ),
      ),
    );
  }
}
