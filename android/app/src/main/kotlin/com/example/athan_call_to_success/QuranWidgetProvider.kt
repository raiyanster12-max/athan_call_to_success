package com.example.athan_call_to_success

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class QuranWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            update(context, appWidgetManager, id)
        }
    }

    companion object {
        fun update(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

            val arabic = prefs.getString("widget_quran_arabic", "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
            val translation = prefs.getString(
                "widget_quran_translation",
                "In the name of Allah, the Entirely Merciful, the Especially Merciful."
            )
            val reference = prefs.getString("widget_quran_reference", "Al-Fatihah 1:1")

            val views = RemoteViews(context.packageName, R.layout.widget_quran)
            views.setTextViewText(R.id.tv_arabic, arabic)
            views.setTextViewText(R.id.tv_translation, translation)
            views.setTextViewText(R.id.tv_reference, reference)

            val intent = Intent(context, MainActivity::class.java).apply {
                putExtra("deeplink_tab", 1)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pi = PendingIntent.getActivity(context, 3, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            views.setOnClickPendingIntent(R.id.widget_root, pi)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
