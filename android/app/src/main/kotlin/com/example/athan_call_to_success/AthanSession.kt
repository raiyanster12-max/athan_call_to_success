package com.example.athan_call_to_success

import android.content.Intent
import androidx.car.app.Screen
import androidx.car.app.Session

/**
 * Manages the lifecycle of the Athan app inside an Android Auto session.
 *
 * [onCreateScreen] returns the [HomeScreen], which is the root of the
 * in-car navigation stack.
 */
class AthanSession : Session() {
    override fun onCreateScreen(intent: Intent): Screen =
        HomeScreen(carContext)
}
