import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';
import 'custom_text_field.dart';

/// Vérification automatique au démarrage (silencieuse si pas de nouveauté
/// ou pas d'Internet) et vérification manuelle depuis les Paramètres.
class UpdateUi {
  UpdateUi._();

  static bool _checkedThisLaunch = false;

  /// Au démarrage : n'affiche quelque chose que s'il y a une nouvelle version.
  static Future<void> checkSilently(BuildContext context) async {
    if (_checkedThisLaunch) return;
    _checkedThisLaunch = true;
    final result = await UpdateService.check();
    if (!context.mounted || !result.hasUpdate) return;
    await showUpdate(context, result);
  }

  /// Bouton « Vérifier les mises à jour ».
  static Future<void> checkManually(BuildContext context) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5)),
          SizedBox(width: 16),
          Text('Recherche de mises à jour…'),
        ]),
      ),
    );
    final result = await UpdateService.check();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (result.privateRepo) {
      // Dépôt privé : on ouvre directement la dernière version sur GitHub
      // (il suffit d'être connecté à son compte GitHub dans le navigateur).
      await _openLatestPage(context, result.currentVersion);
    } else if (result.error != null) {
      showMessage(context, result.error!, error: true);
    } else if (!result.hasUpdate) {
      showMessage(context,
          'Vous avez la dernière version (${result.currentVersion}).');
    } else {
      await showUpdate(context, result);
    }
  }

  static Future<void> showUpdate(
      BuildContext context, UpdateCheckResult result) async {
    final u = result.update!;
    final isIos = Platform.isIOS;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.system_update, size: 36),
        title: const Text('Nouvelle version disponible'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Version installée : ${result.currentVersion}\n'
                  'Nouvelle version : ${u.version}'),
              const SizedBox(height: 12),
              Text(
                isIos
                    ? 'Téléchargez le fichier .ipa sur un ordinateur et '
                        'installez-le avec Sideloadly. Vos factures sont conservées.'
                    : 'Téléchargez le fichier, ouvrez-le puis appuyez sur '
                        '« Mettre à jour ». Vos factures sont conservées.',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Plus tard')),
          FilledButton.icon(
            icon: const Icon(Icons.download),
            label: Text(isIos ? 'Ouvrir la page' : 'Télécharger'),
            onPressed: () async {
              Navigator.pop(ctx);
              final url = isIos ? u.pageUrl : (u.apkUrl ?? u.pageUrl);
              final ok = await _open(url);
              if (!ok && context.mounted) {
                showMessage(context, 'Impossible d’ouvrir le lien : $url',
                    error: true);
              }
            },
          ),
        ],
      ),
    );
  }

  static Future<void> _openLatestPage(
      BuildContext context, String current) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.system_update, size: 36),
        title: const Text('Mettre à jour'),
        content: Text(
          'Version installée : $current\n\n'
          'La dernière version va s’ouvrir sur GitHub. '
          '${Platform.isIOS ? 'Téléchargez le fichier .ipa et installez-le avec Sideloadly.' : 'Touchez le fichier .apk, puis « Mettre à jour ».'} '
          'Vos factures sont conservées.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Ouvrir'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (go != true) return;
    final ok = await _open(UpdateService.releasesPage);
    if (!ok && context.mounted) {
      showMessage(context, 'Impossible d’ouvrir ${UpdateService.releasesPage}',
          error: true);
    }
  }

  static Future<bool> _open(String url) async {
    try {
      return await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
