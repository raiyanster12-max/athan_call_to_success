package com.example.athan_call_to_success

import android.location.Location
import android.location.LocationManager
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.Template
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin

/**
 * Android Auto screen for the Qibla Finder feature.
 *
 * Uses the last-known device location (when available) to compute the bearing
 * toward Mecca (21.4225 °N, 39.8262 °E) and displays it as a cardinal
 * direction and degree value.  When no location is available the user is
 * prompted to open the phone app for full compass functionality.
 */
class QiblaScreen(carContext: CarContext) : Screen(carContext) {

    companion object {
        private const val MECCA_LAT = 21.4225
        private const val MECCA_LON = 39.8262
    }

    override fun onGetTemplate(): Template {
        val message = buildQiblaMessage()

        return MessageTemplate.Builder(message)
            .setTitle("Qibla Finder")
            .setHeaderAction(Action.BACK)
            .addAction(
                Action.Builder()
                    .setTitle("Back")
                    .setOnClickListener { screenManager.pop() }
                    .build()
            )
            .build()
    }

    /** Attempts to resolve the user's last-known location and compute the Qibla bearing. */
    private fun buildQiblaMessage(): String {
        val location = getLastKnownLocation()
            ?: return "Unable to determine your location.\n\n" +
                    "Open the Athan app on your phone to use the interactive Qibla compass."

        val bearing = calculateQiblaBearing(location.latitude, location.longitude)
        val cardinal = bearingToCardinal(bearing)
        val degrees = bearing.toInt().let { if (it < 0) it + 360 else it }

        return "Your Qibla direction is:\n\n" +
                "$degrees° $cardinal\n\n" +
                "Open the Athan app on your phone for a real-time compass view."
    }

    @Suppress("MissingPermission")
    private fun getLastKnownLocation(): Location? {
        val lm = carContext.getSystemService(CarContext.LOCATION_SERVICE) as? LocationManager
            ?: return null
        val providers = lm.getProviders(true)
        // accuracy is a radius in metres; smaller value = more precise fix.
        return providers
            .mapNotNull { lm.getLastKnownLocation(it) }
            .minByOrNull { it.accuracy }
    }

    /**
     * Returns the initial bearing (in degrees, –180..180) from [userLat]/[userLon]
     * toward Mecca using the forward-azimuth formula.
     */
    private fun calculateQiblaBearing(userLat: Double, userLon: Double): Double {
        val lat1 = Math.toRadians(userLat)
        val lat2 = Math.toRadians(MECCA_LAT)
        val dLon = Math.toRadians(MECCA_LON - userLon)

        val x = sin(dLon) * cos(lat2)
        val y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        return Math.toDegrees(atan2(x, y))
    }

    private fun bearingToCardinal(bearing: Double): String {
        val normalized = ((bearing % 360) + 360) % 360
        return when {
            normalized < 22.5 || normalized >= 337.5 -> "N"
            normalized < 67.5 -> "NE"
            normalized < 112.5 -> "E"
            normalized < 157.5 -> "SE"
            normalized < 202.5 -> "S"
            normalized < 247.5 -> "SW"
            normalized < 292.5 -> "W"
            else -> "NW"
        }
    }
}
