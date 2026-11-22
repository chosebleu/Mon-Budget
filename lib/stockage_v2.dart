import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class StockageBudgetV2 {
  static Future<File> fichier() async {
    final dossier = await getApplicationDocumentsDirectory();
    return File('${dossier.path}/mon_budget_v2.json');
  }

  static Future<Map<String, dynamic>> charger() async {
    final principal = await fichier();
    final secours = File('${principal.path}.bak');

    for (final candidat in [principal, secours]) {
      if (!await candidat.exists()) continue;

      try {
        final contenu = jsonDecode(await candidat.readAsString());

        if (contenu is Map<String, dynamic>) {
          return contenu;
        }
      } catch (_) {
        // Essayer la copie de secours.
      }
    }

    if (await principal.exists() || await secours.exists()) {
      throw const FormatException('Sauvegarde illisible');
    }

    return <String, dynamic>{};
  }

  static Future<void> enregistrer(Map<String, dynamic> donnees) async {
    final principal = await fichier();
    final temporaire = File('${principal.path}.tmp');
    final secours = File('${principal.path}.bak');

    await temporaire.writeAsString(jsonEncode(donnees), flush: true);

    if (await principal.exists()) {
      if (await secours.exists()) {
        await secours.delete();
      }

      await principal.rename(secours.path);
    }

    try {
      await temporaire.rename(principal.path);
    } catch (_) {
      if (!await principal.exists() && await secours.exists()) {
        await secours.rename(principal.path);
      }
      rethrow;
    }
  }
}
