import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:mon_budget/stockage_v2.dart';

class FauxStockageV2 extends PathProviderPlatform {
  FauxStockageV2(this.dossier);

  final Directory dossier;

  @override
  Future<String?> getApplicationDocumentsPath() async => dossier.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dossier;
  late PathProviderPlatform fournisseurOriginal;

  setUp(() async {
    fournisseurOriginal = PathProviderPlatform.instance;
    dossier = await Directory.systemTemp.createTemp('budget_stockage_');
    PathProviderPlatform.instance = FauxStockageV2(dossier);
  });

  tearDown(() async {
    PathProviderPlatform.instance = fournisseurOriginal;
    if (await dossier.exists()) {
      await dossier.delete(recursive: true);
    }
  });

  test('Lecture initiale et sauvegarde JSON', () async {
    expect(await StockageBudgetV2.charger(), isEmpty);

    final donnees = <String, dynamic>{
      'operations': {
        '0': [
          {
            'intitule': 'Courses',
            'montant': 25.50,
            'date': '2026-11-19T12:00:00.000',
          },
        ],
        '1': [],
        '2': [],
      },
      'intitules': ['Courses'],
    };

    await StockageBudgetV2.enregistrer(donnees);

    expect(await StockageBudgetV2.charger(), equals(donnees));

    final fichier = await StockageBudgetV2.fichier();
    expect(await fichier.exists(), isTrue);
  });

  test('Recuperation depuis la copie de secours', () async {
    await StockageBudgetV2.enregistrer({'version': 1});
    await StockageBudgetV2.enregistrer({'version': 2});

    final fichier = await StockageBudgetV2.fichier();
    await fichier.writeAsString('JSON invalide');

    expect(await StockageBudgetV2.charger(), equals({'version': 1}));
  });
}
