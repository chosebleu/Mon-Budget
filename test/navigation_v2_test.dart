import 'package:intl/date_symbol_data_local.dart';
import 'package:mon_budget/preferences_regionales.dart';
import 'package:mon_budget/traductions.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:mon_budget/main.dart';
import 'package:mon_budget/stockage_v2.dart';

class FauxStockageV2 extends PathProviderPlatform {
  FauxStockageV2(this.dossier);

  final Directory dossier;

  @override
  Future<String?> getApplicationDocumentsPath() async => dossier.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dossierTemporaire;
  late PathProviderPlatform fournisseurOriginal;

  setUp(() async {
    fournisseurOriginal = PathProviderPlatform.instance;
    dossierTemporaire = await Directory.systemTemp.createTemp(
      'mon_budget_v2_test_',
    );
    PathProviderPlatform.instance = FauxStockageV2(dossierTemporaire);
  });

  tearDown(() async {
    PathProviderPlatform.instance = fournisseurOriginal;

    if (await dossierTemporaire.exists()) {
      for (var tentative = 0; ; tentative++) {
        try {
          await dossierTemporaire.delete(recursive: true);
          break;
        } on FileSystemException catch (erreur) {
          if (!Platform.isWindows ||
              erreur.osError?.errorCode != 32 ||
              tentative >= 9) {
            rethrow;
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    }
  });

  Future<void> ouvrirBudget(WidgetTester tester) async {
    // LANGUE_TESTS_V1
    tester.binding.platformDispatcher.localeTestValue = const Locale(
      'fr',
      'FR',
    );

    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

    await tester.pumpWidget(const MonBudgetApp());

    // Le stockage utilise les entrées/sorties réelles du dossier temporaire.
    for (var essai = 0; essai < 30; essai++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      if (find.byType(PageView).evaluate().isNotEmpty) return;
    }
    expect(find.byType(PageView), findsOneWidget);
  }

  Map<String, dynamic> feuille(String mois, double salaire) => {
    'salaire': salaire,
    'reliquat': 25.0,
    'epargne': 70.0,
    'operations': {
      '0': [],
      '1': [
        {
          'intitule': 'Courses $mois',
          'montant': 29.0,
          'date': '$mois-10T00:00:00.000',
        },
      ],
      '2': [
        {
          'intitule': 'Loyer $mois',
          'montant': 300.0,
          'date': '$mois-28T00:00:00.000',
        },
      ],
      '3': [
        {
          'intitule': 'Prime $mois',
          'montant': 51.0,
          'date': '$mois-20T00:00:00.000',
        },
      ],
    },
  };

  Future<void> preparerBudget({
    required String moisActif,
    required Map<String, dynamic> feuilles,
  }) => StockageBudgetV2.enregistrer({
    'moisActif': moisActif,
    'feuillesMensuelles': feuilles,
  });

  Future<Map<String, dynamic>> attendreSauvegarde(
    WidgetTester tester,
    bool Function(Map<String, dynamic>) correspond,
  ) async {
    for (var essai = 0; essai < 30; essai++) {
      await tester.pump();
      final donnees = await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        // La copie de secours peut encore contenir la valeur attendue
        // pendant que le fichier principal est en cours de remplacement.
        final fichier = await StockageBudgetV2.fichier();
        try {
          final contenu = await fichier.readAsString();
          if (await File('${fichier.path}.tmp').exists()) return null;
          return jsonDecode(contenu) as Map<String, dynamic>;
        } on PathNotFoundException {
          return null;
        }
      });
      if (donnees != null && correspond(donnees)) {
        await tester.pump();
        return donnees;
      }
    }
    fail('Le budget modifié doit être sauvegardé.');
  }

  PageController controleur(WidgetTester tester) =>
      tester.widget<PageView>(find.byType(PageView)).controller!;

  Future<void> toucherAnnulerCreation(WidgetTester tester) async {
    final bouton = find.widgetWithText(TextButton, 'Annuler');
    expect(bouton, findsOneWidget);

    final liste = find.ancestor(of: bouton, matching: find.byType(ListView));
    expect(liste, findsOneWidget);

    for (var geste = 0; geste < 12; geste++) {
      if (bouton.hitTestable().evaluate().isNotEmpty) break;
      await tester.drag(liste, const Offset(0, -180));
      await tester.pumpAndSettle();
    }

    expect(
      bouton.hitTestable(),
      findsOneWidget,
      reason: 'Annuler doit être accessible en faisant défiler la feuille.',
    );
    await tester.tap(bouton.hitTestable());
  }

  Future<void> glisserMois(
    WidgetTester tester, {
    required bool enArriere,
  }) async {
    final vue = find.byType(PageView);
    final largeur = tester.getSize(vue).width;
    await tester.drag(vue, Offset(largeur * (enArriere ? 0.75 : -0.75), 0));
    await tester.pumpAndSettle();
  }

  Future<void> ouvrirConfirmationSuppression(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Options de la feuille'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer ce mois'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer ce mois ?'), findsOneWidget);
  }

  Future<void> ouvrirConfirmationRemiseAZero(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Options de la feuille'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate((widget) => widget is PopupMenuItem),
      findsNWidgets(2),
    );
    expect(find.text('Rechercher sur tous les mois'), findsNothing);
    expect(find.text('Bilan sur six mois'), findsNothing);
    expect(find.text('Supprimer ce mois'), findsOneWidget);
    await tester.tap(find.text('Remettre ce mois à zéro'));
    await tester.pumpAndSettle();
    expect(find.text('Remettre ce mois à zéro ?'), findsOneWidget);
    expect(find.textContaining('La feuille de Novembre 2026'), findsOneWidget);
  }

  // TEST_PERSISTANCE_REGIONALE_V1
  testWidgets('Langue et devise : modification et persistance', (tester) async {
    await tester.runAsync(() async {
      await initializeDateFormatting();
    });

    final novembre = feuille('2026-11', 1100);

    await tester.runAsync(
      () =>
          preparerBudget(moisActif: '2026-11', feuilles: {'2026-11': novembre}),
    );

    await ouvrirBudget(tester);

    expect(find.text('1100,00 €'), findsOneWidget);

    dynamic etat = tester.state(find.byType(StructureV2));
    etat.changerPage(5);
    await tester.pumpAndSettle();

    final panneau = find.byKey(const ValueKey('langue-devise'));

    await tester.ensureVisible(panneau);
    await tester.tap(panneau);
    await tester.pumpAndSettle();

    final langue = find.widgetWithText(ListTile, 'Langue');
    await tester.ensureVisible(langue);
    await tester.tap(langue);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SimpleDialogOption, 'English'));
    await tester.pumpAndSettle();

    await attendreSauvegarde(tester, (d) => d['langueInterface'] == 'en');

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale?.languageCode,
      'en',
    );

    expect(
      find.text(Traductions.traduire('en', 'Langue et devise')),
      findsOneWidget,
    );

    final devise = find.widgetWithText(
      ListTile,
      Traductions.traduire('en', 'Devise'),
    );

    await tester.ensureVisible(devise);
    await tester.tap(devise);
    await tester.pumpAndSettle();

    final recherche = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

    await tester.enterText(recherche, 'USD');
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ListTile, 'USD'),
      ),
    );

    await tester.pumpAndSettle();

    final sauvegarde = await attendreSauvegarde(
      tester,
      (d) => d['langueInterface'] == 'en' && d['deviseInterface'] == 'USD',
    );

    expect(sauvegarde['feuillesMensuelles'], {'2026-11': novembre});

    etat.changerPage(0);
    await tester.pumpAndSettle();

    final montant = PreferencesRegionales.formaterMontant(1100, 'en', 'USD');

    expect(find.text(montant), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await ouvrirBudget(tester);

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale?.languageCode,
      'en',
    );

    expect(find.text(montant), findsOneWidget);

    final recharge = await attendreSauvegarde(
      tester,
      (d) => d['langueInterface'] == 'en' && d['deviseInterface'] == 'USD',
    );

    expect(recharge['feuillesMensuelles'], {'2026-11': novembre});

    expect(tester.takeException(), isNull);
  });

  testWidgets('Annuler la remise à zéro conserve les données du mois', (
    tester,
  ) async {
    final novembre = feuille('2026-11', 1100);
    await tester.runAsync(
      () =>
          preparerBudget(moisActif: '2026-11', feuilles: {'2026-11': novembre}),
    );
    await ouvrirBudget(tester);
    await ouvrirConfirmationRemiseAZero(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Annuler'));
    await tester.pumpAndSettle();

    expect(find.text('1100,00 €'), findsOneWidget);
    final sauvegarde = await attendreSauvegarde(tester, (_) => true);
    expect(sauvegarde['feuillesMensuelles'], {'2026-11': novembre});
  });

  testWidgets(
    'Confirmer la remise à zéro vide uniquement la feuille sélectionnée',
    (tester) async {
      final octobre = feuille('2026-10', 1000);
      final decembre = feuille('2026-12', 1200);
      await tester.runAsync(
        () => preparerBudget(
          moisActif: '2026-11',
          feuilles: {
            '2026-10': octobre,
            '2026-11': feuille('2026-11', 1100),
            '2026-12': decembre,
          },
        ),
      );
      await ouvrirBudget(tester);
      await tester.tap(find.byIcon(Icons.event_repeat_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Loyer 2026-11'), findsOneWidget);

      await ouvrirConfirmationRemiseAZero(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Remettre ce mois à zéro'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Loyer 2026-11'), findsNothing);
      await tester.tap(find.byIcon(Icons.home_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Novembre 2026'), findsOneWidget);
      expect(find.text('0,00 €'), findsNWidgets(6));

      final sauvegarde = await attendreSauvegarde(
        tester,
        (donnees) =>
            (donnees['feuillesMensuelles'] as Map)['2026-11']?['salaire'] == 0,
      );
      expect(sauvegarde['moisActif'], '2026-11');
      expect(sauvegarde['feuillesMensuelles'], {
        '2026-10': octobre,
        '2026-11': {
          'salaire': 0,
          'epargne': 0,
          'reliquat': 0,
          'operations': {'0': [], '1': [], '2': [], '3': []},
        },
        '2026-12': decembre,
      });

      await tester.pumpWidget(const SizedBox.shrink());
      await ouvrirBudget(tester);
      expect(find.text('Novembre 2026'), findsOneWidget);
      expect(find.text('0,00 €'), findsNWidgets(6));
    },
  );

  testWidgets('Créer le mois précédent ouvre un seul nouveau mois à gauche', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(
      () => preparerBudget(
        moisActif: '2027-01',
        feuilles: {'2027-01': feuille('2027-01', 1200)},
      ),
    );
    await ouvrirBudget(tester);
    await glisserMois(tester, enArriere: true);
    expect(find.text('Décembre 2026'), findsOneWidget);
    final creer = find.byTooltip('Créer cette feuille');
    expect(creer, findsOneWidget);
    await glisserMois(tester, enArriere: true);
    expect(find.text('Décembre 2026'), findsOneWidget);
    final avantCreation = await attendreSauvegarde(tester, (_) => true);
    expect((avantCreation['feuillesMensuelles'] as Map).keys, ['2027-01']);

    await toucherAnnulerCreation(tester);
    await tester.pumpAndSettle();
    expect(find.text('Janvier 2027'), findsOneWidget);
    await glisserMois(tester, enArriere: true);
    await Scrollable.ensureVisible(tester.element(creer), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(creer);
    final apresCreation = await attendreSauvegarde(
      tester,
      (donnees) => donnees['moisActif'] == '2026-12',
    );
    await tester.pumpAndSettle();
    expect(find.text('Décembre 2026'), findsOneWidget);
    expect(creer, findsNothing);
    expect(apresCreation['feuillesMensuelles']['2027-01']['salaire'], 1200);
    await glisserMois(tester, enArriere: true);
    expect(find.text('Novembre 2026'), findsOneWidget);
    expect(creer, findsOneWidget);
    await glisserMois(tester, enArriere: true);
    expect(find.text('Novembre 2026'), findsOneWidget);
    await glisserMois(tester, enArriere: false);
    await glisserMois(tester, enArriere: false);
    expect(find.text('Janvier 2027'), findsOneWidget);
    await attendreSauvegarde(
      tester,
      (donnees) => donnees['moisActif'] == '2027-01',
    );
  });

  for (final (premier, icone, titreOnglet) in [
    (true, Icons.event_repeat_rounded, 'Charges fixes'),
    (false, Icons.receipt_long_rounded, 'Dépenses'),
    (false, Icons.savings_rounded, 'Rentrées'),
  ]) {
    testWidgets(
      'Supprimer le ${premier ? 'premier' : 'dernier'} mois depuis $titreOnglet',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(480, 780));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final cible = premier ? '2026-10' : '2026-11';
        final restant = premier ? '2026-11' : '2026-10';
        final titreCible = premier ? 'Octobre 2026' : 'Novembre 2026';
        final titreRestant = premier ? 'Novembre 2026' : 'Octobre 2026';
        await tester.runAsync(
          () => preparerBudget(
            moisActif: restant,
            feuilles: {
              cible: feuille(cible, 1000),
              restant: feuille(restant, 1200),
            },
          ),
        );
        await ouvrirBudget(tester);
        await tester.tap(find.byIcon(icone).first);
        await tester.pumpAndSettle();
        expect(find.text(titreOnglet).hitTestable(), findsOneWidget);
        final cadre = tester.getRect(find.byType(PageView));
        final direction = premier ? 1.0 : -1.0;
        final geste = await tester.startGesture(cadre.center);
        await geste.moveBy(Offset(25 * direction, 0));
        await geste.moveBy(Offset(cadre.width * 0.67 * direction, 0));
        await tester.pump();
        expect(controleur(tester).page, isNot(closeTo(premier ? 1 : 2, 0.01)));
        expect(find.text(titreCible), findsOneWidget);
        await geste.up();
        await ouvrirConfirmationSuppression(tester);
        expect(
          find.textContaining('$titreCible et toutes ses'),
          findsOneWidget,
        );
        await tester.tap(
          find.widgetWithText(FilledButton, 'Supprimer ce mois'),
        );
        final donnees = await attendreSauvegarde(
          tester,
          (donnees) =>
              !(donnees['feuillesMensuelles'] as Map).containsKey(cible),
        );
        await tester.pumpAndSettle();
        expect(donnees['moisActif'], restant);
        expect((donnees['feuillesMensuelles'] as Map).keys, [restant]);
        expect(find.text(titreRestant), findsOneWidget);
        expect(find.text(titreOnglet).hitTestable(), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await ouvrirBudget(tester);
        expect(find.text(titreRestant), findsOneWidget);
        await glisserMois(tester, enArriere: premier);
        expect(find.text(titreCible), findsOneWidget);
        expect(find.byTooltip('Créer cette feuille'), findsOneWidget);
      },
    );
  }

  testWidgets('Retour aux feuilles antérieures depuis l\'accueil', (
    tester,
  ) async {
    await tester.runAsync(
      () => preparerBudget(
        moisActif: '2027-02',
        feuilles: {
          '2027-01': feuille('2027-01', 1200),
          '2026-09': feuille('2026-09', 900),
          '2026-11': feuille('2026-11', 1100),
        },
      ),
    );
    await ouvrirBudget(tester);
    final pages = controleur(tester);
    expect(pages.page, 5);
    expect(find.text('1200,00 €'), findsOneWidget);

    await glisserMois(tester, enArriere: true);
    expect(pages.page, 4);
    expect(find.text('Décembre 2026'), findsOneWidget);
    expect(find.byTooltip('Créer cette feuille'), findsOneWidget);

    await glisserMois(tester, enArriere: true);
    expect(pages.page, 3);
    expect(find.text('Novembre 2026'), findsOneWidget);
    expect(find.text('1100,00 €'), findsOneWidget);

    await glisserMois(tester, enArriere: true);
    expect(pages.page, 2);
    expect(find.text('Octobre 2026'), findsOneWidget);
    expect(find.byTooltip('Créer cette feuille'), findsOneWidget);

    await glisserMois(tester, enArriere: true);
    expect(pages.page, 1);
    expect(find.text('Septembre 2026'), findsOneWidget);
    expect(find.text('900,00 €'), findsOneWidget);
    expect(controleur(tester), same(pages));
    final sauvegarde = await attendreSauvegarde(
      tester,
      (donnees) => donnees['moisActif'] == '2026-09',
    );
    expect(
      (sauvegarde['feuillesMensuelles'] as Map).keys,
      unorderedEquals(['2026-09', '2026-11', '2027-01']),
    );
  });

  testWidgets('Annuler la suppression conserve la feuille affichée', (
    tester,
  ) async {
    await tester.runAsync(
      () => preparerBudget(
        moisActif: '2026-11',
        feuilles: {'2026-11': feuille('2026-11', 1100)},
      ),
    );
    await ouvrirBudget(tester);
    await ouvrirConfirmationSuppression(tester);
    expect(find.textContaining('Novembre 2026 et toutes ses'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('1100,00 €'), findsOneWidget);
    final sauvegarde = await attendreSauvegarde(tester, (_) => true);
    expect(sauvegarde['feuillesMensuelles'], {
      '2026-11': feuille('2026-11', 1100),
    });
  });

  testWidgets('Supprimer une feuille intermédiaire conserve ses voisines', (
    tester,
  ) async {
    await tester.runAsync(
      () => preparerBudget(
        moisActif: '2026-11',
        feuilles: {
          '2026-12': feuille('2026-12', 1200),
          '2026-11': feuille('2026-11', 1100),
          '2026-10': feuille('2026-10', 1000),
        },
      ),
    );
    await ouvrirBudget(tester);
    await ouvrirConfirmationSuppression(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer ce mois'));
    final sauvegarde = await attendreSauvegarde(
      tester,
      (donnees) =>
          !(donnees['feuillesMensuelles'] as Map).containsKey('2026-11'),
    );
    await tester.pumpAndSettle();

    final feuilles = sauvegarde['feuillesMensuelles'] as Map;
    expect(feuilles, {
      '2026-10': feuille('2026-10', 1000),
      '2026-12': feuille('2026-12', 1200),
    });
    expect(sauvegarde['moisActif'], '2026-10');
    expect(find.text('Octobre 2026'), findsOneWidget);

    final corbeille = sauvegarde['corbeilleMensuelle'] as Map;
    expect(corbeille.length, 1);
    expect(corbeille.values.single['mois'], '2026-11');
    expect(corbeille.values.single['feuille'], feuille('2026-11', 1100));

    await glisserMois(tester, enArriere: false);
    expect(find.text('Novembre 2026'), findsOneWidget);
    expect(find.byTooltip('Créer cette feuille'), findsOneWidget);

    await glisserMois(tester, enArriere: false);
    expect(find.text('Décembre 2026'), findsOneWidget);
    expect(find.text('1200,00 €'), findsOneWidget);
    await attendreSauvegarde(
      tester,
      (donnees) => donnees['moisActif'] == '2026-12',
    );

    await glisserMois(tester, enArriere: true);
    expect(find.text('Novembre 2026'), findsOneWidget);
    expect(find.byTooltip('Créer cette feuille'), findsOneWidget);

    await glisserMois(tester, enArriere: true);
    expect(find.text('Octobre 2026'), findsOneWidget);

    final retour = await attendreSauvegarde(
      tester,
      (donnees) => donnees['moisActif'] == '2026-10',
    );

    expect(retour['feuillesMensuelles'], feuilles);
    expect(retour['corbeilleMensuelle'], corbeille);

    await tester.pumpWidget(const SizedBox.shrink());
    await ouvrirBudget(tester);

    expect(find.text('Octobre 2026'), findsOneWidget);

    await glisserMois(tester, enArriere: false);
    expect(find.text('Novembre 2026'), findsOneWidget);
    expect(find.byTooltip('Créer cette feuille'), findsOneWidget);

    await glisserMois(tester, enArriere: false);
    expect(find.text('Décembre 2026'), findsOneWidget);

    final apresRedemarrage = await attendreSauvegarde(
      tester,
      (donnees) => donnees['moisActif'] == '2026-12',
    );

    expect(apresRedemarrage['feuillesMensuelles'], feuilles);
    expect(apresRedemarrage['corbeilleMensuelle'], corbeille);
  });

  testWidgets('Supprimer la dernière feuille ouvre un état vide rechargeable', (
    tester,
  ) async {
    await tester.runAsync(
      () => preparerBudget(
        moisActif: '2026-11',
        feuilles: {'2026-11': feuille('2026-11', 1100)},
      ),
    );
    await ouvrirBudget(tester);
    await ouvrirConfirmationSuppression(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer ce mois'));
    final sauvegarde = await attendreSauvegarde(
      tester,
      (donnees) => (donnees['feuillesMensuelles'] as Map).isEmpty,
    );
    await tester.pumpAndSettle();
    expect(sauvegarde['salaire'], 0);
    expect(find.byTooltip('Créer cette feuille'), findsOneWidget);
    expect(controleur(tester).page, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await ouvrirBudget(tester);
    expect(find.byTooltip('Créer cette feuille'), findsOneWidget);
    await glisserMois(tester, enArriere: false);
    expect(controleur(tester).page, 0);
    final creer = find.byTooltip('Créer cette feuille');
    await Scrollable.ensureVisible(tester.element(creer), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(creer);
    final apresCreation = await attendreSauvegarde(
      tester,
      (donnees) => (donnees['feuillesMensuelles'] as Map).length == 1,
    );
    expect(apresCreation['salaire'], 0);
  });

  testWidgets('Recherche des opérations depuis Statistique', (tester) async {
    await tester.runAsync(
      () => preparerBudget(
        moisActif: '2026-12',
        feuilles: {
          '2026-11': feuille('2026-11', 1100),
          '2026-12': feuille('2026-12', 1200),
        },
      ),
    );
    await ouvrirBudget(tester);
    await tester.tap(find.byIcon(Icons.bar_chart_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'courses 2026-11');
    await tester.pumpAndSettle();
    final resultat = find.widgetWithText(ListTile, 'Courses 2026-11');
    expect(resultat, findsOneWidget);
    await tester.tap(resultat);
    await tester.pumpAndSettle();
    expect(find.text('Dépenses'), findsOneWidget);
    expect(find.text('Novembre 2026'), findsOneWidget);
    await attendreSauvegarde(tester, (d) => d['moisActif'] == '2026-11');
  });

  testWidgets('Navigation entre les rubriques V2', (tester) async {
    await ouvrirBudget(tester);
    expect(find.text('Accueil'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.receipt_long_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Dépenses'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.event_repeat_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Charges fixes'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Paramètres'), findsOneWidget);
    expect(find.text('Apparence'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bar_chart_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Statistique'), findsOneWidget);
    expect(find.text('Dépenses hors charges fixes'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('Les opérations du mois voisin sont visibles pendant le geste', (
    tester,
  ) async {
    await tester.runAsync(
      () => preparerBudget(
        moisActif: '2026-11',
        feuilles: {
          '2026-12': feuille('2026-12', 1200),
          '2026-10': feuille('2026-10', 1000),
          '2026-11': feuille('2026-11', 1100),
        },
      ),
    );
    await ouvrirBudget(tester);
    expect(controleur(tester).page, 2);
    expect(find.text('1100,00 €'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.receipt_long_rounded).first);
    await tester.pumpAndSettle();

    final vue = find.byType(PageView);
    final cadre = tester.getRect(vue);
    final gesture = await tester.startGesture(cadre.center);
    await gesture.moveBy(const Offset(25, 0));
    await gesture.moveBy(Offset(cadre.width * 0.30, 0));
    await tester.pump();
    expect(controleur(tester).page, allOf(greaterThan(1.5), lessThan(2)));
    expect(find.text('Novembre 2026'), findsOneWidget);
    await gesture.moveBy(Offset(cadre.width * 0.58, 0));
    await tester.pump();

    expect(controleur(tester).page, allOf(greaterThan(1), lessThan(1.5)));
    expect(find.text('Octobre 2026'), findsOneWidget);
    expect(find.text('Novembre 2026'), findsNothing);
    final coursesOctobre = find.text('Courses 2026-10');
    expect(coursesOctobre, findsOneWidget);
    expect(cadre.overlaps(tester.getRect(coursesOctobre)), isTrue);
    expect(find.text('Courses 2026-11'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(controleur(tester).page, 1);
    expect(find.text('Octobre 2026'), findsOneWidget);
    expect(coursesOctobre, findsOneWidget);

    for (final index in [2, 3]) {
      await tester.drag(vue, Offset(-cadre.width * 0.75, 0));
      await tester.pumpAndSettle();
      expect(controleur(tester).page, index);
    }
    expect(find.text('Décembre 2026'), findsOneWidget);
    expect(find.text('Courses 2026-12'), findsOneWidget);
    await attendreSauvegarde(
      tester,
      (donnees) => donnees['moisActif'] == '2026-12',
    );
  });

  const optionsImport = ['Rentrées', 'Charges fixes', 'Reliquat', 'Épargne'];
  const titreImport = 'Importer depuis le mois précédent';
  const tailleS23 = Size(360, 780);
  Finder ligneImport(String libelle) => find.widgetWithText(InkWell, libelle);
  Finder interrupteurImport(String libelle) =>
      find.descendant(of: ligneImport(libelle), matching: find.byType(Switch));

  for (final (taille, echelle) in [
    (tailleS23, 1.0),
    (const Size(480, 780), 1.0),
    (const Size(320, 640), 2.0),
  ]) {
    testWidgets('Disposition du bloc d’import à ${taille.width} px ×$echelle', (
      tester,
    ) async {
      const source = '2026-12';
      await tester.binding.setSurfaceSize(echelle == 1 ? taille : tailleS23);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(
        () => preparerBudget(
          moisActif: source,
          feuilles: {source: feuille(source, 1200)},
        ),
      );
      await ouvrirBudget(tester);
      await glisserMois(tester, enArriere: false);

      final titre = find.text(titreImport);
      final bloc = find.ancestor(
        of: titre,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Material &&
              widget.borderRadius == BorderRadius.circular(20),
        ),
      );
      if (echelle != 1) {
        // Isoler le bloc pour mesurer le texte agrandi dans l’espace de la page.
        final conteneur = tester.widget<Material>(bloc);
        final theme = Theme.of(tester.element(titre));
        final largeurBloc = tester.getSize(bloc).width;
        await tester.binding.setSurfaceSize(taille);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(echelle)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Center(
                  child: SizedBox(
                    width: largeurBloc + taille.width - tailleS23.width,
                    child: conteneur,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }
      final cadre = tester.getRect(bloc);
      expect(cadre.width, lessThanOrEqualTo(taille.width));

      final commandes = [
        for (final option in ['Tout importer', ...optionsImport])
          ligneImport(option),
      ];
      expect(
        find.descendant(of: bloc, matching: find.byType(Switch)),
        findsNWidgets(5),
      );
      expect(
        find.descendant(of: bloc, matching: find.byType(Checkbox)),
        findsNothing,
      );
      final zones = commandes.map(tester.getRect).toList();
      final [tout, rentrees, charges, reliquat, epargne] = zones;
      final zoneTitre = tester.getRect(titre);
      for (final (index, zone) in zones.indexed) {
        expect(zone.width, greaterThanOrEqualTo(48));
        expect(zone.height, greaterThanOrEqualTo(48));
        expect(cadre.contains(zone.center), isTrue);
        expect(zone.left, greaterThanOrEqualTo(cadre.left));
        expect(zone.right, lessThanOrEqualTo(cadre.right));
        expect(zone.overlaps(zoneTitre), isFalse);
        expect(zones.skip(index + 1).any(zone.overlaps), isFalse);
      }

      final lignes = [rentrees, charges, reliquat, epargne, tout];
      for (var i = 1; i < lignes.length; i++) {
        expect(lignes[i].top, greaterThanOrEqualTo(lignes[i - 1].bottom));
        expect(lignes[i].left, closeTo(lignes.first.left, 1));
      }
      expect(tout.center.dx, closeTo(cadre.center.dx, 2));
      for (final libelle in ['Tout importer', ...optionsImport]) {
        final commande = ligneImport(libelle);
        await tester.ensureVisible(commande);
        await tester.pumpAndSettle();
        final interrupteur = interrupteurImport(libelle);
        expect(commande.hitTestable(), findsOneWidget);
        expect(interrupteur.hitTestable(), findsOneWidget);
        if (echelle == 1) {
          final zone = tester.getRect(commande);
          final valeur = tester.widget<Switch>(interrupteur).value;
          await tester.tapAt(Offset(zone.left + 2, zone.center.dy));
          await tester.pumpAndSettle();
          expect(tester.widget<Switch>(interrupteur).value, !valeur);
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final selection in [
    ...optionsImport,
    'Tout importer',
    'Reliquat négatif',
    'Aucun',
    'Antérieur',
  ]) {
    testWidgets('Import mensuel $selection et réouverture', (tester) async {
      const source = '2026-12';
      final anterieur = selection == 'Antérieur';
      final destination = anterieur ? '2026-11' : '2027-01';
      final negatif = selection == 'Reliquat négatif';
      final feuilleSource = feuille(source, negatif ? 100 : 1200);
      final autreFeuille = feuille('2026-10', 500);
      await tester.binding.setSurfaceSize(const Size(390, 950));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(
        () => preparerBudget(
          moisActif: source,
          feuilles: {
            if (negatif) '2026-10': autreFeuille,
            source: feuilleSource,
          },
        ),
      );
      await ouvrirBudget(tester);
      await glisserMois(tester, enArriere: anterieur);

      final tout = selection == 'Tout importer';
      bool importe(String option) =>
          tout || selection == option || (negatif && option == 'Reliquat');
      final tous = interrupteurImport('Tout importer');
      Future<void> toucher(Finder cible) async {
        await Scrollable.ensureVisible(tester.element(cible), alignment: 0.5);
        await tester.pumpAndSettle();
        await tester.tap(cible);
        await tester.pumpAndSettle();
      }

      if (tout || selection == 'Aucun') {
        await toucher(tous);
        if (!tout) await toucher(tous);
      } else if (!anterieur) {
        for (final option in optionsImport) {
          final interrupteur = interrupteurImport(option);
          if (tester.widget<Switch>(interrupteur).value != importe(option)) {
            await toucher(interrupteur);
          }
        }
      }
      for (final option in optionsImport) {
        final interrupteur = tester.widget<Switch>(interrupteurImport(option));
        expect(interrupteur.value, importe(option));
        expect(interrupteur.onChanged == null, anterieur);
      }
      final interrupteurTout = tester.widget<Switch>(tous);
      expect(interrupteurTout.value, tout);
      expect(interrupteurTout.onChanged == null, anterieur);

      await toucher(find.byTooltip('Créer cette feuille'));
      final salaire = importe('Rentrées') ? 1200 : 0;
      final charges = importe('Charges fixes') ? 300 : 0;
      final epargne = importe('Épargne') ? 70 : 0;
      final reliquat = importe('Reliquat') ? (negatif ? -204 : 896) : 0;
      void verifierBlocs() {
        final montants = [
          salaire,
          salaire - charges,
          0,
          epargne,
          salaire + reliquat - charges,
        ];
        for (final (index, montant) in montants.indexed) {
          expect(
            find.descendant(
              of: find.byKey(ValueKey('bloc_accueil_$index')),
              matching: find.text('$montant,00 €'),
            ),
            findsOneWidget,
          );
        }
      }

      verifierBlocs();

      final sauvegarde = await attendreSauvegarde(
        tester,
        (donnees) => donnees['feuillesMensuelles']?[destination] != null,
      );
      final feuilles = sauvegarde['feuillesMensuelles'] as Map;
      expect(feuilles[source], feuilleSource);
      if (negatif) expect(feuilles['2026-10'], autreFeuille);
      expect(
        feuilles.keys,
        unorderedEquals([if (negatif) '2026-10', source, destination]),
      );
      expect(feuilles[destination], {
        'salaire': salaire,
        'reliquat': reliquat,
        'epargne': epargne,
        'operations': {
          '0': [],
          '1': [],
          '2': [
            if (importe('Charges fixes'))
              {
                'intitule': 'Loyer $source',
                'montant': 300,
                'date': '$destination-28T00:00:00.000',
              },
          ],
          '3': [
            if (importe('Rentrées'))
              {
                'intitule': 'Prime $source',
                'montant': 51,
                'date': '$destination-20T00:00:00.000',
              },
          ],
        },
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await ouvrirBudget(tester);
      expect(
        find.text(anterieur ? 'Novembre 2026' : 'Janvier 2027'),
        findsOneWidget,
      );
      verifierBlocs();
      expect(await tester.runAsync(StockageBudgetV2.charger), sauvegarde);
    });
  }

  testWidgets(
    'La création borne le défilement et importe une copie indépendante',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 950));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(
        () => preparerBudget(
          moisActif: '2026-12',
          feuilles: {'2026-12': feuille('2026-12', 1200)},
        ),
      );
      await ouvrirBudget(tester);

      final vue = find.byType(PageView);
      final decalage = Offset(-tester.getSize(vue).width * 0.75, 0);
      Future<void> glisser(Offset offset) async {
        await tester.drag(vue, offset);
        await tester.pumpAndSettle();
      }

      await glisser(decalage);
      expect(find.text('Janvier 2027'), findsOneWidget);
      expect(find.byTooltip('Créer cette feuille'), findsOneWidget);
      await glisser(decalage);
      expect(controleur(tester).page, 2);
      expect(find.text('Janvier 2027'), findsOneWidget);

      await toucherAnnulerCreation(tester);
      await tester.pumpAndSettle();
      expect(controleur(tester).page, 1);
      expect(find.text('Décembre 2026'), findsOneWidget);

      expect(find.text('896,00 €'), findsOneWidget);
      await tester.tap(find.text('Épargne'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '900');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('bloc_accueil_3')),
          matching: find.text('900,00 €'),
        ),
        findsOneWidget,
      );
      expect(find.text('896,00 €'), findsOneWidget);
      await attendreSauvegarde(
        tester,
        (donnees) =>
            donnees['feuillesMensuelles']?['2026-12']?['epargne'] == 900,
      );

      await glisser(decalage);
      final toutImporter = find.text('Tout importer');
      await tester.ensureVisible(toutImporter);
      await tester.tap(toutImporter);
      await tester.pumpAndSettle();
      final creer = find.byTooltip('Créer cette feuille');
      await tester.ensureVisible(creer);
      await Scrollable.ensureVisible(tester.element(creer), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(creer);
      await tester.pumpAndSettle();

      expect(controleur(tester).page, 2);
      expect(find.text('1200,00 €'), findsOneWidget);
      expect(find.text('900,00 €'), findsNWidgets(2));
      expect(find.text('1796,00 €'), findsOneWidget);

      await tester.tap(find.text('Salaire'));
      await tester.pumpAndSettle();
      final champSalaire = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == 'Salaire',
        ),
      );
      expect(champSalaire, findsOneWidget);
      await tester.enterText(champSalaire, '1300');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('1300,00 €'), findsOneWidget);
      await attendreSauvegarde(
        tester,
        (donnees) =>
            donnees['feuillesMensuelles']?['2027-01']?['salaire'] == 1300,
      );

      await glisser(-decalage);
      expect(find.text('1200,00 €'), findsOneWidget);
      expect(find.text('896,00 €'), findsOneWidget);
      await attendreSauvegarde(
        tester,
        (donnees) => donnees['moisActif'] == '2026-12',
      );
      await glisser(decalage);
      expect(find.text('1300,00 €'), findsOneWidget);
      await glisser(decalage);
      expect(controleur(tester).page, 3);
      expect(find.text('Février 2027'), findsOneWidget);

      final donnees = await attendreSauvegarde(tester, (donnees) {
        final feuilles = donnees['feuillesMensuelles'] as Map?;
        return feuilles?['2027-01']?['salaire'] == 1300 &&
            donnees['moisActif'] == '2027-01';
      });
      final sauvegarde = donnees['feuillesMensuelles'] as Map;
      final janvier = sauvegarde['2027-01'] as Map;
      expect(sauvegarde.keys, unorderedEquals(['2026-12', '2027-01']));
      expect(sauvegarde['2026-12']['salaire'], 1200);
      expect(sauvegarde['2026-12']['epargne'], 900);
      expect(janvier['reliquat'], 896);
      expect(janvier['epargne'], 900);
      expect(janvier['operations']['1'], isEmpty);
      expect(
        janvier['operations']['2'].single['date'],
        startsWith('2027-01-28'),
      );
      expect(janvier['operations']['3'].single['montant'], 51);
    },
  );

  // TESTS_CORBEILLE_V1

  testWidgets('Corbeille : suppression, persistance et restauration', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final novembre = feuille('2026-11', 1100);
    final decembre = feuille('2026-12', 1200);

    await tester.runAsync(
      () => preparerBudget(
        moisActif: '2026-11',
        feuilles: {'2026-11': novembre, '2026-12': decembre},
      ),
    );

    await ouvrirBudget(tester);
    await ouvrirConfirmationSuppression(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer ce mois'));

    final supprime = await attendreSauvegarde(
      tester,
      (d) => !(d['feuillesMensuelles'] as Map).containsKey('2026-11'),
    );

    expect(supprime['feuillesMensuelles'], {'2026-12': decembre});

    final corbeille = supprime['corbeilleMensuelle'] as Map;
    expect(corbeille.length, 1);
    expect(corbeille.values.single['mois'], '2026-11');
    expect(corbeille.values.single['feuille'], novembre);

    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await ouvrirBudget(tester);

    final etat = tester.state(find.byType(StructureV2)) as dynamic;
    etat.changerPage(5);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Corbeille'));
    await tester.pumpAndSettle();

    final restaurer = find.widgetWithText(TextButton, 'Restaurer');
    expect(restaurer, findsOneWidget);
    await tester.ensureVisible(restaurer);
    await tester.pumpAndSettle();
    await tester.tap(restaurer);

    final restaure = await attendreSauvegarde(
      tester,
      (d) => (d['feuillesMensuelles'] as Map).containsKey('2026-11'),
    );

    expect(restaure['feuillesMensuelles'], {
      '2026-11': novembre,
      '2026-12': decembre,
    });

    expect(restaure['corbeilleMensuelle'], isEmpty);
    expect(restaure['moisActif'], '2026-11');

    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await ouvrirBudget(tester);

    expect(find.text('Novembre 2026'), findsOneWidget);
    expect(find.text('1100,00 €'), findsOneWidget);
  });

  testWidgets('Corbeille : expiration apres 30 jours', (tester) async {
    await tester.runAsync(
      () => preparerBudget(
        moisActif: '2026-12',
        feuilles: {'2026-12': feuille('2026-12', 1200)},
      ),
    );

    await ouvrirBudget(tester);
    final etat = tester.state(find.byType(StructureV2)) as dynamic;
    final maintenant = DateTime.now().toUtc();

    expect(
      etat.entreeCorbeilleValide(
        maintenant.subtract(const Duration(days: 29)),
        maintenant,
      ),
      isTrue,
    );

    expect(
      etat.entreeCorbeilleValide(
        maintenant.subtract(const Duration(days: 30)),
        maintenant,
      ),
      isFalse,
    );

    expect(
      etat.entreeCorbeilleValide(
        maintenant.subtract(const Duration(days: 31)),
        maintenant,
      ),
      isFalse,
    );
  });

  testWidgets('Corbeille : doublon et suppression definitive', (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final novembre = feuille('2026-11', 1100);
    final decembre = feuille('2026-12', 1200);

    await tester.runAsync(() async {
      await preparerBudget(
        moisActif: '2026-12',
        feuilles: {'2026-11': novembre, '2026-12': decembre},
      );

      final donnees = await StockageBudgetV2.charger();
      donnees['corbeilleMensuelle'] = {
        'doublon': {
          'mois': '2026-11',
          'suppression': DateTime.now().toUtc().toIso8601String(),
          'feuille': feuille('2026-11', 999),
        },
      };
      await StockageBudgetV2.enregistrer(donnees);
    });

    await ouvrirBudget(tester);
    final etat = tester.state(find.byType(StructureV2)) as dynamic;
    etat.changerPage(5);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Corbeille'));
    await tester.pumpAndSettle();

    final restaurer = find.widgetWithText(TextButton, 'Restaurer');
    expect(restaurer, findsOneWidget);
    expect(tester.widget<TextButton>(restaurer).onPressed, isNull);

    final supprimer = find.widgetWithText(TextButton, 'Supprimer');
    await tester.ensureVisible(supprimer);
    await tester.pumpAndSettle();
    await tester.tap(supprimer);
    await tester.pumpAndSettle();

    expect(find.text('Suppression définitive'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(restaurer, findsOneWidget);

    await tester.tap(supprimer);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Supprimer'),
      ),
    );

    final sauvegarde = await attendreSauvegarde(
      tester,
      (d) => (d['corbeilleMensuelle'] as Map).isEmpty,
    );

    expect(sauvegarde['feuillesMensuelles'], {
      '2026-11': novembre,
      '2026-12': decembre,
    });

    await tester.pumpAndSettle();
  });

  // TEST_RECREATION_INTERMEDIAIRE_V1
  testWidgets('Recreer un mois intermediaire sans ecraser la corbeille', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final octobre = feuille('2026-10', 1000);
    final novembre = feuille('2026-11', 1100);
    final decembre = feuille('2026-12', 1200);

    await tester.runAsync(
      () => preparerBudget(
        moisActif: '2026-11',
        feuilles: {
          '2026-10': octobre,
          '2026-11': novembre,
          '2026-12': decembre,
        },
      ),
    );

    await ouvrirBudget(tester);
    await ouvrirConfirmationSuppression(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer ce mois'));

    final suppression = await attendreSauvegarde(
      tester,
      (d) => !(d['feuillesMensuelles'] as Map).containsKey('2026-11'),
    );

    final corbeille = suppression['corbeilleMensuelle'] as Map;
    expect(corbeille.length, 1);
    expect(corbeille.values.single['feuille'], novembre);

    await tester.pumpAndSettle();
    await glisserMois(tester, enArriere: false);

    expect(find.text('Novembre 2026'), findsOneWidget);

    final bouton = find.byTooltip('Créer cette feuille');
    expect(bouton, findsOneWidget);

    final pages = controleur(tester);
    final etat = tester.state(find.byType(StructureV2)) as dynamic;
    final chronologie = List<String>.from(etat.moisAffiches as List);

    await tester.ensureVisible(bouton);
    await tester.pumpAndSettle();
    await tester.tap(bouton);

    final recreation = await attendreSauvegarde(
      tester,
      (d) => (d['feuillesMensuelles'] as Map).containsKey('2026-11'),
    );

    await tester.pumpAndSettle();

    final feuilles = recreation['feuillesMensuelles'] as Map;
    expect(feuilles.length, 3);
    expect(feuilles['2026-10'], octobre);
    expect(feuilles['2026-12'], decembre);
    expect(feuilles['2026-11']['salaire'], 0);
    expect(recreation['corbeilleMensuelle'], corbeille);
    expect(recreation['moisActif'], '2026-11');
    expect(controleur(tester), same(pages));
    expect(etat.moisAffiches, chronologie);

    await tester.pumpWidget(const SizedBox.shrink());
    await ouvrirBudget(tester);

    expect(find.text('Novembre 2026'), findsOneWidget);
    expect(find.byTooltip('Créer cette feuille'), findsNothing);

    final persistance = await attendreSauvegarde(tester, (_) => true);
    expect(persistance['feuillesMensuelles'], feuilles);
    expect(persistance['corbeilleMensuelle'], corbeille);
  });
}
