package com.example.athan_call_to_success

import android.content.Intent
import com.google.android.gms.cast.framework.CastContext
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

open class MainActivity : FlutterFragmentActivity() {
    private var deeplinkChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            CastContext.getSharedInstance(applicationContext)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        deeplinkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
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

    companion object {
        const val CHANNEL = "com.example.athan/deeplink"
    }
}
