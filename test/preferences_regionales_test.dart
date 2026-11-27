import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../lib/preferences_regionales.dart';
import '../lib/traductions.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  const langues = ['fr', 'en', 'es', 'pt', 'de', 'it', 'nl', 'pl'];

  test('Exactement huit langues disponibles', () {
    expect(PreferencesRegionales.langues.keys, unorderedEquals(langues));
  });

  test('Toutes les traductions possedent sept versions', () {
    for (final entree in Traductions.textes.entries) {
      expect(entree.value.length, 7, reason: entree.key);
      for (final version in entree.value) {
        expect(version.trim(), isNotEmpty, reason: entree.key);
      }
    }
  });

  test('Les variables des traductions sont conservees', () {
    final motif = RegExp(r'\{[a-zA-Z]+\}');

    for (final entree in Traductions.textes.entries) {
      final variables = motif
          .allMatches(entree.key)
          .map((m) => m.group(0))
          .toList();

      for (final version in entree.value) {
        expect(
          motif.allMatches(version).map((m) => m.group(0)),
          unorderedEquals(variables),
          reason: entree.key,
        );
      }
    }
  });

  for (final langue in langues) {
    test('Langue systeme : $langue', () {
      expect(
        PreferencesRegionales.langueValide(
          null,
          ancienneInstallation: false,
          langueSysteme: langue,
        ),
        langue,
      );
    });

    test('Preference manuelle : $langue', () {
      expect(
        PreferencesRegionales.langueValide(
          langue,
          ancienneInstallation: true,
          langueSysteme: 'en',
        ),
        langue,
      );
    });

    test('Formats regionaux : $langue', () {
      final date = DateTime(2026, 11, 27, 14, 30);

      expect(PreferencesRegionales.formaterMois(date, langue), isNotEmpty);

      expect(PreferencesRegionales.formaterMoisCourt(date, langue), isNotEmpty);

      expect(PreferencesRegionales.formaterDate(date, langue), isNotEmpty);

      final saisie = PreferencesRegionales.formaterSaisie(1234.56, langue);

      expect(double.parse(saisie.replaceAll(',', '.')), 1234.56);

      for (final devise in PreferencesRegionales.devises) {
        expect(
          PreferencesRegionales.formaterMontant(1234.56, langue, devise),
          isNotEmpty,
          reason: '$langue / $devise',
        );
      }
    });
  }

  test('Ancienne installation conserve le francais', () {
    expect(
      PreferencesRegionales.langueValide(
        null,
        ancienneInstallation: true,
        langueSysteme: 'de',
      ),
      'fr',
    );
  });

  test('Langue non prise en charge : anglais', () {
    expect(
      PreferencesRegionales.langueValide(
        null,
        ancienneInstallation: false,
        langueSysteme: 'ja',
      ),
      'en',
    );
  });

  test('Devise par defaut : EUR', () {
    expect(PreferencesRegionales.deviseValide(null), 'EUR');
    expect(PreferencesRegionales.deviseValide('ZZZ'), 'EUR');
  });

  test('Catalogue des devises sans doublons', () {
    final devises = PreferencesRegionales.devises;

    expect(devises.toSet().length, devises.length);

    for (final devise in devises) {
      expect(devise, matches(RegExp(r'^[A-Z]{3}$')));
      expect(PreferencesRegionales.deviseValide(devise), devise);
    }
  });

  test('Format historique francais conserve', () {
    expect(
      PreferencesRegionales.formaterMontant(1234.56, 'fr', 'EUR'),
      '1234,56 €',
    );
  });

  test('Traduction inconnue conserve le texte original', () {
    expect(Traductions.traduire('en', 'Texte personnel'), 'Texte personnel');
  });
}
