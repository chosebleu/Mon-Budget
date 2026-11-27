package com.chosebleu.mon_budget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.widget.RemoteViews

class BudgetWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray
    ) {
        for (id in ids) {
            actualiser(context, manager, id)
        }
    }

    companion object {

        const val ACTION_AJOUT =
            "com.chosebleu.mon_budget_v2.AJOUT_WIDGET"

        fun actualiser(
            context: Context,
            manager: AppWidgetManager,
            id: Int
        ) {
            val preferences = context.getSharedPreferences(
                "budget_widget", Context.MODE_PRIVATE
            )

            val accent = preferences.getInt(
                "accent", 0xFF67B99A.toInt()
            )

            val bitmap = Bitmap.createBitmap(
                256, 256, Bitmap.Config.ARGB_8888
            )

            val canvas = Canvas(bitmap)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)

            paint.color = accent
            canvas.drawRoundRect(
                RectF(5f, 5f, 251f, 251f),
                58f, 58f, paint
            )

            // WIDGET_RELIEF_V1
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 5f
            paint.shader = android.graphics.LinearGradient(
                0f, 5f, 0f, 251f,
                intArrayOf(
                    0x75FFFFFF.toInt(),
                    0x12FFFFFF,
                    0x00000000,
                    0x0A000000,
                    0x52000000
                ),
                floatArrayOf(0f, 0.24f, 0.5f, 0.76f, 1f),
                android.graphics.Shader.TileMode.CLAMP
            )
            canvas.drawRoundRect(
                RectF(7.5f, 7.5f, 248.5f, 248.5f),
                55.5f, 55.5f, paint
            )
            paint.shader = null
            paint.style = Paint.Style.FILL

            paint.color = Color.WHITE
            paint.strokeWidth = 19f
            paint.strokeCap = Paint.Cap.ROUND

            canvas.drawLine(70f, 128f, 186f, 128f, paint)
            canvas.drawLine(128f, 70f, 128f, 186f, paint)

            val intent = Intent(
                context, MainActivity::class.java
            ).apply {
                action = ACTION_AJOUT
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            }

            val pending = PendingIntent.getActivity(
                context,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                    PendingIntent.FLAG_IMMUTABLE
            )

            val views = RemoteViews(
                context.packageName,
                R.layout.budget_widget
            )

            views.setImageViewBitmap(
                R.id.budget_widget_plus, bitmap
            )

            views.setOnClickPendingIntent(
                R.id.budget_widget_plus, pending
            )

            manager.updateAppWidget(id, views)
        }
    }
}