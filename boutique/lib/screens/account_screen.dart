import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/shop_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Demande la connexion si besoin. Renvoie true si le client est connecté.
Future<bool> ensureSignedIn(BuildContext context) async {
  if (context.read<Session>().signedIn) return true;
  final ok = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Connexion')),
        body: const AuthForm(popOnSuccess: true),
      ),
    ),
  );
  return ok == true;
}

/// Onglet « Compte ».
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    return Scaffold(
      appBar: AppBar(title: const Text('Mon compte')),
      body: !s.ready
          ? const Center(child: CircularProgressIndicator())
          : s.signedIn
              ? const _Profile()
              : const AuthForm(),
    );
  }
}

/// Connexion / inscription.
class AuthForm extends StatefulWidget {
  const AuthForm({super.key, this.popOnSuccess = false});
  final bool popOnSuccess;

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = true;
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final session = context.read<Session>();
    try {
      if (_register) {
        await session.register(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await session.login(_email.text.trim(), _password.text);
      }
      if (!mounted) return;
      showMessage(context, _register ? 'Bienvenue !' : 'Connecté');
      if (widget.popOnSuccess) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, authError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      showMessage(context, 'Tapez d’abord votre e-mail.', error: true);
      return;
    }
    try {
      await context.read<Session>().resetPassword(email);
      if (mounted) {
        showMessage(context, 'E-mail envoyé pour changer le mot de passe.');
      }
    } catch (e) {
      if (mounted) showMessage(context, authError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Image.asset('assets/logo/logo.png'),
            ),
          ),
          const SizedBox(height: 14),
          Text(_register ? 'Créer mon compte' : 'Se connecter',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Pour commander et discuter avec MCS VISION',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 18),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Inscription')),
              ButtonSegment(value: false, label: Text('Connexion')),
            ],
            selected: {_register},
            onSelectionChanged: (v) => setState(() => _register = v.first),
          ),
          const SizedBox(height: 16),
          if (_register) ...[
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Nom complet', prefixIcon: Icon(Icons.person)),
              validator: (v) =>
                  (v ?? '').trim().length < 2 ? 'Votre nom' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  hintText: '06 123 45 67',
                  prefixIcon: Icon(Icons.phone)),
              validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 6
                  ? 'Votre numéro'
                  : null,
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
                labelText: 'E-mail', prefixIcon: Icon(Icons.email_outlined)),
            validator: (v) =>
                (v ?? '').contains('@') ? null : 'Adresse e-mail',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: _hide,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
            validator: (v) =>
                (v ?? '').length < 6 ? '6 caractères minimum' : null,
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(_register ? 'Créer mon compte' : 'Se connecter'),
          ),
          if (!_register)
            TextButton(
                onPressed: _forgot,
                child: const Text('Mot de passe oublié ?')),
        ],
      ),
    );
  }
}

class _Profile extends StatefulWidget {
  const _Profile();

  @override
  State<_Profile> createState() => _ProfileState();
}

class _ProfileState extends State<_Profile> {
  late final Session s = context.read<Session>();
  late final _name = TextEditingController(text: s.name);
  late final _phone = TextEditingController(text: s.phone);
  late final _address = TextEditingController(text: s.address);
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await s.saveProfile(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          address: _address.text.trim());
      if (mounted) showMessage(context, 'Profil enregistré');
    } catch (e) {
      if (mounted) showMessage(context, 'Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.yellow,
            child: Text(
              s.name.isEmpty ? '?' : s.name[0].toUpperCase(),
              style: const TextStyle(
                  color: AppColors.dark,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name.isEmpty ? 'Client' : s.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text(s.email, style: const TextStyle(color: Colors.black54)),
            ]),
          ),
        ]),
        const SizedBox(height: 22),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nom complet'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Téléphone'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _address,
          maxLines: 2,
          decoration: const InputDecoration(
              labelText: 'Adresse de livraison',
              hintText: 'Quartier, rue, repère…'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Enregistrer'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => s.logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Se déconnecter'),
        ),
      ],
    );
  }
}
