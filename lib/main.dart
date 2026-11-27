import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:intl/date_symbol_data_local.dart';

import 'stockage_v2.dart';
import 'preferences_regionales.dart';
import 'traductions.dart';
import 'feuilles_mensuelles_v2.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  runApp(const MonBudgetApp());
}

class MonBudgetApp extends StatefulWidget {
  const MonBudgetApp({super.key});

  @override
  State<MonBudgetApp> createState() => _MonBudgetAppState();
}

class _MonBudgetAppState extends State<MonBudgetApp> {
  String langue = 'fr';
  bool sombre = true;
  HSVColor accentHSV = HSVColor.fromColor(const Color(0xFF67B99A));

  ColorScheme _palette(HSVColor accent, Brightness luminosite) {
    final couleur = ColorScheme.fromSeed(
      seedColor: accent.withSaturation(1).toColor(),
      brightness: luminosite,
    );
    final neutre = ColorScheme.fromSeed(
      seedColor: Colors.grey,
      brightness: luminosite,
      dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
    );
    return ColorScheme.lerp(neutre, couleur, accent.saturation * accent.value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: Locale(langue),
      supportedLocales: PreferencesRegionales.langues.keys
          .map((code) => Locale(code))
          .toList(),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      title: 'Mon Budget V2.5',
      debugShowCheckedModeBanner: false,
      themeMode: sombre ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF0F1F3),
        colorScheme: _palette(accentHSV, Brightness.light),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101215),
        colorScheme: _palette(accentHSV, Brightness.dark).copyWith(
          surface: const Color(0xFF191C20),
          surfaceContainerLow: const Color(0xFF1D2025),
          onSurface: const Color(0xFFF1F3F5),
          onSurfaceVariant: const Color(0xFFB9C0C9),
          outlineVariant: const Color(0xFF2D3137),
        ),
      ),
      home: StructureV2(
        sombre: sombre,
        accentHSV: accentHSV,
        onTheme: (valeur) => setState(() => sombre = valeur),
        onLangue: (valeur) {
          if (langue != valeur) {
            setState(() => langue = valeur);
          }
        },
        onAccent: (valeur) => setState(() => accentHSV = valeur),
      ),
    );
  }
}

// OPERATIONS_V2

class OperationV2 {
  // GROUPE_COULEUR_CHARGES_V4
  static const couleursGroupes = <Color>[
    Color(0xFFEF5350),
    Color(0xFFFF8A3D),
    Color(0xFFFDD835),
    Color(0xFF8BC34A),
    Color(0xFF26A69A),
    Color(0xFF42A5F5),
    Color(0xFF7E87F5),
    Color(0xFFAB70D5),
    Color(0xFFEC75A7),
    Color(0xFF90A4AE),
  ];

  OperationV2({
    required this.intitule,
    required this.montant,
    required this.date,
    this.groupeCouleur,
  });

  String intitule;

  String? _intituleRechercheMemorise;
  String? _cleRechercheMemorisee;

  String get intituleNormalise {
    if (_intituleRechercheMemorise != intitule ||
        _cleRechercheMemorisee == null) {
      _intituleRechercheMemorise = intitule;
      _cleRechercheMemorisee = cleRecherche(intitule);
    }
    return _cleRechercheMemorisee!;
  }

  double montant;
  final DateTime date;
  int? groupeCouleur;
}

class _BudgetMensuel {
  _BudgetMensuel.vide() : salaire = 0, reliquat = 0, epargne = 0;

  _BudgetMensuel.depuisFeuille(FeuilleMensuelleV2 feuille)
    : salaire = feuille.salaire,
      reliquat = feuille.reliquat,
      epargne = feuille.epargne {
    for (final page in operations.keys) {
      for (final element in feuille.operations['$page'] ?? []) {
        final intitule = element['intitule'];
        final montant = element['montant'];
        final date = element['date'];
        if (intitule is! String ||
            montant is! num ||
            !montant.isFinite ||
            montant <= 0 ||
            date is! String) {
          throw const FormatException('Operation mensuelle invalide');
        }
        operations[page]!.add(
          OperationV2(
            intitule: intitule,
            montant: montant.toDouble(),
            date: DateTime.parse(date),
            groupeCouleur:
                page == 2 &&
                    element['groupeCouleur'] is int &&
                    (element['groupeCouleur'] as int) >= 0 &&
                    (element['groupeCouleur'] as int) <
                        OperationV2.couleursGroupes.length
                ? element['groupeCouleur'] as int
                : null,
          ),
        );
      }
    }
  }

  final Map<int, List<OperationV2>> operations = {0: [], 1: [], 2: [], 3: []};
  double salaire;
  double reliquat;
  double epargne;

  FeuilleMensuelleV2 versFeuille(String mois) => FeuilleMensuelleV2(
    mois: mois,
    operations: {
      for (final entree in operations.entries)
        '${entree.key}': [
          for (final operation in entree.value)
            {
              'intitule': operation.intitule,
              'montant': operation.montant,
              'date': operation.date.toIso8601String(),
              if (entree.key == 2 && operation.groupeCouleur != null)
                'groupeCouleur': operation.groupeCouleur,
            },
        ],
    },
    salaire: salaire,
    reliquat: reliquat,
    epargne: epargne,
  );

  double totalOperations(int page) => operations[page]!.fold<double>(
    0.0,
    (total, operation) => total + operation.montant,
  );
}

final _motifsRecherche = [
  for (final groupe in const {
    'a': 'àâä',
    'c': 'ç',
    'e': 'éèêë',
    'i': 'îï',
    'o': 'ôö',
    'u': 'ùûü',
  }.entries)
    (RegExp('[${groupe.value}]'), groupe.key),
];

String cleRecherche(String texte) {
  var cle = texte.trim().toLowerCase();
  for (final motif in _motifsRecherche) {
    cle = cle.replaceAll(motif.$1, motif.$2);
  }
  return cle.replaceAll('œ', 'oe');
}

enum TriOperationsV2 { croissant, decroissant, date, nature }

class StructureV2 extends StatefulWidget {
  const StructureV2({
    super.key,
    required this.sombre,
    required this.accentHSV,
    required this.onTheme,
    required this.onAccent,
    this.onLangue,
  });

  final bool sombre;
  final HSVColor accentHSV;
  Color get accent => accentHSV.toColor();
  final ValueChanged<bool> onTheme;
  final ValueChanged<HSVColor> onAccent;
  final ValueChanged<String>? onLangue;

  @override
  State<StructureV2> createState() => _StructureV2State();
}

class _StructureV2State extends State<StructureV2> {
  bool sousTotauxCouleursOuverts = false;
  int pageActive = 0;
  bool sidebarADroite = false;

  // GLISSEMENT_SIDEBAR_V3
  int? pointeurSidebar;
  bool glissementSidebarActif = false;
  final iconeSidebarSurvolee = ValueNotifier<int?>(null);

  void changerPage(int index) {
    if (!mounted ||
        index < 0 ||
        index >= titres.length ||
        index == pageActive) {
      return;
    }

    setState(() {
      pageActive = index;
    });
  }

  double get largeurSidebar => widget.sombre ? 54.0 : 64.0;

  double hauteurIconeSidebar(double hauteur) =>
      ((hauteur - (titres.length - 1)) / titres.length)
          .clamp(0.0, 64.0)
          .toDouble();

  int? indexSidebar(Offset position, double hauteur) {
    final taille = hauteurIconeSidebar(hauteur);
    final groupe = titres.length * taille + titres.length - 1;
    final debut = (hauteur - groupe) / 2;
    final y = position.dy - debut;

    if (position.dx < 0 ||
        position.dx > largeurSidebar ||
        y < 0 ||
        y >= groupe ||
        taille <= 0) {
      return null;
    }

    final index = (y / (taille + 1)).floor();
    return index >= 0 && index < titres.length ? index : null;
  }

  void suivreSidebar(Offset position, double hauteur) {
    iconeSidebarSurvolee.value = indexSidebar(position, hauteur);
  }

  final List<String> intitulesMemorises = [];
  final _budgetInitial = _BudgetMensuel.vide();
  final Map<String, _BudgetMensuel> feuillesMensuelles = {};

  // CORBEILLE_MENSUELLE_V1
  static const dureeCorbeille = Duration(days: 30);

  final corbeilleMensuelle =
      <
        String,
        ({String mois, DateTime suppression, FeuilleMensuelleV2 feuille})
      >{};

  bool entreeCorbeilleValide(DateTime suppression, DateTime maintenant) =>
      maintenant.isBefore(suppression.add(dureeCorbeille));

  Map<String, dynamic> serialiserCorbeille({String? moisSupprime}) {
    final maintenant = DateTime.now().toUtc();

    final resultat = <String, dynamic>{
      for (final entree in corbeilleMensuelle.entries)
        if (entreeCorbeilleValide(entree.value.suppression, maintenant))
          entree.key: {
            'mois': entree.value.mois,
            'suppression': entree.value.suppression.toIso8601String(),
            'feuille': entree.value.feuille.toJson(),
          },
    };

    if (moisSupprime != null) {
      final budget = feuillesMensuelles[moisSupprime]!;
      var identifiant = '${moisSupprime}_${maintenant.microsecondsSinceEpoch}';

      while (resultat.containsKey(identifiant)) {
        identifiant = '${identifiant}_';
      }

      resultat[identifiant] = {
        'mois': moisSupprime,
        'suppression': maintenant.toIso8601String(),
        'feuille': budget.versFeuille(moisSupprime).toJson(),
      };
    }

    return resultat;
  }

  Map<String, ({String mois, DateTime suppression, FeuilleMensuelleV2 feuille})>
  lireCorbeille(dynamic brut) {
    final resultat =
        <
          String,
          ({String mois, DateTime suppression, FeuilleMensuelleV2 feuille})
        >{};

    if (brut == null) return resultat;

    if (brut is! Map) {
      throw const FormatException('Corbeille invalide');
    }

    final maintenant = DateTime.now().toUtc();

    for (final entree in brut.entries) {
      final valeur = entree.value;

      if (entree.key is! String || valeur is! Map) {
        throw const FormatException('Entree de corbeille invalide');
      }

      final mois = valeur['mois'];
      final date = valeur['suppression'];
      final feuille = valeur['feuille'];

      if (mois is! String || date is! String || feuille is! Map) {
        throw const FormatException('Donnees de corbeille invalides');
      }

      GestionFeuillesMensuellesV2.dateDepuisIdentifiant(mois);
      final suppression = DateTime.parse(date).toUtc();

      if (!entreeCorbeilleValide(suppression, maintenant)) continue;

      final feuilleLue = FeuilleMensuelleV2.fromJson(
        mois,
        Map<String, dynamic>.from(feuille),
      );

      // Verifier aussi la validite des operations restaurables.
      _BudgetMensuel.depuisFeuille(feuilleLue);

      resultat[entree.key as String] = (
        mois: mois,
        suppression: suppression,
        feuille: feuilleLue,
      );
    }

    return resultat;
  }

  final List<String> moisAffiches = [];
  String moisActif = GestionFeuillesMensuellesV2.identifiant(DateTime.now());
  late final ValueNotifier<String> moisVisible = ValueNotifier(moisActif);
  int indexMensuel = 0;
  bool donneesChargees = false;
  bool erreurChargement = false;

  // ACCUEIL_PERSONNALISABLE_V1
  static const titresBlocsAccueil = <String>[
    'Salaire',
    'Reste sur salaire',
    'Total dépenses',
    'Épargne',
    'Total disponible',
    'Total charges fixes',
  ];

  List<int> ordreBlocsAccueil = [0, 1, 2, 5, 3, 4];
  Set<int> blocsAccueilMasques = <int>{};

  List<int> get blocsAccueilVisibles => ordreBlocsAccueil
      .where((id) => !blocsAccueilMasques.contains(id))
      .toList();
  PageController? controleurPagesMensuelles;

  String get moisAffiche =>
      donneesChargees ? moisAffiches[indexMensuel] : moisActif;
  bool get creationAffichee =>
      donneesChargees && !feuillesMensuelles.containsKey(moisAffiche);

  bool importerRevenus = false;
  bool importerCharges = true;
  bool importerReliquat = false;
  bool importerEpargne = false;
  bool creationMensuelleEnCours = false;
  bool suppressionMensuelleEnCours = false;

  void reinitialiserOptionsImport() {
    importerRevenus = false;
    importerCharges = true;
    importerReliquat = false;
    importerEpargne = false;
  }

  Future<void> creerFeuilleEnPreparation(String destination) async {
    if (destination != moisAffiche ||
        !creationAffichee ||
        creationMensuelleEnCours ||
        suppressionMensuelleEnCours) {
      return;
    }

    final precedent = moisPrecedent(destination);
    final options = OptionsImportMensuelV2(
      revenus: importerRevenus,
      charges: importerCharges,
      reliquat: importerReliquat,
      epargne: importerEpargne,
    );

    try {
      final nouvelleFeuille = GestionFeuillesMensuellesV2.creer(
        mois: destination,
        precedente: precedent == null
            ? null
            : feuillesMensuelles[precedent]?.versFeuille(precedent),
        options: options,
      );
      final budget = _BudgetMensuel.depuisFeuille(nouvelleFeuille);
      setState(() {
        creationMensuelleEnCours = true;
        feuillesMensuelles[destination] = budget;
        moisActif = destination;
        if (indexMensuel == 0) {
          reconstruirePagesMensuelles();
        } else if (indexMensuel == moisAffiches.length - 1) {
          ajouterPageCreationSuivante();
        }
        reinitialiserOptionsImport();
      });
      await enregistrerDonnees();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('Nouvelle feuille créée'))));
    } catch (erreur) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr("Création impossible")} : $erreur')),
      );
    } finally {
      if (mounted) {
        setState(() => creationMensuelleEnCours = false);
      }
    }
  }

  String? moisPrecedent(String mois) =>
      mois == '0001-01' ? null : GestionFeuillesMensuellesV2.deplacer(mois, -1);

  void ajouterPageCreationSuivante() {
    if (moisAffiches.last != '9999-12') {
      moisAffiches.add(
        GestionFeuillesMensuellesV2.deplacer(moisAffiches.last, 1),
      );
    }
  }

  // CHRONOLOGIE_MENSUELLE_CONTINUE_V1
  void reconstruirePagesMensuelles() {
    final moisExistants = feuillesMensuelles.keys.toList()..sort();
    moisAffiches.clear();

    if (moisExistants.isEmpty) {
      moisAffiches.add(moisActif);
    } else {
      final premier = moisExistants.first;
      final dernier = moisExistants.last;

      final precedent = moisPrecedent(premier);
      if (precedent != null) {
        moisAffiches.add(precedent);
      }

      var courant = premier;

      while (true) {
        moisAffiches.add(courant);

        if (courant == dernier) break;

        courant = GestionFeuillesMensuellesV2.deplacer(courant, 1);
      }

      ajouterPageCreationSuivante();
    }

    indexMensuel = moisAffiches.indexOf(moisActif);
    moisVisible.value = moisActif;
    final ancienControleur = controleurPagesMensuelles;
    controleurPagesMensuelles = PageController(
      initialPage: indexMensuel,
      keepPage: false,
    );
    if (ancienControleur != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ancienControleur.dispose();
      });
    }
  }

  bool selectionnerMoisApresGlissement(ScrollEndNotification notification) {
    final metriques = notification.metrics;
    if (notification.depth != 0 ||
        metriques is! PageMetrics ||
        suppressionMensuelleEnCours) {
      return false;
    }

    final position = metriques.page;
    if (position == null) return false;

    final index = position.round();
    if (index < 0 ||
        index >= moisAffiches.length ||
        index == indexMensuel ||
        (position - index).abs() > 0.01) {
      return false;
    }

    final mois = moisAffiches[index];
    final enregistrerSelection =
        feuillesMensuelles.containsKey(mois) && mois != moisActif;
    setState(() {
      if (creationAffichee) reinitialiserOptionsImport();
      indexMensuel = index;
      if (enregistrerSelection) moisActif = mois;
    });
    if (enregistrerSelection) enregistrerDonnees();
    return false;
  }

  Widget contenuMensuelAnime() {
    final controleur = controleurPagesMensuelles;
    final afficherBudget = pageActive < 4;
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: !afficherBudget,
          child: controleur == null
              ? (afficherBudget
                    ? pageBudget(_budgetInitial)
                    : const SizedBox.expand())
              : NotificationListener<ScrollEndNotification>(
                  onNotification: (notification) =>
                      controleur == controleurPagesMensuelles &&
                      selectionnerMoisApresGlissement(notification),
                  child: PageView.builder(
                    key: ObjectKey(controleur),
                    controller: controleur,
                    onPageChanged: (index) {
                      if (controleur == controleurPagesMensuelles &&
                          !suppressionMensuelleEnCours) {
                        moisVisible.value = moisAffiches[index];
                      }
                    },
                    physics: !afficherBudget || suppressionMensuelleEnCours
                        ? const NeverScrollableScrollPhysics()
                        : const PageScrollPhysics(),
                    itemCount: moisAffiches.length,
                    itemBuilder: (context, index) {
                      final mois = moisAffiches[index];
                      // Garder le viewport et sa position sans construire de
                      // cartes invisibles dans Statistiques et Paramètres.
                      if (!afficherBudget) {
                        return SizedBox.expand(key: ValueKey(mois));
                      }
                      final budget = feuillesMensuelles[mois];
                      // GLISSEMENT_FLUIDE_SANS_ZOOM_V1
                      return KeyedSubtree(
                        key: ValueKey(mois),
                        child: RepaintBoundary(
                          child: Material(
                            color: widget.sombre
                                ? Colors.transparent
                                : Theme.of(context).scaffoldBackgroundColor,
                            child: KeyedSubtree(
                              key: ValueKey(pageActive),
                              child: budget == null
                                  ? feuilleEnPreparation(mois)
                                  : pageBudget(budget),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
        if (pageActive == 5) pageParametres(),
        if (pageActive == 4) pageStatistique(moisAffiche),
      ],
    );
  }

  Widget feuilleEnPreparation(String destination) {
    final precedent = moisPrecedent(destination);
    final moisPrecedentDisponible = feuillesMensuelles.containsKey(precedent);
    final pageSelectionnee = destination == moisAffiche;

    final toutSelectionne =
        importerRevenus &&
        importerCharges &&
        importerReliquat &&
        importerEpargne;

    const rayon = 20.0;
    const margeInterieure = EdgeInsets.symmetric(horizontal: 18, vertical: 14);

    return LayoutBuilder(
      builder: (context, contraintes) {
        final hauteurDisponible = contraintes.maxHeight;
        // CREATION_ALIGNEMENT_COMMUN_V1
        final entete =
            _hauteurEnteteMensuelle +
            (widget.sombre && pageActive == 0
                ? _margeHauteEnteteAccueilSombre
                : 12.0);
        final centre =
            centreVerticalAccueil(hauteurDisponible + entete) - entete;

        return ListView(
          primary: false,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // CREATION_CENTRAGE_ADAPTATIF_V2
                _CentragePanneauCreation(
                  centre: centre,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: _SurfaceFinanciere(
                      sombre: widget.sombre,
                      rayon: rayon,
                      couleurClaire: couleurBlocPalette(),
                      fondClairDansMaterial: true,
                      margeInterieure: margeInterieure,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            tr('Importer depuis le mois précédent'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (final item in [
                            (
                              'Rentrées',
                              importerRevenus,
                              (bool v) => setState(() => importerRevenus = v),
                            ),
                            (
                              'Charges fixes',
                              importerCharges,
                              (bool v) => setState(() => importerCharges = v),
                            ),
                            (
                              'Reliquat',
                              importerReliquat,
                              (bool v) => setState(() => importerReliquat = v),
                            ),
                            (
                              'Épargne',
                              importerEpargne,
                              (bool v) => setState(() => importerEpargne = v),
                            ),
                          ]) ...[
                            InkWell(
                              onTap: moisPrecedentDisponible
                                  ? () => item.$3(!item.$2)
                                  : null,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 39,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        tr(item.$1),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Switch(
                                      value: item.$2 && moisPrecedentDisponible,
                                      onChanged: moisPrecedentDisponible
                                          ? item.$3
                                          : null,
                                      activeThumbColor: Colors.white,
                                      activeTrackColor: widget.accent,
                                      inactiveThumbColor: Colors.white,
                                      inactiveTrackColor: Colors.white24,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Divider(
                              color: widget.sombre
                                  ? Theme.of(context).colorScheme.outlineVariant
                                  : Colors.white24,
                              height: 1,
                              thickness: 0.7,
                            ),
                          ],
                          InkWell(
                            onTap: moisPrecedentDisponible
                                ? () => setState(() {
                                    final selectionner = !toutSelectionne;
                                    importerRevenus = selectionner;
                                    importerCharges = selectionner;
                                    importerReliquat = selectionner;
                                    importerEpargne = selectionner;
                                  })
                                : null,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 39),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      tr('Tout importer'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value:
                                        toutSelectionne &&
                                        moisPrecedentDisponible,
                                    onChanged: moisPrecedentDisponible
                                        ? (v) => setState(() {
                                            importerRevenus = v;
                                            importerCharges = v;
                                            importerReliquat = v;
                                            importerEpargne = v;
                                          })
                                        : null,
                                    activeThumbColor: Colors.white,
                                    activeTrackColor: widget.accent,
                                    inactiveThumbColor: Colors.white,
                                    inactiveTrackColor: Colors.white24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!moisPrecedentDisponible)
                            Text(
                              tr(
                                'Aucune feuille pour le mois qui précède celui-ci. La nouvelle feuille sera vide.',
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            tr('Les dépenses ponctuelles ne sont pas copiées.'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: IconButton(
                    tooltip: tr('Créer cette feuille'),
                    onPressed: creationMensuelleEnCours || !pageSelectionnee
                        ? null
                        : () => creerFeuilleEnPreparation(destination),
                    // PLUS_CREATION_COULEUR_PURE_V1
                    // PLUS_PALETTE_RELIEF_V1
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      size: 82,
                      color: widget.accent,
                      shadows: const [
                        Shadow(
                          color: Color(0x55000000),
                          offset: Offset(0, 3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    iconSize: 82,
                    constraints: const BoxConstraints(
                      minWidth: 100,
                      minHeight: 100,
                    ),
                  ),
                ),
                if (moisAffiches.length > 1) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: creationMensuelleEnCours || !pageSelectionnee
                        ? null
                        : () => controleurPagesMensuelles!.animateToPage(
                            indexMensuel == 0 ? 1 : indexMensuel - 1,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                          ),
                    child: Text(tr('Annuler')),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    canalWidget.setMethodCallHandler((appel) async {
      if (appel.method == 'demandeAjout') {
        await lireDemandeWidget();
      }
    });
    chargerDonnees();
  }

  @override
  void dispose() {
    canalWidget.setMethodCallHandler(null);
    controleurPagesMensuelles?.dispose();
    moisVisible.dispose();
    iconeSidebarSurvolee.dispose();
    super.dispose();
  }

  // WIDGET_SAISIE_RAPIDE_V1
  static const canalWidget = MethodChannel('mon_budget/widget');
  bool ajoutWidgetEnCours = false;

  Future<void> lireDemandeWidget() async {
    if (!mounted || !donneesChargees || erreurChargement) return;
    try {
      final demande = await canalWidget.invokeMethod<bool>(
        'consommerDemandeAjout',
      );
      if (!mounted || demande != true || ajoutWidgetEnCours) return;
      if (ModalRoute.of(context)?.isCurrent != true) return;
      if (creationMensuelleEnCours || suppressionMensuelleEnCours) return;
      if (!feuillesMensuelles.containsKey(moisActif)) {
        changerPage(0);
        return;
      }
      ajoutWidgetEnCours = true;
      try {
        setState(() {
          pageActive = 0;
          if (moisAffiche != moisActif) {
            reconstruirePagesMensuelles();
          }
        });
        await WidgetsBinding.instance.endOfFrame;
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          await ajouterOperation();
        }
      } finally {
        ajoutWidgetEnCours = false;
      }
    } on MissingPluginException {
    } on PlatformException catch (erreur) {
      debugPrint('Widget : $erreur');
    }
  }

  // WIDGET_PALETTE_V1
  Future<void> synchroniserCouleurWidget(Color couleur) async {
    try {
      await const MethodChannel('mon_budget/widget')
          .invokeMethod<void>('actualiserCouleur', couleur.toARGB32());
    } on MissingPluginException {
      // Widget Android indisponible sur cette plateforme.
    } on PlatformException catch (erreur) {
      debugPrint('Widget Android : $erreur');
    }
  }

  // PREFERENCES_REGIONALES_V1
  String langueInterface = 'fr';
  String deviseInterface = 'EUR';

  Future<void> chargerDonnees() async {
    try {
      final donneesBrutes = await StockageBudgetV2.charger();

      final donnees = GestionFeuillesMensuellesV2.preparerMigration(
        donnees: donneesBrutes,
        moisInitial: GestionFeuillesMensuellesV2.identifiant(DateTime.now()),
      );

      final corbeilleChargee = lireCorbeille(donnees['corbeilleMensuelle']);
      final moisCharge = donnees['moisActif'];

      if (moisCharge is! String) {
        throw const FormatException('Mois actif invalide');
      }

      GestionFeuillesMensuellesV2.dateDepuisIdentifiant(moisCharge);

      final feuillesBrutes = donnees['feuillesMensuelles'];

      if (feuillesBrutes is! Map) {
        throw const FormatException('Feuilles mensuelles invalides');
      }

      final feuillesChargees = <String, _BudgetMensuel>{};

      for (final entree in feuillesBrutes.entries) {
        if (entree.key is! String || entree.value is! Map) {
          throw const FormatException('Feuille mensuelle invalide');
        }

        final identifiant = entree.key as String;
        GestionFeuillesMensuellesV2.dateDepuisIdentifiant(identifiant);

        feuillesChargees[identifiant] = _BudgetMensuel.depuisFeuille(
          FeuilleMensuelleV2.fromJson(
            identifiant,
            Map<String, dynamic>.from(entree.value as Map),
          ),
        );
      }

      final moisEnregistres = feuillesChargees.keys.toList()..sort();
      final moisSelectionne = feuillesChargees.containsKey(moisCharge)
          ? moisCharge
          : moisEnregistres.isEmpty
          ? GestionFeuillesMensuellesV2.identifiant(DateTime.now())
          : moisEnregistres.lastWhere(
              (mois) => mois.compareTo(moisCharge) < 0,
              orElse: () => moisEnregistres.first,
            );
      final feuilleActive = feuillesChargees[moisSelectionne] ?? _budgetInitial;

      double lireReglagePalette(String cle, double defaut, double maximum) {
        final valeur = donnees[cle];
        if (valeur is num && valeur.isFinite) {
          return valeur.toDouble().clamp(0.0, maximum);
        }
        return defaut;
      }

      final accentInitial = widget.accentHSV;
      final accentCharge = HSVColor.fromAHSV(
        1,
        lireReglagePalette('teintePalette', accentInitial.hue, 360),
        lireReglagePalette('saturationPalette', accentInitial.saturation, 1),
        lireReglagePalette('luminositePalette', accentInitial.value, 1),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onAccent(accentCharge);
      });

      final ordreCharge = donnees['ordreBlocsAccueil'];
      var ordreValide = <int>[0, 1, 2, 5, 3, 4];

      if (ordreCharge is List &&
          ordreCharge.every((element) => element is int) &&
          ordreCharge.toSet().length == ordreCharge.length) {
        if (ordreCharge.length == 6 &&
            ordreCharge.toSet().containsAll([0, 1, 2, 3, 4, 5])) {
          ordreValide = List<int>.from(ordreCharge);
        } else if (ordreCharge.length == 5 &&
            ordreCharge.toSet().containsAll([0, 1, 2, 3, 4])) {
          ordreValide = List<int>.from(ordreCharge);
          ordreValide.insert(ordreValide.indexOf(2) + 1, 5);
        }
      }

      final masquesCharges = donnees['blocsAccueilMasques'];
      final masquesValides = <int>{};

      if (masquesCharges is List) {
        for (final id in masquesCharges) {
          if (id is int && id >= 0 && id < titresBlocsAccueil.length) {
            masquesValides.add(id);
          }
        }
      }

      if (masquesValides.length == titresBlocsAccueil.length) {
        masquesValides.remove(4);
      }

      final titres = <String>[];

      final anciensTitres = donnees['intitules'];

      if (anciensTitres is List) {
        for (final titre in anciensTitres) {
          if (titre is String && titre.trim().isNotEmpty) {
            titres.add(titre.trim());
          }
        }
      }

      for (final liste in feuilleActive.operations.values) {
        for (final operation in liste) {
          if (!titres.any(
            (titre) => titre.toLowerCase() == operation.intitule.toLowerCase(),
          )) {
            titres.add(operation.intitule);
          }
        }
      }

      if (!mounted) return;

      setState(() {
        intitulesMemorises
          ..clear()
          ..addAll(titres);

        moisActif = moisSelectionne;
        feuillesMensuelles.addAll(feuillesChargees);
        corbeilleMensuelle
          ..clear()
          ..addAll(corbeilleChargee);
        reconstruirePagesMensuelles();
        ordreBlocsAccueil = ordreValide;
        sidebarADroite = donnees['sidebarADroite'] == true;
        langueInterface = PreferencesRegionales.langueValide(
          donnees['langueInterface'],
          ancienneInstallation: donneesBrutes.isNotEmpty,
          langueSysteme:
              WidgetsBinding.instance.platformDispatcher.locale.languageCode,
        );
        deviseInterface = PreferencesRegionales.deviseValide(
          donnees['deviseInterface'],
        );
        blocsAccueilMasques = masquesValides;
        donneesChargees = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onLangue?.call(langueInterface);
          synchroniserCouleurWidget(accentCharge.toColor());
          lireDemandeWidget();
        }
      });
    } catch (erreur) {
      if (!mounted) return;

      setState(() {
        erreurChargement = true;
      });

      debugPrint('Chargement budget impossible : $erreur');
    }
  }

  void memoriserIntitule(String valeur) {
    final titre = valeur.trim();
    if (titre.isEmpty) return;

    intitulesMemorises.removeWhere(
      (element) => element.toLowerCase() == titre.toLowerCase(),
    );

    intitulesMemorises.insert(0, titre);
  }

  final Map<int, TriOperationsV2> tris = {
    0: TriOperationsV2.date,
    1: TriOperationsV2.date,
    2: TriOperationsV2.date,
    3: TriOperationsV2.date,
  };

  // INTERACTIONS_OPERATIONS_V2
  String libelleMois(String identifiant) {
    if (langueInterface != 'fr') {
      return PreferencesRegionales.formaterMois(
        GestionFeuillesMensuellesV2.dateDepuisIdentifiant(identifiant),
        langueInterface,
      );
    }
    const mois = [
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre',
    ];

    final date = GestionFeuillesMensuellesV2.dateDepuisIdentifiant(identifiant);
    return '${mois[date.month - 1]} ${date.year}';
  }

  String montantFormate(double montant) {
    return PreferencesRegionales.formaterMontant(
      montant,
      langueInterface,
      deviseInterface,
    );
  }

  String dateFormatee(DateTime date) {
    if (langueInterface != 'fr') {
      return PreferencesRegionales.formaterDate(date, langueInterface);
    }
    String deux(int valeur) => valeur.toString().padLeft(2, '0');

    return '${deux(date.day)}/${deux(date.month)}/${date.year}'
        '  ${deux(date.hour)}:${deux(date.minute)}';
  }

  List<OperationV2> operationsTriees(
    _BudgetMensuel budget,
    int page, {
    TriOperationsV2? triForce,
  }) {
    final resultat = List<OperationV2>.of(budget.operations[page]!);
    final tri = triForce ?? tris[page] ?? TriOperationsV2.date;

    switch (tri) {
      case TriOperationsV2.nature:
        final cles = {
          for (final operation in resultat)
            operation: operation.intituleNormalise,
        };
        resultat.sort((a, b) {
          final ordre = cles[a]!.compareTo(cles[b]!);
          return ordre == 0 ? b.date.compareTo(a.date) : ordre;
        });
      case TriOperationsV2.croissant:
        resultat.sort((a, b) => a.montant.compareTo(b.montant));
      case TriOperationsV2.decroissant:
        resultat.sort((a, b) => b.montant.compareTo(a.montant));
      case TriOperationsV2.date:
        resultat.sort((a, b) => b.date.compareTo(a.date));
    }

    return resultat;
  }

  Future<OperationV2?> formulaireOperation({OperationV2? operation}) async {
    final intituleControleur = TextEditingController(
      text: operation?.intitule ?? '',
    );

    final montantControleur = TextEditingController(
      text: operation == null
          ? ''
          : PreferencesRegionales.formaterSaisie(
              operation.montant,
              langueInterface,
            ),
    );

    String? erreur;

    try {
      return await showDialog<OperationV2>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, modifierDialogue) {
              return AlertDialog(
                backgroundColor: couleurBlocPalette(),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                title: Text(
                  operation == null
                      ? tr('Ajouter une opération')
                      : tr('Modifier une opération'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: montantControleur,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: tr('Montant'),
                          suffixText: deviseInterface == 'EUR'
                              ? '€'
                              : deviseInterface,
                          labelStyle: const TextStyle(color: Color(0xFFB8BEC8)),
                          filled: true,
                          fillColor: const Color(0xFF30343A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: intituleControleur,
                        onChanged: (_) => modifierDialogue(() {}),
                        autofocus: false,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: tr('Intitulé'),
                          labelStyle: const TextStyle(color: Color(0xFFB8BEC8)),
                          filled: true,
                          fillColor: const Color(0xFF30343A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      if (intitulesMemorises.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Builder(
                          builder: (context) {
                            final recherche = intituleControleur.text
                                .trim()
                                .toLowerCase();

                            final propositions = intitulesMemorises
                                .where(
                                  (titre) =>
                                      recherche.isEmpty ||
                                      titre.toLowerCase().contains(recherche),
                                )
                                .take(5)
                                .toList();

                            return Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                for (final titre in propositions)
                                  ActionChip(
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 0,
                                    ),
                                    labelPadding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    label: Text(
                                      titre,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    onPressed: () {
                                      intituleControleur.value =
                                          TextEditingValue(
                                            text: titre,
                                            selection: TextSelection.collapsed(
                                              offset: titre.length,
                                            ),
                                          );
                                      modifierDialogue(() {});
                                    },
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                      if (erreur != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          erreur!,
                          style: const TextStyle(
                            color: Color(0xFFFFA8A8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(tr('Annuler')),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.accent,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      final intitule = intituleControleur.text.trim();
                      final montant = double.tryParse(
                        montantControleur.text
                            .trim()
                            .replaceAll(' ', '')
                            .replaceAll(',', '.'),
                      );

                      if (intitule.isEmpty ||
                          montant == null ||
                          !montant.isFinite ||
                          montant <= 0) {
                        modifierDialogue(() {
                          erreur = tr('Intitulé et montant positif requis.');
                        });
                        return;
                      }

                      Navigator.pop(
                        dialogContext,
                        OperationV2(
                          intitule: intitule,
                          montant: montant,
                          date: operation?.date ?? DateTime.now(),
                        ),
                      );
                    },
                    child: Text(
                      operation == null ? tr('Ajouter') : tr('Enregistrer'),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        intituleControleur.dispose();
        montantControleur.dispose();
      });
    }
  }

  Future<void> _derniereEcriture = Future<void>.value();

  Future<void> enregistrerDonnees({
    String? moisSupprime,
    String? moisRestantActif,
    HSVColor? accentASauvegarder,
    Map<String, dynamic>? corbeilleASauvegarder,
    FeuilleMensuelleV2? feuilleARestaurer,
  }) {
    if (!donneesChargees ||
        erreurChargement ||
        (suppressionMensuelleEnCours &&
            moisSupprime == null &&
            corbeilleASauvegarder == null)) {
      return Future<void>.value();
    }

    final feuilles = {
      for (final entree in feuillesMensuelles.entries)
        if (entree.key != moisSupprime)
          entree.key: entree.value.versFeuille(entree.key).toJson(),
    };
    if (feuilleARestaurer != null) {
      if (feuilles.containsKey(feuilleARestaurer.mois)) {
        throw StateError('Une feuille existe déjà pour ce mois');
      }
      feuilles[feuilleARestaurer.mois] = feuilleARestaurer.toJson();
    }

    final moisASauvegarder = moisRestantActif ?? moisActif;
    final feuilleActive =
        feuilles[moisASauvegarder] ??
        _budgetInitial.versFeuille(moisASauvegarder).toJson();
    final accent = accentASauvegarder ?? widget.accentHSV;
    if (accentASauvegarder != null) {
      synchroniserCouleurWidget(accent.toColor());
    }
    final donnees = <String, dynamic>{
      ...feuilleActive,
      'intitules': List<String>.from(intitulesMemorises),
      'teintePalette': accent.hue,
      'saturationPalette': accent.saturation,
      'luminositePalette': accent.value,
      'sidebarADroite': sidebarADroite,
      'langueInterface': langueInterface,
      'deviseInterface': deviseInterface,
      'ordreBlocsAccueil': List<int>.from(ordreBlocsAccueil),
      'blocsAccueilMasques': blocsAccueilMasques.toList()..sort(),
      'moisActif': moisASauvegarder,
      'feuillesMensuelles': feuilles,
      'corbeilleMensuelle':
          corbeilleASauvegarder ??
          serialiserCorbeille(moisSupprime: moisSupprime),
    };

    final ecriture = _derniereEcriture
        .catchError((Object erreur) {
          debugPrint('Ecriture precedente echouee : $erreur');
        })
        .then((_) => StockageBudgetV2.enregistrer(donnees));

    _derniereEcriture = ecriture;

    ecriture.catchError((Object erreur) {
      debugPrint('Sauvegarde budget impossible : $erreur');
    });

    return ecriture;
  }

  Future<void> ajouterOperation() async {
    final budget = feuillesMensuelles[moisAffiche];
    if (budget == null) return;

    final destination = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: couleurBlocPalette(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('Nouvelle opération'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                for (final choix in [
                  (1, Icons.receipt_long_rounded, 'Dépense'),
                  (2, Icons.event_repeat_rounded, 'Charge fixe'),
                  (3, Icons.savings_rounded, 'Rentrée'),
                ])
                  ListTile(
                    leading: Icon(choix.$2, color: widget.accent),
                    title: Text(
                      tr(choix.$3),
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () => Navigator.pop(sheetContext, choix.$1),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (destination == null || !mounted) return;

    final resultat = await formulaireOperation();

    if (resultat == null || !mounted) return;

    setState(() {
      budget.operations[destination]!.add(resultat);
      memoriserIntitule(resultat.intitule);
    });

    await enregistrerDonnees();
  }

  // CHOIX_COULEUR_CHARGES_V1
  Future<void> choisirCouleurCharge(OperationV2 operation) async {
    final choix = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF25282D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (contexte) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('Couleur du groupe'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                operation.intitule,
                style: const TextStyle(color: Color(0xFFB0B6C0)),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (var i = 0; i < OperationV2.couleursGroupes.length; i++)
                    InkWell(
                      onTap: () => Navigator.pop(contexte, i),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: OperationV2.couleursGroupes[i],
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: operation.groupeCouleur == i
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: operation.groupeCouleur == i
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.black87,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => Navigator.pop(contexte, -1),
                icon: const Icon(Icons.format_color_reset_rounded),
                label: Text(tr('Retirer la couleur')),
              ),
            ],
          ),
        ),
      ),
    );

    if (choix == null || !mounted) return;

    setState(() {
      operation.groupeCouleur = choix < 0 ? null : choix;
    });

    await enregistrerDonnees();
  }

  Future<void> actionsOperation(
    _BudgetMensuel budget,
    OperationV2 operation,
  ) async {
    final pageSource = pageActive;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF25282D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Material(
          color: const Color(0xFF25282D),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    operation.intitule,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    leading: Icon(Icons.edit_rounded, color: widget.accent),
                    title: Text(
                      tr('Modifier'),
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () => Navigator.pop(sheetContext, 'modifier'),
                  ),
                  if (pageSource == 1)
                    ListTile(
                      leading: Icon(
                        Icons.event_repeat_rounded,
                        color: widget.accent,
                      ),
                      title: Text(
                        tr('Ajouter aux charges fixes'),
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () => Navigator.pop(sheetContext, 'charge'),
                    ),
                  if (pageSource == 2)
                    ListTile(
                      leading: const Icon(
                        Icons.palette_outlined,
                        color: Color(0xFFB0B6C0),
                      ),
                      title: Text(
                        tr('Couleur du groupe'),
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () => Navigator.pop(sheetContext, 'couleur'),
                    ),

                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFFF9999),
                    ),
                    title: Text(
                      tr('Effacer'),
                      style: TextStyle(color: Color(0xFFFF9999)),
                    ),
                    onTap: () => Navigator.pop(sheetContext, 'effacer'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'couleur' && pageSource == 2) {
      await choisirCouleurCharge(operation);
      return;
    }

    if (action == 'modifier') {
      final modification = await formulaireOperation(operation: operation);

      if (modification == null || !mounted) return;

      setState(() {
        operation.intitule = modification.intitule;
        memoriserIntitule(modification.intitule);
        operation.montant = modification.montant;
      });
      await enregistrerDonnees();
    }

    if (action == 'charge') {
      setState(() {
        budget.operations[2]!.add(
          OperationV2(
            intitule: operation.intitule,
            montant: operation.montant,
            date: DateTime.now(),
          ),
        );
      });
      await enregistrerDonnees();
    }

    if (action == 'effacer' && mounted) {
      final confirmer = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(tr('Effacer cette opération ?')),
            content: Text(operation.intitule),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(tr('Annuler')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(tr('Effacer')),
              ),
            ],
          );
        },
      );

      if (confirmer == true && mounted) {
        setState(() {
          budget.operations[pageSource]!.remove(operation);
        });
        await enregistrerDonnees();
      }
    }
  }

  // MULTISELECTION_DEPENSES_V1
  final Set<OperationV2> depensesSelectionnees = <OperationV2>{};

  Widget carteOperation(OperationV2 operation, int page) {
    final compacte = page == 1 || page == 2;
    final selectionnee = page == 1 && depensesSelectionnees.contains(operation);
    final marge = widget.sombre ? 9.0 : 6.0;

    return Container(
      margin: EdgeInsets.only(bottom: compacte ? marge * 0.7 : marge),
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: compacte ? (widget.sombre ? 4 : 2) : marge,
      ),
      decoration: widget.sombre
          ? _surfaceGraphite(
              rayon: 14,
              elevation: 2,
              accentActif: widget.accent,
              intensitePalette: selectionnee ? 0.40 : 0.25,
            )
          : BoxDecoration(
              color: couleurBlocPalette(),
              borderRadius: BorderRadius.circular(12),
              boxShadow: ombreBlocPalette(),
            ),
      child: LayoutBuilder(
        builder: (context, contraintes) => ConstrainedBox(
          constraints: BoxConstraints(minHeight: compacte ? 31 : 0),
          child: Row(
            children: [
              if (page == 1) ...[
                SizedBox(
                  width: 34,
                  height: 34,
                  child: Checkbox(
                    value: selectionnee,
                    activeColor: widget.accent,
                    checkColor: Colors.white,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    onChanged: (valeur) {
                      setState(() {
                        if (valeur == true) {
                          depensesSelectionnees.add(operation);
                        } else {
                          depensesSelectionnees.remove(operation);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 6),
              ],
              // BANDE_COULEUR_CHARGES_V1
              if (page == 2 && operation.groupeCouleur != null) ...[
                Container(
                  width: 5,
                  height: 29,
                  decoration: BoxDecoration(
                    color:
                        OperationV2.couleursGroupes[operation.groupeCouleur!],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      operation.intitule,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.sombre ? null : Colors.white,
                        fontSize: 14,
                        height: compacte ? 1.15 : null,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: compacte ? 1 : 2),
                    Text(
                      dateFormatee(operation.date),
                      style: TextStyle(
                        fontSize: 11,
                        height: compacte ? 1.15 : null,
                        color: widget.sombre
                            ? const Color(0xFF9299A3)
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: compacte
                      ? contraintes.maxWidth * 0.55
                      : double.infinity,
                ),
                child: Text(
                  montantFormate(operation.montant),
                  textAlign: compacte ? TextAlign.end : null,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: page == 1 || page == 2
                        ? (operation.montant >= 100
                              ? const Color(0xFFEF5350)
                              : operation.montant >= 50
                              ? const Color(0xFFFF8500)
                              : const Color(0xFFFFEB3B))
                        : widget.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget listeOperations(_BudgetMensuel budget) {
    final elements = operationsTriees(budget, pageActive);
    final triActuel = tris[pageActive] ?? TriOperationsV2.date;

    Widget boutonTri(String texte, TriOperationsV2 tri) {
      final actif = triActuel == tri;

      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: InkWell(
            onTap: () {
              setState(() {
                tris[pageActive] = tri;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 42,
              alignment: Alignment.center,
              decoration: _decorationTri(context, widget.accent, actif),
              // DEPENSES_ICONES_TRIS_V1
              child: tri == TriOperationsV2.nature
                  ? Text(
                      'ABC',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: actif
                            ? widget.accent
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    )
                  : Icon(
                      tri == TriOperationsV2.croissant
                          ? Icons.arrow_downward_rounded
                          : tri == TriOperationsV2.decroissant
                          ? Icons.arrow_upward_rounded
                          : Icons.calendar_month_rounded,
                      size: 30,
                      weight: 900,
                      color: actif
                          ? widget.accent
                          : Theme.of(context).colorScheme.onSurface,
                    ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        if (pageActive != 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
            child: Row(
              children: [
                boutonTri(tr('Croissant'), TriOperationsV2.croissant),
                boutonTri(tr('Décroissant'), TriOperationsV2.decroissant),
                boutonTri(tr('Date'), TriOperationsV2.date),
                if (pageActive == 1)
                  boutonTri(tr('Nature'), TriOperationsV2.nature),
              ],
            ),
          ),
        Expanded(
          child: elements.isEmpty
              ? const SizedBox.expand()
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    ListView.builder(
                      primary: false,
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
                      itemCount: elements.length,
                      itemBuilder: (context, index) {
                        final operation = elements[index];

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onLongPress: () =>
                              actionsOperation(budget, operation),
                          child: carteOperation(operation, pageActive),
                        );
                      },
                    ),
                    // FILTRE_DEPENSES_NOIR_30_V4
                    if (!widget.sombre && (pageActive == 1 || pageActive == 2))
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.30),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  static const titres = [
    'Accueil',
    'Dépenses',
    'Charges fixes',
    'Rentrées',
    'Statistique',
    'Paramètres',
  ];

  static const icones = [
    Icons.home_rounded,
    Icons.receipt_long_rounded,
    Icons.event_repeat_rounded,
    Icons.savings_rounded,
    Icons.bar_chart_rounded,
    Icons.settings_rounded,
  ];

  Color couleurBlocPalette() {
    final couleurReglee = widget.accentHSV
        .withValue(0.15 + widget.accentHSV.value * 0.70)
        .toColor();

    final fond = widget.sombre
        ? const Color(0xFF20242A)
        : const Color(0xFFD6D9DE);

    return Color.alphaBlend(
      couleurReglee.withValues(alpha: widget.sombre ? 0.21 : 0.65),
      fond,
    );
  }

  List<BoxShadow> ombreBlocPalette() {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: widget.sombre ? 0.36 : 0.18),
        blurRadius: 18,
        spreadRadius: 0.5,
        offset: const Offset(0, 6),
      ),
    ];
  }

  // SOUS_TOTAUX_COULEURS_V1
  Widget blocTotalPage(_BudgetMensuel budget) {
    final total = budget.totalOperations(pageActive);
    final afficherGroupes = pageActive == 2;

    final depensesDuMois = budget.operations[1]!;
    final selectionDuMois = depensesDuMois
        .where((operation) => depensesSelectionnees.contains(operation))
        .toList();
    final sousTotalSelection = selectionDuMois.fold<double>(
      0.0,
      (somme, operation) => somme + operation.montant,
    );
    final afficherSelection = pageActive == 1 && selectionDuMois.isNotEmpty;

    final sousTotaux = <int, double>{};

    if (afficherGroupes) {
      for (final operation in budget.operations[2]!) {
        final groupe = operation.groupeCouleur;
        if (groupe == null ||
            groupe < 0 ||
            groupe >= OperationV2.couleursGroupes.length) {
          continue;
        }

        sousTotaux[groupe] = (sousTotaux[groupe] ?? 0) + operation.montant;
      }
    }

    final groupesTries = sousTotaux.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: widget.sombre
            ? _surfaceGraphite(
                rayon: 18,
                elevation: 5,
                accentActif: widget.accent,
                intensitePalette: 0.25,
              )
            : BoxDecoration(
                color: couleurBlocPalette(),
                borderRadius: BorderRadius.circular(18),
                boxShadow: ombreBlocPalette(),
              ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: afficherGroupes
                  ? () {
                      setState(() {
                        sousTotauxCouleursOuverts = !sousTotauxCouleursOuverts;
                      });
                    }
                  : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            pageActive == 1 || pageActive == 2
                                ? tr('Total')
                                : tr('Total de la liste'),
                            style: TextStyle(
                              fontSize: 13,
                              color: widget.sombre
                                  ? Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                  : Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (afficherGroupes && groupesTries.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(
                            sousTotauxCouleursOuverts
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 19,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        montantFormate(total),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: pageActive == 1 || pageActive == 2
                              ? const Color(0xFFEF5350)
                              : widget.accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (afficherSelection) ...[
              const SizedBox(height: 14),
              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.18),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 19,
                    color: widget.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr('Sous-total sélection ({nombre})').replaceAll(
                        '{nombre}',
                        selectionDuMois.length.toString(),
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: widget.sombre
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    montantFormate(sousTotalSelection),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: widget.accent,
                    ),
                  ),
                ],
              ),
            ],
            if (afficherGroupes &&
                sousTotauxCouleursOuverts &&
                groupesTries.isNotEmpty) ...[
              const SizedBox(height: 14),
              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.18),
              ),
              const SizedBox(height: 12),
              for (final groupe in groupesTries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 24,
                        decoration: BoxDecoration(
                          color: OperationV2.couleursGroupes[groupe],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr('Groupe {nombre}')
                              .replaceAll('{nombre}', (groupe + 1).toString()),
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.sombre
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        montantFormate(sousTotaux[groupe]!),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: OperationV2.couleursGroupes[groupe],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> saisirSalaireEtReliquat(_BudgetMensuel budget) async {
    if (!donneesChargees || erreurChargement) return;

    String afficherValeur(double valeur) => valeur == 0
        ? ''
        : PreferencesRegionales.formaterSaisie(valeur, langueInterface);

    final controleurSalaire = TextEditingController(
      text: afficherValeur(budget.salaire),
    );
    final controleurReliquat = TextEditingController(
      text: afficherValeur(budget.reliquat),
    );

    String? erreurSalaire;
    String? erreurReliquat;

    double? lireMontant(String texte) {
      final normalise = texte
          .trim()
          .replaceAll(' ', '')
          .replaceAll('\u00A0', '')
          .replaceAll('\u202F', '')
          .replaceAll(',', '.');

      if (normalise.isEmpty) return 0.0;
      return double.tryParse(normalise);
    }

    try {
      final resultat = await showDialog<(double, double)>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, actualiser) => AlertDialog(
            backgroundColor: const Color(0xFF25282D),
            title: Text(
              tr('Salaire et reliquat'),
              style: TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controleurSalaire,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: tr('Salaire'),
                      suffixText: deviseInterface == 'EUR'
                          ? '€'
                          : deviseInterface,
                      errorText: erreurSalaire,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: controleurReliquat,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(
                      labelText: tr('Reliquat'),
                      suffixText: deviseInterface == 'EUR'
                          ? '€'
                          : deviseInterface,
                      errorText: erreurReliquat,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr(
                      'Le reliquat est ajouté au total disponible, sans modifier le reste sur salaire.',
                    ),
                    style: TextStyle(color: Color(0xFFB0B6C0), fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(tr('Annuler')),
              ),
              FilledButton(
                onPressed: () {
                  final salaire = lireMontant(controleurSalaire.text);
                  final reliquat = lireMontant(controleurReliquat.text);

                  final salaireValide =
                      salaire != null && salaire.isFinite && salaire >= 0;
                  final reliquatValide = reliquat != null && reliquat.isFinite;

                  if (!salaireValide || !reliquatValide) {
                    actualiser(() {
                      erreurSalaire = salaireValide
                          ? null
                          : tr('Montant positif ou zéro requis.');
                      erreurReliquat = reliquatValide
                          ? null
                          : tr('Montant valide requis.');
                    });
                    return;
                  }

                  Navigator.pop(dialogContext, (salaire, reliquat));
                },
                child: Text(tr('Enregistrer')),
              ),
            ],
          ),
        ),
      );

      if (resultat == null || !mounted) return;

      setState(() {
        budget.salaire = resultat.$1;
        budget.reliquat = resultat.$2;
      });

      await enregistrerDonnees();
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controleurSalaire.dispose();
        controleurReliquat.dispose();
      });
    }
  }

  Future<void> saisirMontantAccueil(_BudgetMensuel budget, String champ) async {
    if (!donneesChargees || erreurChargement) return;

    final valeurActuelle = switch (champ) {
      'salaire' => budget.salaire,
      'reliquat' => budget.reliquat,
      'epargne' => budget.epargne,
      _ => 0.0,
    };

    final controleur = TextEditingController(
      text: valeurActuelle == 0
          ? ''
          : PreferencesRegionales.formaterSaisie(
              valeurActuelle,
              langueInterface,
            ),
    );

    final montantSigne = champ == 'reliquat';
    String? erreur;

    try {
      final montant = await showDialog<double>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, actualiser) => AlertDialog(
            backgroundColor: const Color(0xFF25282D),
            title: Text(
              tr(switch (champ) {
                'salaire' => 'Salaire',
                'reliquat' => 'Reliquat',
                _ => 'Épargne',
              }),
              style: const TextStyle(color: Colors.white),
            ),
            content: TextField(
              controller: controleur,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.numberWithOptions(
                decimal: true,
                signed: montantSigne,
              ),
              decoration: InputDecoration(
                labelText: tr('Montant'),
                suffixText: deviseInterface == 'EUR' ? '€' : deviseInterface,
                errorText: erreur,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(tr('Annuler')),
              ),
              FilledButton(
                onPressed: () {
                  final valeur = double.tryParse(
                    controleur.text
                        .trim()
                        .replaceAll(' ', '')
                        .replaceAll(',', '.'),
                  );

                  if (valeur == null ||
                      !valeur.isFinite ||
                      (!montantSigne && valeur < 0)) {
                    actualiser(() {
                      erreur = montantSigne
                          ? tr('Montant valide requis.')
                          : tr('Montant positif ou zéro requis.');
                    });
                    return;
                  }

                  Navigator.pop(dialogContext, valeur);
                },
                child: Text(tr('Enregistrer')),
              ),
            ],
          ),
        ),
      );

      if (montant == null || !mounted) return;

      setState(() {
        switch (champ) {
          case 'salaire':
            budget.salaire = montant;
          case 'reliquat':
            budget.reliquat = montant;
          case 'epargne':
            budget.epargne = montant;
        }
      });

      await enregistrerDonnees();
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controleur.dispose();
      });
    }
  }

  static const double _hauteurEnteteMensuelle = 68;
  static const double _margeHauteEnteteAccueilSombre = 16;

  // TEXTES_BLANCS_THEME_CLAIR_V1
  Widget blocAccueilFinancier({
    required String titre,
    required double montant,
    required Color couleurMontant,
    required IconData icone,
    VoidCallback? onTap,
  }) {
    final sombre = widget.sombre;
    return SizedBox(
      height: sombre ? _hauteurCarteAccueilSombre : 52,
      child: _SurfaceFinanciere(
        sombre: sombre,
        rayon: sombre ? 14 : 16,
        couleurClaire: couleurBlocPalette(),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  icone,
                  color: sombre ? _refletAccent(widget.accent) : widget.accent,
                  size: sombre ? 25 : 23,
                  shadows: sombre
                      ? [
                          Shadow(
                            color: widget.accent.withValues(alpha: 0.42),
                            blurRadius: 3,
                          ),
                        ]
                      : null,
                ),
                SizedBox(width: sombre ? 10 : 12),
                Expanded(
                  flex: sombre ? 6 : 1,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      titre,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: sombre ? null : Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: sombre ? 5 : 1,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      montantFormate(montant),
                      style: TextStyle(
                        fontSize: sombre ? 16 : 18,
                        fontWeight: FontWeight.w700,
                        color: couleurMontant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget pageAccueilFinancier(_BudgetMensuel budget) {
    final depenses = budget.totalOperations(1);
    final charges = budget.totalOperations(2);
    final totalDisponible = FeuilleMensuelleV2.calculerTotalDisponible(
      salaire: budget.salaire,
      reliquat: budget.reliquat,
      depenses: depenses,
      charges: charges,
    );
    final resteSurSalaire = budget.salaire - charges - depenses;

    // COULEUR_RESTE_SALAIRE_V1
    // Vert a 100 %, jaune a 50 %, orange a 25 %, rouge a 0 %.
    Color couleurResteSalaire() {
      if (budget.salaire <= 0 || resteSurSalaire <= 0) {
        return const Color(0xFFE64A4A);
      }

      final proportion = (resteSurSalaire / budget.salaire).clamp(0.0, 1.0);

      const couleurs = <Color>[
        Color(0xFFE64A4A),
        Color(0xFFF28B38),
        Color(0xFFF3D34D),
        Color(0xFFB5D944),
        Color(0xFF29B765),
      ];

      const positions = <double>[0.0, 0.25, 0.50, 0.75, 1.0];

      for (var i = 0; i < positions.length - 1; i++) {
        if (proportion <= positions[i + 1]) {
          final progression =
              (proportion - positions[i]) / (positions[i + 1] - positions[i]);

          return Color.lerp(couleurs[i], couleurs[i + 1], progression)!;
        }
      }

      return couleurs.last;
    }

    Widget construireBloc(int identifiant) {
      switch (identifiant) {
        case 0:
          return blocAccueilFinancier(
            titre: tr('Salaire'),
            montant: budget.salaire,
            couleurMontant: const Color(0xFF64B5F6),
            icone: widget.sombre
                ? Icons.monetization_on_outlined
                : Icons.payments_rounded,
            onTap: () => saisirSalaireEtReliquat(budget),
          );
        case 1:
          return blocAccueilFinancier(
            titre: tr('Reste sur salaire'),
            montant: resteSurSalaire,
            couleurMontant: couleurResteSalaire(),
            icone: widget.sombre
                ? Icons.account_balance_wallet_outlined
                : Icons.account_balance_wallet_rounded,
          );
        case 2:
          return blocAccueilFinancier(
            titre: tr('Total dépenses'),
            montant: depenses,
            couleurMontant: const Color(0xFFEF5350),
            icone: widget.sombre
                ? Icons.equalizer_rounded
                : Icons.receipt_long_rounded,
          );
        case 3:
          return blocAccueilFinancier(
            titre: tr('Épargne'),
            montant: budget.epargne,
            couleurMontant: widget.sombre
                ? const Color(0xFF73CE69)
                : const Color(0xFF29B765),
            icone: widget.sombre
                ? Icons.savings_outlined
                : Icons.savings_rounded,
            onTap: () => saisirMontantAccueil(budget, 'epargne'),
          );
        case 4:
          return blocAccueilFinancier(
            titre: tr('Total disponible'),
            montant: totalDisponible,
            couleurMontant: totalDisponible < 0
                ? const Color(0xFFE64A4A)
                : widget.sombre
                ? const Color(0xFFA9D957)
                : const Color(0xFF29B765),
            icone: Icons.add_card_rounded,
            onTap: () => saisirMontantAccueil(budget, 'reliquat'),
          );
        case 5:
          return blocAccueilFinancier(
            titre: tr('Total charges fixes'),
            montant: charges,
            couleurMontant: const Color(0xFFEF5350),
            icone: Icons.calendar_month_outlined,
          );
        default:
          return const SizedBox.shrink();
      }
    }

    final espacement = widget.sombre ? 7.0 : 10.0;
    final visibles = blocsAccueilVisibles;

    return LayoutBuilder(
      builder: (context, contraintes) {
        final nombreCartes = visibles.length;

        final hauteurCarte = widget.sombre ? _hauteurCarteAccueilSombre : 52.0;

        final hauteurCartes =
            nombreCartes * hauteurCarte + (nombreCartes - 1) * espacement;

        final hauteurReservee =
            _hauteurEnteteMensuelle + _margeHauteEnteteAccueilSombre;

        final margeCentree =
            (contraintes.maxHeight - hauteurReservee - hauteurCartes) / 2;

        final margeHaute = margeCentree.clamp(8.0, double.infinity).toDouble();

        return ReorderableListView.builder(
          primary: false,
          padding: EdgeInsets.fromLTRB(
            14,
            margeHaute,
            widget.sombre ? 12 : 14,
            84,
          ),
          buildDefaultDragHandles: false,
          itemCount: visibles.length,
          onReorderItem: (ancienIndex, nouvelIndex) {
            setState(() {
              final nouvelOrdre = List<int>.from(visibles);
              final bloc = nouvelOrdre.removeAt(ancienIndex);
              nouvelOrdre.insert(nouvelIndex, bloc);

              var indexVisible = 0;

              ordreBlocsAccueil = [
                for (final id in ordreBlocsAccueil)
                  if (blocsAccueilMasques.contains(id))
                    id
                  else
                    nouvelOrdre[indexVisible++],
              ];
            });

            enregistrerDonnees();
          },
          itemBuilder: (context, index) {
            final identifiant = visibles[index];

            return ReorderableDelayedDragStartListener(
              key: ValueKey('bloc_accueil_$identifiant'),
              index: index,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: index == visibles.length - 1 ? 0 : espacement,
                ),
                child: construireBloc(identifiant),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> confirmerSuppression({
    required String titre,
    required String description,
    required String action,
  }) async {
    final resultat = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(titre),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr('Annuler')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action),
            ),
          ],
        );
      },
    );

    return resultat == true;
  }

  Future<void> remettreMoisAZero(String mois) async {
    final budget = feuillesMensuelles[mois];
    if (budget == null) return;

    final confirme = await confirmerSuppression(
      titre: tr('Remettre ce mois à zéro ?'),
      description: tr(
        'La feuille de {mois} sera conservée. Toutes ses dépenses, charges fixes et rentrées seront supprimées. Le salaire, l’épargne et le reliquat seront remis à zéro.',
      ).replaceAll('{mois}', libelleMois(mois)),
      action: tr('Remettre ce mois à zéro'),
    );
    if (!mounted ||
        !confirme ||
        suppressionMensuelleEnCours ||
        feuillesMensuelles[mois] != budget) {
      return;
    }

    setState(() {
      for (final operations in budget.operations.values) {
        operations.clear();
      }
      budget.salaire = 0;
      budget.epargne = 0;
      budget.reliquat = 0;
    });

    try {
      await enregistrerDonnees();
    } catch (erreur) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr("Sauvegarde impossible")} : $erreur')),
      );
    }
  }

  Future<void> supprimerMois(String mois) async {
    if (creationMensuelleEnCours ||
        suppressionMensuelleEnCours ||
        !feuillesMensuelles.containsKey(mois)) {
      return;
    }

    final confirme = await confirmerSuppression(
      titre: tr('Supprimer ce mois ?'),
      description: tr(
        'La feuille de {mois} et toutes ses données seront placées dans la corbeille pendant 30 jours.',
      ).replaceAll('{mois}', libelleMois(mois)),
      action: tr('Supprimer ce mois'),
    );
    if (!mounted ||
        !confirme ||
        creationMensuelleEnCours ||
        suppressionMensuelleEnCours ||
        !feuillesMensuelles.containsKey(mois)) {
      return;
    }

    final moisRestants =
        feuillesMensuelles.keys.where((cle) => cle != mois).toList()..sort();
    final destination = moisRestants.isEmpty
        ? GestionFeuillesMensuellesV2.identifiant(DateTime.now())
        : moisRestants.lastWhere(
            (cle) => cle.compareTo(mois) < 0,
            orElse: () => moisRestants.first,
          );

    final nouvelleCorbeille = serialiserCorbeille(moisSupprime: mois);
    final corbeilleValidee = lireCorbeille(nouvelleCorbeille);

    setState(() => suppressionMensuelleEnCours = true);
    try {
      await enregistrerDonnees(
        moisSupprime: mois,
        moisRestantActif: destination,
        corbeilleASauvegarder: nouvelleCorbeille,
      );
      if (!mounted) return;
      setState(() {
        depensesSelectionnees.removeAll(
          feuillesMensuelles[mois]!.operations[1]!,
        );
        feuillesMensuelles.remove(mois);
        corbeilleMensuelle
          ..clear()
          ..addAll(corbeilleValidee);
        moisActif = destination;
        reconstruirePagesMensuelles();
        reinitialiserOptionsImport();
      });
    } catch (erreur) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr("Suppression impossible")} : $erreur')),
      );
    } finally {
      if (mounted) setState(() => suppressionMensuelleEnCours = false);
    }
  }

  Widget resultatsRechercheStatistique(String terme) {
    final lignes = [
      for (final feuille in feuillesMensuelles.entries)
        for (final page in [1, 2, 3])
          for (final op in feuille.value.operations[page]!)
            if (op.intituleNormalise.contains(terme))
              (mois: feuille.key, page: page, operation: op),
    ]..sort((a, b) => b.operation.date.compareTo(a.operation.date));

    if (lignes.isEmpty) {
      return Center(child: Text(tr('Aucune opération trouvée')));
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: lignes.length,
      itemBuilder: (context, index) {
        final ligne = lignes[index];
        final theme = Theme.of(context);
        final tuile = ListTile(
          minTileHeight: 50.4,
          minVerticalPadding: 3,
          title: LayoutBuilder(
            builder: (context, contraintes) => Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ligne.operation.intitule),
                      Text(
                        '${libelleMois(ligne.mois)} · ${tr(titres[ligne.page])}',
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: contraintes.maxWidth * 0.55,
                  ),
                  child: Text(
                    montantFormate(ligne.operation.montant),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelSmall!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          onTap: () async {
            FocusScope.of(context).unfocus();
            setState(() {
              moisActif = ligne.mois;
              pageActive = ligne.page;
              reconstruirePagesMensuelles();
            });
            await enregistrerDonnees();
          },
        );
        if (!widget.sombre) return tuile;

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 2.1, 14, 3.5),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: _surfaceGraphite(
                rayon: 14,
                accentActif: widget.accent,
                intensitePalette: 0.25,
              ),
              child: tuile,
            ),
          ),
        );
      },
    );
  }

  Widget pageStatistique(String mois) {
    int numero(String cle) {
      final date = GestionFeuillesMensuellesV2.dateDepuisIdentifiant(cle);
      return (date.year - 1) * 12 + date.month - 1;
    }

    final budgets = <int, _BudgetMensuel>{
      for (final feuille in feuillesMensuelles.entries)
        numero(feuille.key): feuille.value,
    };
    final totaux = {
      for (final entree in budgets.entries)
        entree.key: entree.value.totalOperations(1),
    };
    // Un nouveau rendu de StructureV2 recrée ce cache après une mutation.
    final depensesTriees = <(int, TriOperationsV2), List<OperationV2>>{};

    return _RechercheStatistique(
      accent: widget.accent,
      resultats: resultatsRechercheStatistique,
      graphique: _BilanFrise(
        detailsMois: (n, tri) {
          final budget = budgets[n];
          if (budget == null || budget.operations[1]!.isEmpty) {
            return SliverToBoxAdapter(
              child: Text(
                budget == null
                    ? tr('Aucune feuille pour ce mois')
                    : tr('Aucune dépense pour ce mois'),
              ),
            );
          }
          final depenses = depensesTriees.putIfAbsent((
            n,
            tri,
          ), () => operationsTriees(budget, 1, triForce: tri));
          return SliverList.builder(
            itemCount: depenses.length,
            itemBuilder: (context, index) => carteOperation(depenses[index], 1),
          );
        },
        // SOUS_TOTAL_STATISTIQUES_V1
        sousTotalMois: (n) {
          final budget = budgets[n];

          if (budget == null) {
            return const SizedBox.shrink();
          }

          final selection = budget.operations[1]!
              .where((operation) => depensesSelectionnees.contains(operation))
              .toList();

          if (selection.isEmpty) {
            return const SizedBox.shrink();
          }

          final total = selection.fold<double>(
            0.0,
            (somme, operation) => somme + operation.montant,
          );

          return Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: widget.sombre
                  ? _surfaceGraphite(
                      rayon: 14,
                      accentActif: widget.accent,
                      intensitePalette: 0.40,
                    )
                  : BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: widget.accent.withValues(alpha: 0.25),
                      ),
                    ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: widget.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr('Sous-total sélection ({nombre})')
                          .replaceAll('{nombre}', selection.length.toString()),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    montantFormate(total),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: widget.accent,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        moisInitial: numero(mois),
        totaux: totaux,
        accent: widget.accent,
        montantFormate: montantFormate,
      ),
    );
  }

  Widget menuActionsMois(String mois) {
    return PopupMenuButton<({String action, String mois})>(
      tooltip: tr('Options de la feuille'),
      color: Color.lerp(couleurBlocPalette(), Colors.white, 0.12)!,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 310),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      enabled:
          donneesChargees &&
          !erreurChargement &&
          !creationMensuelleEnCours &&
          !suppressionMensuelleEnCours &&
          feuillesMensuelles.containsKey(mois),
      icon: Icon(
        Icons.more_vert_rounded,
        color: widget.sombre ? _refletAccent(widget.accent) : widget.accent,
        size: widget.sombre ? 22 : 27,
      ),
      onSelected: (choix) {
        if (choix.action == 'supprimer') {
          supprimerMois(choix.mois);
        } else {
          remettreMoisAZero(choix.mois);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: (action: 'supprimer', mois: mois),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFFFB4B4),
                size: 19,
              ),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  tr('Supprimer ce mois'),
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: (action: 'zero', mois: mois),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.restart_alt_rounded, color: widget.accent, size: 19),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  tr('Remettre ce mois à zéro'),
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget pageBudget(_BudgetMensuel budget) {
    if (pageActive == 0 || pageActive >= 4) return pageAccueilFinancier(budget);

    final total = blocTotalPage(budget);
    final operations = listeOperations(budget);
    if (!widget.sombre) {
      return Column(
        children: [
          total,
          Expanded(child: operations),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, contraintes) => Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: contraintes.maxHeight * 0.48,
            ),
            child: SingleChildScrollView(primary: false, child: total),
          ),
          Expanded(child: operations),
        ],
      ),
    );
  }

  // INTERFACE_CORBEILLE_V1

  bool get corbeilleDisponible =>
      donneesChargees &&
      !erreurChargement &&
      !creationMensuelleEnCours &&
      !suppressionMensuelleEnCours;

  Future<void> modifierCorbeille(
    String identifiant, {
    required bool restaurer,
  }) async {
    if (!corbeilleDisponible) return;

    final entree = corbeilleMensuelle[identifiant];
    if (entree == null) return;

    if (!entreeCorbeilleValide(entree.suppression, DateTime.now().toUtc())) {
      setState(() {});
      return;
    }

    if (restaurer && feuillesMensuelles.containsKey(entree.mois)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Ce mois existe déjà. Aucun remplacement effectué.'),
          ),
        ),
      );
      return;
    }

    if (!restaurer) {
      final confirmation = await showDialog<bool>(
        context: context,
        builder: (contexte) => AlertDialog(
          title: Text(tr('Suppression définitive')),
          content: Text(
            tr('Supprimer définitivement {mois} de la corbeille ?')
                .replaceAll('{mois}', libelleMois(entree.mois)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contexte, false),
              child: Text(tr('Annuler')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(contexte, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(contexte).colorScheme.error,
              ),
              child: Text(tr('Supprimer')),
            ),
          ],
        ),
      );

      if (confirmation != true || !mounted || !corbeilleDisponible) {
        return;
      }
    }

    if (!entreeCorbeilleValide(entree.suppression, DateTime.now().toUtc())) {
      setState(() {});
      return;
    }

    if (restaurer && feuillesMensuelles.containsKey(entree.mois)) return;

    final nouvelleCorbeille = serialiserCorbeille()..remove(identifiant);

    final budgetRestaure = restaurer
        ? _BudgetMensuel.depuisFeuille(entree.feuille)
        : null;

    final corbeilleValidee = lireCorbeille(nouvelleCorbeille);

    setState(() => suppressionMensuelleEnCours = true);

    try {
      await enregistrerDonnees(
        corbeilleASauvegarder: nouvelleCorbeille,
        feuilleARestaurer: restaurer ? entree.feuille : null,
        moisRestantActif: restaurer ? entree.mois : null,
      );

      if (!mounted) return;

      setState(() {
        corbeilleMensuelle
          ..clear()
          ..addAll(corbeilleValidee);

        if (budgetRestaure != null) {
          feuillesMensuelles[entree.mois] = budgetRestaure;
          moisActif = entree.mois;
          reconstruirePagesMensuelles();
          reinitialiserOptionsImport();
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restaurer
                ? tr('{mois} restauré')
                      .replaceAll('{mois}', libelleMois(entree.mois))
                : tr('{mois} supprimé de la corbeille')
                      .replaceAll('{mois}', libelleMois(entree.mois)),
          ),
        ),
      );
    } catch (erreur) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr("Action impossible")} : $erreur')),
      );
    } finally {
      if (mounted) {
        setState(() => suppressionMensuelleEnCours = false);
      }
    }
  }

  Widget blocCorbeilleMensuelle() {
    final maintenant = DateTime.now().toUtc();

    final entrees =
        corbeilleMensuelle.entries
            .where(
              (entree) =>
                  entreeCorbeilleValide(entree.value.suppression, maintenant),
            )
            .toList()
          ..sort((a, b) => b.value.suppression.compareTo(a.value.suppression));

    final couleurTexte = Theme.of(context).colorScheme.onSurface;
    final couleurSecondaire = Theme.of(context).colorScheme.onSurfaceVariant;

    return Material(
      color: widget.sombre
          ? const Color(0xFF24262A)
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      elevation: widget.sombre ? 5 : 6,
      surfaceTintColor: widget.sombre ? Colors.transparent : null,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: widget.sombre ? _surfaceGraphite(rayon: 18) : null,
        child: ExpansionTile(
          key: const PageStorageKey('corbeille-mensuelle'),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Icon(Icons.delete_outline_rounded, color: widget.accent),
          title: Text(
            tr('Corbeille'),
            style: TextStyle(
              color: couleurTexte,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            entrees.isEmpty
                ? tr('Vide')
                : tr('{nombre} mois supprimé(s)')
                      .replaceAll('{nombre}', entrees.length.toString()),
            style: TextStyle(color: couleurSecondaire),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            Text(
              tr('Les mois supprimés sont restaurables pendant 30 jours.'),
              style: TextStyle(color: couleurSecondaire, fontSize: 12),
            ),
            for (final entree in entrees) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: widget.sombre
                    ? _surfaceGraphite(rayon: 12)
                    : BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      libelleMois(entree.value.mois),
                      style: TextStyle(
                        color: couleurTexte,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr('Supprimé le {date}').replaceAll(
                        '{date}',
                        dateFormatee(entree.value.suppression.toLocal()),
                      ),
                      style: TextStyle(color: couleurSecondaire, fontSize: 12),
                    ),
                    Text(
                      tr('{nombre} jour(s) restant(s)').replaceAll(
                        '{nombre}',
                        (entree.value.suppression
                                    .add(dureeCorbeille)
                                    .difference(maintenant)
                                    .inSeconds /
                                86400)
                            .ceil()
                            .toString(),
                      ),
                      style: TextStyle(color: couleurSecondaire, fontSize: 12),
                    ),
                    if (feuillesMensuelles.containsKey(entree.value.mois))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          tr('Ce mois existe déjà. Restauration indisponible.'),
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed:
                              corbeilleDisponible &&
                                  !feuillesMensuelles.containsKey(
                                    entree.value.mois,
                                  )
                              ? () => modifierCorbeille(
                                  entree.key,
                                  restaurer: true,
                                )
                              : null,
                          icon: const Icon(Icons.restore_rounded, size: 18),
                          label: Text(tr('Restaurer')),
                          style: TextButton.styleFrom(
                            foregroundColor: widget.accent,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: corbeilleDisponible
                              ? () => modifierCorbeille(
                                  entree.key,
                                  restaurer: false,
                                )
                              : null,
                          icon: const Icon(
                            Icons.delete_forever_outlined,
                            size: 18,
                          ),
                          label: Text(tr('Supprimer')),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context)
                                .colorScheme
                                .error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget panneauBlocsAccueil() {
    final nombreVisibles = blocsAccueilVisibles.length;

    return Material(
      color: widget.sombre ? const Color(0xFF24262A) : couleurBlocPalette(),
      borderRadius: BorderRadius.circular(18),
      elevation: widget.sombre ? 5 : 6,
      surfaceTintColor: widget.sombre ? Colors.transparent : null,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: widget.sombre ? _surfaceGraphite(rayon: 18) : null,
        child: ExpansionTile(
          key: const PageStorageKey('personnalisation-accueil'),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Icon(
            Icons.dashboard_customize_outlined,
            color: widget.accent,
          ),
          title: Text(
            tr('Blocs de l’accueil'),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            tr('{nombre} sur 6 affichés')
                .replaceAll('{nombre}', nombreVisibles.toString()),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            for (final id in ordreBlocsAccueil)
              SwitchListTile(
                key: ValueKey('visibilite_accueil_$id'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(tr(titresBlocsAccueil[id])),
                value: !blocsAccueilMasques.contains(id),
                activeTrackColor: widget.accent,
                onChanged:
                    !donneesChargees ||
                        erreurChargement ||
                        creationMensuelleEnCours ||
                        suppressionMensuelleEnCours ||
                        (nombreVisibles == 1 &&
                            !blocsAccueilMasques.contains(id))
                    ? null
                    : (visible) async {
                        setState(() {
                          if (visible) {
                            blocsAccueilMasques.remove(id);
                          } else {
                            blocsAccueilMasques.add(id);
                          }
                        });

                        try {
                          await enregistrerDonnees();
                        } catch (erreur) {
                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${tr("Sauvegarde impossible")} : $erreur',
                              ),
                            ),
                          );
                        }
                      },
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                tr(
                  'Un appui prolongé sur un bloc de l’accueil permet de modifier son emplacement.',
                ),
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // PANNEAU_LANGUE_DEVISE_V1
  Future<void> choisirLangueInterface() async {
    if (!donneesChargees ||
        erreurChargement ||
        suppressionMensuelleEnCours ||
        creationMensuelleEnCours)
      return;

    final selection = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(tr('Langue')),
        children: [
          for (final langue in PreferencesRegionales.langues.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(langue.key),
              child: Row(
                children: [
                  Expanded(child: Text(langue.value)),
                  if (langue.key == langueInterface)
                    Icon(Icons.check_rounded, color: widget.accent),
                ],
              ),
            ),
        ],
      ),
    );

    if (!mounted || selection == null || selection == langueInterface) return;

    final precedente = langueInterface;

    setState(() => langueInterface = selection);
    widget.onLangue?.call(selection);

    try {
      await enregistrerDonnees();
    } catch (_) {
      if (!mounted) return;
      setState(() => langueInterface = precedente);
      widget.onLangue?.call(precedente);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('Sauvegarde impossible'))));
    }
  }

  // SELECTEUR_DEVISE_V1
  Future<void> choisirDeviseInterface() async {
    if (!donneesChargees ||
        erreurChargement ||
        suppressionMensuelleEnCours ||
        creationMensuelleEnCours)
      return;

    String recherche = '';

    final catalogue = <String>[
      ...PreferencesRegionales.devisesPrincipales,
      ...PreferencesRegionales.devises.where(
        (code) => !PreferencesRegionales.devisesPrincipales.contains(code),
      ),
    ];

    final selection = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, actualiser) {
          final filtre = recherche.trim().toUpperCase();
          final resultats = catalogue
              .where((code) => code.contains(filtre))
              .toList();

          return AlertDialog(
            title: Text(tr('Devise')),
            content: SizedBox(
              width: 340,
              height: MediaQuery.sizeOf(dialogContext).height * 0.45,
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: tr('Rechercher une devise'),
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (texte) {
                      actualiser(() => recherche = texte);
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: resultats.length,
                      itemBuilder: (context, index) {
                        final code = resultats[index];

                        return ListTile(
                          title: Text(code),
                          trailing: code == deviseInterface
                              ? Icon(Icons.check_rounded, color: widget.accent)
                              : null,
                          onTap: () => Navigator.of(dialogContext).pop(code),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('Les montants ne sont pas convertis.'),
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(tr('Annuler')),
              ),
            ],
          );
        },
      ),
    );

    if (!mounted || selection == null || selection == deviseInterface) return;

    final precedente = deviseInterface;

    setState(() => deviseInterface = selection);

    try {
      await enregistrerDonnees();
    } catch (_) {
      if (!mounted) return;
      setState(() => deviseInterface = precedente);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('Sauvegarde impossible'))));
    }
  }

  // TRADUCTION_CORBEILLE_V1
  // TRADUCTION_MENSUELLE_V1
  // TRADUCTION_ACTIONS_V1
  // TRADUCTION_FINANCIERE_V1
  // TRADUCTION_INTERFACE_V1
  String tr(String texte) {
    return Traductions.traduire(langueInterface, texte);
  }

  Widget panneauPreferencesRegionales() {
    final couleurTexte = widget.sombre ? const Color(0xFFF1F3F5) : Colors.white;

    return Material(
      color: widget.sombre ? const Color(0xFF24262A) : couleurBlocPalette(),
      borderRadius: BorderRadius.circular(18),
      elevation: widget.sombre ? 5 : 6,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: widget.sombre ? _surfaceGraphite(rayon: 18) : null,
        child: ExpansionTile(
          key: const ValueKey('langue-devise'),
          iconColor: couleurTexte,
          collapsedIconColor: couleurTexte,
          leading: Icon(Icons.language_rounded, color: couleurTexte),
          title: Text(
            tr('Langue et devise'),
            style: TextStyle(color: couleurTexte, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${PreferencesRegionales.langues[langueInterface]} - $deviseInterface',
            style: TextStyle(color: couleurTexte.withValues(alpha: 0.75)),
          ),
          children: [
            ListTile(
              onTap: choisirLangueInterface,
              leading: Icon(Icons.translate_rounded, color: couleurTexte),
              title: Text(tr('Langue'), style: TextStyle(color: couleurTexte)),
              subtitle: Text(
                PreferencesRegionales.langues[langueInterface]!,
                style: TextStyle(color: couleurTexte),
              ),
            ),
            ListTile(
              onTap: choisirDeviseInterface,
              leading: Icon(
                Icons.currency_exchange_rounded,
                color: couleurTexte,
              ),
              title: Text(tr('Devise'), style: TextStyle(color: couleurTexte)),
              subtitle: Text(
                deviseInterface,
                style: TextStyle(color: couleurTexte),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget pageParametres() {
    final accent = widget.accentHSV;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        blocCorbeilleMensuelle(),
        const SizedBox(height: 14),
        panneauBlocsAccueil(),
        const SizedBox(height: 14),
        panneauPreferencesRegionales(),
        const SizedBox(height: 14),
        Material(
          color: widget.sombre ? const Color(0xFF24262A) : couleurBlocPalette(),
          borderRadius: BorderRadius.circular(18),
          elevation: widget.sombre ? 5 : 6,
          surfaceTintColor: widget.sombre ? Colors.transparent : null,
          shadowColor: Colors.black.withValues(
            alpha: widget.sombre ? 0.42 : 0.24,
          ),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: widget.sombre ? _surfaceGraphite(rayon: 18) : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Apparence'),
                    style: TextStyle(
                      color: widget.sombre ? null : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      tr('Thème sombre'),
                      style: TextStyle(
                        color: widget.sombre ? null : Colors.white,
                      ),
                    ),
                    value: widget.sombre,
                    onChanged: widget.onTheme,
                  ),
                  // SIDEBAR_POSITION_PARAMETRES_V1
                  SwitchListTile(
                    key: const ValueKey('sidebar-position'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      tr('Barre latérale à droite'),
                      style: TextStyle(
                        color: widget.sombre ? null : Colors.white,
                      ),
                    ),
                    value: sidebarADroite,
                    activeTrackColor: widget.accent,
                    onChanged:
                        !donneesChargees ||
                            erreurChargement ||
                            suppressionMensuelleEnCours ||
                            creationMensuelleEnCours
                        ? null
                        : (valeur) async {
                            setState(() => sidebarADroite = valeur);
                            try {
                              await enregistrerDonnees();
                            } catch (_) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(tr('Sauvegarde impossible')),
                                ),
                              );
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('Couleur d’accent'),
                    style: TextStyle(
                      color: widget.sombre ? null : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tr("Teinte")} : ${accent.hue.round()}°',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: widget.sombre ? null : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: 12,
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: [
                                  for (int i = 0; i <= 12; i++)
                                    HSVColor.fromAHSV(
                                      1.0,
                                      i * 30.0,
                                      1.0,
                                      1.0,
                                    ).toColor(),
                                ],
                              ),
                            ),
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.transparent,
                              inactiveTrackColor: Colors.transparent,
                              trackHeight: 12,
                              thumbColor: widget.accent,
                              overlayColor: widget.accent.withValues(
                                alpha: 0.15,
                              ),
                            ),
                            child: Slider(
                              value: accent.hue,
                              min: 0,
                              max: 360,
                              divisions: 360,
                              label: '${accent.hue.round()}°',
                              onChanged: (valeur) =>
                                  widget.onAccent(accent.withHue(valeur)),
                              onChangeEnd: (valeur) => enregistrerDonnees(
                                accentASauvegarder: accent.withHue(valeur),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${tr("Saturation")} : ${(accent.saturation * 100).round()} %',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: widget.sombre ? null : Colors.white,
                    ),
                  ),
                  Slider(
                    value: accent.saturation,
                    min: 0,
                    max: 1,
                    divisions: 100,
                    activeColor: widget.accent,
                    label: '${(accent.saturation * 100).round()} %',
                    onChanged: (valeur) =>
                        widget.onAccent(accent.withSaturation(valeur)),
                    onChangeEnd: (valeur) => enregistrerDonnees(
                      accentASauvegarder: accent.withSaturation(valeur),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${tr("Luminosité")} : ${(accent.value * 100).round()} %',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: widget.sombre ? null : Colors.white,
                    ),
                  ),
                  Slider(
                    value: accent.value,
                    min: 0,
                    max: 1,
                    divisions: 100,
                    activeColor: widget.accent,
                    label: '${(accent.value * 100).round()} %',
                    onChanged: (valeur) =>
                        widget.onAccent(accent.withValue(valeur)),
                    onChangeEnd: (valeur) => enregistrerDonnees(
                      accentASauvegarder: accent.withValue(valeur),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget enteteMensuelle() {
    final avecMois = pageActive < 4;
    final enteteAccueilSombre = widget.sombre && pageActive == 0;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        8,
        enteteAccueilSombre ? _margeHauteEnteteAccueilSombre : 12,
        8,
        0,
      ),
      child: SizedBox(
        width: double.infinity,
        height: _hauteurEnteteMensuelle,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: enteteAccueilSombre
                  ? Alignment.centerLeft
                  : Alignment.center,
              child: Padding(
                padding: enteteAccueilSombre
                    ? const EdgeInsets.only(left: 38, right: 48)
                    : EdgeInsets.symmetric(horizontal: avecMois ? 46 : 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: enteteAccueilSombre
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: FittedBox(
                          key: ValueKey(pageActive),
                          fit: BoxFit.scaleDown,
                          child: Text(
                            tr(titres[pageActive]),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (enteteAccueilSombre) const SizedBox(height: 7),
                    if (avecMois)
                      Flexible(
                        child: ValueListenableBuilder(
                          valueListenable: moisVisible,
                          builder: (context, mois, child) => FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              libelleMois(mois),
                              style: TextStyle(
                                color: widget.accent,
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (avecMois)
              Align(
                alignment: enteteAccueilSombre
                    ? Alignment.bottomRight
                    : Alignment.centerRight,
                child: ValueListenableBuilder(
                  valueListenable: moisVisible,
                  builder: (context, mois, child) => menuActionsMois(mois),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ALIGNEMENT_VERTICAL_COMMUN_V1
  double centreVerticalAccueil(double hauteur) {
    final entete =
        _hauteurEnteteMensuelle +
        (widget.sombre ? _margeHauteEnteteAccueilSombre : 12.0);

    final nombre = blocsAccueilVisibles.length;
    final hauteurCarte = widget.sombre ? _hauteurCarteAccueilSombre : 52.0;
    final espacement = widget.sombre ? 7.0 : 10.0;

    final groupe = nombre * hauteurCarte + (nombre - 1) * espacement;

    final reserve = _hauteurEnteteMensuelle + _margeHauteEnteteAccueilSombre;

    final marge = ((hauteur - entete - reserve - groupe) / 2)
        .clamp(8.0, double.infinity)
        .toDouble();

    return entete + marge + groupe / 2;
  }

  Widget railNavigation(Color couleurInactive, Color fond) {
    final sombre = widget.sombre;
    final largeur = largeurSidebar;
    final navigation = LayoutBuilder(
      builder: (context, contraintesSidebar) {
        final hauteurSidebar = contraintesSidebar.maxHeight;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (evenement) {
            if (pointeurSidebar == null) {
              pointeurSidebar = evenement.pointer;
              glissementSidebarActif = true;
              suivreSidebar(evenement.localPosition, hauteurSidebar);
            }
          },
          onPointerMove: (evenement) {
            if (glissementSidebarActif &&
                evenement.pointer == pointeurSidebar) {
              suivreSidebar(evenement.localPosition, hauteurSidebar);
            }
          },
          onPointerUp: (evenement) {
            if (evenement.pointer == pointeurSidebar) {
              final destination = indexSidebar(
                evenement.localPosition,
                hauteurSidebar,
              );
              pointeurSidebar = null;
              glissementSidebarActif = false;
              iconeSidebarSurvolee.value = null;
              if (destination != null) {
                changerPage(destination);
              }
            }
          },
          onPointerCancel: (evenement) {
            if (evenement.pointer == pointeurSidebar) {
              pointeurSidebar = null;
              glissementSidebarActif = false;
              iconeSidebarSurvolee.value = null;
            }
          },
          child: ValueListenableBuilder<int?>(
            valueListenable: iconeSidebarSurvolee,
            builder: (context, survolee, _) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(titres.length, (index) {
                final actif = index == pageActive;
                final bulle = survolee == index;

                return Column(
                  children: [
                    InkWell(
                      onTap: () => changerPage(index),
                      child: SizedBox(
                        width: largeur,
                        height: hauteurIconeSidebar(hauteurSidebar),
                        child: Center(
                          child: AnimatedScale(
                            scale: bulle ? (sombre ? 1.20 : 1.75) : 1.0,
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOutCubic,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              width: sombre ? 40 : 48,
                              height: sombre ? 40 : 48,
                              // SIDEBAR_BOUTON_TRANSLUCIDE_V1
                              decoration: BoxDecoration(
                                color: actif || bulle
                                    ? widget.accent.withValues(
                                        alpha: sombre ? 0.25 : 0.18,
                                      )
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  sombre ? 13 : 15,
                                ),
                              ),
                              child: Icon(
                                icones[index],
                                size: sombre ? 20 : 26,
                                color: (actif || bulle)
                                    ? (sombre
                                          ? _refletAccent(widget.accent)
                                          : widget.accent)
                                    : couleurInactive,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (index < titres.length - 1)
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 14),
                        color: widget.sombre
                            ? Colors.transparent
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                  ],
                );
              }),
            ),
          ),
        );
      },
    );

    if (!widget.sombre) {
      return Container(
        width: largeur,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(fond, Colors.white, 0.18)!,
              fond,
              fond,
              Color.lerp(fond, Colors.black, 0.30)!,
            ],
            stops: const [0.0, 0.25, 0.65, 1.0],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, contraintes) {
            final hauteur = contraintes.maxHeight;
            final groupe = (titres.length * 64.0 + titres.length - 1)
                .clamp(0.0, hauteur)
                .toDouble();
            final debut = (centreVerticalAccueil(hauteur) - groupe / 2)
                .clamp(0.0, hauteur - groupe)
                .toDouble();

            return Stack(
              children: [
                Positioned(
                  top: debut,
                  left: 0,
                  right: 0,
                  height: groupe,
                  child: RepaintBoundary(child: navigation),
                ),
              ],
            );
          },
        ),
      );
    }

    return SizedBox(
      width: largeur,
      child: LayoutBuilder(
        builder: (context, contraintes) {
          final hauteur = contraintes.maxHeight;
          final hauteurNavigation = (hauteur * 0.57).clamp(0.0, 348.0);
          final debut = (centreVerticalAccueil(hauteur) - hauteurNavigation / 2)
              .clamp(0.0, hauteur - hauteurNavigation)
              .toDouble();
          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _SilhouetteRail(widget.accent, sidebarADroite),
                      isComplex: true,
                      willChange: false,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: debut,
                left: 0,
                right: 0,
                height: hauteurNavigation,
                child: RepaintBoundary(child: navigation),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fondBloc = couleurBlocPalette();
    final couleurInactive = widget.sombre
        ? const Color(0xFFA1A3A6)
        : const Color(0xFF626973);

    final contenu = SafeArea(
      child: Row(
        children: [
          if (!sidebarADroite)
            RepaintBoundary(
              key: const ValueKey('rail-navigation'),
              child: railNavigation(couleurInactive, fondBloc),
            ),
          Expanded(
            key: const ValueKey('contenu-principal'),
            child: Column(
              children: [
                RepaintBoundary(child: enteteMensuelle()),
                Expanded(child: RepaintBoundary(child: contenuMensuelAnime())),
              ],
            ),
          ),
          if (sidebarADroite)
            RepaintBoundary(
              key: const ValueKey('rail-navigation'),
              child: railNavigation(couleurInactive, fondBloc),
            ),
        ],
      ),
    );

    final tailleAjout = widget.sombre ? 59.0 : 64.0;
    const rayonAjout = 21.0;
    final ecran = Scaffold(
      floatingActionButtonLocation: sidebarADroite
          ? FloatingActionButtonLocation.startFloat
          : FloatingActionButtonLocation.endFloat,
      floatingActionButton: pageActive >= 4 || creationAffichee
          ? null
          : Padding(
              padding: widget.sombre
                  ? (sidebarADroite
                        ? const EdgeInsets.only(left: 5, bottom: 12)
                        : const EdgeInsets.only(right: 5, bottom: 12))
                  : EdgeInsets.zero,
              child: SizedBox.square(
                dimension: tailleAjout,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(rayonAjout),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x55000000),
                        offset: Offset(0, 3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    onPressed: donneesChargees ? ajouterOperation : null,
                    backgroundColor: widget.accent,
                    elevation: 0,
                    focusElevation: 0,
                    hoverElevation: 0,
                    highlightElevation: 0,
                    disabledElevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(rayonAjout),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: widget.sombre ? 32 : 34,
                      color:
                          ThemeData.estimateBrightnessForColor(widget.accent) ==
                              Brightness.dark
                          ? Colors.white
                          : const Color(0xFF131518),
                    ),
                  ),
                ),
              ),
            ),
      body: _FondApplication(
        sombre: widget.sombre,
        accent: widget.accent,
        child: contenu,
      ),
    );
    return AbsorbPointer(absorbing: suppressionMensuelleEnCours, child: ecran);
  }
}

Color _refletAccent(Color accent, [double intensite = 0.46]) =>
    Color.lerp(accent, Colors.white, intensite)!;

BoxDecoration _boutonEclaire(Color accent, double rayon) {
  final reflet = _refletAccent(accent);
  final bord = BorderRadius.circular(rayon);
  return BoxDecoration(
    borderRadius: bord,
    border: Border.all(color: reflet.withValues(alpha: 0.28), width: 0.8),
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _refletAccent(accent, 0.50),
        Color.lerp(accent, const Color(0xFF17191D), 0.45)!,
        Color.lerp(accent, const Color(0xFF17191D), 0.79)!,
        Color.lerp(accent, const Color(0xFF17191D), 0.66)!,
      ],
      stops: const [0, 0.30, 0.76, 1],
    ),
    boxShadow: [
      BoxShadow(
        color: accent.withValues(alpha: 0.19),
        blurRadius: 8,
        offset: const Offset(0, -2),
      ),
      const BoxShadow(
        color: Colors.black45,
        blurRadius: 12,
        offset: Offset(0, 5),
      ),
    ],
  );
}

// SIDEBAR_DEGRADE_PALETTE_V1
class _SilhouetteRail extends CustomPainter {
  const _SilhouetteRail(this.accent, this.aDroite);

  final bool aDroite;

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;
    // SIDEBAR_ARRONDIS_SIMPLES_V1
    final silhouette = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(
            aDroite ? w * 0.02 : 0,
            h * 0.025,
            aDroite ? w : w * 0.98,
            h * 0.975,
          ),
          topRight: Radius.circular(aDroite ? 0 : 16),
          bottomRight: Radius.circular(aDroite ? 0 : 16),
          topLeft: Radius.circular(aDroite ? 16 : 0),
          bottomLeft: Radius.circular(aDroite ? 16 : 0),
        ),
      );
    canvas.drawPath(
      silhouette,
      Paint()
        // SIDEBAR_OPACITE_50_V1
        ..color = const Color(0x80FFFFFF)
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent,
            Color.lerp(accent, const Color(0xFF222427), 0.35)!,
            const Color(0xFF222427),
            const Color(0xE917191C),
            const Color(0xD1111316),
            Color.lerp(const Color(0xFF111316), accent, 0.24)!,
            Color.lerp(const Color(0xFF111316), accent, 0.32)!,
          ],
          stops: const [0.0, 0.10, 0.33, 0.42, 0.75, 0.92, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_SilhouetteRail oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.aDroite != aDroite;
}

class _FondApplication extends StatelessWidget {
  const _FondApplication({
    required this.sombre,
    required this.accent,
    required this.child,
  });

  final bool sombre;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!sombre) return child;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                isComplex: true,
                willChange: false,
                painter: _CourbesFond(
                  accent,
                  MediaQuery.paddingOf(context).top,
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _CourbesFond extends CustomPainter {
  const _CourbesFond(this.accent, this.hautZoneSure);

  final Color accent;
  final double hautZoneSure;

  void tracerLiseret(Canvas canvas, Path courbe, Rect rect, Gradient lumiere) {
    final bord = Paint()
      ..style = PaintingStyle.stroke
      ..shader = lumiere.createShader(rect);

    canvas.drawPath(
      courbe,
      bord
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawPath(
      courbe,
      bord
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(
      courbe,
      bord
        ..strokeWidth = 0.8
        ..maskFilter = null,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final reflet = _refletAccent(accent);
    final paint = Paint();

    canvas.drawRect(
      rect,
      paint
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF202328), Color(0xFF141619), Color(0xFF101215)],
          stops: [0, 0.58, 1],
        ).createShader(rect),
    );

    final y = hautZoneSure;
    final amplitude = ((h - y) * 0.197).clamp(0.0, 140.0);
    final haute = Path()
      ..moveTo(0, y + amplitude * 0.79)
      ..cubicTo(
        w * 0.22,
        y + amplitude * 1.17,
        w * 0.51,
        y + amplitude * 1.12,
        w * 0.69,
        y + amplitude * 0.77,
      )
      ..cubicTo(
        w * 0.81,
        y + amplitude * 0.55,
        w * 0.88,
        y + amplitude * 0.33,
        w,
        y + amplitude * 0.24,
      );
    final surfaceHaute = Path.from(haute)
      ..lineTo(w, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(
      surfaceHaute,
      paint
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF171A1E), Color(0xFF26292D), Color(0xFF292829)],
          stops: [0, 0.61, 1],
        ).createShader(Rect.fromLTRB(0, 0, w, y + amplitude)),
    );
    tracerLiseret(
      canvas,
      haute,
      rect,
      LinearGradient(
        colors: [
          accent.withValues(alpha: 0),
          accent.withValues(alpha: 0.23),
          reflet.withValues(alpha: 0.84),
          accent.withValues(alpha: 0.32),
        ],
        stops: const [0.13, 0.46, 0.78, 1],
      ),
    );

    final basse = Path()
      ..moveTo(0, h * 0.996)
      ..cubicTo(w * 0.19, h * 0.887, w * 0.42, h * 0.91, w * 0.60, h * 0.881)
      ..cubicTo(w * 0.77, h * 0.846, w * 0.91, h * 0.807, w, h * 0.79);
    final surfaceBasse = Path.from(basse)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    final zoneBasse = Rect.fromLTRB(0, h * 0.79, w, h);
    canvas.drawPath(
      surfaceBasse,
      paint
        ..shader = const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Color(0xFF242629), Color(0xFF171A1E), Color(0xFF111316)],
        ).createShader(zoneBasse),
    );
    final ruban = Path()
      ..moveTo(w * 0.32, h)
      ..cubicTo(w * 0.49, h * 0.91, w * 0.68, h * 0.87, w, h * 0.81)
      ..lineTo(w, h * 0.92)
      ..cubicTo(w * 0.74, h * 0.90, w * 0.57, h * 0.94, w * 0.46, h)
      ..close();
    canvas.drawPath(
      ruban,
      paint
        ..shader = const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Color(0xFF191C21), Color(0xFF2C2F34), Color(0xFF121417)],
          stops: [0, 0.44, 0.83],
        ).createShader(zoneBasse),
    );
    tracerLiseret(
      canvas,
      basse,
      rect,
      LinearGradient(
        colors: [
          accent.withValues(alpha: 0.37),
          reflet.withValues(alpha: 0.82),
          accent.withValues(alpha: 0.19),
          accent.withValues(alpha: 0),
        ],
        stops: const [0, 0.19, 0.40, 0.56],
      ),
    );
  }

  @override
  bool hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_CourbesFond oldDelegate) =>
      accent != oldDelegate.accent || hautZoneSure != oldDelegate.hautZoneSure;
}

const double _hauteurCarteAccueilSombre = 49;

class _SurfaceFinanciere extends StatelessWidget {
  const _SurfaceFinanciere({
    required this.sombre,
    required this.rayon,
    required this.couleurClaire,
    required this.child,
    this.fondClairDansMaterial = false,
    this.margeInterieure,
  });

  final bool sombre;
  final double rayon;
  final Color couleurClaire;
  final Widget child;
  final bool fondClairDansMaterial;
  final EdgeInsets? margeInterieure;

  @override
  Widget build(BuildContext context) {
    final fondClairDansMaterial = !sombre && this.fondClairDansMaterial;
    final decoration = sombre
        ? _surfaceGraphite(rayon: rayon, refletCarte: true)
        : fondClairDansMaterial
        ? null
        : BoxDecoration(color: couleurClaire);
    final marge = margeInterieure;

    return Material(
      color: fondClairDansMaterial ? couleurClaire : null,
      borderRadius: BorderRadius.circular(rayon),
      elevation: sombre ? 3 : 6,
      surfaceTintColor: sombre ? Colors.transparent : null,
      shadowColor: Colors.black.withValues(
        alpha: fondClairDansMaterial ? 0.35 : 0.38,
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: decoration,
        child: marge == null
            ? child
            : Padding(
                // Ink compte le contour dans la marge intérieure.
                padding: marge.subtract(decoration?.padding ?? EdgeInsets.zero),
                child: child,
              ),
      ),
    );
  }
}

const _positionRefletGraphite = 0.22;

class _DegradeSurfaceFinanciere extends LinearGradient {
  const _DegradeSurfaceFinanciere({required super.colors})
    : super(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0, _positionRefletGraphite, 1],
      );

  @override
  Shader createShader(Rect rect, {TextDirection? textDirection}) {
    if (rect.height <= _hauteurCarteAccueilSombre) {
      return super.createShader(rect, textDirection: textDirection);
    }

    // La profondeur du reflet reste celle d'une carte Accueil. La transition
    // sous le reflet se prolonge jusqu'au bas de la surface.
    final finReflet =
        _hauteurCarteAccueilSombre * _positionRefletGraphite / rect.height;
    return LinearGradient(
      begin: begin,
      end: end,
      colors: colors,
      stops: [0, finReflet, 1],
    ).createShader(rect, textDirection: textDirection);
  }
}

// SURFACES_LISTES_PALETTE_V2
// CACHE_SURFACES_GRAPHITE_V1
const int _limiteCacheGraphite = 64;

final _cacheSurfacesGraphite =
    <(double, double, Color?, bool, double?), BoxDecoration>{};

BoxDecoration _surfaceGraphite({
  required double rayon,
  double elevation = 0,
  Color? accentActif,
  bool refletCarte = false,
  double? intensitePalette,
}) {
  final cle = (rayon, elevation, accentActif, refletCarte, intensitePalette);
  final existante = _cacheSurfacesGraphite.remove(cle);

  if (existante != null) {
    _cacheSurfacesGraphite[cle] = existante;
    return existante;
  }

  final decoration = _construireSurfaceGraphite(
    rayon: rayon,
    elevation: elevation,
    accentActif: accentActif,
    refletCarte: refletCarte,
    intensitePalette: intensitePalette,
  );

  if (_cacheSurfacesGraphite.length >= _limiteCacheGraphite) {
    _cacheSurfacesGraphite.remove(_cacheSurfacesGraphite.keys.first);
  }

  _cacheSurfacesGraphite[cle] = decoration;
  return decoration;
}

BoxDecoration _construireSurfaceGraphite({
  required double rayon,
  double elevation = 0,
  Color? accentActif,
  bool refletCarte = false,
  double? intensitePalette,
}) {
  Color teinter(Color graphite, double opacite) => accentActif == null
      ? graphite
      : Color.alphaBlend(
          accentActif.withValues(
            alpha: intensitePalette == null
                ? opacite
                : (intensitePalette + (opacite - 0.13) * 2.5)
                      .clamp(0.0, 1.0)
                      .toDouble(),
          ),
          graphite,
        );

  final couleurs = [
    teinter(const Color(0xFF2C2E32), 0.17),
    teinter(const Color(0xFF24262A), 0.13),
    teinter(const Color(0xFF1C1E21), 0.09),
  ];

  return BoxDecoration(
    borderRadius: BorderRadius.circular(rayon),
    border: Border.all(
      color: teinter(const Color(0xFF323437), 0.38),
      width: 0.55,
    ),
    gradient: refletCarte
        ? _DegradeSurfaceFinanciere(colors: couleurs)
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: couleurs,
            stops: const [0, _positionRefletGraphite, 1],
          ),
    boxShadow: elevation > 0
        ? [
            BoxShadow(
              color: const Color(0x57000000),
              blurRadius: elevation * 2,
              offset: Offset(0, elevation / 2),
            ),
          ]
        : null,
  );
}

BoxDecoration _decorationTri(BuildContext context, Color accent, bool actif) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? _surfaceGraphite(rayon: 12, accentActif: actif ? accent : null)
      : BoxDecoration(
          color: actif
              ? accent.withValues(alpha: 0.18)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: actif ? accent.withValues(alpha: 0.65) : Colors.transparent,
          ),
        );
}

class _BilanFrise extends StatefulWidget {
  const _BilanFrise({
    required this.detailsMois,
    required this.sousTotalMois,
    required this.moisInitial,
    required this.totaux,
    required this.accent,
    required this.montantFormate,
  });

  final Widget Function(int, TriOperationsV2) detailsMois;
  final Widget Function(int) sousTotalMois;
  final int moisInitial;
  final Map<int, double> totaux;
  final Color accent;
  final String Function(double) montantFormate;

  @override
  State<_BilanFrise> createState() => _BilanFriseState();
}

// TRADUCTION_STATISTIQUES_V1
class _BilanFriseState extends State<_BilanFrise> {
  String tr(String texte) {
    return Traductions.traduire(
      Localizations.localeOf(context).languageCode,
      texte,
    );
  }

  static const nombreMois = 9999 * 12;
  static const visibles = 6;
  static const noms = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];
  static const courts = [
    'Jan.',
    'Fév.',
    'Mars',
    'Avr.',
    'Mai',
    'Juin',
    'Juil.',
    'Août',
    'Sept.',
    'Oct.',
    'Nov.',
    'Déc.',
  ];

  // STATISTIQUES_TRIS_INDEPENDANTS_V1
  TriOperationsV2 triStatistique = TriOperationsV2.date;
  late final ValueNotifier<int> moisSelectionne;
  late final double maximum;
  double largeurColonne = 0;
  ScrollController? controleur;

  @override
  void initState() {
    super.initState();
    moisSelectionne = ValueNotifier(widget.moisInitial);
    maximum = widget.totaux.values.fold<double>(0, (a, b) => a > b ? a : b);
  }

  String moisCourt(int numero) {
    final langue = Localizations.localeOf(context).languageCode;
    if (langue == 'fr') return courts[numero % 12];

    return PreferencesRegionales.formaterMoisCourt(
      DateTime(numero ~/ 12 + 1, numero % 12 + 1),
      langue,
    );
  }

  String nomMois(int numero) {
    final langue = Localizations.localeOf(context).languageCode;
    if (langue == 'fr') {
      return '${noms[numero % 12]} ${numero ~/ 12 + 1}';
    }
    return PreferencesRegionales.formaterMois(
      DateTime(numero ~/ 12 + 1, numero % 12 + 1),
      langue,
    );
  }

  // STATISTIQUE_MOIS_EN_COURS_V1
  void recentrerSurMoisEnCours() {
    final c = controleur;
    if (c == null || !c.hasClients || largeurColonne <= 0) return;

    final maintenant = DateTime.now();
    final numero = (maintenant.year - 1) * 12 + maintenant.month - 1;
    final cible = numero * largeurColonne;
    c.animateTo(
      cible,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void suivreDefilement() {
    final c = controleur;
    if (c == null || !c.hasClients || largeurColonne <= 0) return;
    moisSelectionne.value = (c.offset / largeurColonne)
        .round()
        .clamp(0, nombreMois - 1)
        .toInt();
  }

  @override
  void dispose() {
    controleur?.dispose();
    moisSelectionne.dispose();
    super.dispose();
  }

  Widget barreTrisStatistiques() {
    Widget bouton(String titre, TriOperationsV2 tri) {
      final actif = triStatistique == tri;

      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: InkWell(
            onTap: () => setState(() => triStatistique = tri),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 42,
              alignment: Alignment.center,
              decoration: _decorationTri(context, widget.accent, actif),
              child:
                  tri == TriOperationsV2.croissant ||
                      tri == TriOperationsV2.decroissant
                  ? Icon(
                      tri == TriOperationsV2.croissant
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      size: 30,
                      weight: 900,
                      color: actif
                          ? widget.accent
                          : Theme.of(context).colorScheme.onSurface,
                    )
                  : tri == TriOperationsV2.date
                  ? Icon(
                      Icons.calendar_month_rounded,
                      size: 30,
                      color: actif
                          ? widget.accent
                          : Theme.of(context).colorScheme.onSurface,
                    )
                  : Text(
                      titre,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: actif
                            ? widget.accent
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      child: Row(
        children: [
          bouton('↑', TriOperationsV2.croissant),
          bouton('↓', TriOperationsV2.decroissant),
          bouton(tr('Date'), TriOperationsV2.date),
          bouton('ABC', TriOperationsV2.nature),
        ],
      ),
    );
  }

  Widget colonne(int numero, Color texte) {
    final montant = widget.totaux[numero];
    final valeur = montant == null ? '—' : widget.montantFormate(montant);
    final description =
        '${nomMois(numero)}, ${montant == null ? tr("sans feuille") : valeur}';
    final hauteur = montant == null || maximum == 0
        ? 0.0
        : (montant / maximum) * 130.0;

    return Tooltip(
      message: description,
      excludeFromSemantics: true,
      child: Semantics(
        label: description,
        excludeSemantics: true,
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          valeur,
                          style: TextStyle(
                            color: texte,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FractionallySizedBox(
                    widthFactor: 0.52,
                    child: Container(
                      height: hauteur,
                      decoration: BoxDecoration(
                        color: widget.accent,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 34,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(moisCourt(numero)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;
    final fond = Color.alphaBlend(
      widget.accent.withValues(alpha: sombre ? 0.08 : 0.12),
      theme.colorScheme.surface,
    );

    return Scaffold(
      backgroundColor: sombre ? Colors.transparent : null,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverList.list(
                children: [
                  Text(
                    tr('Dépenses hors charges fixes'),
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: recentrerSurMoisEnCours,
                      icon: const Icon(Icons.my_location_rounded, size: 18),
                      label: Text(tr('Mois en cours')),
                    ),
                  ),
                  const SizedBox(height: 4),
                  DecoratedBox(
                    decoration: sombre
                        ? _surfaceGraphite(
                            rayon: 18,
                            elevation: 5,
                            accentActif: widget.accent,
                            intensitePalette: 0.25,
                          )
                        : BoxDecoration(
                            color: fond,
                            borderRadius: BorderRadius.circular(18),
                          ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                      child: SizedBox(
                        height: 200,
                        child: LayoutBuilder(
                          builder: (context, contraintes) {
                            final largeur = (contraintes.maxWidth / visibles)
                                .roundToDouble();
                            if (largeur <= 0) return const SizedBox.shrink();
                            final ancienneLargeur = largeurColonne;
                            largeurColonne = largeur;
                            if (controleur == null) {
                              controleur = ScrollController(
                                keepScrollOffset: false,
                                initialScrollOffset:
                                    moisSelectionne.value * largeur,
                              )..addListener(suivreDefilement);
                            } else if (ancienneLargeur != largeur &&
                                controleur!.hasClients) {
                              final positionEnMois =
                                  controleur!.offset / ancienneLargeur;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted ||
                                    !controleur!.hasClients ||
                                    largeurColonne != largeur) {
                                  return;
                                }
                                final position = controleur!.position;
                                controleur!.jumpTo(
                                  (positionEnMois * largeur)
                                      .clamp(
                                        position.minScrollExtent,
                                        position.maxScrollExtent,
                                      )
                                      .toDouble(),
                                );
                              });
                            }
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                // GRILLE_STATISTIQUE_100_V1
                                if (maximum.isFinite && maximum >= 100)
                                  for (
                                    double palier =
                                        100.0 * (maximum / 2000).ceil();
                                    palier <= maximum;
                                    palier += 100.0 * (maximum / 2000).ceil()
                                  )
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 34 + (palier / maximum) * 130.0,
                                      child: IgnorePointer(
                                        child: Container(
                                          height: 0.8,
                                          color: widget.accent.withValues(
                                            alpha: 0.45,
                                          ),
                                        ),
                                      ),
                                    ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 34,
                                  child: Container(
                                    height: 1,
                                    color: theme.brightness == Brightness.dark
                                        ? theme.colorScheme.outlineVariant
                                        : theme.dividerColor,
                                  ),
                                ),
                                Center(
                                  child: IgnorePointer(
                                    child: Container(
                                      width: largeur,
                                      decoration: BoxDecoration(
                                        color: widget.accent.withValues(
                                          alpha: 0.19,
                                        ),
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                          color: widget.accent.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                ListView.builder(
                                  padding: EdgeInsets.symmetric(
                                    horizontal:
                                        (contraintes.maxWidth - largeur) / 2,
                                  ),
                                  controller: controleur,
                                  primary: false,
                                  scrollDirection: Axis.horizontal,
                                  itemExtent: largeur,
                                  itemCount: nombreMois,
                                  itemBuilder: (_, numero) => colonne(
                                    numero,
                                    theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<int>(
                    valueListenable: moisSelectionne,
                    builder: (context, n, _) {
                      final courant = widget.totaux[n];
                      final precedent = widget.totaux[n - 1];
                      final ecart = courant == null || precedent == null
                          ? null
                          : courant - precedent;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${tr("Dépenses")} · ${nomMois(n)}',
                            style: theme.textTheme.titleMedium,
                          ),
                          if (ecart != null)
                            Text(
                              ecart == 0
                                  ? tr('Même montant que le mois précédent')
                                  : tr(
                                      ecart > 0
                                          ? '{montant} de plus que le mois précédent'
                                          : '{montant} de moins que le mois précédent',
                                    ).replaceAll(
                                      '{montant}',
                                      widget.montantFormate(ecart.abs()),
                                    ),
                            ),
                          widget.sousTotalMois(n),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              sliver: SliverToBoxAdapter(child: barreTrisStatistiques()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: ValueListenableBuilder<int>(
                valueListenable: moisSelectionne,
                builder: (context, n, _) =>
                    widget.detailsMois(n, triStatistique),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RechercheStatistique extends StatefulWidget {
  const _RechercheStatistique({
    required this.accent,
    required this.graphique,
    required this.resultats,
  });

  final Color accent;
  final Widget graphique;
  final Widget Function(String terme) resultats;

  @override
  State<_RechercheStatistique> createState() => _RechercheStatistiqueState();
}

class _RechercheStatistiqueState extends State<_RechercheStatistique> {
  String tr(String texte) {
    return Traductions.traduire(
      Localizations.localeOf(context).languageCode,
      texte,
    );
  }

  final champ = TextEditingController();
  String terme = '';

  void actualiser(String texte) {
    final valeur = cleRecherche(texte);
    if (valeur != terme) setState(() => terme = valeur);
  }

  @override
  void dispose() {
    champ.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: TextField(
            controller: champ,
            onChanged: actualiser,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: tr('Rechercher sur tous les mois'),
              // RECHERCHE_STATISTIQUE_PALETTE_25_V2
              fillColor: widget.accent.withValues(alpha: 0.25),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: terme.isEmpty
                  ? null
                  : IconButton(
                      tooltip: tr('Effacer la recherche'),
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        champ.clear();
                        actualiser('');
                        FocusScope.of(context).unfocus();
                      },
                    ),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Offstage(offstage: terme.isNotEmpty, child: widget.graphique),
              if (terme.isNotEmpty) widget.resultats(terme),
            ],
          ),
        ),
      ],
    );
  }
}

// CREATION_CENTRAGE_MESURE_V3
class _CentragePanneauCreation extends SingleChildRenderObjectWidget {
  const _CentragePanneauCreation({required this.centre, required Widget child})
    : super(child: child);

  final double centre;

  @override
  _RenduCentrageCreation createRenderObject(BuildContext context) {
    return _RenduCentrageCreation(centre);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenduCentrageCreation renderObject,
  ) {
    renderObject.centre = centre;
  }
}

class _RenduCentrageCreation extends RenderShiftedBox {
  _RenduCentrageCreation(this._centre) : super(null);

  double _centre;

  set centre(double valeur) {
    if (_centre == valeur) return;
    _centre = valeur;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final panneau = child;

    if (panneau == null) {
      size = constraints.constrain(Size.zero);
      return;
    }

    panneau.layout(
      BoxConstraints(maxWidth: constraints.maxWidth),
      parentUsesSize: true,
    );

    final marge = (_centre - panneau.size.height / 2)
        .clamp(0.0, double.infinity)
        .toDouble();

    size = constraints.constrain(
      Size(constraints.maxWidth, marge + panneau.size.height),
    );

    final position = panneau.parentData! as BoxParentData;
    position.offset = Offset((size.width - panneau.size.width) / 2, marge);
  }
}
