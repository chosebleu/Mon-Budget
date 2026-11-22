import 'package:flutter/material.dart';

import 'stockage_v2.dart';
import 'feuilles_mensuelles_v2.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MonBudgetApp());
}

class MonBudgetApp extends StatefulWidget {
  const MonBudgetApp({super.key});

  @override
  State<MonBudgetApp> createState() => _MonBudgetAppState();
}

class _MonBudgetAppState extends State<MonBudgetApp> {
  bool sombre = true;
  Color accent = const Color(0xFF67B99A);
  double saturationPalette = 0.65;
  double luminositePalette = 0.40;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mon Budget V2',
      debugShowCheckedModeBanner: false,
      themeMode: sombre ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF0F1F3),
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF17191D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        ),
      ),
      home: StructureV2(
        sombre: sombre,
        accent: accent,
        saturationPalette: saturationPalette,
        luminositePalette: luminositePalette,
        onSaturationPalette: (valeur) =>
            setState(() => saturationPalette = valeur),
        onLuminositePalette: (valeur) =>
            setState(() => luminositePalette = valeur),
        onTheme: (valeur) => setState(() => sombre = valeur),
        onAccent: (valeur) => setState(() => accent = valeur),
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

String cleRecherche(String texte) {
  var cle = texte.trim().toLowerCase();
  for (final groupe in const {
    'a': 'àâä',
    'c': 'ç',
    'e': 'éèêë',
    'i': 'îï',
    'o': 'ôö',
    'u': 'ùûü',
  }.entries) {
    cle = cle.replaceAll(RegExp('[${groupe.value}]'), groupe.key);
  }
  return cle.replaceAll('œ', 'oe');
}

enum TriOperationsV2 { croissant, decroissant, date, nature }

class StructureV2 extends StatefulWidget {
  const StructureV2({
    super.key,
    required this.sombre,
    required this.accent,
    required this.saturationPalette,
    required this.luminositePalette,
    required this.onSaturationPalette,
    required this.onLuminositePalette,
    required this.onTheme,
    required this.onAccent,
  });

  final bool sombre;
  final Color accent;
  final double saturationPalette;
  final double luminositePalette;
  final ValueChanged<double> onSaturationPalette;
  final ValueChanged<double> onLuminositePalette;
  final ValueChanged<bool> onTheme;
  final ValueChanged<Color> onAccent;

  @override
  State<StructureV2> createState() => _StructureV2State();
}

class _StructureV2State extends State<StructureV2> {
  bool sousTotauxCouleursOuverts = false;
  int pageActive = 0;

  // GLISSEMENT_SIDEBAR_V3
  int? pointeurSidebar;
  bool glissementSidebarActif = false;
  // SIDEBAR_BULLE_EXPERIMENTALE_V1
  int? iconeSidebarSurvolee;

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
        position.dx > 80 ||
        y < 0 ||
        y >= groupe ||
        taille <= 0) {
      return null;
    }

    final index = (y / (taille + 1)).floor();
    return index >= 0 && index < titres.length ? index : null;
  }

  void suivreSidebar(Offset position, double hauteur) {
    final index = indexSidebar(position, hauteur);
    if (iconeSidebarSurvolee != index) {
      setState(() {
        iconeSidebarSurvolee = index;
      });
    }
  }

  final List<String> intitulesMemorises = [];
  final _budgetInitial = _BudgetMensuel.vide();
  final Map<String, _BudgetMensuel> feuillesMensuelles = {};
  final List<String> moisAffiches = [];
  String moisActif = GestionFeuillesMensuellesV2.identifiant(DateTime.now());
  late final ValueNotifier<String> moisVisible = ValueNotifier(moisActif);
  int indexMensuel = 0;
  bool donneesChargees = false;
  bool erreurChargement = false;

  List<int> ordreBlocsAccueil = [0, 1, 2, 3, 4];
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
        } else {
          ajouterPageCreationSuivante();
        }
        reinitialiserOptionsImport();
      });
      await enregistrerDonnees();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nouvelle feuille créée')));
    } catch (erreur) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Création impossible : $erreur')));
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

  void reconstruirePagesMensuelles() {
    moisAffiches
      ..clear()
      ..addAll(feuillesMensuelles.keys.toList()..sort());
    if (moisAffiches.isEmpty) {
      moisAffiches.add(moisActif);
    } else {
      final precedent = moisPrecedent(moisAffiches.first);
      if (precedent != null) moisAffiches.insert(0, precedent);
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
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: pageActive >= 4,
          child: controleur == null
              ? pageBudget(_budgetInitial)
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
                    physics: pageActive >= 4 || suppressionMensuelleEnCours
                        ? const NeverScrollableScrollPhysics()
                        : const PageScrollPhysics(),
                    itemCount: moisAffiches.length,
                    itemBuilder: (context, index) {
                      final mois = moisAffiches[index];
                      final budget = feuillesMensuelles[mois];
                      return AnimatedBuilder(
                        key: ValueKey(mois),
                        animation: controleur,
                        builder: (context, child) {
                          final position =
                              controleur.hasClients &&
                                  controleur.position.hasContentDimensions
                              ? controleur.page ?? indexMensuel.toDouble()
                              : indexMensuel.toDouble();
                          final distance = (position - index).abs().clamp(
                            0.0,
                            1.0,
                          );
                          return Transform.scale(
                            scale: 1.0 - 0.10 * distance,
                            child: child,
                          );
                        },
                        child: RepaintBoundary(
                          child: Material(
                            color: Theme.of(context).scaffoldBackgroundColor,
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

    return LayoutBuilder(
      builder: (context, contraintes) {
        final hauteurDisponible = contraintes.maxHeight;
        final hauteurEcran =
            MediaQuery.sizeOf(context).height -
            MediaQuery.paddingOf(context).vertical;
        final decalageCentre = (hauteurEcran - hauteurDisponible) / 2;

        return ListView(
          primary: false,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: (hauteurDisponible / 2 - decalageCentre - 145).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Material(
                      color: couleurBlocPalette(),
                      borderRadius: BorderRadius.circular(20),
                      elevation: 6,
                      shadowColor: Colors.black.withValues(alpha: 0.35),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Importer depuis le mois précédent',
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
                                (bool v) =>
                                    setState(() => importerReliquat = v),
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
                                          item.$1,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      Switch(
                                        value:
                                            item.$2 && moisPrecedentDisponible,
                                        onChanged: moisPrecedentDisponible
                                            ? item.$3
                                            : null,
                                        activeThumbColor: Colors.white,
                                        activeTrackColor: Colors.green,
                                        inactiveThumbColor: Colors.white,
                                        inactiveTrackColor: Colors.white24,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(
                                color: Colors.white24,
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
                                constraints: const BoxConstraints(
                                  minHeight: 39,
                                ),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Tout importer',
                                        style: TextStyle(
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
                                      activeTrackColor: Colors.green,
                                      inactiveThumbColor: Colors.white,
                                      inactiveTrackColor: Colors.white24,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!moisPrecedentDisponible)
                              const Text(
                                'Aucune feuille pour le mois qui précède celui-ci. '
                                'La nouvelle feuille sera vide.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70),
                              ),
                            const SizedBox(height: 8),
                            const Text(
                              'Les dépenses ponctuelles ne sont pas copiées.',
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
                ),
                const SizedBox(height: 18),
                Center(
                  child: IconButton(
                    tooltip: 'Créer cette feuille',
                    onPressed: creationMensuelleEnCours || !pageSelectionnee
                        ? null
                        : () => creerFeuilleEnPreparation(destination),
                    // DEGRADE_PLUS_CREATION_V1
                    icon: Stack(
                      alignment: Alignment.center,
                      children: [
                        const ExcludeSemantics(
                          child: Icon(
                            Icons.add_circle_outline_rounded,
                            size: 82,
                            color: Colors.transparent,
                            shadows: [
                              Shadow(
                                color: Color(0x66000000),
                                offset: Offset(0, 3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (bounds) {
                            final base = couleurBlocPalette();
                            return LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color.lerp(base, Colors.white, 0.12)!,
                                base,
                                Color.lerp(base, Colors.black, 0.10)!,
                              ],
                            ).createShader(bounds);
                          },
                          child: const Icon(
                            Icons.add_circle_outline_rounded,
                            size: 82,
                            color: Colors.white,
                          ),
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
                    child: const Text('Annuler'),
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
    chargerDonnees();
  }

  @override
  void dispose() {
    controleurPagesMensuelles?.dispose();
    moisVisible.dispose();
    super.dispose();
  }

  Future<void> chargerDonnees() async {
    try {
      final donneesBrutes = await StockageBudgetV2.charger();

      final donnees = GestionFeuillesMensuellesV2.preparerMigration(
        donnees: donneesBrutes,
        moisInitial: GestionFeuillesMensuellesV2.identifiant(DateTime.now()),
      );

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

      double lireReglagePalette(String cle, double defaut) {
        final valeur = donnees[cle];
        if (valeur is num && valeur.isFinite) {
          return valeur.toDouble().clamp(0.0, 1.0);
        }
        return defaut;
      }

      final saturationChargee = lireReglagePalette('saturationPalette', 0.65);
      final luminositeChargee = lireReglagePalette('luminositePalette', 0.40);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onSaturationPalette(saturationChargee);
        widget.onLuminositePalette(luminositeChargee);
      });

      final ordreCharge = donnees['ordreBlocsAccueil'];
      var ordreValide = <int>[0, 1, 2, 3, 4];

      if (ordreCharge is List &&
          ordreCharge.length == 5 &&
          ordreCharge.every((element) => element is int) &&
          ordreCharge.toSet().length == 5 &&
          ordreCharge.toSet().containsAll([0, 1, 2, 3, 4])) {
        ordreValide = List<int>.from(ordreCharge);
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
        reconstruirePagesMensuelles();
        ordreBlocsAccueil = ordreValide;
        donneesChargees = true;
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
    return '${montant.toStringAsFixed(2).replaceAll('.', ',')} €';
  }

  String dateFormatee(DateTime date) {
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
        resultat.sort((a, b) {
          final ordre = cleRecherche(a.intitule)
              .compareTo(cleRecherche(b.intitule));
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
          : operation.montant.toStringAsFixed(2).replaceAll('.', ','),
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
                      ? 'Ajouter une opération'
                      : 'Modifier une opération',
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
                          labelText: 'Montant',
                          suffixText: '€',
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
                          labelText: 'Intitulé',
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
                    child: const Text('Annuler'),
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
                          erreur = 'Intitulé et montant positif requis.';
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
                    child: Text(operation == null ? 'Ajouter' : 'Enregistrer'),
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
  }) {
    if (!donneesChargees ||
        erreurChargement ||
        (suppressionMensuelleEnCours && moisSupprime == null)) {
      return Future<void>.value();
    }

    final feuilles = {
      for (final entree in feuillesMensuelles.entries)
        if (entree.key != moisSupprime)
          entree.key: entree.value.versFeuille(entree.key).toJson(),
    };
    final moisASauvegarder = moisRestantActif ?? moisActif;
    final feuilleActive =
        feuilles[moisASauvegarder] ??
        _budgetInitial.versFeuille(moisASauvegarder).toJson();
    final donnees = <String, dynamic>{
      ...feuilleActive,
      'intitules': List<String>.from(intitulesMemorises),
      'saturationPalette': widget.saturationPalette,
      'luminositePalette': widget.luminositePalette,
      'ordreBlocsAccueil': List<int>.from(ordreBlocsAccueil),
      'moisActif': moisASauvegarder,
      'feuillesMensuelles': feuilles,
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
                const Text(
                  'Nouvelle opération',
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
                      choix.$3,
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
              const Text(
                'Couleur du groupe',
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
                label: const Text('Retirer la couleur'),
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
                    title: const Text(
                      'Modifier',
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
                      title: const Text(
                        'Ajouter aux charges fixes',
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
                      title: const Text(
                        'Couleur du groupe',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () => Navigator.pop(sheetContext, 'couleur'),
                    ),

                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFFF9999),
                    ),
                    title: const Text(
                      'Effacer',
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
            title: const Text('Effacer cette opération ?'),
            content: Text(operation.intitule),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Effacer'),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: couleurBlocPalette(),
        borderRadius: BorderRadius.circular(12),
        boxShadow: ombreBlocPalette(),
      ),
      child: Row(
        children: [
          if (page == 1) ...[
            SizedBox(
              width: 34,
              height: 42,
              child: Checkbox(
                value: depensesSelectionnees.contains(operation),
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
              height: 35,
              decoration: BoxDecoration(
                color: OperationV2.couleursGroupes[operation.groupeCouleur!],
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateFormatee(operation.date),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9299A3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            montantFormate(operation.montant),
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
        ],
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
              decoration: BoxDecoration(
                color: actif
                    ? widget.accent.withValues(alpha: 0.18)
                    : Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: actif
                      ? widget.accent.withValues(alpha: 0.65)
                      : Colors.transparent,
                ),
              ),
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
                boutonTri('Croissant', TriOperationsV2.croissant),
                boutonTri('Décroissant', TriOperationsV2.decroissant),
                boutonTri('Date', TriOperationsV2.date),
                if (pageActive == 1)
                  boutonTri('Nature', TriOperationsV2.nature),
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
                    if (pageActive == 1 || pageActive == 2)
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
    final hsv = HSVColor.fromColor(widget.accent);

    final couleurReglee = hsv
        .withSaturation(widget.saturationPalette)
        .withValue((0.15 + widget.luminositePalette * 0.70).clamp(0.0, 1.0))
        .toColor();

    final fond = widget.sombre
        ? const Color(0xFF24272D)
        : const Color(0xFFD6D9DE);

    return Color.alphaBlend(
      couleurReglee.withValues(alpha: widget.sombre ? 0.82 : 0.65),
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
        decoration: BoxDecoration(
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
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            pageActive == 1 || pageActive == 2
                                ? 'Total'
                                : 'Total de la liste',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
                  Text(
                    montantFormate(total),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: pageActive == 1 || pageActive == 2
                          ? const Color(0xFFEF5350)
                          : widget.accent,
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
                      'Sous-total sélection (${selectionDuMois.length})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                          'Groupe ${groupe + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
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

    String afficherValeur(double valeur) =>
        valeur == 0 ? '' : valeur.toStringAsFixed(2).replaceAll('.', ',');

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
            title: const Text(
              'Salaire et reliquat',
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
                      labelText: 'Salaire',
                      suffixText: '€',
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
                      labelText: 'Reliquat',
                      suffixText: '€',
                      errorText: erreurReliquat,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Le reliquat est ajouté au total disponible, '
                    'sans modifier le reste sur salaire.',
                    style: TextStyle(color: Color(0xFFB0B6C0), fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
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
                          : 'Montant positif ou zéro requis.';
                      erreurReliquat = reliquatValide
                          ? null
                          : 'Montant valide requis.';
                    });
                    return;
                  }

                  Navigator.pop(dialogContext, (salaire, reliquat));
                },
                child: const Text('Enregistrer'),
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
          : valeurActuelle.toStringAsFixed(2).replaceAll('.', ','),
    );

    final montantSigne = champ == 'reliquat';
    String? erreur;

    try {
      final montant = await showDialog<double>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, actualiser) => AlertDialog(
            backgroundColor: const Color(0xFF25282D),
            title: Text(switch (champ) {
              'salaire' => 'Salaire',
              'reliquat' => 'Reliquat',
              _ => 'Épargne',
            }, style: const TextStyle(color: Colors.white)),
            content: TextField(
              controller: controleur,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.numberWithOptions(
                decimal: true,
                signed: montantSigne,
              ),
              decoration: InputDecoration(
                labelText: 'Montant',
                suffixText: '€',
                errorText: erreur,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
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
                          ? 'Montant valide requis.'
                          : 'Montant positif ou zéro requis.';
                    });
                    return;
                  }

                  Navigator.pop(dialogContext, valeur);
                },
                child: const Text('Enregistrer'),
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

  Widget blocAccueilFinancier({
    required String titre,
    required double montant,
    Color? couleurMontant,
    required IconData icone,
    VoidCallback? onTap,
    String? sousTitre,
  }) {
    return SizedBox(
      height: 52,
      child: Material(
        // DEGRADE_INDEPENDANT_ACCUEIL_V1
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        elevation: 6,
        shadowColor: Colors.black.withValues(
          alpha: widget.sombre ? 0.42 : 0.24,
        ),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          // SUPPRESSION_DEGRADE_BLOCS_ACCUEIL_V1
          decoration: BoxDecoration(color: couleurBlocPalette()),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                children: [
                  Icon(icone, color: widget.accent, size: 23),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      montantFormate(montant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: couleurMontant,
                      ),
                    ),
                  ),
                ],
              ),
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
            titre: 'Salaire',
            montant: budget.salaire,
            couleurMontant: const Color(0xFF64B5F6),
            icone: Icons.payments_rounded,
            onTap: () => saisirSalaireEtReliquat(budget),
          );
        case 1:
          return blocAccueilFinancier(
            titre: 'Reste sur salaire',
            montant: resteSurSalaire,
            couleurMontant: couleurResteSalaire(),
            icone: Icons.account_balance_wallet_rounded,
            sousTitre: 'Salaire moins charges fixes et dépenses',
          );
        case 2:
          return blocAccueilFinancier(
            titre: 'Total dépenses',
            montant: depenses,
            couleurMontant: const Color(0xFFEF5350),
            icone: Icons.receipt_long_rounded,
            sousTitre: 'Hors charges fixes',
          );
        case 3:
          return blocAccueilFinancier(
            titre: 'Épargne',
            montant: budget.epargne,
            // ACCUEIL_EPARGNE_DISPONIBLE_VERT_V1
            couleurMontant: const Color(0xFF29B765),
            icone: Icons.savings_rounded,
            onTap: () => saisirMontantAccueil(budget, 'epargne'),
          );
        case 4:
          return blocAccueilFinancier(
            titre: 'Total disponible',
            montant: totalDisponible,
            couleurMontant: const Color(0xFF29B765),
            icone: Icons.add_card_rounded,
            sousTitre: 'Reliquat : ${montantFormate(budget.reliquat)}',
            onTap: () => saisirMontantAccueil(budget, 'reliquat'),
          );
        default:
          return const SizedBox.shrink();
      }
    }

    return LayoutBuilder(
      builder: (context, contraintes) {
        final hauteurDisponible = contraintes.maxHeight;

        // La sidebar est centree dans la SafeArea.
        // L'en-tete mesure 112 + 10 + 8 = 130 pixels logiques.
        const hauteurEnTete = 130.0;
        const hauteurGroupe = 310.0;

        // Le centre de la SafeArea, rapporte a la zone de contenu.
        final centreSidebar =
            (hauteurDisponible + hauteurEnTete) / 2 - hauteurEnTete;

        final hautGroupe = centreSidebar - hauteurGroupe / 2;

        return SingleChildScrollView(
          primary: false,
          child: SizedBox(
            height: hauteurDisponible > hauteurGroupe
                ? hauteurDisponible
                : hauteurGroupe,
            child: Stack(
              children: [
                Positioned(
                  top: hautGroupe.clamp(0.0, double.infinity),
                  left: 14,
                  right: 14,
                  height: hauteurGroupe,
                  child: ReorderableListView.builder(
                    primary: false,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    buildDefaultDragHandles: false,
                    itemCount: ordreBlocsAccueil.length,
                    onReorderItem: (ancienIndex, nouvelIndex) {
                      setState(() {
                        final bloc = ordreBlocsAccueil.removeAt(ancienIndex);
                        ordreBlocsAccueil.insert(nouvelIndex, bloc);
                      });
                      enregistrerDonnees();
                    },
                    itemBuilder: (context, index) {
                      final identifiant = ordreBlocsAccueil[index];
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey('bloc_accueil_$identifiant'),
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: construireBloc(identifiant),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
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
              child: const Text('Annuler'),
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
      titre: 'Remettre ce mois à zéro ?',
      description:
          'La feuille de ${libelleMois(mois)} sera conservée. '
          'Toutes ses dépenses, charges fixes et rentrées seront supprimées. '
          'Le salaire, l’épargne et le reliquat seront remis à zéro.',
      action: 'Remettre ce mois à zéro',
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
        SnackBar(content: Text('Sauvegarde impossible : $erreur')),
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
      titre: 'Supprimer ce mois ?',
      description:
          'La feuille de ${libelleMois(mois)} et toutes ses '
          'données seront supprimées.',
      action: 'Supprimer ce mois',
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

    setState(() => suppressionMensuelleEnCours = true);
    try {
      await enregistrerDonnees(
        moisSupprime: mois,
        moisRestantActif: destination,
      );
      if (!mounted) return;
      setState(() {
        feuillesMensuelles.remove(mois);
        moisActif = destination;
        reconstruirePagesMensuelles();
        reinitialiserOptionsImport();
      });
    } catch (erreur) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suppression impossible : $erreur')),
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
            if (cleRecherche(op.intitule).contains(terme))
              (mois: feuille.key, page: page, operation: op),
    ]..sort((a, b) => b.operation.date.compareTo(a.operation.date));

    if (lignes.isEmpty) {
      return const Center(child: Text('Aucune opération trouvée'));
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: lignes.length,
      itemBuilder: (context, index) {
        final ligne = lignes[index];
        return ListTile(
          title: Text(ligne.operation.intitule),
          subtitle: Text('${libelleMois(ligne.mois)} · ${titres[ligne.page]}'),
          trailing: Text(montantFormate(ligne.operation.montant)),
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
      },
    );
  }

  Widget pageStatistique(String mois) {
    int numero(String cle) {
      final date = GestionFeuillesMensuellesV2.dateDepuisIdentifiant(cle);
      return (date.year - 1) * 12 + date.month - 1;
    }

    final totaux = <int, double>{
      for (final feuille in feuillesMensuelles.entries)
        numero(feuille.key): feuille.value.totalOperations(1),
    };

    return _RechercheStatistique(
      resultats: resultatsRechercheStatistique,
      graphique: _BilanFrise(
        detailsMois: (n, tri) {
          final date = DateTime(n ~/ 12 + 1, n % 12 + 1);
          final cle = GestionFeuillesMensuellesV2.identifiant(date);
          final budget = feuillesMensuelles[cle];
          if (budget == null || budget.operations[1]!.isEmpty) {
            return SliverToBoxAdapter(
              child: Text(
                budget == null
                    ? 'Aucune feuille pour ce mois'
                    : 'Aucune dépense pour ce mois',
              ),
            );
          }
          final depenses = operationsTriees(budget, 1, triForce: tri);
          return SliverList.builder(
            itemCount: depenses.length,
            itemBuilder: (context, index) => carteOperation(depenses[index], 1),
          );
        },
        // SOUS_TOTAL_STATISTIQUES_V1
        sousTotalMois: (n) {
          final date = DateTime(n ~/ 12 + 1, n % 12 + 1);
          final cle = GestionFeuillesMensuellesV2.identifiant(date);
          final budget = feuillesMensuelles[cle];

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
              decoration: BoxDecoration(
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
                      'Sous-total sélection (${selection.length})',
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
      tooltip: 'Options de la feuille',
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
      icon: Icon(Icons.more_vert_rounded, color: widget.accent, size: 27),
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
          child: const Row(
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
                  'Supprimer ce mois',
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
              const Flexible(
                child: Text(
                  'Remettre ce mois à zéro',
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

    return Column(
      children: [
        blocTotalPage(budget),
        Expanded(child: listeOperations(budget)),
      ],
    );
  }

  Widget pageParametres() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Material(
          color: couleurBlocPalette(),
          borderRadius: BorderRadius.circular(18),
          elevation: 6,
          shadowColor: Colors.black.withValues(
            alpha: widget.sombre ? 0.42 : 0.24,
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Apparence',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Thème sombre'),
                  value: widget.sombre,
                  onChanged: widget.onTheme,
                ),
                const SizedBox(height: 12),
                const Text('Couleur d’accent'),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Teinte : ${HSVColor.fromColor(widget.accent).hue.round()}°',
                      style: const TextStyle(fontWeight: FontWeight.w500),
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
                            overlayColor: widget.accent.withValues(alpha: 0.15),
                          ),
                          child: Slider(
                            value: HSVColor.fromColor(widget.accent).hue,
                            min: 0,
                            max: 360,
                            divisions: 360,
                            label:
                                '${HSVColor.fromColor(widget.accent).hue.round()}°',
                            onChanged: (valeur) {
                              final hsv = HSVColor.fromColor(widget.accent);
                              widget.onAccent(hsv.withHue(valeur).toColor());
                            },
                            onChangeEnd: (_) => enregistrerDonnees(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Saturation : ${(widget.saturationPalette * 100).round()} %',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Slider(
                  value: widget.saturationPalette,
                  min: 0,
                  max: 1,
                  divisions: 100,
                  activeColor: widget.accent,
                  label: '${(widget.saturationPalette * 100).round()} %',
                  onChanged: widget.onSaturationPalette,
                  onChangeEnd: (_) => enregistrerDonnees(),
                ),
                const SizedBox(height: 12),
                Text(
                  'Luminosité : ${(widget.luminositePalette * 100).round()} %',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Slider(
                  value: widget.luminositePalette,
                  min: 0,
                  max: 1,
                  divisions: 100,
                  activeColor: widget.accent,
                  label: '${(widget.luminositePalette * 100).round()} %',
                  onChanged: widget.onLuminositePalette,
                  onChangeEnd: (_) => enregistrerDonnees(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final couleurInactive = widget.sombre
        ? const Color(0xFF9299A3)
        : const Color(0xFF626973);

    final ecran = Scaffold(
      floatingActionButton: pageActive >= 4 || creationAffichee
          ? null
          : SizedBox(
              width: 84,
              height: 84,
              child: FloatingActionButton(
                onPressed: donneesChargees ? ajouterOperation : null,
                backgroundColor: HSVColor.fromColor(widget.accent)
                    .withSaturation(
                      (HSVColor.fromColor(widget.accent).saturation * 1.30)
                          .clamp(0.0, 1.0),
                    )
                    .withValue(
                      (HSVColor.fromColor(widget.accent).value * 0.72).clamp(
                        0.0,
                        1.0,
                      ),
                    )
                    .toColor(),
                foregroundColor: Colors.white,
                elevation: 9,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(23),
                ),
                child: const Icon(Icons.add_rounded, size: 43),
              ),
            ),
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: 64,
              decoration: BoxDecoration(
                color: couleurBlocPalette(),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(couleurBlocPalette(), Colors.white, 0.18)!,
                    couleurBlocPalette(),
                    couleurBlocPalette(),
                    Color.lerp(couleurBlocPalette(), Colors.black, 0.30)!,
                  ],
                  stops: const [0.0, 0.25, 0.65, 1.0],
                ),
              ),
              child: LayoutBuilder(
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
                        setState(() {
                          iconeSidebarSurvolee = null;
                        });
                        if (destination != null) {
                          changerPage(destination);
                        }
                      }
                    },
                    onPointerCancel: (evenement) {
                      if (evenement.pointer == pointeurSidebar) {
                        pointeurSidebar = null;
                        glissementSidebarActif = false;
                        setState(() {
                          iconeSidebarSurvolee = null;
                        });
                      }
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(titres.length, (index) {
                        final actif = index == pageActive;
                        final bulle = iconeSidebarSurvolee == index;

                        return Column(
                          children: [
                            InkWell(
                              onTap: () => changerPage(index),
                              child: SizedBox(
                                width: 64,
                                height: hauteurIconeSidebar(hauteurSidebar),
                                child: Center(
                                  child: AnimatedScale(
                                    scale: bulle ? 1.75 : 1.0,
                                    duration: const Duration(milliseconds: 160),
                                    curve: Curves.easeOutCubic,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: (actif || bulle)
                                            ? widget.accent.withValues(
                                                alpha: 0.18,
                                              )
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Icon(
                                        icones[index],
                                        size: 26,
                                        color: (actif || bulle)
                                            ? widget.accent
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
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                          ],
                        );
                      }),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  // TITRES_ENCARTS_V2
                  Container(
                    width: double.infinity,
                    height: 112,
                    margin: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                    decoration: BoxDecoration(
                      color: couleurBlocPalette(),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned(
                          left: 0,
                          right: pageActive >= 4 ? 0 : 49,
                          top: 0,
                          bottom: 0,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: Text(
                                  titres[pageActive],
                                  key: ValueKey(pageActive),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              if (pageActive != 4) const SizedBox(height: 5),
                              if (pageActive != 4)
                                ValueListenableBuilder(
                                  valueListenable: moisVisible,
                                  builder: (context, mois, child) => Text(
                                    libelleMois(mois),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w500,
                                      color: widget.accent,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (pageActive < 4)
                          Positioned(
                            top: 0,
                            bottom: 0,
                            right: 0,
                            width: 49,
                            child: Row(
                              children: [
                                Container(
                                  width: 1,
                                  height: 72,
                                  color: Colors.white.withValues(
                                    alpha: widget.sombre ? 0.30 : 0.45,
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: ValueListenableBuilder(
                                      valueListenable: moisVisible,
                                      builder: (context, mois, child) =>
                                          menuActionsMois(mois),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(child: contenuMensuelAnime()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return AbsorbPointer(absorbing: suppressionMensuelleEnCours, child: ecran);
  }
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

class _BilanFriseState extends State<_BilanFrise> {
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

  String nomMois(int numero) => '${noms[numero % 12]} ${numero ~/ 12 + 1}';

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
              decoration: BoxDecoration(
                color: actif
                    ? widget.accent.withValues(alpha: 0.18)
                    : Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: actif
                      ? widget.accent.withValues(alpha: 0.65)
                      : Colors.transparent,
                ),
              ),
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
          bouton('Date', TriOperationsV2.date),
          bouton('ABC', TriOperationsV2.nature),
        ],
      ),
    );
  }

  Widget colonne(int numero, Color texte) {
    final montant = widget.totaux[numero];
    final valeur = montant == null ? '—' : widget.montantFormate(montant);
    final description =
        '${nomMois(numero)}, ${montant == null ? "sans feuille" : valeur}';
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
                  child: Text(courts[numero % 12]),
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
    final fond = Color.alphaBlend(
      widget.accent.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.16 : 0.12,
      ),
      theme.colorScheme.surface,
    );

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverList.list(
                children: [
                  Text(
                    'Dépenses hors charges fixes',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: recentrerSurMoisEnCours,
                      icon: const Icon(Icons.my_location_rounded, size: 18),
                      label: const Text('Mois en cours'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                    decoration: BoxDecoration(
                      color: fond,
                      borderRadius: BorderRadius.circular(18),
                    ),
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
                                  largeurColonne != largeur)
                                return;
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
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 34,
                                child: Container(
                                  height: 1,
                                  color: theme.dividerColor,
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
                            'Dépenses · ${nomMois(n)}',
                            style: theme.textTheme.titleMedium,
                          ),
                          if (ecart != null)
                            Text(
                              ecart == 0
                                  ? 'Même montant que le mois précédent'
                                  : '${widget.montantFormate(ecart.abs())} de ${ecart > 0 ? "plus" : "moins"} que le mois précédent',
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
    required this.graphique,
    required this.resultats,
  });

  final Widget graphique;
  final Widget Function(String terme) resultats;

  @override
  State<_RechercheStatistique> createState() => _RechercheStatistiqueState();
}

class _RechercheStatistiqueState extends State<_RechercheStatistique> {
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
              hintText: 'Rechercher sur tous les mois',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: terme.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer la recherche',
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
