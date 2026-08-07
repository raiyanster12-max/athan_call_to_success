package com.example.athan_call_to_success

import android.content.Intent
import android.util.Log
import com.google.android.gms.cast.framework.CastContext
// import com.google.android.gms.wearable.DataClient
// import com.google.android.gms.wearable.MessageClient
// import com.google.android.gms.wearable.MessageEvent
// import com.google.android.gms.wearable.PutDataMapRequest
// import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val TAG = "MainActivity"

open class MainActivity : FlutterFragmentActivity() /*, MessageClient.OnMessageReceivedListener */ {
    private var deeplinkChannel: MethodChannel? = null
    private var wearChannel: MethodChannel? = null

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

        // Wear Channel
        wearChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WEAR_CHANNEL)
        wearChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "syncData" -> {
                    /*
                    val jsonStr = call.arguments as? String
                    if (jsonStr != null) {
                        syncDataToWatch(jsonStr)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Data JSON is null", null)
                    }
                    */
                    result.success(true)
                }
                "sendAthanNotification" -> {
                    /*
                    val prayerName = call.arguments as? String
                    if (prayerName != null) {
                        sendAthanNotificationToWatch(prayerName)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Prayer name is null", null)
                    }
                    */
                    result.success(true)
                }
                "sendStopAthan" -> {
                    // sendStopAthanToWatch()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Register Wearable Listener
        // Wearable.getMessageClient(this).addListener(this)
    }

    override fun onDestroy() {
        // Wearable.getMessageClient(this).removeListener(this)
        super.onDestroy()
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
        const val WEAR_CHANNEL = "com.example.athan/wear"
    }
}
