package com.example.athan_call_to_success

import com.google.android.gms.cast.framework.CastContext
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

open class MainActivity : FlutterFragmentActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		try {
			CastContext.getSharedInstance(applicationContext)
		} catch (e: Exception) {
			// Cast context may not be available in all scenarios
			e.printStackTrace()
		}
	}
}
