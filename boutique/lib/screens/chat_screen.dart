import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/shop_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'account_screen.dart';

/// Discussion avec MCS VISION. Ouverte depuis un article, elle propose
/// d'envoyer l'article en premier message.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, this.product, this.draft});
  final ShopProduct? product;
  final String? draft;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white,
            backgroundImage: AssetImage('assets/logo/logo.png'),
          ),
          SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('MCS VISION', style: TextStyle(fontSize: 16)),
            Text('Répond en général rapidement',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ]),
        ]),
      ),
      body: !s.signedIn
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.chat_bubble_outline,
                      size: 56, color: AppColors.light),
                  const SizedBox(height: 10),
                  const Text('Connectez-vous pour discuter avec nous.'),
                  const SizedBox(height: 12),
                  FilledButton(
                      onPressed: () => ensureSignedIn(context),
                      child: const Text('Se connecter')),
                ]),
              ),
            )
          : _Conversation(
              key: ValueKey(s.uid), session: s, product: product, draft: draft),
    );
  }
}

class _Conversation extends StatefulWidget {
  const _Conversation(
      {super.key, required this.session, this.product, this.draft});
  final Session session;
  final ShopProduct? product;
  final String? draft;

  @override
  State<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<_Conversation> {
  late final _stream = ShopService.messages(widget.session.uid);
  late final _text = TextEditingController(text: widget.draft ?? '');
  final _scroll = ScrollController();
  ShopProduct? _product;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    ShopService.markRead(widget.session.uid).catchError((_) {});
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send({String? image}) async {
    final text = _text.text.trim();
    if (text.isEmpty && image == null && _product == null) return;
    setState(() => _sending = true);
    try {
      final s = widget.session;
      await ShopService.send(
        uid: s.uid,
        clientName: s.name,
        phone: s.phone,
        text: text,
        product: _product,
        image: image,
      );
      _text.clear();
      setState(() => _product = null);
    } catch (e) {
      if (mounted) showMessage(context, 'Envoi impossible : $e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendPhoto() async {
    final img = await pickImageB64(context);
    if (img != null) await _send(image: img);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: StreamBuilder<List<ChatMessage>>(
          stream: _stream,
          builder: (_, snap) {
            final list = snap.data ?? const <ChatMessage>[];
            if (snap.hasData) {
              // Messages lus dès qu'ils s'affichent.
              ShopService.markRead(widget.session.uid).catchError((_) {});
            }
            if (list.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Posez votre question : prix, disponibilité, installation…\n'
                    'MCS VISION vous répond ici.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              );
            }
            return ListView.builder(
              controller: _scroll,
              reverse: true,
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (_, i) => _Bubble(m: list[list.length - 1 - i]),
            );
          },
        ),
      ),
      if (_product != null)
        Container(
          color: const Color(0xFFFFF4D6),
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: B64Image(_product!.thumb, width: 40, height: 40),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('À propos de : ${_product!.name}',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _product = null)),
          ]),
        ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
          child: Row(children: [
            IconButton(
              tooltip: 'Envoyer une photo',
              onPressed: _sending ? null : _sendPhoto,
              icon: const Icon(Icons.photo_outlined),
            ),
            Expanded(
              child: TextField(
                controller: _text,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Votre message…',
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
    ]);
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.m});
  final ChatMessage m;

  @override
  Widget build(BuildContext context) {
    final mine = m.fromClient;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: mine ? AppColors.dark : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 2),
            bottomRight: Radius.circular(mine ? 2 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (m.productName != null)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mine ? Colors.white12 : const Color(0xFFF1F5FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🛒 ${m.productName}'
                  '${m.productPrice != null && m.productPrice! > 0 ? '\n${fcfa(m.productPrice!)}' : ''}',
                  style: TextStyle(
                      color: mine ? Colors.white : AppColors.dark,
                      fontWeight: FontWeight.w600),
                ),
              ),
            if (m.image != null)
              GestureDetector(
                onTap: () => openImage(context, m.image!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: B64Image(m.image, width: 200, height: 200),
                ),
              ),
            if (m.text.isNotEmpty)
              Text(m.text,
                  style: TextStyle(
                      color: mine ? Colors.white : Colors.black87,
                      fontSize: 15)),
            const SizedBox(height: 2),
            Text(DateFormat('HH:mm').format(m.createdAt),
                style: TextStyle(
                    fontSize: 10,
                    color: mine ? Colors.white60 : Colors.black45)),
          ],
        ),
      ),
    );
  }
}
