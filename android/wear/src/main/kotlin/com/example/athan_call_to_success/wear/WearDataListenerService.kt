package com.example.athan_call_to_success.wear

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

private const val TAG = "WearDataService"
private const val CHANNEL_ID = "wear_athan_alerts"
private const val NOTIFICATION_ID = 3001

class WearDataListenerService : WearableListenerService() {

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        /*
        Log.d(TAG, "onDataChanged triggered")
        for (event in dataEvents) {
            if (event.type == DataEvent.TYPE_CHANGED && event.dataItem.uri.path == "/athan_sync") {
                val dataMap = DataMapItem.fromDataItem(event.dataItem).dataMap
                val jsonStr = dataMap.getString("data_json")
                if (jsonStr != null) {
                    Log.d(TAG, "Received sync data: $jsonStr")
                    val prefs = getSharedPreferences("athan_wear_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putString("sync_data", jsonStr).apply()
                    
                    // Broadcast intent to running activities
                    val intent = Intent("com.example.athan.WEAR_DATA_UPDATED").apply {
                        setPackage(packageName)
                    }
                    sendBroadcast(intent)
                }
            }
        }
        */
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        /*
        Log.d(TAG, "onMessageReceived path: ${messageEvent.path}")
        if (messageEvent.path == "/athan_notification") {
            val prayerName = String(messageEvent.data)
            Log.d(TAG, "Received Athan notification: $prayerName")
            
            // 1. Show notification on watch
            showWatchAthanNotification(prayerName)
            
            // 2. Strong vibration on watch
            vibrateWatch()
        }
        */
    }

    private fun showWatchAthanNotification(prayerName: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Athan Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Reminders for obligatory prayers"
                enableVibration(true)
            }
            nm.createNotificationChannel(channel)
        }

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("$prayerName Athan")
            .setContentText("Time for $prayerName prayer")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)

        nm.notify(NOTIFICATION_ID, builder.build())
    }

    private fun vibrateWatch() {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Vibrate for 1.5 seconds with repeating patterns (0.5s on, 0.2s off, 0.5s on...)
            val timings = longArrayOf(0, 500, 200, 500, 200, 500)
            val amplitudes = intArrayOf(0, 255, 0, 255, 0, 255)
            vibrator.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(1500)
        }
    }
}
