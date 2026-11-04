import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Nouvelle version publiée sur GitHub (page « Releases »).
class UpdateInfo {
  final String version; // ex. 1.0.7
  final String notes;
  final String pageUrl; // page de la version
  final String? apkUrl; // fichier Android
  final String? ipaUrl; // fichier iPhone

  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.pageUrl,
    this.apkUrl,
    this.ipaUrl,
  });
}

class UpdateCheckResult {
  final String currentVersion;
  final UpdateInfo? update; // null = déjà à jour
  final String? error; // message compréhensible si la vérification échoue
  final bool privateRepo; // dépôt privé : on passe par la page GitHub

  const UpdateCheckResult(this.currentVersion,
      {this.update, this.error, this.privateRepo = false});

  bool get hasUpdate => update != null;
}

/// Vérifie s'il existe une version plus récente que celle installée.
class UpdateService {
  UpdateService._();

  static const owner = 'syllapro888';
  static const repo = 'mcs-facture';
  static const releasesPage = 'https://github.com/$owner/$repo/releases/latest';

  static Future<String> currentVersion() async {
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return '0.0.0';
    }
  }

  /// "v1.0.12" -> [1, 0, 12]
  static List<int> parse(String v) {
    final clean = v.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
    return clean
        .split('.')
        .map((e) => int.tryParse(RegExp(r'\d+').stringMatch(e) ?? '') ?? 0)
        .toList();
  }

  /// true si [remote] est plus récente que [local].
  static bool isNewer(String remote, String local) {
    final r = parse(remote);
    final l = parse(local);
    for (var i = 0; i < 3; i++) {
      final a = i < r.length ? r[i] : 0;
      final b = i < l.length ? l[i] : 0;
      if (a != b) return a > b;
    }
    return false;
  }

  static Future<UpdateCheckResult> check() async {
    final current = await currentVersion();
    // La version web se met à jour toute seule.
    if (kIsWeb) return UpdateCheckResult(current);
    try {
      final res = await http.get(
        Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest'),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 15));
      final body = utf8.decode(res.bodyBytes);
      if (res.statusCode == 404) {
        return UpdateCheckResult(current,
            privateRepo: true,
            error: 'Mises à jour sur la page GitHub privée.');
      }
      if (res.statusCode != 200) {
        return UpdateCheckResult(current,
            error: 'Le serveur de mises à jour ne répond pas '
                '(code ${res.statusCode}). Réessayez plus tard.');
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String?) ?? '';
      if (tag.isEmpty || !isNewer(tag, current)) {
        return UpdateCheckResult(current);
      }
      String? asset(String ext) {
        for (final a in (data['assets'] as List? ?? const [])) {
          final m = a as Map<String, dynamic>;
          final name = (m['name'] as String? ?? '').toLowerCase();
          if (name.endsWith(ext)) return m['browser_download_url'] as String?;
        }
        return null;
      }

      return UpdateCheckResult(
        current,
        update: UpdateInfo(
          version: tag.replaceFirst(RegExp(r'^[vV]'), ''),
          notes: (data['body'] as String?) ?? '',
          pageUrl: (data['html_url'] as String?) ?? releasesPage,
          apkUrl: asset('.apk'),
          ipaUrl: asset('.ipa'),
        ),
      );
    } on TimeoutException {
      return UpdateCheckResult(current,
          error: 'La connexion est trop lente. Réessayez plus tard.');
    } catch (e) {
      return UpdateCheckResult(current,
          error: 'Pas de connexion Internet ou serveur injoignable. '
              'Réessayez plus tard.');
    }
  }
}
