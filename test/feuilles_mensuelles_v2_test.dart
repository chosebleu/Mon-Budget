import 'package:flutter_test/flutter_test.dart';
import 'package:mon_budget/feuilles_mensuelles_v2.dart';

void main() {
  test('Navigation entre decembre et janvier', () {
    expect(GestionFeuillesMensuellesV2.deplacer('2026-12', 1), '2027-01');
    expect(GestionFeuillesMensuellesV2.deplacer('2027-01', -1), '2026-12');
  });

  test('Creation vierge sans import', () {
    final precedente = FeuilleMensuelleV2(
      mois: '2026-11',
      operations: {
        '0': [],
        '1': [
          {
            'intitule': 'Courses',
            'montant': 50.0,
            'date': '2026-11-10T12:00:00.000',
          },
        ],
        '2': [
          {
            'intitule': 'Loyer',
            'montant': 600.0,
            'date': '2026-11-01T12:00:00.000',
          },
        ],
        '3': [],
      },
      salaire: 2000,
      reliquat: 100,
      epargne: 250,
    );

    final nouvelle = GestionFeuillesMensuellesV2.creer(
      mois: '2026-12',
      precedente: precedente,
    );

    expect(nouvelle.operations['1'], isEmpty);
    expect(nouvelle.operations['2'], isEmpty);
    expect(nouvelle.salaire, 0);
    expect(nouvelle.reliquat, 0);
    expect(nouvelle.epargne, 0);
  });

  test('Tout importer sans depenses ponctuelles', () {
    final precedente = FeuilleMensuelleV2(
      mois: '2026-11',
      operations: {
        '0': [],
        '1': [
          {
            'intitule': 'Restaurant',
            'montant': 45.0,
            'date': '2026-11-12T10:00:00.000',
          },
        ],
        '2': [
          {
            'intitule': 'Loyer',
            'montant': 650.0,
            'date': '2026-11-01T10:00:00.000',
          },
        ],
        '3': [
          {
            'intitule': 'Prime',
            'montant': 150.0,
            'date': '2026-11-05T10:00:00.000',
          },
        ],
      },
      salaire: 2200,
      reliquat: 80,
      epargne: 300,
    );

    final nouvelle = GestionFeuillesMensuellesV2.creer(
      mois: '2026-12',
      precedente: precedente,
      options: OptionsImportMensuelV2.toutImporter,
    );

    expect(nouvelle.operations['1'], isEmpty);
    expect(nouvelle.operations['2']!.length, 1);
    expect(nouvelle.operations['3']!.length, 1);
    expect(nouvelle.salaire, 2200);
    expect(nouvelle.reliquat, 1585);
    expect(nouvelle.epargne, 300);

    nouvelle.operations['2']![0]['montant'] = 999.0;
    expect(precedente.operations['2']![0]['montant'], 650.0);
  });

  test('Le total disponible inclut une seule fois les 450 euros importés', () {
    final novembre = FeuilleMensuelleV2.fromJson('2026-11', {
      'salaire': 1300,
      'epargne': 100,
      'reliquat': 50,
      'operations': {
        '1': [
          {'montant': 400},
        ],
        '2': [
          {'montant': 500},
        ],
      },
    });

    final decembre = GestionFeuillesMensuellesV2.creer(
      mois: '2026-12',
      precedente: novembre,
      options: const OptionsImportMensuelV2(reliquat: true),
    );
    expect(decembre.reliquat, 450);
    expect(decembre.operations['1'], isEmpty);
    expect(decembre.salaire, 0);

    final donneesDecembre = <String, dynamic>{
      ...decembre.toJson(),
      'salaire': 2000,
      'operations': {
        '1': [
          {'montant': 300},
        ],
        '2': [
          {'montant': 800, 'date': '2026-12-01T12:00:00.000'},
        ],
      },
    };
    for (final epargne in [500, 900]) {
      final decembreComplete = FeuilleMensuelleV2.fromJson('2026-12', {
        ...donneesDecembre,
        'epargne': epargne,
      });
      expect(decembreComplete.totalDisponible, 1350);
      final janvier = GestionFeuillesMensuellesV2.creer(
        mois: '2027-01',
        precedente: decembreComplete,
        options: OptionsImportMensuelV2.toutImporter,
      );
      expect(janvier.reliquat, 1350);
      expect(janvier.epargne, epargne);
      expect(decembreComplete.toJson()['epargne'], epargne);
    }
    expect(novembre.reliquat, 50);
  });

  test('Migration non destructive et idempotente', () {
    final anciennes = <String, dynamic>{
      'operations': {
        '1': [
          {
            'intitule': 'Courses',
            'montant': 40.0,
            'date': '2026-11-10T12:00:00.000',
          },
        ],
      },
      'salaire': 1900.0,
      'reliquat': 90.0,
      'epargne': 200.0,
      'intitules': ['Courses'],
      'saturationPalette': 0.8,
    };

    final migration = GestionFeuillesMensuellesV2.preparerMigration(
      donnees: anciennes,
      moisInitial: '2026-11',
    );

    expect(migration['operations'], anciennes['operations']);
    expect(migration['salaire'], 1900.0);
    expect(migration['intitules'], ['Courses']);
    expect(migration['saturationPalette'], 0.8);
    expect(migration['moisActif'], '2026-11');

    final feuilles = migration['feuillesMensuelles'] as Map;
    expect(feuilles['2026-11']['salaire'], 1900.0);
    expect(feuilles['2026-11']['operations']['1'].length, 1);

    final seconde = GestionFeuillesMensuellesV2.preparerMigration(
      donnees: migration,
      moisInitial: '2026-12',
    );

    expect(seconde['moisActif'], '2026-11');
  });

  test('Les dates importees correspondent au nouveau mois', () {
    final precedente = FeuilleMensuelleV2(
      mois: '2026-01',
      operations: {
        '0': [],
        '1': [],
        '2': [
          {
            'intitule': 'Abonnement',
            'montant': 25.0,
            'date': '2026-01-31T08:30:00.000',
          },
        ],
        '3': [],
      },
      salaire: 0,
      reliquat: 0,
      epargne: 0,
    );

    final nouvelle = GestionFeuillesMensuellesV2.creer(
      mois: '2026-02',
      precedente: precedente,
      options: const OptionsImportMensuelV2(charges: true),
    );

    expect(nouvelle.operations['2']![0]['date'], '2026-02-28T08:30:00.000');

    expect(precedente.operations['2']![0]['date'], '2026-01-31T08:30:00.000');
  });
  test('Sauvegarde et restauration d une feuille', () {
    final feuille = FeuilleMensuelleV2(
      mois: '2026-12',
      operations: {'0': [], '1': [], '2': [], '3': []},
      salaire: 2500,
      reliquat: 75,
      epargne: 400,
    );

    final restauree = FeuilleMensuelleV2.fromJson('2026-12', feuille.toJson());

    expect(restauree.mois, '2026-12');
    expect(restauree.salaire, 2500);
    expect(restauree.reliquat, 75);
    expect(restauree.epargne, 400);
  });
}
