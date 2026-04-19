package com.example.athan_call_to_success

import android.annotation.SuppressLint
import android.content.Context
import android.location.Location
import android.location.LocationManager
import android.util.Log
import androidx.car.app.CarAppService
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.LongMessageTemplate
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.car.app.validation.HostValidator
import java.util.Calendar
import java.util.TimeZone
import kotlin.math.abs
import kotlin.math.acos
import kotlin.math.asin
import kotlin.math.atan
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.math.tan

private const val TAG = "AthanCar"

// ── Mecca coordinates ────────────────────────────────────────────────────────
private const val MECCA_LAT = 21.4225
private const val MECCA_LON = 39.8262

// ── Qibla helpers ────────────────────────────────────────────────────────────

/** Great-circle bearing from (lat, lon) to Mecca — degrees clockwise from North. */
private fun qiblaBearing(lat: Double, lon: Double): Double {
    val φ1 = Math.toRadians(lat)
    val φ2 = Math.toRadians(MECCA_LAT)
    val Δλ = Math.toRadians(MECCA_LON - lon)
    val x = sin(Δλ) * cos(φ2)
    val y = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
    return (Math.toDegrees(atan2(x, y)) + 360.0) % 360.0
}

/** Haversine distance from (lat, lon) to Mecca in km. */
private fun distanceToMeccaKm(lat: Double, lon: Double): Int {
    val R = 6371.0
    val dLat = Math.toRadians(MECCA_LAT - lat)
    val dLon = Math.toRadians(MECCA_LON - lon)
    val a = sin(dLat / 2) * sin(dLat / 2) +
            cos(Math.toRadians(lat)) * cos(Math.toRadians(MECCA_LAT)) *
            sin(dLon / 2) * sin(dLon / 2)
    return (2.0 * R * asin(sqrt(a))).toInt()
}

/** Abbreviated compass cardinal from a bearing in degrees. */
private fun cardinal(deg: Double): String = when {
    deg < 22.5 || deg >= 337.5 -> "N"
    deg < 67.5  -> "NE"
    deg < 112.5 -> "E"
    deg < 157.5 -> "SE"
    deg < 202.5 -> "S"
    deg < 247.5 -> "SW"
    deg < 292.5 -> "W"
    else        -> "NW"
}

// ── Prayer-time solar calculation ─────────────────────────────────────────────
//   Method : Muslim World League (Fajr −18°, Isha −17°), Shafi Asr (shadow × 1)
//   Reference: https://aa.usno.navy.mil/faq/sun_approx

private data class PrayerTimesData(
    val fajr: String,
    val sunrise: String,
    val dhuhr: String,
    val asr: String,
    val maghrib: String,
    val isha: String,
)

private fun calcPrayers(lat: Double, lon: Double): PrayerTimesData {
    val cal     = Calendar.getInstance()
    val tzHours = TimeZone.getDefault().getOffset(cal.timeInMillis) / 3_600_000.0
    val year    = cal.get(Calendar.YEAR)
    val month   = cal.get(Calendar.MONTH) + 1
    val day     = cal.get(Calendar.DAY_OF_MONTH)

    // Julian Date
    val yJ = if (month <= 2) year - 1 else year
    val mJ = if (month <= 2) month + 12 else month
    val A  = yJ / 100
    val B  = 2 - A + A / 4
    val jd = (365.25 * (yJ + 4716)).toLong() +
             (30.6001 * (mJ + 1)).toLong() +
             day + B - 1524.5

    val D  = jd - 2451545.0
    val g  = Math.toRadians((357.529 + 0.98560028 * D) % 360.0)
    val q  = (280.459 + 0.98564736 * D) % 360.0
    val L  = Math.toRadians((q + 1.915 * sin(g) + 0.020 * sin(2.0 * g)) % 360.0)
    val e  = Math.toRadians(23.439 - 0.00000036 * D)
    val ra = Math.toDegrees(atan2(cos(e) * sin(L), cos(L))) / 15.0
    val declRad = asin(sin(e) * sin(L))          // declination in radians
    val eqt = q / 15.0 - ra                      // equation of time, hours

    // Solar noon in local clock time
    val transit = 12.0 - eqt - lon / 15.0 + tzHours

    // Hour angle for a given altitude angle (degrees) → time hours
    fun hourAngle(altDeg: Double): Double {
        val cosH = (sin(Math.toRadians(altDeg)) -
                sin(Math.toRadians(lat)) * sin(declRad)) /
                (cos(Math.toRadians(lat)) * cos(declRad))
        return if (cosH < -1.0 || cosH > 1.0) Double.NaN
               else Math.toDegrees(acos(cosH)) / 15.0
    }

    // Shafi Asr altitude: acot(1 + tan|φ − δ|)
    val asrAlt = Math.toDegrees(
        atan(1.0 / (1.0 + tan(abs(Math.toRadians(lat) - declRad))))
    )

    fun fmt(h: Double): String {
        if (h.isNaN()) return "N/A"
        val norm = ((h % 24.0) + 24.0) % 24.0
        val hh   = norm.toInt()
        val mm   = ((norm - hh) * 60.0).toInt()
        val sfx  = if (hh < 12) "AM" else "PM"
        val h12  = if (hh % 12 == 0) 12 else hh % 12
        return "%d:%02d %s".format(h12, mm, sfx)
    }

    return PrayerTimesData(
        fajr    = fmt(transit - hourAngle(-18.0)),
        sunrise = fmt(transit - hourAngle(-0.8333)),
        dhuhr   = fmt(transit + 0.033),
        asr     = fmt(transit + hourAngle(asrAlt)),
        maghrib = fmt(transit + hourAngle(-0.8333)),
        isha    = fmt(transit + hourAngle(-17.0)),
    )
}

// ── Location helper ───────────────────────────────────────────────────────────
// Uses the phone-side GPS that was already granted via ACCESS_FINE_LOCATION.
// Cannot prompt for new permissions from the car screen — permissions must be
// granted in the phone app first.

@SuppressLint("MissingPermission")
private fun lastKnownLocation(context: Context): Location? = runCatching {
    val lm = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    listOf(
        LocationManager.GPS_PROVIDER,
        LocationManager.NETWORK_PROVIDER,
        LocationManager.PASSIVE_PROVIDER,
    ).mapNotNull { provider ->
        runCatching { lm.getLastKnownLocation(provider) }.getOrNull()
    }.maxByOrNull { it.time }
}.getOrNull()

// ── Car App Service ───────────────────────────────────────────────────────────

class AthanCarAppService : CarAppService() {
    override fun onCreateSession(): Session = AthanCarSession()
    override fun createHostValidator(): HostValidator =
        HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
}

private class AthanCarSession : Session() {
    override fun onCreateScreen(intent: android.content.Intent): Screen {
        Log.d(TAG, "onCreateScreen")
        return CarHomeScreen(carContext)
    }
}

// ── Main menu ─────────────────────────────────────────────────────────────────

private class CarHomeScreen(ctx: CarContext) : Screen(ctx) {
    override fun onGetTemplate(): ListTemplate {
        Log.d(TAG, "CarHomeScreen: onGetTemplate")
        val list = ItemList.Builder()
            .addItem(
                Row.Builder()
                    .setTitle("Prayer Times")
                    .addText("Today's Fajr → Isha schedule")
                    .setBrowsable(true)
                    .setOnClickListener {
                        Log.d(TAG, "CarHomeScreen → CarPrayerTimesScreen")
                        screenManager.push(CarPrayerTimesScreen(carContext))
                    }
                    .build(),
            )
            .addItem(
                Row.Builder()
                    .setTitle("Qibla Direction")
                    .addText("Bearing & distance to Mecca")
                    .setBrowsable(true)
                    .setOnClickListener {
                        Log.d(TAG, "CarHomeScreen → CarQiblaScreen")
                        screenManager.push(CarQiblaScreen(carContext))
                    }
                    .build(),
            )
            .addItem(
                Row.Builder()
                    .setTitle("Quran Audio")
                    .addText("Listen to Quran recitation")
                    .setBrowsable(true)
                    .setOnClickListener {
                        Log.d(TAG, "CarHomeScreen → CarQuranScreen")
                        screenManager.push(CarQuranScreen(carContext))
                    }
                    .build(),
            )
            .build()

        return ListTemplate.Builder()
            .setTitle("Athan — Call to Success")
            .setHeaderAction(Action.APP_ICON)
            .setSingleList(list)
            .build()
    }
}

// ── Prayer Times screen ───────────────────────────────────────────────────────

private class CarPrayerTimesScreen(ctx: CarContext) : Screen(ctx) {
    override fun onGetTemplate(): ListTemplate {
        Log.d(TAG, "CarPrayerTimesScreen: onGetTemplate")
        val loc    = lastKnownLocation(carContext)
        val lat    = loc?.latitude  ?: MECCA_LAT   // fallback: Mecca
        val lon    = loc?.longitude ?: MECCA_LON
        val source = if (loc != null) "GPS" else "Default (Mecca)"
        val pt     = calcPrayers(lat, lon)

        val list = ItemList.Builder()
            .addItem(Row.Builder().setTitle("Fajr")    .addText(pt.fajr)    .build())
            .addItem(Row.Builder().setTitle("Sunrise")  .addText(pt.sunrise) .build())
            .addItem(Row.Builder().setTitle("Dhuhr")   .addText(pt.dhuhr)   .build())
            .addItem(Row.Builder().setTitle("Asr")     .addText(pt.asr)     .build())
            .addItem(Row.Builder().setTitle("Maghrib") .addText(pt.maghrib) .build())
            .addItem(Row.Builder().setTitle("Isha")    .addText(pt.isha)    .build())
            .build()

        return ListTemplate.Builder()
            .setTitle("Prayer Times  ·  $source")
            .setHeaderAction(Action.BACK)
            .setSingleList(list)
            .build()
    }
}

// ── Qibla Direction screen ────────────────────────────────────────────────────
// Displays Qibla as a compass bearing (degrees from North) and distance to Mecca.
// No custom animations allowed in Car App Library templates; numeric data is used
// intentionally as per Android Auto safety guidelines.

private class CarQiblaScreen(ctx: CarContext) : Screen(ctx) {
    override fun onGetTemplate(): PaneTemplate {
        Log.d(TAG, "CarQiblaScreen: onGetTemplate")
        val loc   = lastKnownLocation(carContext)
        val noGps = loc == null

        val paneBuilder = Pane.Builder()
        if (noGps) {
            paneBuilder.addRow(
                Row.Builder()
                    .setTitle("Location Unavailable")
                    .addText(
                        "Open the phone app and grant location permission first. " +
                        "Android Auto cannot prompt for permissions.",
                    )
                    .build(),
            )
        } else {
            val bearing = qiblaBearing(loc!!.latitude, loc.longitude)
            val distKm  = distanceToMeccaKm(loc.latitude, loc.longitude)
            val card    = cardinal(bearing)

            paneBuilder
                .addRow(
                    Row.Builder()
                        .setTitle("Qibla Bearing")
                        .addText("%.1f° %s from North".format(bearing, card))
                        .build(),
                )
                .addRow(
                    Row.Builder()
                        .setTitle("Distance to Mecca")
                        .addText("%,d km".format(distKm))
                        .build(),
                )
                .addRow(
                    Row.Builder()
                        .setTitle("How to Use")
                        .addText(
                            "Turn to face %.0f° on your car compass to face Mecca.".format(bearing),
                        )
                        .build(),
                )
        }

        return PaneTemplate.Builder(paneBuilder.build())
            .setTitle("Qibla Direction")
            .setHeaderAction(Action.BACK)
            .build()
    }
}

// ── Quran Audio screen ────────────────────────────────────────────────────────
// Safety rule: long-form Quran text must NOT be shown while driving.
// Uses LongMessageTemplate (Car API 2) when supported; falls back to
// MessageTemplate (Car API 1) on older hosts — both remain safe while driving.

private class CarQuranScreen(ctx: CarContext) : Screen(ctx) {
    override fun onGetTemplate(): Template {
        Log.d(TAG, "CarQuranScreen: onGetTemplate  (carAppApiLevel=${carContext.carAppApiLevel})")

        val message =
            "For driving safety, Quran text display is disabled while the vehicle is in motion.\n\n" +
            "• Select a Surah on your phone to queue audio playback.\n" +
            "• The Athan call will sound automatically at each prayer time.\n" +
            "• Audio controls are available in the media notification on your head unit."

        val openOnPhoneAction = Action.Builder()
            .setTitle("Open on Phone")
            .setOnClickListener {
                // The user is directed to interact on their handset.
                // Deep-linking from car to phone requires a PhoneCallManager
                // or a notification — left as a follow-up integration point.
                Log.d(TAG, "CarQuranScreen: Open on Phone tapped")
            }
            .build()

        // LongMessageTemplate requires Car API level 2 and is automatically
        // disabled by the host while the vehicle is moving (by design).
        return if (carContext.carAppApiLevel >= 2) {
            LongMessageTemplate.Builder(message)
                .setTitle("Quran Audio")
                .setHeaderAction(Action.BACK)
                .addAction(openOnPhoneAction)
                .build()
        } else {
            // API level 1 fallback — MessageTemplate always renders safely.
            MessageTemplate.Builder(message)
                .setTitle("Quran Audio")
                .setHeaderAction(Action.BACK)
                .addAction(openOnPhoneAction)
                .build()
        }
    }
}
