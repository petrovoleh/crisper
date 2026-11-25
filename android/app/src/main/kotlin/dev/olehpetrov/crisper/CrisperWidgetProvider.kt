package dev.olehpetrov.crisper

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class CrisperWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateSingleWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        private const val PREFS_NAME = "crisper_widget_prefs"

        fun saveAndRefresh(
            context: Context,
            expiringCount: Int,
            topUrgentLabel: String,
            pantryCount: Int
        ) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putInt("expiringCount", expiringCount)
                .putString("topUrgentLabel", topUrgentLabel)
                .putInt("pantryCount", pantryCount)
                .apply()

            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, CrisperWidgetProvider::class.java)
            )
            for (id in ids) {
                updateSingleWidget(context, manager, id)
            }
        }

        private fun updateSingleWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val expiringCount = prefs.getInt("expiringCount", 3)
            val topUrgent = prefs.getString("topUrgentLabel", "Шпинат молодий (1 день)")
                ?: "Усі продукти свіжі"
            val pantryCount = prefs.getInt("pantryCount", 14)

            val views = RemoteViews(context.packageName, R.layout.crisper_widget)
            views.setTextViewText(
                R.id.widget_badge,
                if (expiringCount > 0) "$expiringCount термінові" else "Свіже"
            )
            views.setTextViewText(R.id.widget_urgent_item, topUrgent)
            views.setTextViewText(
                R.id.widget_subtitle,
                "У наявності: $pantryCount продуктів • Zero-Waste"
            )

            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openPending = PendingIntent.getActivity(
                context,
                100,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, openPending)

            val scanIntent = Intent(context, MainActivity::class.java).apply {
                action = MainActivity.ACTION_OPEN_SCANNER
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val scanPending = PendingIntent.getActivity(
                context,
                101,
                scanIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_btn_scan, scanPending)

            val importIntent = Intent(context, MainActivity::class.java).apply {
                action = MainActivity.ACTION_OPEN_IMPORT
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val importPending = PendingIntent.getActivity(
                context,
                102,
                importIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_btn_import, importPending)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
