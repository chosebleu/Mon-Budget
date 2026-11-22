// Gestion des feuilles mensuelles de Mon Budget V2.
//
// Ce module ne modifie pas le fichier de stockage existant.
// Il prepare une migration explicite vers des mois independants.

class FeuilleMensuelleV2 {
  FeuilleMensuelleV2({
    required this.mois,
    required this.operations,
    required this.salaire,
    required this.reliquat,
    required this.epargne,
  });

  /// Identifiant stable au format AAAA-MM.
  final String mois;

  /// Operations classees par page : 0, 1, 2 et 3.
  final Map<String, List<Map<String, dynamic>>> operations;

  final double salaire;
  final double reliquat;
  final double epargne;

  double get totalDisponible => calculerTotalDisponible(
    salaire: salaire,
    reliquat: reliquat,
    depenses: _totalOperations('1'),
    charges: _totalOperations('2'),
  );

  double _totalOperations(String page) => (operations[page] ?? []).fold<double>(
    0,
    (total, operation) => total + (operation['montant'] as num),
  );

  static double calculerTotalDisponible({
    required double salaire,
    required double reliquat,
    required double depenses,
    required double charges,
  }) => salaire + reliquat - depenses - charges;

  Map<String, dynamic> toJson() => {
    'operations': operations,
    'salaire': salaire,
    'reliquat': reliquat,
    'epargne': epargne,
  };

  factory FeuilleMensuelleV2.fromJson(
    String mois,
    Map<String, dynamic> donnees,
  ) {
    final operations = <String, List<Map<String, dynamic>>>{
      '0': [],
      '1': [],
      '2': [],
      '3': [],
    };

    final source = donnees['operations'];

    if (source != null && source is! Map) {
      throw const FormatException('Operations mensuelles invalides');
    }

    if (source is Map) {
      for (final page in operations.keys) {
        final elements = source[page];

        if (elements == null) continue;
        if (elements is! List) {
          throw const FormatException('Liste mensuelle invalide');
        }

        operations[page] = [
          for (final element in elements)
            if (element is Map)
              Map<String, dynamic>.from(element)
            else
              throw const FormatException('Operation mensuelle invalide'),
        ];
      }
    }

    double montant(String cle) {
      final valeur = donnees[cle];

      if (valeur == null) return 0;
      if (valeur is! num ||
          !valeur.isFinite ||
          (cle != 'reliquat' && valeur < 0)) {
        throw FormatException('Montant mensuel invalide : $cle');
      }

      return valeur.toDouble();
    }

    return FeuilleMensuelleV2(
      mois: mois,
      operations: operations,
      salaire: montant('salaire'),
      reliquat: montant('reliquat'),
      epargne: montant('epargne'),
    );
  }
}

class OptionsImportMensuelV2 {
  const OptionsImportMensuelV2({
    this.revenus = false,
    this.charges = false,
    this.reliquat = false,
    this.epargne = false,
  });

  final bool revenus;
  final bool charges;
  final bool reliquat;
  final bool epargne;

  static const toutImporter = OptionsImportMensuelV2(
    revenus: true,
    charges: true,
    reliquat: true,
    epargne: true,
  );
}

class GestionFeuillesMensuellesV2 {
  static String identifiant(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}';
  }

  static DateTime dateDepuisIdentifiant(String identifiant) {
    final correspondance = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(identifiant);

    if (correspondance == null) {
      throw const FormatException('Identifiant mensuel invalide');
    }

    final annee = int.parse(correspondance.group(1)!);
    final mois = int.parse(correspondance.group(2)!);

    if (annee < 1 || mois < 1 || mois > 12) {
      throw const FormatException('Date mensuelle invalide');
    }

    return DateTime(annee, mois);
  }

  static String deplacer(String identifiant, int decalage) {
    final date = dateDepuisIdentifiant(identifiant);
    return GestionFeuillesMensuellesV2.identifiant(
      DateTime(date.year, date.month + decalage),
    );
  }

  static Map<String, dynamic> recopierOperationPourMois(
    Map<String, dynamic> operation,
    String mois,
  ) {
    final copie = Map<String, dynamic>.from(operation);
    final ancienneDate = copie['date'];

    if (ancienneDate is! String) {
      throw const FormatException('Date de l operation invalide');
    }

    final date = DateTime.parse(ancienneDate);
    final destination = dateDepuisIdentifiant(mois);

    final dernierJour = DateTime(
      destination.year,
      destination.month + 1,
      0,
    ).day;

    final jour = date.day > dernierJour ? dernierJour : date.day;

    final nouvelleDate = date.isUtc
        ? DateTime.utc(
            destination.year,
            destination.month,
            jour,
            date.hour,
            date.minute,
            date.second,
            date.millisecond,
            date.microsecond,
          )
        : DateTime(
            destination.year,
            destination.month,
            jour,
            date.hour,
            date.minute,
            date.second,
            date.millisecond,
            date.microsecond,
          );

    copie['date'] = nouvelleDate.toIso8601String();

    return copie;
  }

  static FeuilleMensuelleV2 creer({
    required String mois,
    FeuilleMensuelleV2? precedente,
    OptionsImportMensuelV2 options = const OptionsImportMensuelV2(),
  }) {
    final operations = <String, List<Map<String, dynamic>>>{
      '0': [],
      '1': [],
      '2': [],
      '3': [],
    };

    if (precedente != null) {
      if (options.revenus) {
        operations['3'] = [
          for (final operation in precedente.operations['3'] ?? [])
            recopierOperationPourMois(operation, mois),
        ];
      }

      if (options.charges) {
        operations['2'] = [
          for (final operation in precedente.operations['2'] ?? [])
            recopierOperationPourMois(operation, mois),
        ];
      }
    }

    return FeuilleMensuelleV2(
      mois: mois,
      operations: operations,
      salaire: precedente != null && options.revenus ? precedente.salaire : 0,
      reliquat: precedente != null && options.reliquat
          ? precedente.totalDisponible
          : 0,
      epargne: precedente != null && options.epargne ? precedente.epargne : 0,
    );
  }

  /// Migration sans destruction : l'ancien format est conserve
  /// jusqu'a la validation de l'integration dans main.dart.
  static Map<String, dynamic> preparerMigration({
    required Map<String, dynamic> donnees,
    required String moisInitial,
  }) {
    if (donnees['feuillesMensuelles'] is Map) {
      return Map<String, dynamic>.from(donnees);
    }

    final resultat = Map<String, dynamic>.from(donnees);

    resultat['moisActif'] = moisInitial;
    resultat['feuillesMensuelles'] = {
      moisInitial: {
        'operations':
            donnees['operations'] ?? {'0': [], '1': [], '2': [], '3': []},
        'salaire': donnees['salaire'] ?? 0,
        'reliquat': donnees['reliquat'] ?? 0,
        'epargne': donnees['epargne'] ?? 0,
      },
    };

    return resultat;
  }
}
