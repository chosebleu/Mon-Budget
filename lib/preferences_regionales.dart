import 'package:intl/intl.dart';

class PreferencesRegionales {
  // CATALOGUE_DEVISES_V1
  static const codesDevises =
      'AED AFN ALL AMD AOA ARS AUD AWG AZN '
      'BAM BBD BDT BHD BIF BMD BND BOB BRL BSD BTN BWP BYN BZD '
      'CAD CDF CHF CLP CNY COP CRC CUP CVE CZK '
      'DJF DKK DOP DZD EGP ERN ETB EUR '
      'FJD FKP GBP GEL GHS GIP GMD GNF GTQ GYD '
      'HKD HNL HTG HUF IDR ILS INR IQD IRR ISK '
      'JMD JOD JPY KES KGS KHR KMF KPW KRW KWD KYD KZT '
      'LAK LBP LKR LRD LSL LYD MAD MDL MGA MKD MMK MNT '
      'MOP MRU MUR MVR MWK MXN MYR MZN '
      'NAD NGN NIO NOK NPR NZD OMR '
      'PAB PEN PGK PHP PKR PLN PYG QAR '
      'RON RSD RUB RWF SAR SBD SCR SDG SEK SGD SHP '
      'SLE SOS SRD SSP STN SVC SYP SZL '
      'THB TJS TMT TND TOP TRY TTD TWD TZS '
      'UAH UGX USD UYU UZS VES VND VUV WST '
      'XAF XCD XCG XOF XPF YER ZAR ZMW ZWG';

  static final devises = List<String>.unmodifiable(codesDevises.split(' '));

  static const devisesPrincipales = <String>[
    'EUR',
    'USD',
    'GBP',
    'CHF',
    'CAD',
    'AUD',
    'JPY',
    'CNY',
    'PLN',
    'BRL',
  ];

  // FORMATS_REGIONAUX_V2
  static String formaterSaisie(double montant, String langue) {
    final texte = montant.toStringAsFixed(2);
    final separateur = NumberFormat.decimalPattern(langue).symbols.DECIMAL_SEP;
    return texte.replaceAll('.', separateur);
  }

  static String formaterMoisCourt(DateTime date, String langue) {
    final format = _formatsDates.putIfAbsent(
      '$langue-mois-court',
      () => DateFormat.MMM(langue),
    );

    final texte = format.format(date);
    return texte.isEmpty ? texte : texte[0].toUpperCase() + texte.substring(1);
  }

  // FORMAT_DATES_V1
  static final _formatsDates = <String, DateFormat>{};

  static String formaterMois(DateTime date, String langue) {
    final format = _formatsDates.putIfAbsent(
      '$langue-mois',
      () => DateFormat.yMMMM(langue),
    );
    final texte = format.format(date);
    return texte.isEmpty ? texte : texte[0].toUpperCase() + texte.substring(1);
  }

  static String formaterDate(DateTime date, String langue) {
    final format = _formatsDates.putIfAbsent(
      '$langue-date',
      () => DateFormat.yMd(langue).add_Hm(),
    );
    return format.format(date);
  }

  // FORMAT_MONETAIRE_V1
  static final _formats = <String, NumberFormat>{};

  static String formaterMontant(double montant, String langue, String devise) {
    if (langue == 'fr' && devise == 'EUR') {
      return '${montant.toStringAsFixed(2).replaceAll('.', ',')} €';
    }

    final cle = '$langue-$devise';

    final format = _formats.putIfAbsent(
      cle,
      () => NumberFormat.currency(
        locale: langue,
        name: devise,
        symbol: devise == 'EUR' ? '€' : devise,
        decimalDigits: 2,
      ),
    );

    return format.format(montant);
  }

  static const langues = <String, String>{
    'fr': 'Français',
    'en': 'English',
    'es': 'Español',
    'pt': 'Português',
    'de': 'Deutsch',
    'it': 'Italiano',
    'nl': 'Nederlands',
    'pl': 'Polski',
  };

  static String langueValide(
    Object? valeur, {
    required bool ancienneInstallation,
    required String langueSysteme,
  }) {
    if (valeur is String && langues.containsKey(valeur)) {
      return valeur;
    }
    if (ancienneInstallation) return 'fr';
    return langues.containsKey(langueSysteme) ? langueSysteme : 'en';
  }

  static String deviseValide(Object? valeur) {
    if (valeur is String && devises.contains(valeur)) {
      return valeur;
    }
    return 'EUR';
  }
}
