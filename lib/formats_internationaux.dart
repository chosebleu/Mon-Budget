class DeviseBudget {
  const DeviseBudget({
    required this.code,
    required this.symbole,
    required this.decimales,
  });

  final String code;
  final String symbole;
  final int decimales;
}

class FormatsInternationaux {
  static const devises = <DeviseBudget>[
    DeviseBudget(code: 'EUR', symbole: '€', decimales: 2),
    DeviseBudget(code: 'USD', symbole: '\$', decimales: 2),
    DeviseBudget(code: 'GBP', symbole: '£', decimales: 2),
    DeviseBudget(code: 'CAD', symbole: 'CA\$', decimales: 2),
    DeviseBudget(code: 'CHF', symbole: 'CHF', decimales: 2),
    DeviseBudget(code: 'JPY', symbole: '¥', decimales: 0),
  ];

  static DeviseBudget devise(String code) {
    for (final element in devises) {
      if (element.code == code) return element;
    }
    return devises.first;
  }

  static String montant(
    double valeur, {
    String codeDevise = 'EUR',
    String langue = 'fr',
  }) {
    final configuration = devise(codeDevise);
    final anglais = langue.toLowerCase().startsWith('en');

    // Conserver l'affichage historique pour l'euro en francais.
    if (configuration.code == 'EUR' && !anglais) {
      return '${valeur.toStringAsFixed(2).replaceAll('.', ',')} €';
    }

    final negatif = valeur < 0;
    final absolu = valeur.abs();

    final parties = absolu.toStringAsFixed(configuration.decimales).split('.');
    final chiffres = parties.first;

    final groupes = <String>[];
    for (var fin = chiffres.length; fin > 0; fin -= 3) {
      final debut = fin - 3 < 0 ? 0 : fin - 3;
      groupes.insert(0, chiffres.substring(debut, fin));
    }

    final separateurMilliers = anglais ? ',' : '\u202F';
    final separateurDecimal = anglais ? '.' : ',';

    var nombre = groupes.join(separateurMilliers);

    if (configuration.decimales > 0) {
      nombre += '$separateurDecimal${parties.last}';
    }

    final signe = negatif ? '-' : '';

    if (anglais && const ['USD', 'GBP', 'CAD', 'JPY'].contains(codeDevise)) {
      return '$signe${configuration.symbole}$nombre';
    }

    return '$signe$nombre\u00A0${configuration.symbole}';
  }
}
