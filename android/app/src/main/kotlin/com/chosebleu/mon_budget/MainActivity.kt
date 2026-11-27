package com.chosebleu.mon_budget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var canalWidget: MethodChannel? = null
    private var ajoutEnAttente = false

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == BudgetWidget.ACTION_AJOUT) {
            ajoutEnAttente = true
            intent.action = Intent.ACTION_MAIN
            canalWidget?.invokeMethod("demandeAjout", null)
        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (intent?.action == BudgetWidget.ACTION_AJOUT) {
            ajoutEnAttente = true
            intent?.action = Intent.ACTION_MAIN
        }
        canalWidget = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "mon_budget/widget"
        )
        canalWidget?.setMethodCallHandler { call, result ->
            if (call.method == "consommerDemandeAjout") {
                val demande = ajoutEnAttente
                ajoutEnAttente = false
                result.success(demande)
            } else if (call.method == "actualiserCouleur") {
                val accent = (call.arguments as? Number)?.toInt()
                if (accent == null) {
                    result.error("COULEUR", "Couleur invalide", null)
                } else {
                    getSharedPreferences("budget_widget", Context.MODE_PRIVATE)
                        .edit().putInt("accent", accent).apply()

                    val manager = AppWidgetManager.getInstance(this)
                    val ids = manager.getAppWidgetIds(
                        ComponentName(this, BudgetWidget::class.java)
                    )

                    for (id in ids) {
                        BudgetWidget.actualiser(this, manager, id)
                    }
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}