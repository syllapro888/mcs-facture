import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../providers/product_provider.dart';
import '../services/shop_cloud.dart';
import '../utils/currency_formatter.dart';
import '../widgets/custom_text_field.dart';

/// Adresse du site MCS Boutique (Firebase Hosting).
const shopWebUrl = 'https://mcs-vision.web.app';

DateTime _date(Object? v) => v is Timestamp ? v.toDate() : DateTime.now();
int _int(Object? v) => (v as num?)?.toInt() ?? 0;
String _str(Object? v) => (v as String?) ?? '';

const _statusLabels = {
  'attente': 'En attente',
  'confirmee': 'Confirmée',
  'livree': 'Livrée',
  'annulee': 'Annulée',
};

const _paymentLabels = {
  'momo': 'Mobile Money',
  'cash': 'Paiement à la réception',
  'alipay': 'Alipay',
};

Color _statusColor(String s) => switch (s) {
      'confirmee' => AppColors.light,
      'livree' => const Color(0xFF2E9E5B),
      'annulee' => const Color(0xFFC62828),
      _ => AppColors.yellow,
    };

void _openImage(BuildContext context, String b64) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black),
        body: InteractiveViewer(
          maxScale: 5,
          child: Center(child: Image.memory(base64Decode(b64))),
        ),
      ),
    ),
  );
}

Future<void> _launch(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showMessage(context, 'Impossible d’ouvrir.', error: true);
}

/// Boutique en ligne : commandes, messages et réglages de MCS Boutique.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<ShopCloud>();
    if (!ShopCloud.available) {
      return Scaffold(
        appBar: AppBar(title: const Text('Boutique en ligne')),
        body: const _Info(
          icon: Icons.cloud_off,
          text: 'La boutique en ligne n’est pas disponible sur cet appareil.\n'
              'Utilisez MCS Facture sur Android ou la version web, avec Internet.',
        ),
      );
    }
    if (!cloud.signedIn) return const _LoginScreen();
    if (cloud.checking) {
      return Scaffold(
        appBar: AppBar(title: const Text('Boutique en ligne')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!cloud.isOwner) {
      return Scaffold(
        appBar: AppBar(title: const Text('Boutique en ligne')),
        body: _Info(
          icon: Icons.lock_outline,
          text: cloud.error ??
              'Ce compte (${cloud.user?.email}) n’est pas celui de MCS VISION.\n'
                  'Connectez-vous avec le compte propriétaire.',
          action: OutlinedButton(
              onPressed: cloud.logout, child: const Text('Se déconnecter')),
        ),
      );
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Boutique en ligne'),
          bottom: TabBar(
            labelColor: AppColors.yellow,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppColors.yellow,
            tabs: [
              Tab(
                  child: Badge(
                      isLabelVisible: cloud.pendingOrders > 0,
                      label: Text('${cloud.pendingOrders}'),
                      child: const Text('Commandes'))),
              Tab(
                  child: Badge(
                      isLabelVisible: cloud.unreadChats > 0,
                      label: Text('${cloud.unreadChats}'),
                      child: const Text('Messages'))),
              const Tab(text: 'Réglages'),
            ],
          ),
        ),
        body: const TabBarView(children: [
          _OrdersTab(),
          _ChatsTab(),
          _SettingsTab(),
        ]),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: AppColors.light),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 14), action!],
          ]),
        ),
      );
}

// ======================= Connexion =======================

class _LoginScreen extends StatefulWidget {
  const _LoginScreen();

  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pw = _password.text;
    if (!email.contains('@') || pw.length < 6) {
      showMessage(context, 'E-mail valide et mot de passe de 6 caractères minimum.',
          error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final cloud = context.read<ShopCloud>();
      _register
          ? await cloud.register(email, pw)
          : await cloud.login(email, pw);
    } catch (e) {
      if (mounted) showMessage(context, cloudAuthError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Boutique en ligne')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.storefront, size: 64, color: AppColors.dark),
          const SizedBox(height: 10),
          const Text('Compte MCS VISION',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Connectez-vous pour recevoir les commandes et les messages de '
            'MCS Boutique. Le premier compte connecté devient le compte '
            'propriétaire de la boutique.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 18),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Se connecter')),
              ButtonSegment(value: true, label: Text('Créer le compte')),
            ],
            selected: {_register},
            onSelectionChanged: (v) => setState(() => _register = v.first),
          ),
          const SizedBox(height: 14),
          CustomTextField(
              controller: _email,
              label: 'E-mail',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: 'Mot de passe', prefixIcon: Icon(Icons.lock_outline)),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(_register ? 'Créer le compte' : 'Se connecter'),
          ),
          if (!_register)
            TextButton(
              onPressed: () async {
                final email = _email.text.trim();
                if (!email.contains('@')) {
                  showMessage(context, 'Tapez d’abord votre e-mail.', error: true);
                  return;
                }
                try {
                  await context.read<ShopCloud>().resetPassword(email);
                  if (context.mounted) {
                    showMessage(context, 'E-mail de réinitialisation envoyé.');
                  }
                } catch (e) {
                  if (context.mounted) {
                    showMessage(context, cloudAuthError(e), error: true);
                  }
                }
              },
              child: const Text('Mot de passe oublié ?'),
            ),
        ],
      ),
    );
  }
}

// ======================= Commandes =======================

class _OrdersTab extends StatefulWidget {
  const _OrdersTab();

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab>
    with AutomaticKeepAliveClientMixin {
  late final _stream = ShopCloud.instance.orders();
  String? _filter = 'attente';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          children: [
            for (final e in {null: 'Toutes', ..._statusLabels}.entries)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(e.value),
                  selected: _filter == e.key,
                  onSelected: (_) => setState(() => _filter = e.key),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: StreamBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
          stream: _stream,
          builder: (_, snap) {
            if (snap.hasError) {
              return _Info(
                  icon: Icons.error_outline,
                  text: 'Erreur : ${snap.error}');
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = snap.data!
                .where((d) => _filter == null || d.data()?['status'] == _filter)
                .toList();
            if (list.isEmpty) {
              return const _Info(
                  icon: Icons.receipt_long_outlined,
                  text: 'Aucune commande ici.');
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              itemCount: list.length,
              itemBuilder: (_, i) => _OrderCard(doc: list[i]),
            );
          },
        ),
      ),
    ]);
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.doc});
  final DocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final m = doc.data() ?? const {};
    final status = _str(m['status']);
    final items = (m['items'] as List?) ?? const [];
    final hasProof = _str(m['proof']).isNotEmpty;
    final color = _statusColor(status);
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => _OrderScreen(id: doc.id))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(_str(m['clientName']).isEmpty
                    ? 'Client'
                    : _str(m['clientName']),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(_statusLabels[status] ?? status,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
            Text(
              '${DateFormat('dd/MM HH:mm').format(_date(m['createdAt']))} • '
              '${_paymentLabels[m['payment']] ?? ''}'
              '${m['payment'] == 'momo' ? (hasProof ? ' • capture ✅' : ' • sans capture') : ''}',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              items
                  .whereType<Map>()
                  .map((i) => '${i['qty']} × ${i['name']}')
                  .join(', '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(CurrencyFormatter.fcfa(_int(m['total'])),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.dark,
                      fontSize: 15)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _OrderScreen extends StatelessWidget {
  const _OrderScreen({required this.id});
  final String id;

  Future<void> _set(BuildContext context, String status, String msg) async {
    try {
      await ShopCloud.instance.setOrderStatus(id, status);
      if (context.mounted) showMessage(context, msg);
    } catch (e) {
      if (context.mounted) showMessage(context, 'Erreur : $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').doc(id).snapshots(),
      builder: (_, snap) {
        final m = snap.data?.data();
        return Scaffold(
          appBar: AppBar(
              title: Text('Commande ${id.substring(0, 6).toUpperCase()}')),
          body: m == null
              ? const Center(child: CircularProgressIndicator())
              : _body(context, m),
        );
      },
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> m) {
    final status = _str(m['status']);
    final items = ((m['items'] as List?) ?? const []).whereType<Map>().toList();
    final proof = _str(m['proof']);
    final phone = _str(m['phone']);
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final wa = digits.length <= 9 ? '242$digits' : digits;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_str(m['clientName']),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              if (phone.isNotEmpty) Text('📞 $phone'),
              if (_str(m['email']).isNotEmpty) Text('✉️ ${_str(m['email'])}'),
              if (_str(m['address']).isNotEmpty)
                Text('📍 ${_str(m['address'])}'),
              if (_str(m['note']).isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Remarque : ${_str(m['note'])}',
                    style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 8),
              Row(children: [
                if (phone.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _launch(context, 'tel:$phone'),
                    icon: const Icon(Icons.call),
                    label: const Text('Appeler'),
                  ),
                const SizedBox(width: 8),
                if (digits.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _launch(context, 'https://wa.me/$wa'),
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp'),
                  ),
              ]),
            ]),
          ),
        ),
        Card(
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text('${i['qty']} × ${i['name']}')),
                    Text(CurrencyFormatter.fcfa(_int(i['price']) * _int(i['qty']))),
                  ]),
                ),
              const Divider(),
              Row(children: [
                Text(_paymentLabels[m['payment']] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(CurrencyFormatter.fcfa(_int(m['total'])),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark)),
              ]),
            ]),
          ),
        ),
        if (m['payment'] == 'momo')
          Card(
            elevation: 0,
            color: proof.isEmpty ? const Color(0xFFFFF4D6) : Colors.white,
            child: ListTile(
              leading: proof.isEmpty
                  ? const Icon(Icons.hourglass_empty)
                  : GestureDetector(
                      onTap: () => _openImage(context, proof),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(base64Decode(proof),
                            width: 48, height: 48, fit: BoxFit.cover),
                      ),
                    ),
              title: Text(proof.isEmpty
                  ? 'Capture Mobile Money pas encore envoyée'
                  : 'Capture du paiement'),
              subtitle: proof.isEmpty
                  ? null
                  : const Text('Vérifiez la réception de l’argent avant de confirmer'),
              onTap: proof.isEmpty ? null : () => _openImage(context, proof),
            ),
          ),
        const SizedBox(height: 12),
        if (status == 'attente') ...[
          FilledButton.icon(
            onPressed: () => _set(context, 'confirmee', 'Commande confirmée'),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(m['payment'] == 'momo'
                ? 'Paiement reçu : confirmer'
                : 'Confirmer la commande'),
          ),
          const SizedBox(height: 8),
        ],
        if (status == 'confirmee') ...[
          FilledButton.icon(
            onPressed: () => _set(context, 'livree', 'Commande livrée'),
            icon: const Icon(Icons.local_shipping),
            label: const Text('Marquer comme livrée'),
          ),
          const SizedBox(height: 8),
        ],
        if (status != 'annulee' && status != 'livree')
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
            onPressed: () async {
              final ok = await confirm(context, 'Annuler la commande ?',
                  'Le client verra la commande comme annulée.',
                  ok: 'Annuler la commande', danger: true);
              if (ok && context.mounted) {
                await _set(context, 'annulee', 'Commande annulée');
              }
            },
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Annuler'),
          ),
        if (_str(m['uid']).isNotEmpty) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ShopChatScreen(
                        uid: _str(m['uid']), name: _str(m['clientName'])))),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Écrire au client'),
          ),
        ],
      ],
    );
  }
}

// ======================= Messages =======================

class _ChatsTab extends StatefulWidget {
  const _ChatsTab();

  @override
  State<_ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<_ChatsTab>
    with AutomaticKeepAliveClientMixin {
  late final _stream = ShopCloud.instance.chats();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
      stream: _stream,
      builder: (_, snap) {
        if (snap.hasError) {
          return _Info(icon: Icons.error_outline, text: 'Erreur : ${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return const _Info(
              icon: Icons.chat_bubble_outline,
              text: 'Aucun message pour le moment.');
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (_, i) {
            final m = list[i].data() ?? const {};
            final name = _str(m['clientName']).isEmpty ? 'Client' : _str(m['clientName']);
            final unread = _int(m['unreadOwner']);
            return ListTile(
              tileColor: Colors.white,
              leading: CircleAvatar(
                backgroundColor: AppColors.yellow,
                child: Text(name[0].toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.dark, fontWeight: FontWeight.bold)),
              ),
              title: Text(name,
                  style: TextStyle(
                      fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w500)),
              subtitle: Text(
                  '${m['lastFrom'] == 'owner' ? 'Vous : ' : ''}${_str(m['lastText'])}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(DateFormat('dd/MM HH:mm').format(_date(m['lastAt'])),
                      style: const TextStyle(fontSize: 11)),
                  if (unread > 0)
                    Badge(
                        label: Text('$unread'),
                        backgroundColor: AppColors.yellow,
                        textColor: AppColors.dark),
                ],
              ),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ShopChatScreen(uid: list[i].id, name: name))),
            );
          },
        );
      },
    );
  }
}

class ShopChatScreen extends StatefulWidget {
  const ShopChatScreen({super.key, required this.uid, required this.name});
  final String uid;
  final String name;

  @override
  State<ShopChatScreen> createState() => _ShopChatScreenState();
}

class _ShopChatScreenState extends State<ShopChatScreen> {
  late final _stream = ShopCloud.instance.messages(widget.uid);
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send({String? image}) async {
    final text = _text.text.trim();
    if (text.isEmpty && image == null) return;
    setState(() => _sending = true);
    try {
      await ShopCloud.instance.sendMessage(widget.uid, text: text, image: image);
      _text.clear();
    } catch (e) {
      if (mounted) showMessage(context, 'Envoi impossible : $e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _photo() async {
    try {
      final x = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1000,
          maxHeight: 1400,
          imageQuality: 60);
      if (x == null) return;
      await _send(image: base64Encode(await x.readAsBytes()));
    } catch (e) {
      if (mounted) showMessage(context, 'Photo impossible : $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
            stream: _stream,
            builder: (_, snap) {
              final list = snap.data ?? const [];
              if (snap.hasData) {
                ShopCloud.instance.markChatRead(widget.uid).catchError((_) {});
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (_, i) =>
                    _Bubble(m: list[list.length - 1 - i].data() ?? const {}),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
            child: Row(children: [
              IconButton(
                  onPressed: _sending ? null : _photo,
                  icon: const Icon(Icons.photo_outlined)),
              Expanded(
                child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Répondre…',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                style: IconButton.styleFrom(
                    backgroundColor: AppColors.yellow,
                    foregroundColor: AppColors.dark),
                onPressed: _sending ? null : () => _send(),
                icon: const Icon(Icons.send),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.m});
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    final mine = m['from'] == 'owner';
    final text = _str(m['text']);
    final image = _str(m['image']);
    final product = _str(m['productName']);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: mine ? AppColors.dark : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (product.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4D6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                    '🛒 $product${_int(m['productPrice']) > 0 ? '\n${CurrencyFormatter.fcfa(_int(m['productPrice']))}' : ''}',
                    style: const TextStyle(
                        color: AppColors.dark, fontWeight: FontWeight.w600)),
              ),
            if (image.isNotEmpty)
              GestureDetector(
                onTap: () => _openImage(context, image),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(base64Decode(image),
                      width: 200, height: 200, fit: BoxFit.cover),
                ),
              ),
            if (text.isNotEmpty)
              Text(text,
                  style: TextStyle(
                      color: mine ? Colors.white : Colors.black87,
                      fontSize: 15)),
            Text(DateFormat('HH:mm').format(_date(m['createdAt'])),
                style: TextStyle(
                    fontSize: 10,
                    color: mine ? Colors.white60 : Colors.black45)),
          ],
        ),
      ),
    );
  }
}

// ======================= Réglages =======================

class _SettingsTab extends StatefulWidget {
  const _SettingsTab();

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab>
    with AutomaticKeepAliveClientMixin {
  late final _info = ShopCloud.instance.info();

  @override
  bool get wantKeepAlive => true;

  Future<void> _editMomo(List<Map<String, String>> current) async {
    final rows = [
      for (final m in current)
        (
          TextEditingController(text: m['operator'] ?? ''),
          TextEditingController(text: m['number'] ?? ''),
          TextEditingController(text: m['name'] ?? ''),
        )
    ];
    if (rows.isEmpty) {
      rows.add((
        TextEditingController(text: 'MTN Mobile Money'),
        TextEditingController(),
        TextEditingController(text: 'MCS VISION'),
      ));
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Numéros Mobile Money'),
          content: SizedBox(
            width: 420,
            child: ListView(shrinkWrap: true, children: [
              for (final r in rows) ...[
                TextField(
                    controller: r.$1,
                    decoration: const InputDecoration(
                        labelText: 'Opérateur', isDense: true)),
                const SizedBox(height: 6),
                TextField(
                    controller: r.$2,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Numéro', isDense: true)),
                const SizedBox(height: 6),
                TextField(
                    controller: r.$3,
                    decoration: const InputDecoration(
                        labelText: 'Nom du titulaire', isDense: true)),
                const Divider(height: 24),
              ],
              TextButton.icon(
                onPressed: () => setD(() => rows.add((
                      TextEditingController(text: 'Airtel Money'),
                      TextEditingController(),
                      TextEditingController(text: 'MCS VISION'),
                    ))),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un numéro'),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (ok == true) {
      final list = [
        for (final r in rows)
          if (r.$2.text.trim().isNotEmpty)
            {
              'operator': r.$1.text.trim(),
              'number': r.$2.text.trim(),
              'name': r.$3.text.trim(),
            }
      ];
      try {
        await ShopCloud.instance.saveMomo(list);
        if (mounted) showMessage(context, 'Numéros enregistrés');
      } catch (e) {
        if (mounted) showMessage(context, 'Erreur : $e', error: true);
      }
    }
    for (final r in rows) {
      r.$1.dispose();
      r.$2.dispose();
      r.$3.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cloud = context.watch<ShopCloud>();
    final products = context.watch<ProductProvider>();
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Articles en ligne',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text('${products.publishedCount} article(s) publiés dans le catalogue.'),
              const SizedBox(height: 6),
              if (cloud.syncing)
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  LinearProgressIndicator(
                      value: cloud.syncTotal == 0
                          ? null
                          : cloud.syncDone / cloud.syncTotal),
                  const SizedBox(height: 4),
                  Text('Envoi ${cloud.syncDone} / ${cloud.syncTotal}…'),
                ])
              else if (cloud.syncError != null)
                Text('Erreur d’envoi : ${cloud.syncError}',
                    style: const TextStyle(color: Color(0xFFC62828)))
              else if (cloud.lastSync != null)
                Text(
                    'À jour (${DateFormat('HH:mm').format(cloud.lastSync!)}) ✅',
                    style: const TextStyle(color: Color(0xFF2E9E5B))),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                  onPressed: cloud.syncing
                      ? null
                      : () => cloud.syncProducts(products.products),
                  icon: const Icon(Icons.sync),
                  label: const Text('Synchroniser'),
                ),
                OutlinedButton(
                  onPressed: cloud.syncing
                      ? null
                      : () => cloud.syncProducts(products.products, force: true),
                  child: const Text('Tout renvoyer'),
                ),
              ]),
              const SizedBox(height: 6),
              const Text(
                'Les changements sont envoyés automatiquement. Pour publier un '
                'article : Catalogue → ⋮ → « Publier dans MCS Boutique ».',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ]),
          ),
        ),
        StreamBuilder<Map<String, dynamic>>(
          stream: _info,
          builder: (_, snap) {
            final momo = [
              for (final e in (snap.data?['momo'] as List?) ?? const [])
                if (e is Map)
                  {
                    'operator': '${e['operator'] ?? ''}',
                    'number': '${e['number'] ?? ''}',
                    'name': '${e['name'] ?? ''}',
                  }
            ];
            return Card(
              elevation: 0,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mobile Money',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      if (momo.isEmpty)
                        const Text(
                            'Aucun numéro : les clients verront vos téléphones.')
                      else
                        for (final m in momo)
                          Text('${m['operator']} : ${m['number']} (${m['name']})'),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _editMomo(momo),
                        icon: const Icon(Icons.edit),
                        label: const Text('Modifier les numéros'),
                      ),
                    ]),
              ),
            );
          },
        ),
        Card(
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Lien de la boutique',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const SelectableText(shopWebUrl),
              const SelectableText('$shopWebUrl/download/MCS-Boutique.apk',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              const Text(
                'Partagez ce lien : sur iPhone, ouvrir dans Safari → Partager → '
                '« Sur l’écran d’accueil ». Sur Android, télécharger l’APK.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _launch(context, shopWebUrl),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Ouvrir la boutique'),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text('Connecté : ${cloud.user?.email ?? ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54)),
        TextButton(onPressed: cloud.logout, child: const Text('Se déconnecter')),
      ],
    );
  }
}
