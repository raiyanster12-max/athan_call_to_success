package com.example.athan_call_to_success

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import com.google.android.gms.cast.framework.CastContext
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val TAG = "MainActivity"

open class MainActivity : FlutterFragmentActivity() {
    private var deeplinkChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Ensure the activity can show over the lockscreen and wake the screen
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            CastContext.getSharedInstance(applicationContext)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        // Deeplink Channel
        deeplinkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEPLINK_CHANNEL)
        deeplinkChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialTab" -> {
                    val tab = intent?.getIntExtra("deeplink_tab", -1) ?: -1
                    result.success(tab)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val tab = intent.getIntExtra("deeplink_tab", -1)
        if (tab >= 0) {
            deeplinkChannel?.invokeMethod("navigateToTab", tab)
        }
    }

    /*
    override fun onMessageReceived(messageEvent: MessageEvent) {
        Log.d(TAG, "onMessageReceived path: ${messageEvent.path}")
        when (messageEvent.path) {
            "/tracker_update" -> {
                val jsonStr = String(messageEvent.data)
                runOnUiThread {
                    wearChannel?.invokeMethod("onTrackerUpdatedFromWatch", jsonStr)
                }
            }
            "/request_sync" -> {
                runOnUiThread {
                    wearChannel?.invokeMethod("onRequestSync", null)
                }
            }
            "/stop_athan" -> {
                runOnUiThread {
                    wearChannel?.invokeMethod("onStopAthanFromWatch", null)
                }
            }
        }
    }

    private fun syncDataToWatch(jsonStr: String) {
        val putDataReq = PutDataMapRequest.create("/athan_sync").run {
            dataMap.putString("data_json", jsonStr)
            dataMap.putLong("timestamp", System.currentTimeMillis())
            asPutDataRequest()
        }
        putDataReq.setUrgent()
        val dataClient = Wearable.getDataClient(this)
        dataClient.putDataItem(putDataReq)
            .addOnSuccessListener { Log.d(TAG, "Successfully synced data to watch") }
            .addOnFailureListener { e -> Log.e(TAG, "Failed to sync data: $e") }
    }

    private fun sendAthanNotificationToWatch(prayerName: String) {
        val messageClient = Wearable.getMessageClient(this)
        val data = prayerName.toByteArray()
        Wearable.getNodeClient(this).connectedNodes.addOnSuccessListener { nodes ->
            for (node in nodes) {
                messageClient.sendMessage(node.id, "/athan_notification", data)
            }
        }
    }

    private fun sendStopAthanToWatch() {
        val messageClient = Wearable.getMessageClient(this)
        Wearable.getNodeClient(this).connectedNodes.addOnSuccessListener { nodes ->
            for (node in nodes) {
                messageClient.sendMessage(node.id, "/stop_athan", null)
            }
        }
    }
    */

    companion object {
        const val DEEPLINK_CHANNEL = "com.example.athan/deeplink"
    }
}
