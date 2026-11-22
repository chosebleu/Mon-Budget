<!-- MON_BUDGET_FRISE_GRAPHIQUE -->

<p align="center">
  <img src="docs/frise_presentation_graphique.png" alt="Présentation graphique de Mon Budget V2" width="100%">
</p>

<h1 align="center">Mon Budget V2</h1>

<p align="center">
  <strong>Application Android de gestion de budget personnel</strong><br>
  Une application Flutter pour suivre ses revenus, ses dépenses et son budget mensuel avec une interface sombre, épurée et pratique.
</p>

<p align="center">
  <a href="https://github.com/chosebleu/Mon-Budget/releases/latest">
    <img src="https://img.shields.io/badge/Télécharger-APK%20Android-2f6f55?style=for-the-badge&logo=android&logoColor=white" alt="Télécharger l'APK Android">
  </a>
  <a href="https://github.com/chosebleu/Mon-Budget/releases">
    <img src="https://img.shields.io/badge/Version-1.1.0-444444?style=for-the-badge" alt="Version 1.1.0">
  </a>
</p>

<p align="center">
  <strong>Langues disponibles :</strong><br>
  Français · English
</p>

<p align="center">Développement : <strong>chosebleu</strong></p>

## Fonctionnalités

| Fonction | Description |
|---|---|
| Accueil | Consultation du solde réel et du reste à vivre |
| Saisie rapide | Ajout de revenus et de dépenses |
| Dépenses | Consultation, tri et filtrage des opérations |
| Sélection multiple | Calcul du sous-total des dépenses sélectionnées |
| Statistiques | Graphique mensuel et consultation des dépenses par mois |
| Gestion mensuelle | Organisation des opérations par mois |
| Internationalisation | Interface disponible en français et en anglais |

## Parcours de l'application

```mermaid
flowchart LR
    A["Accueil"] --> B["Saisie rapide"]
    B --> C["Dépenses"]
    C --> D["Filtres et sélection"]
    D --> E["Statistiques"]
    E --> F["Suivi mensuel"]
```

## Captures d'écran

<p align="center">
  <img src="docs/screenshots/01_accueil.png" alt="Écran d'accueil - solde réel et reste à vivre" width="48%">
  <img src="docs/screenshots/02_depenses.png" alt="Écran des dépenses" width="48%">
</p>

<p align="center">
  <img src="docs/screenshots/03_statistiques.png" alt="Écran des statistiques" width="48%">
  <img src="docs/screenshots/04_gestion_mensuelle.png" alt="Écran de gestion mensuelle" width="48%">
</p>

Les captures présentent les principaux écrans de l'application.

## Télécharger et installer

La version Android officielle est disponible dans les **[Releases GitHub](https://github.com/chosebleu/Mon-Budget/releases/latest)**.

1. Ouvrir la dernière version publiée.
2. Télécharger le fichier APK.
3. Ouvrir le fichier sur un appareil Android compatible.
4. Autoriser l'installation depuis cette source si Android le demande.
5. Installer et lancer **Mon Budget V2**.

Les mises à jour signées avec le même certificat peuvent être installées sur une version précédente compatible, sans désinstallation.

## Développement

Projet développé avec Flutter et Dart.

Prérequis : Flutter et Android SDK.

Pour récupérer les dépendances et lancer les tests :

```powershell
flutter pub get
flutter test
flutter run
```

Pour compiler un APK :

```powershell
flutter build apk --release
```

La clé de signature officielle n'est pas fournie dans ce dépôt.

## Confidentialité

L'application est conçue pour gérer un budget personnel avec un stockage local.

Aucune donnée financière personnelle ne doit être incluse dans le dépôt public, les captures d'écran ou les fichiers de démonstration.

## Licence

Ce projet est distribué sous licence MIT. Consulter le fichier [LICENSE](LICENSE).

## Développeur

**chosebleu**
