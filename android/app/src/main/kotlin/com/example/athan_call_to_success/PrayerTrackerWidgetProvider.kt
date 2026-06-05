package com.example.athan_call_to_success

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews

class PrayerTrackerWidgetProvider : AppWidgetProvider() {
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
        private val PRAYER_IDS = listOf(
            Pair("fajr", R.id.dot_fajr),
            Pair("dhuhr", R.id.dot_dhuhr),
            Pair("asr", R.id.dot_asr),
            Pair("maghrib", R.id.dot_maghrib),
            Pair("isha", R.id.dot_isha),
        )

        fun update(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.widget_prayer_tracker)

            for ((key, viewId) in PRAYER_IDS) {
                val done = prefs.getBoolean("widget_tracker_$key", false)
                views.setTextViewText(viewId, if (done) "●" else "○")
                views.setTextColor(viewId, if (done) Color.parseColor("#26C6A6") else Color.parseColor("#80FFFFFF"))
            }

            val count = prefs.getString("widget_tracker_count", "0/5") ?: "0/5"
            views.setTextViewText(R.id.tv_tracker_count, count)

            val intent = Intent(context, MainActivity::class.java).apply {
                putExtra("deeplink_tab", 2)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pi = PendingIntent.getActivity(context, 2, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            views.setOnClickPendingIntent(R.id.widget_root, pi)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
