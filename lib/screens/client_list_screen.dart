import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../models/client.dart';
import '../providers/client_provider.dart';
import '../widgets/custom_text_field.dart';
import 'client_form_screen.dart';

/// Liste des clients. En mode sélection, un appui renvoie le client.
class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key, this.pickMode = false});
  final bool pickMode;

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  String _query = '';

  Future<void> _edit([Client? c]) async {
    final saved = await Navigator.push<Client>(context,
        MaterialPageRoute(builder: (_) => ClientFormScreen(client: c)));
    if (saved != null && widget.pickMode && mounted) {
      Navigator.pop(context, saved);
    }
  }

  Future<void> _delete(Client c) async {
    final ok = await confirm(context, 'Supprimer le client ?',
        '« ${c.name} » sera supprimé. Ses factures existantes sont conservées.',
        ok: 'Supprimer', danger: true);
    if (!ok || !mounted) return;
    await context.read<ClientProvider>().delete(c);
    if (mounted) showMessage(context, 'Client supprimé');
  }

  @override
  Widget build(BuildContext context) {
    final list = context.watch<ClientProvider>().search(_query);
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.pickMode ? 'Choisir un client' : 'Clients')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Client'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Rechercher (nom, téléphone)',
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('Aucun client.'))
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = list[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.dark,
                        foregroundColor: Colors.white,
                        child: Text(
                            c.name.isEmpty ? '?' : c.name[0].toUpperCase()),
                      ),
                      title: Text(c.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text([c.phone, c.address]
                          .where((e) => e.isNotEmpty)
                          .join(' • ')),
                      onTap: widget.pickMode
                          ? () => Navigator.pop(context, c)
                          : () => _edit(c),
                      trailing: widget.pickMode
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(c),
                            ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
