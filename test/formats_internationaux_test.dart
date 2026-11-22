import 'package:flutter_test/flutter_test.dart';
import 'package:mon_budget/formats_internationaux.dart';

void main() {
  group('Formats internationaux', () {
    test('Six devises disponibles', () {
      expect(FormatsInternationaux.devises.length, 6);
      expect(FormatsInternationaux.devises.map((d) => d.code).toList(), [
        'EUR',
        'USD',
        'GBP',
        'CAD',
        'CHF',
        'JPY',
      ]);
    });

    test('Euro francais', () {
      expect(FormatsInternationaux.montant(1234.56), '1234,56 €');
    });

    test('Dollar americain anglais', () {
      expect(
        FormatsInternationaux.montant(1234.56, codeDevise: 'USD', langue: 'en'),
        '\$1,234.56',
      );
    });

    test('Livre sterling anglaise', () {
      expect(
        FormatsInternationaux.montant(1234.56, codeDevise: 'GBP', langue: 'en'),
        '£1,234.56',
      );
    });

    test('Dollar canadien francais', () {
      expect(
        FormatsInternationaux.montant(1234.56, codeDevise: 'CAD'),
        '1\u202F234,56\u00A0CA\$',
      );
    });

    test('Franc suisse francais', () {
      expect(
        FormatsInternationaux.montant(1234.56, codeDevise: 'CHF'),
        '1\u202F234,56\u00A0CHF',
      );
    });

    test('Yen japonais sans decimales', () {
      expect(
        FormatsInternationaux.montant(1234.56, codeDevise: 'JPY', langue: 'en'),
        '¥1,235',
      );
    });

    test('Montant negatif', () {
      expect(
        FormatsInternationaux.montant(
          -1234.56,
          codeDevise: 'USD',
          langue: 'en',
        ),
        '-\$1,234.56',
      );
    });

    test('Devise inconnue : repli sur euro', () {
      expect(FormatsInternationaux.devise('XXX').code, 'EUR');
    });
  });
}
