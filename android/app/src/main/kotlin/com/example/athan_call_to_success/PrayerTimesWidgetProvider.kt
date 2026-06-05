package com.example.athan_call_to_success

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews

class PrayerTimesWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            update(context, appWidgetManager, id)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        update(context, appWidgetManager, appWidgetId)
    }

    companion object {
        fun update(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val maxWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0)
            val maxHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
            val useHorizontal = maxHeight == 0 || maxWidth >= maxHeight * 1.5

            val layoutId = if (useHorizontal) R.layout.widget_prayer_times_horizontal
                           else R.layout.widget_prayer_times

            val views = RemoteViews(context.packageName, layoutId)
            views.setTextViewText(R.id.tv_fajr_time, prefs.getString("widget_fajr_time", "--:--"))
            views.setTextViewText(R.id.tv_dhuhr_time, prefs.getString("widget_dhuhr_time", "--:--"))
            views.setTextViewText(R.id.tv_asr_time, prefs.getString("widget_asr_time", "--:--"))
            views.setTextViewText(R.id.tv_maghrib_time, prefs.getString("widget_maghrib_time", "--:--"))
            views.setTextViewText(R.id.tv_isha_time, prefs.getString("widget_isha_time", "--:--"))
            if (useHorizontal) {
                val nextName = prefs.getString("widget_next_prayer_name", "") ?: ""
                views.setTextViewText(R.id.tv_next_name, nextName.ifEmpty { "Next" })
                views.setTextViewText(R.id.tv_next_time, prefs.getString("widget_next_prayer_time", "--:--"))
                views.setTextViewText(R.id.tv_city, prefs.getString("widget_city", ""))

                val indicators = mapOf(
                    "Fajr" to R.id.indicator_fajr,
                    "Dhuhr" to R.id.indicator_dhuhr,
                    "Asr" to R.id.indicator_asr,
                    "Maghrib" to R.id.indicator_maghrib,
                    "Isha" to R.id.indicator_isha,
                )
                for ((name, id) in indicators) {
                    views.setViewVisibility(id, if (name == nextName) View.VISIBLE else View.GONE)
                }
            }

            val intent = Intent(context, MainActivity::class.java).apply {
                putExtra("deeplink_tab", 0)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pi = PendingIntent.getActivity(context, 1, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            views.setOnClickPendingIntent(R.id.widget_root, pi)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
