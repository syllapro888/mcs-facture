import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/client.dart';
import '../providers/client_provider.dart';
import '../widgets/custom_text_field.dart';

/// Création / modification d'un client. Renvoie le client enregistré.
class ClientFormScreen extends StatefulWidget {
  const ClientFormScreen({super.key, this.client});
  final Client? client;

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _phone, _address, _email, _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _name = TextEditingController(text: c?.name ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _address = TextEditingController(text: c?.address ?? '');
    _email = TextEditingController(text: c?.email ?? '');
    _notes = TextEditingController(text: c?.notes ?? '');
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _email, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final saved = await context.read<ClientProvider>().save(Client(
            id: widget.client?.id,
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            address: _address.text.trim(),
            email: _email.text.trim(),
            notes: _notes.text.trim(),
          ));
      if (!mounted) return;
      showMessage(context, 'Client enregistré');
      Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) showMessage(context, 'Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(
              widget.client == null ? 'Nouveau client' : 'Modifier le client')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CustomTextField(
                controller: _name,
                label: 'Nom ou entreprise',
                icon: Icons.person_outline,
                required: true),
            CustomTextField(
                controller: _phone,
                label: 'Téléphone',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            CustomTextField(
                controller: _address,
                label: 'Adresse',
                icon: Icons.place_outlined,
                maxLines: 2),
            CustomTextField(
              controller: _email,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                    ? null
                    : 'Email invalide';
              },
            ),
            CustomTextField(
                controller: _notes,
                label: 'Notes',
                icon: Icons.notes,
                maxLines: 3),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
