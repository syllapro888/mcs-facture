# MCS Factures — MCS VISION

Application mobile (Android et iPhone) de factures et devis professionnels pour
**MCS VISION**, Brazzaville. Elle fonctionne hors ligne : tout est enregistré
sur le téléphone (SQLite).

## Fonctionnalités

- Tableau de bord : nombre de factures, payées, impayées, chiffre d’affaires.
- Factures et devis avec numéro automatique (`MCSV-2026-0001`, `MCSV-D-2026-0001`).
- Articles avec photo, désignation, quantité, unité, prix, remise ; calculs automatiques.
- Main-d’œuvre en lignes séparées ; laissée vide, elle affiche « À préciser »
  et le total définitif aussi.
- TVA facultative (taux réglable, 0 % ou sans TVA), remise globale.
- Catalogue de produits (photos, catégories, recherche) et fichier clients.
- PDF A4 vectoriel aux couleurs MCS VISION : aperçu, impression, partage
  (WhatsApp, email, Bluetooth…), export dans les fichiers. Plusieurs pages si besoin.
- Historique : recherche, filtres par statut et par date, duplication,
  transformation d’un devis en facture, duplicata, suppression.
- Paramètres : coordonnées, logo, couleurs, textes, sauvegarde et restauration.

## Construire l’application

Chaque envoi sur la branche `main` lance GitHub Actions (onglet **Actions**) :

1. tests des calculs et du PDF ;
2. construction de l’APK Android ;
3. construction de l’application iPhone (fichier `.ipa` non signé) ;
4. publication dans **Releases** avec un PDF d’exemple.

### Installer sur Android

Ouvrir la page **Releases** depuis le téléphone, télécharger le fichier `.apk`
et l’installer (autoriser l’installation depuis le navigateur si demandé).

### Installer sur iPhone

Apple n’autorise pas l’installation directe d’un fichier. Deux possibilités :

- **Gratuit** : sur un ordinateur Windows ou Mac, installer **Sideloadly**,
  brancher l’iPhone, glisser le fichier `.ipa` et se connecter avec son
  identifiant Apple. L’application est à réinstaller tous les 7 jours.
- **Compte Apple Developer (99 $/an)** : signature et distribution par
  TestFlight, sans limite de 7 jours.

## Structure

```
lib/
  models/      produits, clients, factures, lignes, paramètres
  database/    base SQLite
  providers/   état de l'application (Provider)
  screens/     écrans
  services/    PDF, factures, sauvegarde
  widgets/     composants réutilisables
  utils/       formats FCFA, numérotation, photos
test/          tests des calculs et du PDF
```
